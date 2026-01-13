## Tests for SocketAddr parsing

import unittest
import std/strutils
import ../src/nimlana/types
import ../src/nimlana/crds
import ../src/nimlana/borsh

suite "SocketAddr Parsing":
  test "Parse IPv4 address":
    let socketAddr = newSocketAddr("127.0.0.1", 8080'u16)
    # Check IPv6-mapped format: ::ffff:127.0.0.1
    check socketAddr.ip[10] == 0xFF.byte
    check socketAddr.ip[11] == 0xFF.byte
    check socketAddr.ip[12] == 127.byte
    check socketAddr.ip[13] == 0.byte
    check socketAddr.ip[14] == 0.byte
    check socketAddr.ip[15] == 1.byte
    check socketAddr.port == 8080'u16

  test "Parse IPv4 address (192.168.1.1)":
    let socketAddr = newSocketAddr("192.168.1.1", 9000'u16)
    check socketAddr.ip[12] == 192.byte
    check socketAddr.ip[13] == 168.byte
    check socketAddr.ip[14] == 1.byte
    check socketAddr.ip[15] == 1.byte
    check socketAddr.port == 9000'u16

  test "Parse IPv6 address (simplified)":
    # Test basic IPv6 parsing
    let socketAddr = newSocketAddr("2001:0db8:85a3:0000:0000:8a2e:0370:7334", 8080'u16)
    # Check that it's not all zeros (basic validation)
    var allZero = true
    for b in socketAddr.ip:
      if b != 0:
        allZero = false
        break
    # Should have some non-zero bytes
    check not allZero
    check socketAddr.port == 8080'u16

  test "Parse IPv6 localhost":
    let socketAddr = newSocketAddr("::1", 8080'u16)
    # ::1 should have last byte as 1
    check socketAddr.ip[15] == 1.byte
    check socketAddr.port == 8080'u16

  test "SocketAddr to string (IPv4)":
    let socketAddr = newSocketAddr("127.0.0.1", 8080'u16)
    let str = socketAddrToString(socketAddr)
    check "127.0.0.1" in str
    check "8080" in str

  test "Serialize and deserialize SocketAddr":
    let socketAddr = newSocketAddr("192.168.1.1", 9000'u16)
    let serialized = serializeSocketAddr(socketAddr)
    check serialized.len == 18  # 16 bytes IP + 2 bytes port
    
    var offset = 0
    let deserialized = deserializeSocketAddr(serialized, offset)
    check deserialized.ip[12] == 192.byte
    check deserialized.ip[13] == 168.byte
    check deserialized.ip[14] == 1.byte
    check deserialized.ip[15] == 1.byte
    check deserialized.port == 9000'u16

  test "Serialize and deserialize ContactInfo with SocketAddr":
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

  test "Serialize and deserialize LegacyContactInfo with SocketAddr":
    var legacyContactInfo = LegacyContactInfo(
      id: types.zeroPubkey(),
      gossip: newSocketAddr("127.0.0.1", 8001'u16),
      tvu: newSocketAddr("127.0.0.1", 8002'u16),
      tpu: newSocketAddr("127.0.0.1", 8003'u16),
      rpc: newSocketAddr("127.0.0.1", 8004'u16),
      wallclock: 1234567890'u64
    )
    legacyContactInfo.id[0] = 0x01
    
    let serialized = serializeLegacyContactInfo(legacyContactInfo)
    check serialized.len > 0
    
    var offset = 0
    let deserialized = deserializeLegacyContactInfo(serialized, offset)
    check deserialized.id[0] == 0x01
    check deserialized.gossip.port == 8001'u16
    check deserialized.tvu.port == 8002'u16
    check deserialized.tpu.port == 8003'u16
    check deserialized.rpc.port == 8004'u16
    check deserialized.wallclock == 1234567890'u64

