## Mock tests for recvmmsg batch packet receiving
## Tests Linux-specific optimization for batch UDP packet reception

import unittest
import chronos
import net
import std/sequtils
import ../src/nimlana/tpu
import ../src/nimlana/types
import ../src/nimlana/buffer
import ../src/nimlana/errors
import std/sets

# Mock recvmmsg implementation
# recvmmsg allows receiving multiple UDP packets in a single system call
# This is a Linux-specific optimization for high-throughput packet processing

type
  BatchPacket* = object
    data*: seq[byte]
    source*: TransportAddress
    timestamp*: float64

  MockBatchReceiver* = ref object
    batchSize*: int # Maximum packets per batch
    packets*: seq[BatchPacket] # Queue of packets to return
    currentBatch*: int # Current batch index
    totalReceived*: int # Total packets received

proc newMockBatchReceiver*(batchSize: int = 10): MockBatchReceiver =
  ## Create a mock batch receiver
  result = MockBatchReceiver(
    batchSize: batchSize, packets: @[], currentBatch: 0, totalReceived: 0
  )

proc addPacket*(
    receiver: MockBatchReceiver, data: seq[byte], source: TransportAddress
) =
  ## Add a packet to the mock receiver queue
  receiver.packets.add(
    BatchPacket(
      data: data, source: source, timestamp: 0.0 # Will be set by ingestor
    )
  )

proc receiveBatch*(receiver: MockBatchReceiver): seq[BatchPacket] =
  ## Simulate recvmmsg batch receive
  ## Returns up to batchSize packets in a single "system call"
  var batch: seq[BatchPacket] = @[]
  let startIdx = receiver.currentBatch * receiver.batchSize
  let endIdx = min(startIdx + receiver.batchSize, receiver.packets.len)

  if startIdx < receiver.packets.len:
    for i in startIdx ..< endIdx:
      batch.add(receiver.packets[i])
    receiver.currentBatch.inc()
    receiver.totalReceived += batch.len

  result = batch

proc hasMorePackets*(receiver: MockBatchReceiver): bool =
  ## Check if there are more packets to receive
  let startIdx = receiver.currentBatch * receiver.batchSize
  result = startIdx < receiver.packets.len

proc reset*(receiver: MockBatchReceiver) =
  ## Reset the batch receiver
  receiver.currentBatch = 0
  receiver.totalReceived = 0

# Mock TPU ingestor with batch processing
type BatchTPUIngestor* = ref object
  ingestor*: TPUIngestor # Composition instead of inheritance
  batchReceiver*: MockBatchReceiver
  batchMode*: bool

proc newBatchTPUIngestor*(
    port: Port, batchReceiver: MockBatchReceiver
): BatchTPUIngestor =
  ## Create a TPU ingestor with batch processing support
  result = BatchTPUIngestor(
    ingestor: newTPUIngestor(port), batchReceiver: batchReceiver, batchMode: true
  )

proc processBatch*(ingestor: BatchTPUIngestor): int =
  ## Process a batch of packets (simulating recvmmsg)
  let batch = ingestor.batchReceiver.receiveBatch()
  var processed = 0

  for packet in batch:
    try:
      ingestor.ingestor.handlePacket(packet.data, packet.source)
      inc processed
    except:
      # Ignore errors
      discard

  result = processed

suite "recvmmsg Mock Tests - Batch Receiving":
  test "Mock batch receiver creation":
    let receiver = newMockBatchReceiver(10)
    check receiver.batchSize == 10
    check receiver.packets.len == 0
    check receiver.totalReceived == 0

  test "Mock batch receiver add packets":
    let receiver = newMockBatchReceiver(5)
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 7:
      receiver.addPacket(@[i.byte], address)

    check receiver.packets.len == 7

  test "Mock batch receiver receive single batch":
    let receiver = newMockBatchReceiver(5)
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 3:
      receiver.addPacket(@[i.byte], address)

    let batch = receiver.receiveBatch()
    check batch.len == 3
    check receiver.totalReceived == 3
    check receiver.hasMorePackets == false

  test "Mock batch receiver receive multiple batches":
    let receiver = newMockBatchReceiver(3)
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 7:
      receiver.addPacket(@[i.byte], address)

    # First batch
    let batch1 = receiver.receiveBatch()
    check batch1.len == 3
    check receiver.totalReceived == 3
    check receiver.hasMorePackets == true

    # Second batch
    let batch2 = receiver.receiveBatch()
    check batch2.len == 3
    check receiver.totalReceived == 6
    check receiver.hasMorePackets == true

    # Third batch (partial)
    let batch3 = receiver.receiveBatch()
    check batch3.len == 1
    check receiver.totalReceived == 7
    check receiver.hasMorePackets == false

  test "Mock batch receiver empty queue":
    let receiver = newMockBatchReceiver(5)
    let batch = receiver.receiveBatch()
    check batch.len == 0
    check receiver.totalReceived == 0

  test "Mock batch receiver reset":
    let receiver = newMockBatchReceiver(5)
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 5:
      receiver.addPacket(@[i.byte], address)

    discard receiver.receiveBatch()
    check receiver.totalReceived == 5
    check receiver.currentBatch == 1

    receiver.reset()
    check receiver.totalReceived == 0
    check receiver.currentBatch == 0

