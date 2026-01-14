## Tests for leader schedule module

import unittest
import std/options
import std/tables
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/leader_schedule

suite "Leader Schedule":
  test "Create leader schedule":
    let schedule = newLeaderSchedule(0'u64, 432000'u64)
    check schedule.epoch == 0'u64
    check schedule.slotsPerEpoch == 432000'u64
    check schedule.firstSlot == 0'u64
    check schedule.lastSlot == 431999'u64
  
  test "Get current epoch":
    check getCurrentEpoch(0'u64) == 0'u64
    check getCurrentEpoch(432000'u64) == 1'u64
    check getCurrentEpoch(864000'u64) == 2'u64
  
  test "Get epoch slots":
    check getEpochFirstSlot(0'u64) == 0'u64
    check getEpochLastSlot(0'u64) == 431999'u64
    check getEpochFirstSlot(1'u64) == 432000'u64
    check getEpochLastSlot(1'u64) == 863999'u64
  
  test "Add and get leader":
    let schedule = newLeaderSchedule(0'u64)
    let pubkey = types.zeroPubkey()
    
    # Add leader for slot 100
    schedule.addLeader(100'u64, pubkey)
    
    # Get leader
    let leader = schedule.getSlotLeader(100'u64)
    check leader.isSome()
    check leader.get() == pubkey
  
  test "Check slot leader":
    let schedule = newLeaderSchedule(0'u64)
    let pubkey = types.zeroPubkey()
    var otherPubkey: Pubkey
    for i in 0 ..< 32:
      otherPubkey[i] = 0xFF.byte
    
    schedule.addLeader(100'u64, pubkey)
    
    check schedule.isSlotLeader(100'u64, pubkey) == true
    check schedule.isSlotLeader(100'u64, otherPubkey) == false
  
  test "Get slot leader outside epoch":
    let schedule = newLeaderSchedule(0'u64)
    
    # Slot outside epoch should return None
    let leader = schedule.getSlotLeader(1000000'u64)
    check leader.isNone()
  
  test "Update leader schedule":
    let schedule = newLeaderSchedule(0'u64)
    var newLeaders = initTable[uint64, Pubkey]()
    let pubkey = types.zeroPubkey()
    newLeaders[432100'u64] = pubkey  # Add leader for slot in epoch 1
    
    schedule.updateLeaderSchedule(1'u64, newLeaders)
    
    check schedule.epoch == 1'u64
    check schedule.firstSlot == 432000'u64
    check schedule.lastSlot == 863999'u64
    check schedule.getSlotLeader(100'u64).isNone()  # Slot 100 is in epoch 0
    check schedule.getSlotLeader(432100'u64).isSome()  # Slot 432100 is in epoch 1
  
  test "Get next leader slot":
    let schedule = newLeaderSchedule(0'u64)
    let pubkey = types.zeroPubkey()
    
    # Add leaders at slots 100, 200, 300
    schedule.addLeader(100'u64, pubkey)
    schedule.addLeader(200'u64, pubkey)
    schedule.addLeader(300'u64, pubkey)
    
    # Get next leader slot from slot 50
    let nextSlot = schedule.getNextLeaderSlot(50'u64, pubkey)
    check nextSlot.isSome()
    check nextSlot.get() == 100'u64
    
    # Get next leader slot from slot 150
    let nextSlot2 = schedule.getNextLeaderSlot(150'u64, pubkey)
    check nextSlot2.isSome()
    check nextSlot2.get() == 200'u64
    
    # Get next leader slot from slot 400 (no more leaders)
    let nextSlot3 = schedule.getNextLeaderSlot(400'u64, pubkey)
    check nextSlot3.isNone()
