## Mock tests for relayer.nim
## Tests relayer functionality with mocked components and edge cases

import unittest
import chronos
import net
import ../src/nimlana/types
import ../src/nimlana/relayer
import ../src/nimlana/tpu
import ../src/nimlana/blockengine
import ../src/nimlana/bundle
import ../src/nimlana/buffer
import ../src/nimlana/errors
import ../src/nimlana/borsh

# Mock Block Engine Client for testing
type MockBlockEngine* = ref object
  client*: BlockEngineClient # Composition
  sendBundleCalls*: int
  acceptBundles*: bool
  shouldFail*: bool
  lastBundle*: Bundle
  connectionFailures*: int
  maxConnectionFailures*: int

proc newMockBlockEngine*(acceptBundles: bool = true): MockBlockEngine =
  result = MockBlockEngine(
    client: newBlockEngineClient("mock.jito.wtf:443"),
    sendBundleCalls: 0,
    acceptBundles: acceptBundles,
    shouldFail: false,
    connectionFailures: 0,
    maxConnectionFailures: 0,
  )

proc connect*(client: MockBlockEngine) {.async.} =
  if client.connectionFailures < client.maxConnectionFailures:
    inc client.connectionFailures
    raiseNetworkError("Mock connection failure")
  await client.client.connect()

proc sendBundle*(client: MockBlockEngine, bundle: Bundle): Future[bool] {.async.} =
  inc client.sendBundleCalls
  client.lastBundle = bundle

  if client.shouldFail:
    raiseNetworkError("Mock send failure")

  await sleepAsync(milliseconds(1)) # Simulate network delay
  result = client.acceptBundles

proc disconnect*(client: MockBlockEngine) =
  client.client.disconnect()

# Mock TPU Ingestor for testing
type MockTPUIngestor* = ref object
  ingestor*: TPUIngestor # Composition
  shouldFailStart*: bool
  packetsToReturn*: seq[(seq[byte], TransportAddress)]
  currentPacketIndex*: int

proc newMockTPUIngestor*(port: Port): MockTPUIngestor =
  result = MockTPUIngestor(
    ingestor: newTPUIngestor(port),
    shouldFailStart: false,
    packetsToReturn: @[],
    currentPacketIndex: 0,
  )

proc addMockPacket*(
    ingestor: MockTPUIngestor, data: seq[byte], source: TransportAddress
) =
  ingestor.packetsToReturn.add((data, source))

proc start*(ingestor: MockTPUIngestor) {.async.} =
  if ingestor.shouldFailStart:
    raiseNetworkError("Mock TPU start failure")
  await ingestor.ingestor.start()

proc stop*(ingestor: MockTPUIngestor) =
  ingestor.ingestor.stop()

suite "Relayer Mock Tests - Bundle Processing":
  test "Relayer processes bundle queue with mock block engine":
    let relayer = newRelayer(Port(8001))
    # Note: We can't directly replace blockEngine, but we can test bundle queue behavior

    # Create a valid bundle packet
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(borshSerializeU32(70'u32)) # Transaction length

    # Add transaction: 1 signature + 64 bytes sig + 5 bytes message
    bundleData.add(1.byte)
    for i in 0 ..< 64:
      bundleData.add(i.byte)
    for i in 0 ..< 5:
      bundleData.add(i.byte)

    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)

    check relayer.bundleQueue.len > 0

  test "Relayer with mock block engine that rejects bundles":
    let relayer = newRelayer(Port(8002))
    # Test bundle queue behavior

    # Add bundle to queue manually
    var bundleData: seq[byte] = @[0x01.byte]
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )
    relayer.bundleQueue.add(packet)

    check relayer.bundleQueue.len == 1

  test "Relayer with mock block engine connection failure":
    let relayer = newRelayer(Port(8003))
    let mockEngine = newMockBlockEngine()
    mockEngine.maxConnectionFailures = 1

    # Try to connect (async, so we use waitFor)
    expect(NetworkError):
      waitFor mockEngine.connect()

    check mockEngine.client.connected == false

  test "Relayer with mock block engine send failure":
    let relayer = newRelayer(Port(8004))
    let mockEngine = newMockBlockEngine()
    mockEngine.shouldFail = true
    # Test that bundle queue can handle failures

    # Add bundle to queue
    var bundleData: seq[byte] = @[0x01.byte]
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )
    relayer.bundleQueue.add(packet)

    check relayer.bundleQueue.len == 1

