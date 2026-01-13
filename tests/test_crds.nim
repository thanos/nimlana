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
      gossip: newSocketAddr("127.0.0.1", 8001'u16),
      tvu: newSocketAddr("127.0.0.1", 8002'u16),
      tpu: newSocketAddr("127.0.0.1", 8003'u16),
      tpuForwards: newSocketAddr("127.0.0.1", 8004'u16),
      tpuVote: newSocketAddr("127.0.0.1", 8005'u16),
      rpc: newSocketAddr("127.0.0.1", 8006'u16),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007'u16),
      serveRepair: newSocketAddr("127.0.0.1", 8008'u16),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    check contactInfo.id[0] == 0x01
    check contactInfo.gossip.port == 8001'u16
    check contactInfo.wallclock == 1234567890'u64
    check contactInfo.shredVersion == 12345'u16

  test "Serialize and deserialize ContactInfo":
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      gossip: newSocketAddr("127.0.0.1", 8001'u16),
      tvu: newSocketAddr("127.0.0.1", 8002'u16),
      tpu: newSocketAddr("127.0.0.1", 8003'u16),
      tpuForwards: newSocketAddr("127.0.0.1", 8004'u16),
      tpuVote: newSocketAddr("127.0.0.1", 8005'u16),
      rpc: newSocketAddr("127.0.0.1", 8006'u16),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007'u16),
      serveRepair: newSocketAddr("127.0.0.1", 8008'u16),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    let serialized = serializeContactInfo(contactInfo)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeContactInfo(serialized, offset)
    check deserialized.id[0] == 0x01
    check deserialized.gossip.port == 8001'u16
    check deserialized.tvu.port == 8002'u16
    check deserialized.tpu.port == 8003'u16
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

  test "Serialize and deserialize EpochSlots":
    var epochSlots = EpochSlots()
    epochSlots.fromPubkey = types.zeroPubkey()
    epochSlots.fromPubkey[0] = 0x03
    epochSlots.slots = @[100'u64, 101'u64, 102'u64]
    epochSlots.wallclock = 1234567890'u64
    
    let serialized = serializeEpochSlots(epochSlots)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeEpochSlots(serialized, offset)
    check deserialized.fromPubkey[0] == 0x03
    check deserialized.slots.len == 3
    check deserialized.slots[0] == 100'u64
    check deserialized.wallclock == 1234567890'u64

  test "Serialize and deserialize LegacyVersion":
    var legacyVersion = LegacyVersion()
    legacyVersion.fromPubkey = types.zeroPubkey()
    legacyVersion.fromPubkey[0] = 0x04
    legacyVersion.version = 12345'u32
    legacyVersion.wallclock = 1234567890'u64
    
    let serialized = serializeLegacyVersion(legacyVersion)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeLegacyVersion(serialized, offset)
    check deserialized.fromPubkey[0] == 0x04
    check deserialized.version == 12345'u32
    check deserialized.wallclock == 1234567890'u64

  test "Serialize and deserialize LegacyContactInfo":
    var legacyContactInfo = LegacyContactInfo()
    legacyContactInfo.id = types.zeroPubkey()
    legacyContactInfo.id[0] = 0x05
    legacyContactInfo.wallclock = 1234567890'u64
    
    let serialized = serializeLegacyContactInfo(legacyContactInfo)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeLegacyContactInfo(serialized, offset)
    check deserialized.id[0] == 0x05
    check deserialized.wallclock == 1234567890'u64

  test "Serialize and deserialize CrdsValue (EpochSlots)":
    var value = CrdsValue(kind: CrdsEpochSlots)
    value.epochSlots.fromPubkey = types.zeroPubkey()
    value.epochSlots.fromPubkey[0] = 0x03
    value.epochSlots.slots = @[100'u64, 101'u64]
    value.epochSlots.wallclock = 1234567890'u64
    
    let serialized = serializeCrdsValue(value)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeCrdsValue(serialized, offset)
    check deserialized.kind == CrdsEpochSlots
    check deserialized.epochSlots.fromPubkey[0] == 0x03
    check deserialized.epochSlots.slots.len == 2

  test "Serialize and deserialize CrdsValue (LegacyVersion)":
    var value = CrdsValue(kind: CrdsLegacyVersion)
    value.legacyVersion.fromPubkey = types.zeroPubkey()
    value.legacyVersion.fromPubkey[0] = 0x04
    value.legacyVersion.version = 12345'u32
    value.legacyVersion.wallclock = 1234567890'u64
    
    let serialized = serializeCrdsValue(value)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeCrdsValue(serialized, offset)
    check deserialized.kind == CrdsLegacyVersion
    check deserialized.legacyVersion.fromPubkey[0] == 0x04
    check deserialized.legacyVersion.version == 12345'u32

  test "Serialize and deserialize CrdsValue (LegacyContactInfo)":
    var value = CrdsValue(kind: CrdsLegacyContactInfo)
    value.legacyContactInfo.id = types.zeroPubkey()
    value.legacyContactInfo.id[0] = 0x05
    value.legacyContactInfo.wallclock = 1234567890'u64
    
    let serialized = serializeCrdsValue(value)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeCrdsValue(serialized, offset)
    check deserialized.kind == CrdsLegacyContactInfo
    check deserialized.legacyContactInfo.id[0] == 0x05

  test "Validate CrdsValue (EpochSlots)":
    var value = CrdsValue(kind: CrdsEpochSlots)
    value.epochSlots.fromPubkey = types.zeroPubkey()  # Invalid: zero pubkey
    value.epochSlots.slots = @[]  # Invalid: no slots
    
    let (isValid, errorMsg) = validateCrdsValue(value)
    check not isValid
    check "zero pubkey" in errorMsg or "no slots" in errorMsg

  test "Validate CrdsValue (LegacyVersion)":
    var value = CrdsValue(kind: CrdsLegacyVersion)
    value.legacyVersion.fromPubkey = types.zeroPubkey()  # Invalid: zero pubkey
    value.legacyVersion.wallclock = 0'u64  # Invalid: zero wallclock
    
    let (isValid, errorMsg) = validateCrdsValue(value)
    check not isValid
    check "zero pubkey" in errorMsg or "zero wallclock" in errorMsg

  test "Validate CrdsValue (LegacyContactInfo)":
    var value = CrdsValue(kind: CrdsLegacyContactInfo)
    value.legacyContactInfo.id = types.zeroPubkey()  # Invalid: zero pubkey
    value.legacyContactInfo.wallclock = 0'u64  # Invalid: zero wallclock
    
    let (isValid, errorMsg) = validateCrdsValue(value)
    check not isValid
    check "zero pubkey" in errorMsg or "zero wallclock" in errorMsg

