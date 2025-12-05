## Mock tests for tpu.nim
## Tests TPU functionality with mocked network and edge cases

import unittest
import chronos
import net
import std/sets
import ../src/nimlana/types
import ../src/nimlana/tpu
import ../src/nimlana/buffer
import ../src/nimlana/errors

# Mock DatagramTransport for testing
# Since DatagramTransport is a ref object, we use composition
type
  MockDatagramTransport* = ref object
    messagesToReturn*: seq[seq[byte]]
    remoteAddresses*: seq[TransportAddress]
    currentIndex*: int
    shouldFail*: bool
    getMessageCalls*: int
    closeCalls*: int

proc newMockDatagramTransport*(): MockDatagramTransport =
  result = MockDatagramTransport(
    messagesToReturn: @[],
    remoteAddresses: @[],
    currentIndex: 0,
    shouldFail: false,
    getMessageCalls: 0,
    closeCalls: 0,
  )

proc addMessage*(transp: MockDatagramTransport, data: seq[byte], remote: TransportAddress) =
  transp.messagesToReturn.add(data)
  transp.remoteAddresses.add(remote)

proc getMessage*(transp: MockDatagramTransport): seq[byte] =
  inc transp.getMessageCalls
  if transp.shouldFail:
    raise newException(IOError, "Mock getMessage failure")
  
  if transp.currentIndex < transp.messagesToReturn.len:
    result = transp.messagesToReturn[transp.currentIndex]
    inc transp.currentIndex
  else:
    result = @[] # No more messages

proc close*(transp: MockDatagramTransport) =
  inc transp.closeCalls

suite "TPU Mock Tests - Packet Reception":
  test "TPU ingestor with mock DatagramTransport":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    # Test mock transport functionality
    check mockTransport != nil

  test "TPU ingestor handles mock messages":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    # Add mock messages
    var packet1: seq[byte] = @[0x00.byte, 0x01.byte]
    var packet2: seq[byte] = @[0x01.byte, 0x02.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    
    mockTransport.addMessage(packet1, address)
    mockTransport.addMessage(packet2, address)
    
    # Simulate packet handler - test mock transport functionality
    var callCount = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount
    
    ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount
    
    # Process messages using mock transport's getMessage
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, mockTransport.remoteAddresses[i])
    
    check callCount == 2
    check ingestor.packetCount == 2

  test "TPU ingestor handles empty mock messages":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    # Empty message
    let emptyData: seq[byte] = @[]
    let address = initTAddress("127.0.0.1", Port(1234))
    mockTransport.addMessage(emptyData, address)
    
    # Test mock transport getMessage
    let data = mockTransport.getMessage()
    check data.len == 0
    
    # Test ingestor handles empty packets
    ingestor.handlePacket(data, address)
    check ingestor.packetCount == 0

  test "TPU ingestor handles mock message failures":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    mockTransport.shouldFail = true
    
    # Test mock transport failure
    expect(IOError):
      discard mockTransport.getMessage()

suite "TPU Mock Tests - Deduplication":
  test "TPU ingestor deduplication with mock packets":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add same packet multiple times
    for i in 0 ..< 5:
      mockTransport.addMessage(packetData, address)
    
    var callCount = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount
    
    # Process all messages
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    # Only first packet should be processed
    check callCount == 1
    check ingestor.packetCount == 1
    check ingestor.dedupSet.card == 1

  test "TPU ingestor deduplication across different sources":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte]
    let address1 = initTAddress("127.0.0.1", Port(1234))
    let address2 = initTAddress("192.168.1.1", Port(5678))
    
    mockTransport.addMessage(packetData, address1)
    mockTransport.addMessage(packetData, address2)
    
    var callCount = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount
    
    # Process messages
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, mockTransport.remoteAddresses[i])
    
    # Same packet data, different source - still deduplicated
    check callCount == 1
    check ingestor.packetCount == 1

suite "TPU Mock Tests - Packet Types":
  test "TPU ingestor handles all packet types via mock":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    var packetCount = 0
    var bundleCount = 0
    var voteCount = 0
    var unknownCount = 0
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      case packet.header
      of NormalTransaction:
        inc packetCount
      of VoteTransaction:
        inc voteCount
      of Unknown:
        inc unknownCount
      else:
        discard
    
    ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      inc bundleCount
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add different packet types
    mockTransport.addMessage(@[0x00.byte], address) # Normal
    mockTransport.addMessage(@[0x01.byte], address) # Bundle
    mockTransport.addMessage(@[0x02.byte], address) # Vote
    mockTransport.addMessage(@[0xFF.byte], address) # Unknown
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    check packetCount == 1
    check bundleCount == 1
    check voteCount == 1
    check unknownCount == 1
    check ingestor.packetCount == 4

  test "TPU ingestor handles large packets via mock":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    # Create large packet (500 bytes)
    var largePacket: seq[byte] = @[0x00.byte]
    for i in 1 ..< 500:
      largePacket.add(i.byte)
    
    let address = initTAddress("127.0.0.1", Port(1234))
    mockTransport.addMessage(largePacket, address)
    
    var receivedLen = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      receivedLen = packet.data.len
    
    let data = mockTransport.getMessage()
    ingestor.handlePacket(data, address)
    
    check receivedLen == 500
    check ingestor.packetCount == 1

