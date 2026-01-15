## Tests for Base58 encoding/decoding

import unittest
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/base58

suite "Base58 Encoding/Decoding":
  test "Encode and decode simple bytes":
    let data: seq[byte] = @[0x01.byte, 0x02.byte, 0x03.byte]
    let encoded = base58Encode(data)
    check encoded.len > 0
    check encoded != ""
    
    let decoded = base58Decode(encoded)
    check decoded.len == data.len
    check decoded == data

  test "Encode and decode empty bytes":
    let data: seq[byte] = @[]
    let encoded = base58Encode(data)
    check encoded == ""
    
    let decoded = base58Decode(encoded)
    check decoded.len == 0

  test "Encode and decode with leading zeros":
    let data: seq[byte] = @[0x00.byte, 0x00.byte, 0x01.byte, 0x02.byte]
    let encoded = base58Encode(data)
    check encoded.len > 0
    # Leading zeros should be encoded as '1' characters
    check encoded.startsWith("11")  # Two leading zeros = two '1's
    
    let decoded = base58Decode(encoded)
    check decoded.len == data.len
    check decoded == data

  test "Pubkey to Base58 and back":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x01
    pubkey[31] = 0xFF
    
    let encoded = pubkeyToBase58(pubkey)
    check encoded.len > 0
    
    let decoded = pubkeyFromBase58(encoded)
    check decoded == pubkey

  test "Pubkey from Base58 - invalid length":
    # Test with a string that doesn't decode to 32 bytes
    let invalid = "123"  # Too short
    try:
      discard pubkeyFromBase58(invalid)
      fail()
    except ValueError:
      check true

  test "Base58 decode - invalid characters":
    # Test with invalid Base58 characters (0, O, I, l)
    let invalid = "0OIl"  # These characters are not in Base58 alphabet
    let decoded = base58Decode(invalid)
    # Should return empty sequence for invalid input
    check decoded.len == 0

  test "Base58 round-trip with known Solana pubkey format":
    # Test with a typical Solana pubkey pattern
    var pubkey: array[32, byte]
    for i in 0 ..< 32:
      pubkey[i] = (i mod 256).byte
    
    let encoded = base58Encode(pubkey)
    check encoded.len > 0
    
    let decoded = base58Decode(encoded)
    check decoded.len == 32
    
    var decodedPubkey: array[32, byte]
    for i in 0 ..< 32:
      decodedPubkey[i] = decoded[i]
    
    check decodedPubkey == pubkey

  test "Pubkey to Base58 matches types.nim string conversion":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x42
    
    let base58Str = pubkeyToBase58(pubkey)
    let typesStr = base58Encode(pubkey)  # Uses base58Encode directly
    
    # Should match (both use base58Encode)
    check base58Str == typesStr
