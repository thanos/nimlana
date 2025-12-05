## Tests for bundle parsing functionality

import unittest
import chronos
import net
import ../src/nimlana/types
import ../src/nimlana/borsh
import ../src/nimlana/buffer
import ../src/nimlana/tpu
import ../src/nimlana/bundle
import ../src/nimlana/errors

suite "Bundle Parsing":
  test "Parse simple transaction":
    # Create a minimal transaction: 1 signature (64 bytes) + message
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    # Add signature (64 bytes)
    for i in 0 ..< 64:
      txData.add(i.byte)
    # Add message data
    txData.add(0x01.byte)
    txData.add(0x02.byte)

    let parsed = parseTransaction(txData)
    check parsed.signatures.len == 1
    check parsed.message.len == 2
    check parsed.rawData.len == txData.len

  test "Parse transaction with multiple signatures":
    var txData: seq[byte] = @[]
    txData.add(2.byte) # 2 signatures
    # Add first signature
    for i in 0 ..< 64:
      txData.add(i.byte)
    # Add second signature
    for i in 64 ..< 128:
      txData.add(i.byte)
    # Add message
    txData.add(0xAA.byte)

    let parsed = parseTransaction(txData)
    check parsed.signatures.len == 2
    check parsed.message.len == 1
    check parsed.signatures[0][0] == 0
    check parsed.signatures[1][0] == 64

  test "Parse transaction with no signatures should fail":
    var txData: seq[byte] = @[0.byte] # 0 signatures
    expect(SerializationError):
      discard parseTransaction(txData)

  test "Parse transaction with insufficient data should fail":
    var txData: seq[byte] = @[1.byte] # 1 signature but no data
    expect(SerializationError):
      discard parseTransaction(txData)

  test "Extract tip payment (placeholder)":
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    for i in 0 ..< 64:
      txData.add(i.byte)
    txData.add(0x01.byte) # message

    let parsed = parseTransaction(txData)
    let (tipAccount, tipAmount) = extractTipPayment(parsed)

    # Placeholder returns no tip - just check tipAmount
    check tipAmount == 0

  test "Parse bundle packet":
    # Create a bundle packet: 0x01 (marker) + transaction length + transaction
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker

    # Add transaction length (u32, little-endian)
    let txLen = 70'u32 # 1 byte sig count + 64 bytes sig + 5 bytes message
    bundleData.add(borshSerializeU32(txLen))

    # Add transaction: 1 signature + 64 bytes sig + message
    bundleData.add(1.byte)
    for i in 0 ..< 64:
      bundleData.add(i.byte)
    bundleData.add(0x01.byte)
    bundleData.add(0x02.byte)
    bundleData.add(0x03.byte)
    bundleData.add(0x04.byte)
    bundleData.add(0x05.byte)

    # Create IngestedPacket
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    let parsed = parseBundle(packet)
    check parsed.transactions.len == 1
    check parsed.transactions[0].signatures.len == 1
    check parsed.tipAmount == 0 # No tip extracted yet

  test "Parse bundle with multiple transactions":
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker

    # First transaction: length 70
    bundleData.add(borshSerializeU32(70'u32))
    bundleData.add(1.byte) # 1 signature
    for i in 0 ..< 64:
      bundleData.add(i.byte)
    for i in 0 ..< 5:
      bundleData.add(i.byte)

    # Second transaction: length 70
    bundleData.add(borshSerializeU32(70'u32))
    bundleData.add(1.byte) # 1 signature
    for i in 64 ..< 128:
      bundleData.add(i.byte)
    for i in 5 ..< 10:
      bundleData.add(i.byte)

    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    let parsed = parseBundle(packet)
    check parsed.transactions.len == 2
    check parsed.transactions[0].signatures[0][0] == 0
    check parsed.transactions[1].signatures[0][0] == 64

  test "Parse bundle with invalid header should fail":
    var bundleData: seq[byte] = @[0x00.byte] # NormalTransaction, not BundleMarker
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: NormalTransaction,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    expect(SerializationError):
      discard parseBundle(packet)

  test "Parse bundle with invalid transaction length should fail":
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(borshSerializeU32(2000'u32)) # Invalid length > 1280
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    expect(SerializationError):
      discard parseBundle(packet)

  test "Convert ParsedBundle to Bundle":
    var parsed =
      ParsedBundle(transactions: @[], tipAccount: zeroPubkey(), tipAmount: 1000'u64)

    # Add a parsed transaction
    var txData: seq[byte] = @[]
    txData.add(1.byte)
    for i in 0 ..< 64:
      txData.add(i.byte)
    txData.add(0x01.byte)

    let parsedTx = parseTransaction(txData)
    parsed.transactions.add(parsedTx)

    let bundle = toBundle(parsed)
    check bundle.transactions.len == 1
    check bundle.tipAccount == zeroPubkey()
    check bundle.tipAmount == 1000'u64
    check bundle.transactions[0].len == txData.len

suite "Bundle Parsing Edge Cases":
  test "Parse bundle with zero-length transaction should skip":
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(borshSerializeU32(0'u32)) # Zero length

    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    expect(SerializationError):
      discard parseBundle(packet)

  test "Parse bundle with incomplete transaction length":
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(0x01.byte) # Only 1 byte of length, need 4

    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    # Should handle gracefully (break out of loop)
    let parsed = parseBundle(packet)
    check parsed.transactions.len == 0

  test "Parse bundle with incomplete transaction data":
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(borshSerializeU32(100'u32)) # Length 100
    bundleData.add(1.byte) # Only partial data

    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )

    expect(SerializationError):
      discard parseBundle(packet)