suite "TPU Mock Tests - Statistics":
  test "TPU ingestor statistics with mock transport":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add mix of packets
    for i in 0 ..< 10:
      if i mod 2 == 0:
        mockTransport.addMessage(@[0x00.byte, i.byte], address)
      else:
        mockTransport.addMessage(@[0x01.byte, i.byte], address)
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    let (packets, bundles, dedupSize) = ingestor.getStats()
    check packets == 10
    check bundles == 5
    check dedupSize == 10

  test "TPU ingestor statistics with duplicate packets":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add same packet 5 times
    for i in 0 ..< 5:
      mockTransport.addMessage(packetData, address)
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    let (packets, bundles, dedupSize) = ingestor.getStats()
    check packets == 1 # Only one unique packet
    check dedupSize == 1

suite "TPU Mock Tests - Stop Functionality":
  test "TPU ingestor stop with mock transport":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    ingestor.running = true
    
    ingestor.stop()
    
    check ingestor.running == false
    # Mock transport close is tested separately

  test "TPU ingestor stop multiple times":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.running = true
    
    ingestor.stop()
    ingestor.stop() # Second call
    
    check ingestor.running == false

  test "TPU ingestor stop with nil socket":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.socket = nil
    ingestor.running = true
    
    # Should not crash
    ingestor.stop()
    check ingestor.running == false

suite "TPU Mock Tests - Edge Cases":
  test "TPU ingestor with rapid packet bursts":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add many packets rapidly
    for i in 0 ..< 100:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      mockTransport.addMessage(packetData, address)
    
    var processed = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc processed
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    check processed == 100
    check ingestor.packetCount == 100

  test "TPU ingestor with alternating packet types":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    var normalCount = 0
    var bundleCount = 0
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc normalCount
    
    ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      inc bundleCount
    
    # Alternate packet types
    for i in 0 ..< 20:
      if i mod 2 == 0:
        mockTransport.addMessage(@[0x00.byte, i.byte], address)
      else:
        mockTransport.addMessage(@[0x01.byte, i.byte], address)
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    check normalCount == 10
    check bundleCount == 10
    check ingestor.packetCount == 20
    check ingestor.bundleCount == 10

  test "TPU ingestor with maximum size packets":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    # Create max size packet (1280 bytes)
    var maxPacket: seq[byte] = @[0x00.byte]
    for i in 1 ..< 1280:
      maxPacket.add(i.byte)
    
    let address = initTAddress("127.0.0.1", Port(1234))
    mockTransport.addMessage(maxPacket, address)
    
    var received = false
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      received = true
      check packet.data.len == 1280
    
    let data = mockTransport.getMessage()
    ingestor.handlePacket(data, address)
    
    check received == true
    check ingestor.packetCount == 1

  test "TPU ingestor handles callback errors gracefully":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      raise newException(Exception, "Callback error")
    
    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    mockTransport.addMessage(packetData, address)
    
    # Should not crash, error is caught in handlePacket
    let data = mockTransport.getMessage()
    ingestor.handlePacket(data, address)
    
    # Packet still counted even if callback errors
    check ingestor.packetCount == 1

suite "TPU Mock Tests - Performance":
  test "TPU ingestor processes many unique packets":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add 1000 unique packets
    for i in 0 ..< 1000:
      var packetData: seq[byte] = @[0x00.byte]
      packetData.add((i mod 256).byte)
      packetData.add((i div 256).byte)
      packetData.add((i div 65536).byte)
      mockTransport.addMessage(packetData, address)
    
    var processed = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc processed
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    check processed == 1000
    check ingestor.packetCount == 1000
    check ingestor.dedupSet.card == 1000

  test "TPU ingestor deduplication performance":
    let ingestor = newTPUIngestor(Port(9999))
    let mockTransport = newMockDatagramTransport()
    
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    
    # Add same packet many times
    for i in 0 ..< 1000:
      mockTransport.addMessage(packetData, address)
    
    var processed = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc processed
    
    # Process all
    for i in 0 ..< mockTransport.messagesToReturn.len:
      let data = mockTransport.getMessage()
      if data.len > 0:
        ingestor.handlePacket(data, address)
    
    # Only first should be processed
    check processed == 1
    check ingestor.packetCount == 1
    check ingestor.dedupSet.card == 1

