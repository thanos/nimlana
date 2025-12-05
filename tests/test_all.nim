## Test suite for Nimlana

import unittest
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

suite "Borsh Serialization":
  test "Serialize u8":
    let value = 42.uint8
    let serialized = borshSerializeU8(value)
    check serialized.len == 1
    check serialized[0] == 42
  
  test "Serialize u32":
    let value = 0x12345678.uint32
    let serialized = borshSerializeU32(value)
    check serialized.len == 4
    # Check little-endian
    check serialized[0] == 0x78
    check serialized[3] == 0x12
  
  test "Serialize string":
    let s = "hello"
    let serialized = borshSerializeString(s)
    check serialized.len == 5 + 4  # 4 bytes for length + 5 for string
    var offset = 0
    let deserialized = borshDeserializeString(serialized, offset)
    check deserialized == s
    check offset == serialized.len
  
  test "Serialize Pubkey":
    var pk = zeroPubkey()
    pk[0] = 0xAA
    let serialized = borshSerializePubkey(pk)
    check serialized.len == 32
    check serialized[0] == 0xAA
    var offset = 0
    let deserialized = borshDeserializePubkey(serialized, offset)
    check deserialized == pk

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
    for i in 0..31:
      pubkey[i] = ED25519_TEST_VECTOR_EMPTY.publicKey[i]
    for i in 0..63:
      signature[i] = ED25519_TEST_VECTOR_EMPTY.signature[i]
    
    # Handle empty message case - convert string to bytes
    var messageBytes: seq[byte] = @[]
    if message.len > 0:
      for c in message:
        messageBytes.add(c.byte)
    
    # Verify the signature with error reporting
    let (isValid, errorCode) = verifyEd25519SignatureWithError(
      messageBytes,
      signature,
      pubkey
    )
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
    for i in 0..31:
      pubkey[i] = 0x01.byte
    for i in 0..63:
      signature[i] = 0x00.byte
    
    var messageBytes: seq[byte] = @[]
    for c in message:
      messageBytes.add(c.byte)
    
    # Verify should fail
    let isValid = verifyEd25519Signature(
      messageBytes,
      signature,
      pubkey
    )
    check isValid == false
    echo "✓ Ed25519 correctly rejects invalid signature"