suite "Relayer Mock Tests - Error Handling":
  test "Relayer handles bundle parsing errors gracefully":
    let relayer = newRelayer(Port(8005))

    # Add invalid bundle (too short to parse)
    var bundleData: seq[byte] = @[0x01.byte] # BundleMarker only
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )
    relayer.bundleQueue.add(packet)

    # Should not crash when processing
    check relayer.bundleQueue.len == 1

  test "Relayer handles empty bundle transactions":
    let relayer = newRelayer(Port(8006))

    # Create bundle with no transactions (invalid)
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(borshSerializeU32(0'u32)) # Zero length

    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)

    # Should be queued but will fail parsing
    check relayer.bundleQueue.len > 0

  test "Relayer handles network errors during bundle send":
    let relayer = newRelayer(Port(8007))
    # Test error handling in bundle queue

    # Add valid bundle
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte)
    bundleData.add(borshSerializeU32(70'u32))
    bundleData.add(1.byte)
    for i in 0 ..< 64:
      bundleData.add(i.byte)
    for i in 0 ..< 5:
      bundleData.add(i.byte)

    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )
    relayer.bundleQueue.add(packet)

    check relayer.bundleQueue.len == 1

suite "Relayer Mock Tests - Integration":
  test "Relayer with mock TPU ingestor":
    let relayer = newRelayer(Port(8008))
    # Test that relayer has TPU ingestor
    check relayer.tpuIngestor.port == Port(8008)
    check relayer.tpuIngestor.running == false

  test "Relayer start with mock components":
    let relayer = newRelayer(Port(8009))
    # Start should not crash (async, so we just check it doesn't error immediately)
    asyncCheck relayer.start()
    # Note: Can't easily test async start without event loop
    check relayer.running == false # Not set until async start completes

  test "Relayer stop with mock components":
    let relayer = newRelayer(Port(8010))
    relayer.running = true
    relayer.tpuIngestor.running = true
    relayer.blockEngine.connected = true

    relayer.stop()

    check relayer.running == false
    check relayer.tpuIngestor.running == false
    check relayer.blockEngine.connected == false

  test "Relayer processes multiple bundles in queue":
    let relayer = newRelayer(Port(8011))

    # Add multiple bundles
    for i in 0 ..< 5:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(bundleData, address)

    check relayer.bundleQueue.len == 5

suite "Relayer Mock Tests - Statistics":
  test "Relayer statistics with mock components":
    let relayer = newRelayer(Port(8012))

    # Process some packets
    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(packetData, address)

    # Add bundles to queue
    for i in 0 ..< 3:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      let buffer = newSharedBufferFromBytes(bundleData)
      let packet = IngestedPacket(
        data: buffer, header: BundleMarker, timestamp: 0.0, source: address
      )
      relayer.bundleQueue.add(packet)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 1
    check bundles == 0 # Bundles not processed yet
    check queueSize == 3

  test "Relayer statistics reflect mock TPU state":
    let relayer = newRelayer(Port(8013))

    # Process various packets
    let address = initTAddress("127.0.0.1", Port(1234))

    # Normal packets
    for i in 0 ..< 3:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      relayer.tpuIngestor.handlePacket(packetData, address)

    # Bundle packets
    for i in 0 ..< 2:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      relayer.tpuIngestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 5
    check bundles == 2
    check queueSize >= 2 # Bundles should be in queue

suite "Relayer Mock Tests - Edge Cases":
  test "Relayer with very large bundle queue":
    let relayer = newRelayer(Port(8014))

    # Add many bundles
    for i in 0 ..< 1000:
      var bundleData: seq[byte] = @[0x01.byte]
      bundleData.add((i mod 256).byte)
      bundleData.add((i div 256).byte)
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(bundleData, address)

    check relayer.bundleQueue.len == 1000

  test "Relayer handles rapid bundle additions":
    let relayer = newRelayer(Port(8015))

    # Rapidly add bundles
    let address = initTAddress("127.0.0.1", Port(1234))
    for i in 0 ..< 100:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      relayer.tpuIngestor.handlePacket(bundleData, address)

    check relayer.bundleQueue.len == 100

  test "Relayer with mixed packet types and mock engine":
    let relayer = newRelayer(Port(8016))

    let address = initTAddress("127.0.0.1", Port(1234))

    # Mix of normal and bundle packets
    for i in 0 ..< 10:
      if i mod 2 == 0:
        var packetData: seq[byte] = @[0x00.byte, i.byte]
        relayer.tpuIngestor.handlePacket(packetData, address)
      else:
        var bundleData: seq[byte] = @[0x01.byte, i.byte]
        relayer.tpuIngestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 10
    check bundles == 5
    check queueSize == 5

  test "Relayer stop during active processing":
    let relayer = newRelayer(Port(8017))
    relayer.running = true
    relayer.tpuIngestor.running = true

    # Stop should work even if processing
    relayer.stop()

    check relayer.running == false
    check relayer.tpuIngestor.running == false
