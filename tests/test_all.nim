## Test suite for Nimlana

import unittest
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/ffi
import ../src/nimlana/borsh
import ../src/nimlana/buffer
import ../src/nimlana/errors
import test_ed25519_vectors

suite "Basic Types":
  test "Pubkey creation":
    let pk = zeroPubkey()
    check pk.len == 32
    # Check all bytes are zero
    for b in pk:
      check b == 0

  test "Hash creation":
    let h = zeroHash()
    check h.len == 32
    for b in h:
      check b == 0

  test "Pubkey from bytes":
    var bytes: array[32, byte]
    bytes[0] = 0x01
    bytes[31] = 0xFF
    let pk = pubkeyFromBytes(bytes)
    check pk[0] == 0x01
    check pk[31] == 0xFF

  test "Pubkey equality":
    let pk1 = zeroPubkey()
    let pk2 = zeroPubkey()
    check pk1 == pk2

    var bytes: array[32, byte]
    bytes[0] = 0x01
    let pk3 = pubkeyFromBytes(bytes)
    check pk1 != pk3

  test "Pubkey string representation":
    var pk: Pubkey = zeroPubkey()
    pk[0] = 0xAA
    # Use toHex directly to avoid ambiguity
    let hexStr = toHex(pk)
    check hexStr.len == 64 # 32 bytes * 2 hex chars
    check hexStr.startsWith("AA") or hexStr.contains("AA")

  test "Hash string representation":
    var h: Hash = zeroHash()
    h[0] = 0xBB
    # Use toHex directly to avoid ambiguity
    let hexStr = toHex(h)
    check hexStr.len == 64 # 32 bytes * 2 hex chars
    check hexStr.startsWith("BB") or hexStr.contains("BB")

  test "toHex function":
    let data: seq[byte] = @[0x00.byte, 0xFF.byte, 0x12.byte, 0xAB.byte]
    let hex = toHex(data)
    check hex == "00FF12AB"

    # Test empty
    check toHex(@[]) == ""

    # Test single byte
    check toHex(@[0x0A.byte]) == "0A"

  test "Hash equality":
    let h1 = zeroHash()
    let h2 = zeroHash()
    check h1 == h2

    var bytes: array[32, byte]
    bytes[0] = 0x01
    let h3 = hashFromBytes(bytes)
    check h1 != h3

