## Comprehensive tests for tpu.nim
## Tests all TPU functionality, edge cases, and error paths

import unittest
import chronos
import net
import std/sets
import std/times
import ../src/nimlana/types
import ../src/nimlana/tpu
import ../src/nimlana/buffer
import ../src/nimlana/errors

suite "Packet Header Parsing":
  test "parsePacketHeader - NormalTransaction":
    var data: seq[byte] = @[0x00.byte]
    check parsePacketHeader(data) == NormalTransaction

  test "parsePacketHeader - BundleMarker":
    var data: seq[byte] = @[0x01.byte]
    check parsePacketHeader(data) == BundleMarker

  test "parsePacketHeader - VoteTransaction":
    var data: seq[byte] = @[0x02.byte]
    check parsePacketHeader(data) == VoteTransaction

  test "parsePacketHeader - Unknown":
    var data: seq[byte] = @[0xFF.byte]
    check parsePacketHeader(data) == Unknown

    data = @[0x03.byte]
    check parsePacketHeader(data) == Unknown

    data = @[0x80.byte]
    check parsePacketHeader(data) == Unknown

  test "parsePacketHeader - Empty data":
    var data: seq[byte] = @[]
    check parsePacketHeader(data) == Unknown

  test "parsePacketHeader - Multiple bytes (uses first)":
    var data: seq[byte] = @[0x01.byte, 0x00.byte, 0x02.byte]
    check parsePacketHeader(data) == BundleMarker

suite "Packet Hash Computation":
  test "computePacketHash - Small packet":
    var data: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    let hash = computePacketHash(data)
    check hash != zeroHash()

  test "computePacketHash - Same data produces same hash":
    var data: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    let hash1 = computePacketHash(data)
    let hash2 = computePacketHash(data)
    check hash1 == hash2

  test "computePacketHash - Different data produces different hash":
    var data1: seq[byte] = @[0x00.byte, 0x01.byte]
    var data2: seq[byte] = @[0x00.byte, 0x02.byte]
    let hash1 = computePacketHash(data1)
    let hash2 = computePacketHash(data2)
    check hash1 != hash2

  test "computePacketHash - Large packet (uses first 128 bytes)":
    var largeData: seq[byte] = @[]
    for i in 0 ..< 200:
      largeData.add(i.byte)

    let hash1 = computePacketHash(largeData)
    let hash2 = computePacketHash(largeData[0 .. 127])
    check hash1 == hash2

  test "computePacketHash - Exactly 128 bytes":
    var data: seq[byte] = @[]
    for i in 0 ..< 128:
      data.add(i.byte)
    let hash = computePacketHash(data)
    check hash != zeroHash()

  test "computePacketHash - 129 bytes (truncates to 128)":
    var data: seq[byte] = @[]
    for i in 0 ..< 129:
      data.add(i.byte)
    let hash1 = computePacketHash(data)
    let hash2 = computePacketHash(data[0 .. 127])
    check hash1 == hash2

suite "TPU Ingestor Creation":
  test "newTPUIngestor - Basic creation":
    let ingestor = newTPUIngestor(Port(9999))
    check ingestor.port == Port(9999)
    check ingestor.running == false
    check ingestor.packetCount == 0
    check ingestor.bundleCount == 0
    check ingestor.socket == nil
    check ingestor.dedupSet.card == 0

  test "newTPUIngestor - Different ports":
    let ingestor1 = newTPUIngestor(Port(8001))
    let ingestor2 = newTPUIngestor(Port(8002))
    check ingestor1.port != ingestor2.port

suite "Packet Handling":
  test "handlePacket - Empty packet":
    let ingestor = newTPUIngestor(Port(9999))
    let emptyData: seq[byte] = @[]
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(emptyData, address)
    check ingestor.packetCount == 0

  test "handlePacket - Normal transaction":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0x00.byte]
    for i in 1 ..< 50:
      packetData.add(i.byte)
    let expectedLen = packetData.len

    var packetCalled = false
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      packetCalled = true
      check packet.header == NormalTransaction
      check packet.data.len == expectedLen

    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)

    check ingestor.packetCount == 1
    check ingestor.bundleCount == 0
    check packetCalled == true

  test "handlePacket - Bundle marker":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0x01.byte]
    for i in 1 ..< 50:
      packetData.add(i.byte)

    var bundleCalled = false
    ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      bundleCalled = true
      check packet.header == BundleMarker

    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)

    check ingestor.packetCount == 1
    check ingestor.bundleCount == 1
    check bundleCalled == true

  test "handlePacket - Vote transaction":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0x02.byte]
    for i in 1 ..< 50:
      packetData.add(i.byte)

    var packetCalled = false
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      packetCalled = true
      check packet.header == VoteTransaction

    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)

    check ingestor.packetCount == 1
    check packetCalled == true

  test "handlePacket - Unknown header":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0xFF.byte]
    for i in 1 ..< 50:
      packetData.add(i.byte)

    var packetCalled = false
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      packetCalled = true
      check packet.header == Unknown

    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)

    check ingestor.packetCount == 1
    check packetCalled == true

  test "handlePacket - Timestamp is set":
    let ingestor = newTPUIngestor(Port(9999))
    var receivedTimestamp: float64 = 0.0

    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      receivedTimestamp = packet.timestamp

    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)

    check receivedTimestamp > 0.0

  test "handlePacket - Source address is preserved":
    let ingestor = newTPUIngestor(Port(9999))
    var receivedSource: TransportAddress = initTAddress("0.0.0.0", Port(0))

    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      receivedSource = packet.source

    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("192.168.1.1", Port(5432))
    ingestor.handlePacket(packetData, address)

    check receivedSource.address == address.address

