## Tests for new CRDS types (LowestSlot, SnapshotHashes, AccountsHashes, Version, NodeInstance, DuplicateShred)

import unittest
import std/times
import ../src/nimlana/types
import ../src/nimlana/crds

suite "New CRDS Types":
  test "LowestSlot serialization/deserialization":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x01
    
    var lowestSlot = LowestSlot(
      fromPubkey: pubkey,
      lowest: 12345'u64,
      wallclock: uint64(getTime().toUnix())
    )
    
    # Serialize
    let serialized = serializeLowestSlot(lowestSlot)
    check serialized.len > 0
    
    # Deserialize
    var offset = 0
    let deserialized = deserializeLowestSlot(serialized, offset)
    check deserialized.fromPubkey == pubkey
    check deserialized.lowest == 12345'u64
    check deserialized.wallclock == lowestSlot.wallclock

  test "SnapshotHashes serialization/deserialization":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x02
    
    var fullHash = types.zeroHash()
    fullHash[0] = 0xFF
    
    var incHash1 = types.zeroHash()
    incHash1[1] = 0xAA
    
    var incHash2 = types.zeroHash()
    incHash2[2] = 0xBB
    
    var snapshotHashes = SnapshotHashes(
      fromPubkey: pubkey,
      full: SnapshotHashEntry(slot: 1000'u64, hash: fullHash),
      incremental: @[
        SnapshotHashEntry(slot: 1001'u64, hash: incHash1),
        SnapshotHashEntry(slot: 1002'u64, hash: incHash2)
      ],
      wallclock: uint64(getTime().toUnix())
    )
    
    # Serialize
    let serialized = serializeSnapshotHashes(snapshotHashes)
    check serialized.len > 0
    
    # Deserialize
    var offset = 0
    let deserialized = deserializeSnapshotHashes(serialized, offset)
    check deserialized.fromPubkey == pubkey
    check deserialized.full.slot == 1000'u64
    check deserialized.full.hash == fullHash
    check deserialized.incremental.len == 2
    check deserialized.incremental[0].slot == 1001'u64
    check deserialized.incremental[0].hash == incHash1
    check deserialized.incremental[1].slot == 1002'u64
    check deserialized.incremental[1].hash == incHash2
    check deserialized.wallclock == snapshotHashes.wallclock

  test "AccountsHashes serialization/deserialization":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x03
    
    var hash = types.zeroHash()
    hash[0] = 0xCC
    
    var accountsHashes = AccountsHashes(
      fromPubkey: pubkey,
      hash: hash,
      wallclock: uint64(getTime().toUnix())
    )
    
    # Serialize
    let serialized = serializeAccountsHashes(accountsHashes)
    check serialized.len > 0
    
    # Deserialize
    var offset = 0
    let deserialized = deserializeAccountsHashes(serialized, offset)
    check deserialized.fromPubkey == pubkey
    check deserialized.hash == hash
    check deserialized.wallclock == accountsHashes.wallclock

  test "Version serialization/deserialization":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x04
    
    var version = Version(
      fromPubkey: pubkey,
      version: "1.18.0",
      wallclock: uint64(getTime().toUnix())
    )
    
    # Serialize
    let serialized = serializeVersion(version)
    check serialized.len > 0
    
    # Deserialize
    var offset = 0
    let deserialized = deserializeVersion(serialized, offset)
    check deserialized.fromPubkey == pubkey
    check deserialized.version == "1.18.0"
    check deserialized.wallclock == version.wallclock

  test "NodeInstance serialization/deserialization":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x05
    
    var nodeInstance = NodeInstance(
      fromPubkey: pubkey,
      token: 9876543210'u64,
      wallclock: uint64(getTime().toUnix())
    )
    
    # Serialize
    let serialized = serializeNodeInstance(nodeInstance)
    check serialized.len > 0
    
    # Deserialize
    var offset = 0
    let deserialized = deserializeNodeInstance(serialized, offset)
    check deserialized.fromPubkey == pubkey
    check deserialized.token == 9876543210'u64
    check deserialized.wallclock == nodeInstance.wallclock

  test "DuplicateShred serialization/deserialization":
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x06
    
    var shredData: seq[byte] = @[]
    for i in 0 ..< 100:
      shredData.add(i.byte)
    
    var duplicateShred = DuplicateShred(
      fromPubkey: pubkey,
      shred: shredData,
      wallclock: uint64(getTime().toUnix())
    )
    
    # Serialize
    let serialized = serializeDuplicateShred(duplicateShred)
    check serialized.len > 0
    
    # Deserialize
    var offset = 0
    let deserialized = deserializeDuplicateShred(serialized, offset)
    check deserialized.fromPubkey == pubkey
    check deserialized.shred.len == 100
    for i in 0 ..< 100:
      check deserialized.shred[i] == i.byte
    check deserialized.wallclock == duplicateShred.wallclock

  test "CrdsValue with new types":
    # Test LowestSlot
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    var lowestSlot = LowestSlot(fromPubkey: pubkey1, lowest: 5000'u64, wallclock: uint64(getTime().toUnix()))
    var value1 = CrdsValue(kind: CrdsLowestSlot)
    value1.lowestSlot = lowestSlot
    
    let serialized1 = serializeCrdsValue(value1)
    var offset1 = 0
    let deserialized1 = deserializeCrdsValue(serialized1, offset1)
    check deserialized1.kind == CrdsLowestSlot
    check deserialized1.lowestSlot.fromPubkey == pubkey1
    check deserialized1.lowestSlot.lowest == 5000'u64
    
    # Test SnapshotHashes
    var pubkey2 = types.zeroPubkey()
    pubkey2[0] = 0x02
    var hash = types.zeroHash()
    var snapshotHashes = SnapshotHashes(
      fromPubkey: pubkey2,
      full: SnapshotHashEntry(slot: 1000'u64, hash: hash),
      incremental: @[],
      wallclock: uint64(getTime().toUnix())
    )
    var value2 = CrdsValue(kind: CrdsSnapshotHashes)
    value2.snapshotHashes = snapshotHashes
    
    let serialized2 = serializeCrdsValue(value2)
    var offset2 = 0
    let deserialized2 = deserializeCrdsValue(serialized2, offset2)
    check deserialized2.kind == CrdsSnapshotHashes
    check deserialized2.snapshotHashes.fromPubkey == pubkey2
    
    # Test AccountsHashes
    var pubkey3 = types.zeroPubkey()
    pubkey3[0] = 0x03
    var accountsHashes = AccountsHashes(fromPubkey: pubkey3, hash: hash, wallclock: uint64(getTime().toUnix()))
    var value3 = CrdsValue(kind: CrdsAccountsHashes)
    value3.accountsHashes = accountsHashes
    
    let serialized3 = serializeCrdsValue(value3)
    var offset3 = 0
    let deserialized3 = deserializeCrdsValue(serialized3, offset3)
    check deserialized3.kind == CrdsAccountsHashes
    check deserialized3.accountsHashes.fromPubkey == pubkey3
    
    # Test Version
    var pubkey4 = types.zeroPubkey()
    pubkey4[0] = 0x04
    var version = Version(fromPubkey: pubkey4, version: "1.18.0", wallclock: uint64(getTime().toUnix()))
    var value4 = CrdsValue(kind: CrdsVersion)
    value4.version = version
    
    let serialized4 = serializeCrdsValue(value4)
    var offset4 = 0
    let deserialized4 = deserializeCrdsValue(serialized4, offset4)
    check deserialized4.kind == CrdsVersion
    check deserialized4.version.fromPubkey == pubkey4
    check deserialized4.version.version == "1.18.0"
    
    # Test NodeInstance
    var pubkey5 = types.zeroPubkey()
    pubkey5[0] = 0x05
    var nodeInstance = NodeInstance(fromPubkey: pubkey5, token: 12345'u64, wallclock: uint64(getTime().toUnix()))
    var value5 = CrdsValue(kind: CrdsNodeInstance)
    value5.nodeInstance = nodeInstance
    
    let serialized5 = serializeCrdsValue(value5)
    var offset5 = 0
    let deserialized5 = deserializeCrdsValue(serialized5, offset5)
    check deserialized5.kind == CrdsNodeInstance
    check deserialized5.nodeInstance.fromPubkey == pubkey5
    check deserialized5.nodeInstance.token == 12345'u64
    
    # Test DuplicateShred
    var pubkey6 = types.zeroPubkey()
    pubkey6[0] = 0x06
    var duplicateShred = DuplicateShred(fromPubkey: pubkey6, shred: @[0x01.byte, 0x02.byte, 0x03.byte], wallclock: uint64(getTime().toUnix()))
    var value6 = CrdsValue(kind: CrdsDuplicateShred)
    value6.duplicateShred = duplicateShred
    
    let serialized6 = serializeCrdsValue(value6)
    var offset6 = 0
    let deserialized6 = deserializeCrdsValue(serialized6, offset6)
    check deserialized6.kind == CrdsDuplicateShred
    check deserialized6.duplicateShred.fromPubkey == pubkey6
    check deserialized6.duplicateShred.shred.len == 3

  test "Validation for new CRDS types":
    # Test LowestSlot validation
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x01
    
    var lowestSlot = LowestSlot(fromPubkey: pubkey, lowest: 1000'u64, wallclock: uint64(getTime().toUnix()))
    var value = CrdsValue(kind: CrdsLowestSlot)
    value.lowestSlot = lowestSlot
    
    let (isValid, _) = validateCrdsValue(value)
    check isValid == true
    
    # Test invalid (zero pubkey)
    var invalidValue = CrdsValue(kind: CrdsLowestSlot)
    invalidValue.lowestSlot = LowestSlot(fromPubkey: types.zeroPubkey(), lowest: 1000'u64, wallclock: uint64(getTime().toUnix()))
    let (isInvalid, _) = validateCrdsValue(invalidValue)
    check isInvalid == false
    
    # Test SnapshotHashes validation
    var snapshotHashes = SnapshotHashes(
      fromPubkey: pubkey,
      full: SnapshotHashEntry(slot: 1000'u64, hash: types.zeroHash()),
      incremental: @[],
      wallclock: uint64(getTime().toUnix())
    )
    var value2 = CrdsValue(kind: CrdsSnapshotHashes)
    value2.snapshotHashes = snapshotHashes
    let (isValid2, _) = validateCrdsValue(value2)
    check isValid2 == true
    
    # Test Version validation
    var version = Version(fromPubkey: pubkey, version: "1.18.0", wallclock: uint64(getTime().toUnix()))
    var value3 = CrdsValue(kind: CrdsVersion)
    value3.version = version
    let (isValid3, _) = validateCrdsValue(value3)
    check isValid3 == true
    
    # Test invalid Version (empty version string)
    var invalidVersion = Version(fromPubkey: pubkey, version: "", wallclock: uint64(getTime().toUnix()))
    var value4 = CrdsValue(kind: CrdsVersion)
    value4.version = invalidVersion
    let (isInvalid2, _) = validateCrdsValue(value4)
    check isInvalid2 == false