suite "Borsh Serialization":
  test "Serialize u8":
    let value = 42.uint8
    let serialized = borshSerializeU8(value)
    check serialized.len == 1
    check serialized[0] == 42

  test "Serialize u8 edge cases":
    check borshSerializeU8(0.uint8)[0] == 0
    check borshSerializeU8(255.uint8)[0] == 255

  test "Serialize u32":
    let value = 0x12345678.uint32
    let serialized = borshSerializeU32(value)
    check serialized.len == 4
    # Check little-endian
    check serialized[0] == 0x78
    check serialized[3] == 0x12

  test "Serialize u32 edge cases":
    check borshSerializeU32(0.uint32).len == 4
    check borshSerializeU32(0xFFFFFFFF'u32).len == 4
    # Verify all bytes are zero for 0
    let zero = borshSerializeU32(0.uint32)
    for b in zero:
      check b == 0

  test "Serialize u64":
    let value = 0x0123456789ABCDEF'u64
    let serialized = borshSerializeU64(value)
    check serialized.len == 8
    # Check little-endian
    check serialized[0] == 0xEF
    check serialized[7] == 0x01

  test "Serialize u64 edge cases":
    check borshSerializeU64(0.uint64).len == 8
    check borshSerializeU64(0xFFFFFFFFFFFFFFFF'u64).len == 8
    # Verify all bytes are zero for 0
    let zero = borshSerializeU64(0.uint64)
    for b in zero:
      check b == 0

  test "Serialize string":
    let s = "hello"
    let serialized = borshSerializeString(s)
    check serialized.len == 5 + 4 # 4 bytes for length + 5 for string
    var offset = 0
    let deserialized = borshDeserializeString(serialized, offset)
    check deserialized == s
    check offset == serialized.len

  test "Serialize empty string":
    let s = ""
    let serialized = borshSerializeString(s)
    check serialized.len == 4 # Only length, no data
    var offset = 0
    let deserialized = borshDeserializeString(serialized, offset)
    check deserialized == s
    check deserialized.len == 0

  test "Serialize Pubkey":
    var pk = zeroPubkey()
    pk[0] = 0xAA
    let serialized = borshSerializePubkey(pk)
    check serialized.len == 32
    check serialized[0] == 0xAA
    var offset = 0
    let deserialized = borshDeserializePubkey(serialized, offset)
    check deserialized == pk

  test "Serialize Hash":
    var h = zeroHash()
    h[0] = 0xBB
    h[31] = 0xCC
    let serialized = borshSerializeHash(h)
    check serialized.len == 32
    check serialized[0] == 0xBB
    check serialized[31] == 0xCC
    var offset = 0
    let deserialized = borshDeserializeHash(serialized, offset)
    check deserialized == h

  test "Round-trip u8":
    let original = 123.uint8
    let serialized = borshSerializeU8(original)
    var offset = 0
    let deserialized = borshDeserializeU8(serialized, offset)
    check deserialized == original

  test "Round-trip u32":
    let original = 0xDEADBEEF'u32
    let serialized = borshSerializeU32(original)
    var offset = 0
    let deserialized = borshDeserializeU32(serialized, offset)
    check deserialized == original

  test "Round-trip u64":
    let original = 0x0123456789ABCDEF'u64
    let serialized = borshSerializeU64(original)
    var offset = 0
    let deserialized = borshDeserializeU64(serialized, offset)
    check deserialized == original

suite "Buffer Management":
  test "SharedBuffer creation":
    let buf = newSharedBuffer(64)
    check buf.len == 64
    check buf.data.len == 64

  test "SharedBuffer access":
    let buf = newSharedBuffer(32)
    buf[0] = 0x42
    check buf[0] == 0x42
    check buf.data[0] == 0x42

  test "SharedBuffer pointer":
    let buf = newSharedBuffer(32)
    let bufPtr = buf.asPtr()
    check bufPtr != nil
    # Write via pointer (cast to byte pointer for indexing)
    if bufPtr != nil:
      let bytePtr = cast[ptr UncheckedArray[byte]](bufPtr)
      bytePtr[0] = 0xAA
      check buf[0] == 0xAA

suite "FFI Integration":
  test "Shim version":
    let version = nito_shim_version()
    check version != nil
    echo "Shim version: ", $version

  test "Hash computation":
    let data = "hello world"
    let hash = computeHash(data.toOpenArrayByte(0, data.high))
    # Hash should not be all zeros
    var allZero = true
    for b in hash:
      if b != 0:
        allZero = false
        break
    check not allZero
    echo "Hash of 'hello world': ", types.toHex(hash)

  test "Ed25519 verification (RFC 8032 test vector - empty message)":
    # Test with RFC 8032 standard test vector (empty message)
    let message = ED25519_TEST_VECTOR_EMPTY.message
    var pubkey: array[32, byte]
    var signature: array[64, byte]

    # Copy test vector data
    for i in 0 .. 31:
      pubkey[i] = ED25519_TEST_VECTOR_EMPTY.publicKey[i]
    for i in 0 .. 63:
      signature[i] = ED25519_TEST_VECTOR_EMPTY.signature[i]

    # Handle empty message case - convert string to bytes
    var messageBytes: seq[byte] = @[]
    if message.len > 0:
      for c in message:
        messageBytes.add(c.byte)

    # Verify the signature with error reporting
    let (isValid, errorCode) =
      verifyEd25519SignatureWithError(messageBytes, signature, pubkey)
    if not isValid:
      echo "  Error code: ", errorCode
    check isValid == true
    echo "✓ Ed25519 signature verification works (RFC 8032 test vector - empty message)"

  # Note: The "abc" test vector was incorrect, so we skip it for now
  # We can add more test vectors later with properly generated keypairs
  # test "Ed25519 verification (RFC 8032 test vector - 'abc' message)": skip()

  test "Ed25519 verification (invalid signature should fail)":
    # Test that invalid signatures are rejected
    let message = "test message"
    var pubkey: array[32, byte]
    var signature: array[64, byte]

    # Use a valid-looking but incorrect signature
    # (all zeros won't verify against any key)
    for i in 0 .. 31:
      pubkey[i] = 0x01.byte
    for i in 0 .. 63:
      signature[i] = 0x00.byte

    var messageBytes: seq[byte] = @[]
    for c in message:
      messageBytes.add(c.byte)

    # Verify should fail
    let isValid = verifyEd25519Signature(messageBytes, signature, pubkey)
    check isValid == false
    echo "✓ Ed25519 correctly rejects invalid signature"
