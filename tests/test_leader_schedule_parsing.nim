## Tests for leader schedule parsing from CRDS

import unittest
import std/tables
import std/times
import std/options
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/leader_schedule
import ../src/nimlana/gossip_table

suite "Leader Schedule Parsing from CRDS":
  test "Parse leader schedule from empty table":
    let table = newGossipTable()
    let schedule = parseLeaderScheduleFromCrds(table, 0'u64, 100'u64)
    check schedule.epoch == 0'u64
    check schedule.leaders.len == 0
    check schedule.firstSlot == 0'u64
    check schedule.lastSlot == 99'u64

  test "Parse leader schedule with single validator":
    let table = newGossipTable()
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x01
    
    var contactInfo = ContactInfo(
      id: pubkey,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    let timestamp = uint64(getTime().toUnix())
    discard table.insert(value, timestamp, stake = 1000000'u64, epoch = 0'u64)
    
    let schedule = parseLeaderScheduleFromCrds(table, 0'u64, 100'u64)
    check schedule.epoch == 0'u64
    check schedule.leaders.len > 0  # Should have some slot assignments
    check schedule.firstSlot == 0'u64
    check schedule.lastSlot == 99'u64
    
    # All slots should be assigned to the single validator
    for slot in schedule.firstSlot .. schedule.lastSlot:
      let leader = schedule.getSlotLeader(slot)
      check leader.isSome()
      check leader.get() == pubkey

  test "Parse leader schedule with multiple validators (stake-weighted)":
    let table = newGossipTable()
    
    # Create 3 validators with different stakes
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    var pubkey2 = types.zeroPubkey()
    pubkey2[0] = 0x02
    var pubkey3 = types.zeroPubkey()
    pubkey3[0] = 0x03
    
    var contactInfo1 = ContactInfo(
      id: pubkey1,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var contactInfo2 = ContactInfo(
      id: pubkey2,
      gossip: newSocketAddr("127.0.0.2", 8001),
      tvu: newSocketAddr("127.0.0.2", 8002),
      tpu: newSocketAddr("127.0.0.2", 8003),
      tpuForwards: newSocketAddr("127.0.0.2", 8004),
      tpuVote: newSocketAddr("127.0.0.2", 8005),
      rpc: newSocketAddr("127.0.0.2", 8006),
      rpcPubsub: newSocketAddr("127.0.0.2", 8007),
      serveRepair: newSocketAddr("127.0.0.2", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var contactInfo3 = ContactInfo(
      id: pubkey3,
      gossip: newSocketAddr("127.0.0.3", 8001),
      tvu: newSocketAddr("127.0.0.3", 8002),
      tpu: newSocketAddr("127.0.0.3", 8003),
      tpuForwards: newSocketAddr("127.0.0.3", 8004),
      tpuVote: newSocketAddr("127.0.0.3", 8005),
      rpc: newSocketAddr("127.0.0.3", 8006),
      rpcPubsub: newSocketAddr("127.0.0.3", 8007),
      serveRepair: newSocketAddr("127.0.0.3", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    var value2 = CrdsValue(kind: CrdsContactInfo)
    value2.contactInfo = contactInfo2
    var value3 = CrdsValue(kind: CrdsContactInfo)
    value3.contactInfo = contactInfo3
    
    let timestamp = uint64(getTime().toUnix())
    # Validator 1: 50% stake
    discard table.insert(value1, timestamp, stake = 5000000'u64, epoch = 0'u64)
    # Validator 2: 30% stake
    discard table.insert(value2, timestamp, stake = 3000000'u64, epoch = 0'u64)
    # Validator 3: 20% stake
    discard table.insert(value3, timestamp, stake = 2000000'u64, epoch = 0'u64)
    
    let schedule = parseLeaderScheduleFromCrds(table, 0'u64, 1000'u64)
    check schedule.epoch == 0'u64
    check schedule.leaders.len > 0
    
    # Count assignments per validator
    var count1, count2, count3: int
    for slot in schedule.firstSlot .. schedule.lastSlot:
      let leader = schedule.getSlotLeader(slot)
      if leader.isSome():
        if leader.get() == pubkey1:
          inc count1
        elif leader.get() == pubkey2:
          inc count2
        elif leader.get() == pubkey3:
          inc count3
    
    # Validator 1 should have more assignments (higher stake)
    check count1 > 0
    check count2 > 0
    check count3 > 0
    # Validator 1 should have roughly 50% of slots (allowing for randomness)
    check count1 >= count2  # Validator 1 should have >= validator 2
    check count1 >= count3   # Validator 1 should have >= validator 3

  test "Deterministic schedule generation (same epoch, same validators)":
    let table1 = newGossipTable()
    let table2 = newGossipTable()
    
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x01
    
    var contactInfo = ContactInfo(
      id: pubkey,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo
    var value2 = CrdsValue(kind: CrdsContactInfo)
    value2.contactInfo = contactInfo
    
    let timestamp = uint64(getTime().toUnix())
    discard table1.insert(value1, timestamp, stake = 1000000'u64, epoch = 0'u64)
    discard table2.insert(value2, timestamp, stake = 1000000'u64, epoch = 0'u64)
    
    let schedule1 = parseLeaderScheduleFromCrds(table1, 0'u64, 100'u64)
    let schedule2 = parseLeaderScheduleFromCrds(table2, 0'u64, 100'u64)
    
    # Schedules should be deterministic (same epoch, same validators)
    check schedule1.leaders.len == schedule2.leaders.len
    
    # Check that slot assignments match
    for slot in schedule1.firstSlot .. schedule1.lastSlot:
      let leader1 = schedule1.getSlotLeader(slot)
      let leader2 = schedule2.getSlotLeader(slot)
      if leader1.isSome() and leader2.isSome():
        check leader1.get() == leader2.get()

  test "Different epochs produce different schedules":
    let table = newGossipTable()
    
    var pubkey = types.zeroPubkey()
    pubkey[0] = 0x01
    
    var contactInfo = ContactInfo(
      id: pubkey,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    let timestamp = uint64(getTime().toUnix())
    discard table.insert(value, timestamp, stake = 1000000'u64, epoch = 0'u64)
    
    let schedule1 = parseLeaderScheduleFromCrds(table, 0'u64, 100'u64)
    let schedule2 = parseLeaderScheduleFromCrds(table, 1'u64, 100'u64)
    
    # Different epochs should produce different schedules
    check schedule1.epoch == 0'u64
    check schedule2.epoch == 1'u64
    check schedule1.firstSlot != schedule2.firstSlot
    check schedule1.lastSlot != schedule2.lastSlot

  test "Zero-stake validators get assignments when total stake is zero":
    let table = newGossipTable()
    
    var pubkey1 = types.zeroPubkey()
    pubkey1[0] = 0x01
    var pubkey2 = types.zeroPubkey()
    pubkey2[0] = 0x02
    
    var contactInfo1 = ContactInfo(
      id: pubkey1,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var contactInfo2 = ContactInfo(
      id: pubkey2,
      gossip: newSocketAddr("127.0.0.2", 8001),
      tvu: newSocketAddr("127.0.0.2", 8002),
      tpu: newSocketAddr("127.0.0.2", 8003),
      tpuForwards: newSocketAddr("127.0.0.2", 8004),
      tpuVote: newSocketAddr("127.0.0.2", 8005),
      rpc: newSocketAddr("127.0.0.2", 8006),
      rpcPubsub: newSocketAddr("127.0.0.2", 8007),
      serveRepair: newSocketAddr("127.0.0.2", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 0'u16
    )
    
    var value1 = CrdsValue(kind: CrdsContactInfo)
    value1.contactInfo = contactInfo1
    var value2 = CrdsValue(kind: CrdsContactInfo)
    value2.contactInfo = contactInfo2
    
    let timestamp = uint64(getTime().toUnix())
    # Both with zero stake - should use uniform distribution
    discard table.insert(value1, timestamp, stake = 0'u64, epoch = 0'u64)
    discard table.insert(value2, timestamp, stake = 0'u64, epoch = 0'u64)
    
    let schedule = parseLeaderScheduleFromCrds(table, 0'u64, 1000'u64)
    
    # Both validators should get some assignments when total stake is zero
    var count1, count2: int
    for slot in schedule.firstSlot .. schedule.lastSlot:
      let leader = schedule.getSlotLeader(slot)
      if leader.isSome():
        if leader.get() == pubkey1:
          inc count1
        elif leader.get() == pubkey2:
          inc count2
    
    check count1 > 0
    check count2 > 0  # Both should get assignments when total stake is zero (uniform distribution)
