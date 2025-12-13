## Tests for CRDS (Cluster Repair and Discovery Service) module

import unittest
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/borsh

suite "CRDS Data Structures":
  test "Create ContactInfo":
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    check contactInfo.id[0] == 0x01
    check contactInfo.wallclock == 1234567890'u64
    check contactInfo.shredVersion == 12345'u16

  test "Serialize and deserialize ContactInfo":
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    let serialized = serializeContactInfo(contactInfo)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeContactInfo(serialized, offset)
    check deserialized.id[0] == 0x01
    check deserialized.wallclock == 1234567890'u64
    check deserialized.shredVersion == 12345'u16

  test "Create Vote":
    var vote = Vote()
    vote.fromPubkey = types.zeroPubkey()
    vote.wallclock = 1234567890'u64
    vote.fromPubkey[0] = 0x02
    vote.vote.slots = @[100'u64, 101'u64, 102'u64]
    vote.vote.hash = types.zeroHash()
    vote.vote.hash[0] = 0x03
    vote.vote.timestamp = 1234567890'u64
    
    check vote.fromPubkey[0] == 0x02
    check vote.vote.slots.len == 3
    check vote.vote.hash[0] == 0x03

  test "Serialize and deserialize Vote":
    var vote = Vote()
    vote.fromPubkey = types.zeroPubkey()
    vote.wallclock = 1234567890'u64
    vote.fromPubkey[0] = 0x02
    vote.vote.slots = @[100'u64, 101'u64, 102'u64]
    vote.vote.hash = types.zeroHash()
    vote.vote.hash[0] = 0x03
    vote.vote.timestamp = 1234567890'u64
    
    let serialized = serializeVote(vote)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeVote(serialized, offset)
    check deserialized.fromPubkey[0] == 0x02
    check deserialized.vote.slots.len == 3
    check deserialized.vote.slots[0] == 100'u64
    check deserialized.vote.hash[0] == 0x03

  test "Serialize and deserialize CrdsValue (ContactInfo)":
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo.id = types.zeroPubkey()
    value.contactInfo.id[0] = 0x01
    value.contactInfo.wallclock = 1234567890'u64
    value.contactInfo.shredVersion = 12345'u16
    
    let serialized = serializeCrdsValue(value)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeCrdsValue(serialized, offset)
    check deserialized.kind == CrdsContactInfo
    check deserialized.contactInfo.id[0] == 0x01

  test "Serialize and deserialize CrdsValue (Vote)":
    var value = CrdsValue(kind: CrdsVote)
    value.vote.fromPubkey = types.zeroPubkey()
    value.vote.fromPubkey[0] = 0x02
    value.vote.vote.slots = @[100'u64, 101'u64]
    value.vote.vote.hash = types.zeroHash()
    value.vote.vote.timestamp = 1234567890'u64
    value.vote.wallclock = 1234567890'u64
    
    let serialized = serializeCrdsValue(value)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeCrdsValue(serialized, offset)
    check deserialized.kind == CrdsVote
    check deserialized.vote.fromPubkey[0] == 0x02
    check deserialized.vote.vote.slots.len == 2

  test "Validate CrdsValue (ContactInfo)":
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo.id = types.zeroPubkey()
    value.contactInfo.wallclock = 0'u64  # Invalid: zero wallclock
    
    let (isValid, errorMsg) = validateCrdsValue(value)
    check not isValid
    check "zero wallclock" in errorMsg or "zero pubkey" in errorMsg

  test "Validate CrdsValue (Vote)":
    var value = CrdsValue(kind: CrdsVote)
    value.vote.fromPubkey = types.zeroPubkey()  # Invalid: zero pubkey
    value.vote.vote.slots = @[]  # Invalid: no slots
    
    let (isValid, errorMsg) = validateCrdsValue(value)
    check not isValid
    check "zero pubkey" in errorMsg or "no slots" in errorMsg