suite "Deduplication":
  test "handlePacket - Duplicate packets are skipped":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0x00.byte, 0x01.byte, 0x02.byte]
    let address = initTAddress("127.0.0.1", Port(1234))

    var callCount = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount

    # First packet
    ingestor.handlePacket(packetData, address)
    check ingestor.packetCount == 1
    check callCount == 1

    # Duplicate packet
    ingestor.handlePacket(packetData, address)
    check ingestor.packetCount == 1 # Count doesn't increase
    check callCount == 1 # Callback not called again

  test "handlePacket - Different packets are not deduplicated":
    let ingestor = newTPUIngestor(Port(9999))
    let address = initTAddress("127.0.0.1", Port(1234))

    var callCount = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount

    var packet1: seq[byte] = @[0x00.byte, 0x01.byte]
    var packet2: seq[byte] = @[0x00.byte, 0x02.byte]

    ingestor.handlePacket(packet1, address)
    ingestor.handlePacket(packet2, address)

    check ingestor.packetCount == 2
    check callCount == 2

  test "handlePacket - Deduplication set grows":
    let ingestor = newTPUIngestor(Port(9999))
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 10:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      ingestor.handlePacket(packetData, address)

    check ingestor.dedupSet.card == 10

suite "Callback Behavior":
  test "handlePacket - onPacket callback with nil":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.onPacket = nil

    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    # Should not crash
    ingestor.handlePacket(packetData, address)
    check ingestor.packetCount == 1

  test "handlePacket - onBundle callback with nil":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.onBundle = nil

    var bundleData: seq[byte] = @[0x01.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    # Should not crash
    ingestor.handlePacket(bundleData, address)
    check ingestor.bundleCount == 1

  test "handlePacket - Both callbacks set":
    let ingestor = newTPUIngestor(Port(9999))
    var packetCalled = false
    var bundleCalled = false

    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      packetCalled = true

    ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      bundleCalled = true

    # Normal packet
    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)
    check packetCalled == true
    check bundleCalled == false

    # Reset
    packetCalled = false
    bundleCalled = false

    # Bundle packet
    var bundleData: seq[byte] = @[0x01.byte]
    ingestor.handlePacket(bundleData, address)
    check packetCalled == false
    check bundleCalled == true

suite "Statistics":
  test "getStats - Initial state":
    let ingestor = newTPUIngestor(Port(9999))
    let (packets, bundles, dedupSize) = ingestor.getStats()
    check packets == 0
    check bundles == 0
    check dedupSize == 0

  test "getStats - After processing packets":
    let ingestor = newTPUIngestor(Port(9999))
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 5:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      ingestor.handlePacket(packetData, address)

    let (packets, bundles, dedupSize) = ingestor.getStats()
    check packets == 5
    check bundles == 0
    check dedupSize == 5

  test "getStats - After processing bundles":
    let ingestor = newTPUIngestor(Port(9999))
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 3:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      ingestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize) = ingestor.getStats()
    check packets == 3
    check bundles == 3
    check dedupSize == 3

  test "getStats - Mixed packets and bundles":
    let ingestor = newTPUIngestor(Port(9999))
    let address = initTAddress("127.0.0.1", Port(1234))

    # Add normal packets
    for i in 0 ..< 4:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      ingestor.handlePacket(packetData, address)

    # Add bundles
    for i in 0 ..< 2:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      ingestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize) = ingestor.getStats()
    check packets == 6
    check bundles == 2
    check dedupSize == 6

suite "Stop Functionality":
  test "stop - Sets running to false":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.running = true
    ingestor.stop()
    check ingestor.running == false

  test "stop - With nil socket":
    let ingestor = newTPUIngestor(Port(9999))
    ingestor.running = true
    ingestor.socket = nil
    # Should not crash
    ingestor.stop()
    check ingestor.running == false

suite "Edge Cases":
  test "handlePacket - Very large packet":
    let ingestor = newTPUIngestor(Port(9999))
    var largeData: seq[byte] = @[0x00.byte]
    for i in 1 ..< 1000:
      largeData.add(i.byte)

    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(largeData, address)
    check ingestor.packetCount == 1

  test "handlePacket - Single byte packet":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)
    check ingestor.packetCount == 1

  test "handlePacket - Maximum size packet (1280 bytes)":
    let ingestor = newTPUIngestor(Port(9999))
    var packetData: seq[byte] = @[0x00.byte]
    for i in 1 ..< 1280:
      packetData.add(i.byte)

    let address = initTAddress("127.0.0.1", Port(1234))
    ingestor.handlePacket(packetData, address)
    check ingestor.packetCount == 1

  test "handlePacket - Different source addresses":
    let ingestor = newTPUIngestor(Port(9999))
    var callCount = 0
    ingestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      inc callCount

    var packetData: seq[byte] = @[0x00.byte, 0x01.byte]
    let address1 = initTAddress("127.0.0.1", Port(1234))
    let address2 = initTAddress("192.168.1.1", Port(5678))

    ingestor.handlePacket(packetData, address1)
    ingestor.handlePacket(packetData, address2)

    # Same packet data, different source - still deduplicated
    check ingestor.packetCount == 1
    check callCount == 1

  test "handlePacket - Many unique packets":
    let ingestor = newTPUIngestor(Port(9999))
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 100:
      var packetData: seq[byte] = @[0x00.byte]
      packetData.add((i mod 256).byte)
      packetData.add((i div 256).byte)
      ingestor.handlePacket(packetData, address)

    check ingestor.packetCount == 100
    check ingestor.dedupSet.card == 100

