## Tests for gossip table module

import unittest
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/gossip_table

suite "Gossip Table":
  test "Create gossip table":
    let table = newGossipTable()
    check table.len == 0

  test "Insert ContactInfo":
    let table = newGossipTable()
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    let inserted = table.insert(value, 1234567890'u64, 600'u64)
    check inserted == true
    check table.len == 1

  test "Get by pubkey":
    let table = newGossipTable()
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    discard table.insert(value, 1234567890'u64)
    
    let values = table.getByPubkey(contactInfo.id)
    check values.len == 1
    check values[0].kind == CrdsContactInfo

  test "Get by kind":
    let table = newGossipTable()
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    discard table.insert(value, 1234567890'u64)
    
    let values = table.getByKind(CrdsContactInfo)
    check values.len == 1
    check values[0].kind == CrdsContactInfo

  test "Remove expired entries":
    let table = newGossipTable()
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    # Insert with short TTL
    discard table.insert(value, 1000'u64, 100'u64)
    check table.len == 1
    
    # Remove expired (current time is way past TTL)
    table.removeExpired(2000'u64)
    check table.len == 0

  test "Clear table":
    let table = newGossipTable()
    var contactInfo = ContactInfo(
      id: types.zeroPubkey(),
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    contactInfo.id[0] = 0x01
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    discard table.insert(value, 1234567890'u64)
    check table.len == 1
    
    table.clear()
    check table.len == 0

