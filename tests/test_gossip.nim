## Tests for main gossip module

import unittest
import chronos
import net
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/gossip

suite "Gossip Module":
  test "Create gossip instance":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(Port(8001))
    let gossip = newGossip(localPubkey, config)
    
    check gossip.localPubkey == localPubkey
    check gossip.config.port == Port(8001)
    check gossip.running == false
    check gossip.stats.pushMessagesSent == 0

  test "Insert CRDS value":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(Port(8002))
    let gossip = newGossip(localPubkey, config)
    
    var contactInfo = ContactInfo(
      id: localPubkey,
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    let inserted = gossip.insertValue(value)
    check inserted == true
    check gossip.stats.valuesInserted == 1

  test "Get value by pubkey":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(Port(8003))
    let gossip = newGossip(localPubkey, config)
    
    var contactInfo = ContactInfo(
      id: localPubkey,
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    discard gossip.insertValue(value)
    
    let values = gossip.getValue(localPubkey)
    check values.len == 1
    check values[0].kind == CrdsContactInfo

  test "Get values by kind":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(Port(8004))
    let gossip = newGossip(localPubkey, config)
    
    var contactInfo = ContactInfo(
      id: localPubkey,
      wallclock: 1234567890'u64,
      shredVersion: 12345'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    discard gossip.insertValue(value)
    
    let values = gossip.getValuesByKind(CrdsContactInfo)
    check values.len == 1
    check values[0].kind == CrdsContactInfo

  test "Add and remove peer":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(Port(8005))
    let gossip = newGossip(localPubkey, config)
    
    var peerPubkey = types.zeroPubkey()
    peerPubkey[0] = 0x02
    let peerAddress = initTAddress("127.0.0.1", Port(9001))
    
    gossip.addPeer(peerPubkey, peerAddress)
    let (stats, totalPeers, _, _) = gossip.getStats()
    check totalPeers == 1
    
    gossip.removePeer(peerPubkey)
    let (stats2, totalPeers2, _, _) = gossip.getStats()
    check totalPeers2 == 0
    check stats2.peersRemoved == 1

  test "Get stats":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(Port(8006))
    let gossip = newGossip(localPubkey, config)
    
    let (stats, totalPeers, healthyPeers, tableSize) = gossip.getStats()
    check totalPeers == 0
    check healthyPeers == 0
    check tableSize == 0
    check stats.pushMessagesSent == 0
    check stats.valuesInserted == 0



