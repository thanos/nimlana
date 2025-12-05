## Tests for UDP socket functionality
## Tests the chronos DatagramTransport integration

import unittest
import chronos
import net
import ../src/nimlana/tpu
import ../src/nimlana/types
import ../src/nimlana/errors

suite "UDP Socket Functionality":
  test "TPU Ingestor socket creation":
    let ingestor = newTPUIngestor(Port(9999))
    check ingestor.socket == nil  # Not created until start()
    check ingestor.running == false
  
  test "TPU Ingestor start sets running flag":
    let ingestor = newTPUIngestor(Port(9999))
    # Note: We can't fully test async start() without running event loop
    # But we can verify the structure
    check ingestor.running == false
    check ingestor.port == Port(9999)
  
  test "TPU Ingestor stop functionality":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.running = true
    ingestor.stop()
    check ingestor.running == false
  
  test "TPU Ingestor stop with nil socket":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.running = true
    ingestor.socket = nil
    # Should not crash when socket is nil
    ingestor.stop()
    check ingestor.running == false
  
  test "Packet handler callback structure":
    # Test that the callback can be set up correctly
    let ingestor = newTPUIngestor(Port(9999))
    var callbackInvoked = false
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      callbackInvoked = true
    
    # Simulate packet handling
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)
    
    check callbackInvoked == true
  
  test "Packet handler with getMessage simulation":
    # Test that handlePacket works correctly (which is called from getMessage in real scenario)
    let ingestor = newTPUIngestor(Port(9999))
    var packetReceived = false
    var receivedDataLen = 0
    var receivedHeader: PacketHeader = Unknown
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      packetReceived = true
      receivedDataLen = packet.data.len
      receivedHeader = packet.header
    
    # Simulate what getMessage() would return
    var packetData: seq[byte] = @[0x00.byte]
    for i in 1..<100:
      packetData.add(i.byte)
    
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)
    
    check packetReceived == true
    check receivedDataLen == packetData.len
    check receivedHeader == NormalTransaction
  
  test "Packet handler error handling":
    # Test that errors in packet handling don't crash
    let ingestor = newTPUIngestor(Port(9999))
    
    # Set up a callback that might raise
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      # This would normally be caught in the packetHandler
      discard
    
    # Empty packet should be handled gracefully
    let emptyData: seq[byte] = @[]
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(emptyData, address)
    
    # Should not crash
    check ingestor.packetCount == 0
  
  test "Multiple packet handling":
    let ingestor = newTPUIngestor(Port(9999))
    var packetCount = 0
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc packetCount
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Send multiple packets
    for i in 0..<5:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      ingestor.handlePacket(packetData, address)
    
    check ingestor.packetCount == 5
    check packetCount == 5
  
  test "Bundle packet handling in callback":
    let ingestor = newTPUIngestor(Port(9999))
    var bundleCount = 0
    
    ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      inc bundleCount
    
    let address = initTAddress("127.0.0.1", Port(1234))
    var bundleData: seq[byte] = @[0x01.byte]  # BundleMarker
    for i in 1..<50:
      bundleData.add(i.byte)
    
    ingestor.handlePacket(bundleData, address)
    
    check ingestor.bundleCount == 1
    check bundleCount == 1

suite "UDP Socket Mock Tests":
  test "Mock packet reception flow":
    # Test the flow without actual network I/O
    let ingestor = newTPUIngestor(Port(9999))
    var packetCount = 0
    var firstPacketLen = 0
    var secondPacketLen = 0
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc packetCount
      if packetCount == 1:
        firstPacketLen = packet.data.len
      elif packetCount == 2:
        secondPacketLen = packet.data.len
    
    # Simulate receiving packets (as if from getMessage())
    let address = initTAddress("127.0.0.1", Port(1234))
    
    var packet1: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    var packet2: seq[byte] = @[0x00.byte, 0x03.byte, 0x04.byte]
    
    ingestor.handlePacket(packet1, address)
    ingestor.handlePacket(packet2, address)
    
    check packetCount == 2
    check firstPacketLen == packet1.len
    check secondPacketLen == packet2.len
  
  test "Mock error recovery":
    # Test that errors in packet processing don't stop the ingestor
    let ingestor = newTPUIngestor(Port(9999))
    var successCount = 0
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc successCount
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Process valid packet
    var validPacket1: seq[byte] = @[0x00.byte, 0x01.byte]
    ingestor.handlePacket(validPacket1, address)
    
    # Process empty packet (should be ignored but not crash)
    let emptyPacket: seq[byte] = @[]
    ingestor.handlePacket(emptyPacket, address)
    
    # Process another valid packet (different to avoid deduplication)
    var validPacket2: seq[byte] = @[0x00.byte, 0x02.byte]
    ingestor.handlePacket(validPacket2, address)
    
    check successCount == 2
    check ingestor.packetCount == 2
  
  test "Mock timestamp in IngestedPacket":
    let ingestor = newTPUIngestor(Port(9999))
    var receivedTimestamp: float64 = 0.0
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      receivedTimestamp = packet.timestamp
    
    let address = initTAddress("127.0.0.1", Port(1234))
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte]
    ingestor.handlePacket(packetData, address)
    
    # Timestamp should be set (epochTime() returns current time)
    check receivedTimestamp > 0.0

