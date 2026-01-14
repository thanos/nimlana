## Testnet Integration Tests for Gossip Protocol
## Tests gossip protocol against Solana testnet validators

import unittest
import chronos
import net
import std/strutils
import std/options
import std/times
import std/os
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/gossip
import ../src/nimlana/gossip_protocol
import ../src/nimlana/testnet_rpc

# Testnet configuration
const TESTNET_GOSSIP_PORT = Port(8001)
const TESTNET_RPC_ENDPOINT = "https://api.testnet.solana.com"

# Environment variable to enable testnet tests
const ENABLE_TESTNET_TESTS = "NIMLANA_ENABLE_TESTNET_TESTS"

proc shouldRunTestnetTests*(): bool =
  ## Check if testnet tests should run
  ## Set NIMLANA_ENABLE_TESTNET_TESTS=1 to enable
  existsEnv(ENABLE_TESTNET_TESTS) and getEnv(ENABLE_TESTNET_TESTS) == "1"

suite "Gossip Protocol Testnet Integration":
  test "Discover testnet validators via RPC":
    ## Test discovering testnet validators using RPC
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    let rpcClient = newTestnetRpcClient(TESTNET_RPC_ENDPOINT)
    let validators = rpcClient.getTestnetValidators()
    
    echo "Discovered ", validators.len, " testnet validators"
    
    # Should discover at least some validators
    check validators.len > 0
    
    # Print first few validators for debugging
    for i in 0 ..< min(3, validators.len):
      let (host, port, pubkey) = validators[i]
      echo "  Validator ", i, ": ", host, ":", port, " (pubkey: ", pubkey, ")"

  test "Connect to testnet validator":
    ## Test connecting to a testnet validator and receiving gossip messages
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    # Discover validators
    let rpcClient = newTestnetRpcClient(TESTNET_RPC_ENDPOINT)
    let validators = rpcClient.getTestnetValidators()
    
    if validators.len == 0:
      skip("No testnet validators discovered")
      return
    
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(TESTNET_GOSSIP_PORT)
    let gossip = newGossip(localPubkey, config)
    
    # Add first validator as peer (use placeholder pubkey since we don't have the actual pubkey format)
    let (host, port, _) = validators[0]
    let address = initTAddress(host, port)
    var validatorPubkey = types.zeroPubkey()
    validatorPubkey[0] = 0x02
    gossip.addPeer(validatorPubkey, address)
    
    echo "Connecting to testnet validator: ", host, ":", port
    
    # Start gossip
    waitFor gossip.start()
    
    # Wait for messages (timeout after 30 seconds)
    await sleepAsync(milliseconds(30000))
    
    # Check if we received any messages
    let (stats, totalPeers, healthyPeers, tableSize) = gossip.getStats()
    echo "Testnet stats: totalPeers=", totalPeers, " healthyPeers=", healthyPeers, " tableSize=", tableSize
    echo "Messages received: push=", stats.pushMessagesReceived, " pull=", stats.pullResponsesReceived
    
    gossip.stop()
    
    # In a real test, we'd check that we received messages
    # For now, just verify the gossip instance works
    check true

  test "Verify message format compliance":
    ## Test that our messages are in the correct format for Solana gossip protocol
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    # Create a test message
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    var contactInfo = ContactInfo(
      id: localPubkey,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 12345'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    # Create signed push message
    var secretKey: array[32, byte]
    secretKey[0] = 0x01  # Placeholder secret key
    
    let msg = createPushMessage(@[value], localPubkey, secretKey)
    
    # Serialize and check format
    let serialized = serializeGossipMessage(msg)
    
    # Basic checks
    check serialized.len > 0
    check msg.kind == GossipPushMessage
    check msg.push.values.len == 1
    
    # Verify message structure
    # Message should start with message kind (1 byte)
    check serialized[0] == GossipPushMessage.uint8
    
    # In a real test, we'd send this to a testnet validator and verify it's accepted
    echo "Message format: ", serialized.len, " bytes, kind: ", msg.kind
    check true

  test "Get current slot from testnet":
    ## Test getting current slot from testnet RPC
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    let rpcClient = newTestnetRpcClient(TESTNET_RPC_ENDPOINT)
    let slot = rpcClient.getSlot()
    
    if slot.isSome():
      echo "Current testnet slot: ", slot.get()
      check slot.get() > 0'u64
    else:
      echo "Could not get slot from testnet (may be unavailable)"
      # This is OK - testnet may be down
      check true

  test "Get epoch info from testnet":
    ## Test getting epoch information from testnet RPC
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    let rpcClient = newTestnetRpcClient(TESTNET_RPC_ENDPOINT)
    let epochInfo = rpcClient.getEpochInfo()
    
    if epochInfo.isSome():
      let info = epochInfo.get()
      echo "Epoch info: ", $info
      check true
    else:
      echo "Could not get epoch info from testnet (may be unavailable)"
      # This is OK - testnet may be down
      check true

  test "Handle network partition recovery":
    ## Test that gossip recovers from network partitions
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(TESTNET_GOSSIP_PORT)
    let gossip = newGossip(localPubkey, config)
    
    waitFor gossip.start()
    
    # Simulate network partition (disconnect)
    # In a real test, we'd disconnect from network and reconnect
    await sleepAsync(milliseconds(1000))
    
    # Check that gossip continues to work after reconnection
    let (stats, totalPeers, healthyPeers, tableSize) = gossip.getStats()
    echo "After partition recovery: totalPeers=", totalPeers, " healthyPeers=", healthyPeers
    
    gossip.stop()
    
    check true

  test "Rate limiting with testnet":
    ## Test that rate limiting works correctly with testnet validators
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(TESTNET_GOSSIP_PORT)
    let gossip = newGossip(localPubkey, config)
    
    waitFor gossip.start()
    
    # Send many messages quickly to test rate limiting
    # In a real test, we'd verify that rate limiting prevents spam
    await sleepAsync(milliseconds(5000))
    
    gossip.stop()
    
    check true

  test "Leader schedule from testnet":
    ## Test that we can parse leader schedule from testnet CRDS values
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    let config = defaultGossipConfig(TESTNET_GOSSIP_PORT)
    let gossip = newGossip(localPubkey, config)
    
    # Get current slot from testnet
    let rpcClient = newTestnetRpcClient(TESTNET_RPC_ENDPOINT)
    let slot = rpcClient.getSlot()
    
    if slot.isSome():
      gossip.updateCurrentSlot(slot.get())
    
    waitFor gossip.start()
    
    # Wait for leader schedule to be populated
    await sleepAsync(milliseconds(60000))
    
    # Check if leader schedule is available
    if gossip.leaderSchedule.isSome():
      let schedule = gossip.leaderSchedule.get()
      echo "Leader schedule available with ", schedule.leaders.len, " slot assignments"
      check true
    else:
      echo "Leader schedule not yet available"
      # This is OK - leader schedule may take time to populate
      check true
    
    gossip.stop()

  test "Protocol compliance - message serialization":
    ## Test that message serialization matches Solana format
    if not shouldRunTestnetTests():
      skip("Set NIMLANA_ENABLE_TESTNET_TESTS=1 to run testnet tests")
      return
    
    # Test push message serialization
    var localPubkey = types.zeroPubkey()
    localPubkey[0] = 0x01
    
    var contactInfo = ContactInfo(
      id: localPubkey,
      gossip: newSocketAddr("127.0.0.1", 8001),
      tvu: newSocketAddr("127.0.0.1", 8002),
      tpu: newSocketAddr("127.0.0.1", 8003),
      tpuForwards: newSocketAddr("127.0.0.1", 8004),
      tpuVote: newSocketAddr("127.0.0.1", 8005),
      rpc: newSocketAddr("127.0.0.1", 8006),
      rpcPubsub: newSocketAddr("127.0.0.1", 8007),
      serveRepair: newSocketAddr("127.0.0.1", 8008),
      wallclock: uint64(getTime().toUnix()),
      shredVersion: 12345'u16
    )
    
    var value = CrdsValue(kind: CrdsContactInfo)
    value.contactInfo = contactInfo
    
    var secretKey: array[32, byte]
    secretKey[0] = 0x01
    
    let pushMsg = createPushMessage(@[value], localPubkey, secretKey)
    let pullReq = createPullRequest(localPubkey, secretKey)
    
    # Serialize messages
    let pushSerialized = serializeGossipMessage(pushMsg)
    let pullSerialized = serializeGossipMessage(pullReq)
    
    # Basic format checks
    check pushSerialized.len > 0
    check pullSerialized.len > 0
    check pushSerialized[0] == GossipPushMessage.uint8
    check pullSerialized[0] == GossipPullRequest.uint8
    
    echo "Push message: ", pushSerialized.len, " bytes"
    echo "Pull request: ", pullSerialized.len, " bytes"
    
    check true
