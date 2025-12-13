## Tests for gossip network module

import unittest
import chronos
import net
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/gossip_protocol
import ../src/nimlana/gossip_table
import ../src/nimlana/gossip_network

suite "Gossip Network":
  test "Create gossip network":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let network = newGossipNetwork(Port(8001), localPubkey)
    check network.port == Port(8001)
    check network.localPubkey == localPubkey
    check network.running == false
    check network.peers.len == 0

  test "Add peer":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let network = newGossipNetwork(Port(8002), localPubkey)
    
    var peerPubkey = types.zeroPubkey()
    peerPubkey[0] = 0x02
    let peerAddress = initTAddress("127.0.0.1", Port(9001))
    
    network.addPeer(peerPubkey, peerAddress)
    check network.peers.len == 1
    check peerPubkey in network.peers
    check network.peers[peerPubkey].address == peerAddress

  test "Remove peer":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let network = newGossipNetwork(Port(8003), localPubkey)
    
    var peerPubkey = types.zeroPubkey()
    peerPubkey[0] = 0x02
    let peerAddress = initTAddress("127.0.0.1", Port(9002))
    
    network.addPeer(peerPubkey, peerAddress)
    check network.peers.len == 1
    
    network.removePeer(peerPubkey)
    check network.peers.len == 0

  test "Get healthy peers":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let network = newGossipNetwork(Port(8004), localPubkey)
    
    var peer1Pubkey = types.zeroPubkey()
    peer1Pubkey[0] = 0x02
    network.addPeer(peer1Pubkey, initTAddress("127.0.0.1", Port(9003)))
    
    var peer2Pubkey = types.zeroPubkey()
    peer2Pubkey[0] = 0x03
    network.addPeer(peer2Pubkey, initTAddress("127.0.0.1", Port(9004)))
    
    # Mark one peer as unhealthy
    network.peers[peer2Pubkey].isHealthy = false
    
    let healthyPeers = network.getHealthyPeers()
    check healthyPeers.len == 1
    check healthyPeers[0].pubkey == peer1Pubkey

  test "Get stats":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let network = newGossipNetwork(Port(8005), localPubkey)
    
    var peerPubkey = types.zeroPubkey()
    peerPubkey[0] = 0x02
    network.addPeer(peerPubkey, initTAddress("127.0.0.1", Port(9005)))
    
    let (totalPeers, healthyPeers, tableSize) = network.getStats()
    check totalPeers == 1
    check healthyPeers == 1
    check tableSize == 0

  test "Cleanup stale peers":
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let network = newGossipNetwork(Port(8006), localPubkey)
    
    var peerPubkey = types.zeroPubkey()
    peerPubkey[0] = 0x02
    network.addPeer(peerPubkey, initTAddress("127.0.0.1", Port(9006)))
    
    # Set lastSeen to very old timestamp
    network.peers[peerPubkey].lastSeen = 0'u64
    
    network.cleanupStalePeers(100'u64)  # Max age 100 seconds
    check network.peers.len == 0

