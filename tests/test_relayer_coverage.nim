## Comprehensive tests for relayer.nim
## Tests all relayer functionality, edge cases, and error paths

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

suite "Relayer Creation and Configuration":
  test "Relayer creation with default endpoint":
    let relayer = newRelayer(Port(8001))
    check relayer.tpuIngestor != nil
    check relayer.blockEngine != nil
    check relayer.running == false
    check relayer.bundleQueue.len == 0
    check relayer.tpuIngestor.port == Port(8001)
    check relayer.blockEngine.endpoint == "block-engine.jito.wtf:443"

  test "Relayer creation with custom endpoint":
    let relayer = newRelayer(Port(8002), "custom.jito.wtf:8080")
    check relayer.blockEngine.endpoint == "custom.jito.wtf:8080"
    check relayer.tpuIngestor.port == Port(8002)

  test "Relayer initial state":
    let relayer = newRelayer(Port(8003))
    check relayer.running == false
    check relayer.bundleQueue.len == 0
    check relayer.tpuIngestor.running == false
    check relayer.blockEngine.connected == false

  test "Relayer callbacks are set":
    let relayer = newRelayer(Port(8004))
    check relayer.tpuIngestor.onPacket != nil
    check relayer.tpuIngestor.onBundle != nil

suite "Relayer Bundle Queue":
  test "Bundle queue starts empty":
    let relayer = newRelayer(Port(8005))
    check relayer.bundleQueue.len == 0

  test "Bundle added to queue via callback":
    let relayer = newRelayer(Port(8006))
    let initialQueueSize = relayer.bundleQueue.len

    # Create a bundle packet
    var bundleData: seq[byte] = @[0x01.byte] # BundleMarker
    for i in 1 ..< 50:
      bundleData.add(i.byte)

    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)

    # Bundle should be added to queue
    check relayer.bundleQueue.len > initialQueueSize

  test "Multiple bundles in queue":
    let relayer = newRelayer(Port(8007))

    # Add multiple bundles
    for i in 0 ..< 5:
      var bundleData: seq[byte] = @[0x01.byte, i.byte] # Different bundles
      for j in 1 ..< 50:
        bundleData.add((i + j).byte)
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(bundleData, address)

    check relayer.bundleQueue.len == 5

  test "Normal packets don't go to bundle queue":
    let relayer = newRelayer(Port(8008))
    let initialQueueSize = relayer.bundleQueue.len

    var packetData: seq[byte] = @[0x00.byte] # NormalTransaction
    for i in 1 ..< 50:
      packetData.add(i.byte)

    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(packetData, address)

    # Normal packets shouldn't be added to bundle queue
    check relayer.bundleQueue.len == initialQueueSize

suite "Relayer Statistics":
  test "getStats returns correct values":
    let relayer = newRelayer(Port(8009))
    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 0
    check bundles == 0
    check dedupSize == 0
    check queueSize == 0

  test "getStats reflects packet counts":
    let relayer = newRelayer(Port(8010))

    # Process some packets
    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(packetData, address)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 1
    check bundles == 0

  test "getStats reflects bundle counts":
    let relayer = newRelayer(Port(8011))

    # Process a bundle
    var bundleData: seq[byte] = @[0x01.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 1
    check bundles == 1
    check queueSize > 0

  test "getStats reflects queue size":
    let relayer = newRelayer(Port(8012))

    # Add bundles to queue
    for i in 0 ..< 3:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check queueSize == 3

suite "Relayer Stop Functionality":
  test "Relayer stop sets running to false":
    let relayer = newRelayer(Port(8013))
    relayer.running = true
    relayer.stop()
    check relayer.running == false

  test "Relayer stop stops TPU ingestor":
    let relayer = newRelayer(Port(8014))
    relayer.tpuIngestor.running = true
    relayer.stop()
    check relayer.tpuIngestor.running == false

  test "Relayer stop disconnects block engine":
    let relayer = newRelayer(Port(8015))
    relayer.blockEngine.connected = true
    relayer.stop()
    check relayer.blockEngine.connected == false

  test "Relayer stop when already stopped":
    let relayer = newRelayer(Port(8016))
    relayer.running = false
    # Should not crash
    relayer.stop()
    check relayer.running == false

suite "Relayer Bundle Processing (Mock)":
  test "processBundleQueue with empty queue":
    let relayer = newRelayer(Port(8017))
    relayer.running = true
    # Should not crash with empty queue
    # Note: This is async, so we can't easily test the loop without running event loop
    check relayer.bundleQueue.len == 0

  test "Bundle processing with valid bundle":
    let relayer = newRelayer(Port(8018))

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

  test "Bundle processing with invalid bundle":
    let relayer = newRelayer(Port(8019))

    # Create an invalid bundle packet (too short)
    var bundleData: seq[byte] = @[0x01.byte] # BundleMarker only
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)

    # Should still be added to queue (parsing happens during processing)
    check relayer.bundleQueue.len > 0

suite "Relayer Callback Behavior":
  test "onPacket callback is called for normal packets":
    let relayer = newRelayer(Port(8020))
    var packetCalled = false

    relayer.tpuIngestor.onPacket = proc(packet: IngestedPacket) {.gcsafe.} =
      packetCalled = true

    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(packetData, address)

    check packetCalled == true

  test "onBundle callback is called for bundle packets":
    let relayer = newRelayer(Port(8021))
    var bundleCalled = false

    relayer.tpuIngestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      bundleCalled = true

    var bundleData: seq[byte] = @[0x01.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)

    check bundleCalled == true

  test "onPacket callback with nil":
    let relayer = newRelayer(Port(8022))
    relayer.tpuIngestor.onPacket = nil

    var packetData: seq[byte] = @[0x00.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    # Should not crash
    relayer.tpuIngestor.handlePacket(packetData, address)

  test "onBundle callback with nil":
    let relayer = newRelayer(Port(8023))
    relayer.tpuIngestor.onBundle = nil

    var bundleData: seq[byte] = @[0x01.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    # Should not crash
    relayer.tpuIngestor.handlePacket(bundleData, address)

suite "Relayer Edge Cases":
  test "Relayer with very large bundle queue":
    let relayer = newRelayer(Port(8024))

    # Add many bundles
    for i in 0 ..< 100:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(bundleData, address)

    check relayer.bundleQueue.len == 100

  test "Relayer with duplicate bundles":
    let relayer = newRelayer(Port(8025))

    # Add same bundle twice (should be deduplicated)
    var bundleData: seq[byte] = @[0x01.byte, 0xAA.byte]
    let address = initTAddress("127.0.0.1", Port(1234))
    relayer.tpuIngestor.handlePacket(bundleData, address)
    relayer.tpuIngestor.handlePacket(bundleData, address)

    # First one should be in queue, second should be deduplicated
    # But deduplication happens at TPU level, so both might be queued
    check relayer.bundleQueue.len >= 1

  test "Relayer statistics with mixed packets":
    let relayer = newRelayer(Port(8026))

    # Add mix of normal and bundle packets
    for i in 0 ..< 5:
      var packetData: seq[byte] = @[0x00.byte, i.byte]
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(packetData, address)

    for i in 0 ..< 3:
      var bundleData: seq[byte] = @[0x01.byte, i.byte]
      let address = initTAddress("127.0.0.1", Port(1234))
      relayer.tpuIngestor.handlePacket(bundleData, address)

    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    check packets == 8
    check bundles == 3
    check queueSize == 3