suite "recvmmsg Mock Tests - TPU Integration":
  test "Batch TPU ingestor process single batch":
    let receiver = newMockBatchReceiver(5)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)
    let address = initTAddress("127.0.0.1", Port(1234))

    # Add packets to receiver
    for i in 0 ..< 3:
      receiver.addPacket(@[0x00.byte, i.byte], address)

    # Process batch
    let processed = ingestor.processBatch()
    check processed == 3
    check ingestor.ingestor.packetCount == 3

  test "Batch TPU ingestor process multiple batches":
    let receiver = newMockBatchReceiver(3)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)
    let address = initTAddress("127.0.0.1", Port(1234))

    # Add 7 packets
    for i in 0 ..< 7:
      receiver.addPacket(@[0x00.byte, i.byte], address)

    # Process first batch
    let processed1 = ingestor.processBatch()
    check processed1 == 3
    check ingestor.ingestor.packetCount == 3

    # Process second batch
    let processed2 = ingestor.processBatch()
    check processed2 == 3
    check ingestor.ingestor.packetCount == 6

    # Process third batch (partial)
    let processed3 = ingestor.processBatch()
    check processed3 == 1
    check ingestor.ingestor.packetCount == 7

  test "Batch TPU ingestor with bundle packets":
    let receiver = newMockBatchReceiver(5)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)
    let address = initTAddress("127.0.0.1", Port(1234))
    var bundleCount = 0

    ingestor.ingestor.onBundle = proc(packet: IngestedPacket) {.gcsafe.} =
      inc bundleCount

    # Add mix of normal and bundle packets
    receiver.addPacket(@[0x00.byte, 0x01.byte], address) # Normal
    receiver.addPacket(@[0x01.byte, 0x02.byte], address) # Bundle
    receiver.addPacket(@[0x00.byte, 0x03.byte], address) # Normal
    receiver.addPacket(@[0x01.byte, 0x04.byte], address) # Bundle

    let processed = ingestor.processBatch()
    check processed == 4
    check ingestor.ingestor.packetCount == 4
    check ingestor.ingestor.bundleCount == 2
    check bundleCount == 2

  test "Batch TPU ingestor deduplication across batches":
    let receiver = newMockBatchReceiver(3)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)
    let address = initTAddress("127.0.0.1", Port(1234))

    # Add duplicate packets
    let packetData = @[0x00.byte, 0x01.byte, 0x02.byte]
    receiver.addPacket(packetData, address)
    receiver.addPacket(packetData, address) # Duplicate
    receiver.addPacket(@[0x00.byte, 0x03.byte], address) # Different

    let processed = ingestor.processBatch()
    check processed == 3 # All processed, but one is duplicate
    check ingestor.ingestor.packetCount == 2 # Only 2 unique packets counted

  test "Batch TPU ingestor with empty batch":
    let receiver = newMockBatchReceiver(5)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)

    let processed = ingestor.processBatch()
    check processed == 0
    check ingestor.ingestor.packetCount == 0

  test "Batch TPU ingestor performance simulation":
    # Simulate high-throughput scenario
    let receiver = newMockBatchReceiver(10)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)
    let address = initTAddress("127.0.0.1", Port(1234))

    # Add 100 packets
    for i in 0 ..< 100:
      receiver.addPacket(@[0x00.byte, i.byte], address)

    # Process in batches (10 batches of 10 packets each)
    var totalProcessed = 0
    while receiver.hasMorePackets():
      let processed = ingestor.processBatch()
      totalProcessed += processed

    check totalProcessed == 100
    check ingestor.ingestor.packetCount == 100
    check receiver.totalReceived == 100

suite "recvmmsg Mock Tests - Edge Cases":
  test "Batch receiver with batch size larger than packets":
    let receiver = newMockBatchReceiver(100)
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 5:
      receiver.addPacket(@[i.byte], address)

    let batch = receiver.receiveBatch()
    check batch.len == 5
    check receiver.hasMorePackets == false

  test "Batch receiver with exactly batch size packets":
    let receiver = newMockBatchReceiver(5)
    let address = initTAddress("127.0.0.1", Port(1234))

    for i in 0 ..< 5:
      receiver.addPacket(@[i.byte], address)

    let batch = receiver.receiveBatch()
    check batch.len == 5
    check receiver.hasMorePackets == false

  test "Batch TPU ingestor with error handling":
    let receiver = newMockBatchReceiver(5)
    let ingestor = newBatchTPUIngestor(Port(9999), receiver)
    let address = initTAddress("127.0.0.1", Port(1234))

    # Add valid and invalid packets
    receiver.addPacket(@[0x00.byte, 0x01.byte], address) # Valid
    receiver.addPacket(@[], address)
      # Empty (handlePacket skips it, but it's still in batch)
    receiver.addPacket(@[0x00.byte, 0x02.byte], address) # Valid

    let processed = ingestor.processBatch()
    # All 3 packets are processed (empty one is handled but skipped internally)
    check processed == 3
    # But only 2 are counted (empty packet is skipped in handlePacket)
    check ingestor.ingestor.packetCount == 2
