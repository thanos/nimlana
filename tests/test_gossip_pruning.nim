## Tests for gossip protocol pruning functionality

import unittest
import std/times
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/gossip_table

suite "Gossip Table Pruning":
  test "Stake-based pruning - zero-stake nodes":
    let table = newGossipTable()
    let baseTime = uint64(getTime().toUnix())
    
    # Create a zero-stake ContactInfo
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    
    var contactInfo1 = ContactInfo(
      id: pubkey1,
      wallclock: baseTime,
      shredVersion: 12345'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    
    # Insert with zero stake
    discard table.insert(value1, baseTime, ttl = 600'u64, stake = 0'u64, epoch = 0'u64)
    check table.len == 1
    
    # Wait 20 seconds (more than 15s TTL for zero-stake)
    let laterTime = baseTime + 20'u64
    
    # Prune zero-stake nodes
    let pruned = table.pruneStakeBased(laterTime, zeroStakeTTL = 15'u64)
    check pruned == 1
    check table.len == 0

  test "Stake-based pruning - staked nodes not pruned":
    let table = newGossipTable()
    let baseTime = uint64(getTime().toUnix())
    
    # Create a staked ContactInfo
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    
    var contactInfo1 = ContactInfo(
      id: pubkey1,
      wallclock: baseTime,
      shredVersion: 12345'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    
    # Insert with stake > 0
    discard table.insert(value1, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 0'u64)
    check table.len == 1
    
    # Wait 20 seconds
    let laterTime = baseTime + 20'u64
    
    # Prune zero-stake nodes (should not prune staked nodes)
    let pruned = table.pruneStakeBased(laterTime, zeroStakeTTL = 15'u64)
    check pruned == 0
    check table.len == 1

  test "Epoch-based pruning - previous epoch entries":
    let table = newGossipTable()
    let baseTime = uint64(getTime().toUnix())
    
    # Create entries from different epochs
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    
    var contactInfo1 = ContactInfo(
      id: pubkey1,
      wallclock: baseTime,
      shredVersion: 12345'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    
    # Insert from epoch 0
    discard table.insert(value1, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 0'u64)
    
    # Create another entry from epoch 1
    var pubkey2 = types.zeroPubkey()
    pubkey2[0] = 0x02
    
    var contactInfo2 = ContactInfo(
      id: pubkey2,
      wallclock: baseTime,
      shredVersion: 12345'u16
    )
    
    var value2 = CrdsValue(kind: CrdsContactInfo)
    value2.contactInfo = contactInfo2
    
    # Insert from epoch 1
    discard table.insert(value2, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 1'u64)
    
    check table.len == 2
    
    # Prune entries from epoch 0 (current epoch is 1)
    let pruned = table.pruneEpochBased(1'u64)
    check pruned == 1
    check table.len == 1
    
    # Verify only epoch 1 entry remains
    let remaining = table.getByPubkey(pubkey2)
    check remaining.len == 1
    check remaining[0].kind == CrdsContactInfo

  test "Epoch-based pruning - zero-stake nodes not affected":
    let table = newGossipTable()
    let baseTime = uint64(getTime().toUnix())
    
    # Create zero-stake entry from previous epoch
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    
    var contactInfo1 = ContactInfo(
      id: pubkey1,
      wallclock: baseTime,
      shredVersion: 12345'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    
    # Insert zero-stake from epoch 0
    discard table.insert(value1, baseTime, ttl = 600'u64, stake = 0'u64, epoch = 0'u64)
    check table.len == 1
    
    # Prune previous epochs (should not prune zero-stake, that's handled by stake-based pruning)
    let pruned = table.pruneEpochBased(1'u64)
    check pruned == 0  # Zero-stake nodes are not pruned by epoch-based pruning
    check table.len == 1

  test "Prune by pubkeys":
    let table = newGossipTable()
    let baseTime = uint64(getTime().toUnix())
    
    # Create multiple entries
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    
    var pubkey2 = types.zeroPubkey()
    pubkey2[0] = 0x02
    
    var pubkey3 = types.zeroPubkey()
    pubkey3[0] = 0x03
    
    var contactInfo1 = ContactInfo(id: pubkey1, wallclock: baseTime, shredVersion: 12345'u16)
    var contactInfo2 = ContactInfo(id: pubkey2, wallclock: baseTime, shredVersion: 12345'u16)
    var contactInfo3 = ContactInfo(id: pubkey3, wallclock: baseTime, shredVersion: 12345'u16)
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    
    var value2 = CrdsValue(kind: CrdsContactInfo)
    value2.contactInfo = contactInfo2
    
    var value3 = CrdsValue(kind: CrdsContactInfo)
    value3.contactInfo = contactInfo3
    
    discard table.insert(value1, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 0'u64)
    discard table.insert(value2, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 0'u64)
    discard table.insert(value3, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 0'u64)
    
    check table.len == 3
    
    # Prune pubkey1 and pubkey2
    let pruned = table.pruneByPubkeys(@[pubkey1, pubkey2])
    check pruned == 2
    check table.len == 1
    
    # Verify only pubkey3 remains
    let remaining = table.getByPubkey(pubkey3)
    check remaining.len == 1

  test "Combined pruning - stake and epoch":
    let table = newGossipTable()
    let baseTime = uint64(getTime().toUnix())
    
    # Create entries:
    # 1. Zero-stake from current epoch (should be pruned by stake-based)
    # 2. Staked from previous epoch (should be pruned by epoch-based)
    # 3. Staked from current epoch (should remain)
    
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    var contactInfo1 = ContactInfo(id: pubkey1, wallclock: baseTime, shredVersion: 12345'u16)
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    discard table.insert(value1, baseTime, ttl = 600'u64, stake = 0'u64, epoch = 1'u64)
    
    var pubkey2 = types.zeroPubkey()
    pubkey2[0] = 0x02
    var contactInfo2 = ContactInfo(id: pubkey2, wallclock: baseTime, shredVersion: 12345'u16)
    var value2 = CrdsValue(kind: CrdsContactInfo)
    value2.contactInfo = contactInfo2
    discard table.insert(value2, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 0'u64)
    
    var pubkey3 = types.zeroPubkey()
    pubkey3[0] = 0x03
    var contactInfo3 = ContactInfo(id: pubkey3, wallclock: baseTime, shredVersion: 12345'u16)
    var value3 = CrdsValue(kind: CrdsContactInfo)
    value3.contactInfo = contactInfo3
    discard table.insert(value3, baseTime, ttl = 600'u64, stake = 1000000'u64, epoch = 1'u64)
    
    check table.len == 3
    
    # Prune zero-stake (current epoch = 1, so pubkey1 should be pruned)
    let laterTime = baseTime + 20'u64
    let prunedStake = table.pruneStakeBased(laterTime, zeroStakeTTL = 15'u64)
    check prunedStake == 1
    check table.len == 2
    
    # Prune previous epochs (current epoch = 1, so pubkey2 should be pruned)
    let prunedEpoch = table.pruneEpochBased(1'u64)
    check prunedEpoch == 1
    check table.len == 1
    
    # Verify only pubkey3 remains
    let remaining = table.getByPubkey(pubkey3)
    check remaining.len == 1
