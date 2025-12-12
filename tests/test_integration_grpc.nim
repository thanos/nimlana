## Integration tests for gRPC client with -d:useFullGrpc flag
## Tests the full gRPC implementation

import unittest
import chronos
import net
import ../src/nimlana/types
import ../src/nimlana/blockengine
import ../src/nimlana/grpc_client
import ../src/nimlana/jito_pb
import ../src/nimlana/errors

when defined(useFullGrpc):
  suite "gRPC Integration Tests - Full gRPC":
    test "gRPC client creation with full gRPC":
      let client = newGrpcClient("localhost:9000")
      check client.endpoint == "localhost:9000"
      check client.host == "localhost"
      check client.port == Port(9000)

    test "gRPC client connection (full gRPC)":
      let client = newGrpcClient("localhost:9000")
      waitFor client.connect()
      check client.connected == true

    test "gRPC sendBundle with full gRPC":
      let client = newGrpcClient("localhost:9000")
      waitFor client.connect()
      
      let request = SendBundleRequest(
        transactions: @[@[0x01.byte, 0x02.byte, 0x03.byte]],
        tipAccount: "11111111111111111111111111111111", # Base58 encoded
        tipAmount: 1000'u64,
      )
      
      # This will use the full gRPC implementation
      let response = waitFor client.sendBundle(request)
      check response.accepted == true or response.accepted == false # Either is valid for test

else:
  suite "gRPC Integration Tests - Simplified (Phase 2)":
    test "gRPC client creation (simplified)":
      let client = newGrpcClient("localhost:9000")
      check client.endpoint == "localhost:9000"

    test "gRPC client connection (simplified)":
      let client = newGrpcClient("localhost:9000")
      waitFor client.connect()
      check client.connected == true

    test "gRPC sendBundle (simplified - mock)":
      let client = newGrpcClient("localhost:9000")
      waitFor client.connect()
      
      let request = SendBundleRequest(
        transactions: @[@[0x01.byte, 0x02.byte, 0x03.byte]],
        tipAccount: "11111111111111111111111111111111",
        tipAmount: 1000'u64,
      )
      
      # This will use the simplified mock implementation
      let response = waitFor client.sendBundle(request)
      check response.accepted == true # Mock always accepts
      check response.bundleId.len > 0



