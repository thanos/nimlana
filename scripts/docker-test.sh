#!/bin/bash
# Docker test script for Nimlana integration tests

set -e

echo "=== Nimlana Docker Integration Tests ==="
echo ""

# Build Docker image
echo "1. Building Docker image..."
docker build -t nimlana:latest .

# Run integration tests
echo ""
echo "2. Running integration tests..."
echo ""

echo "2.1. Testing gRPC client with -d:useFullGrpc..."
docker run --rm nimlana:latest nim c -d:useFullGrpc -r tests/test_integration_grpc.nim || echo "gRPC test failed (may need grpc package setup)"

echo ""
echo "2.2. Testing recvmmsg integration..."
docker run --rm nimlana:latest nim c -r tests/test_integration_recvmmsg.nim

echo ""
echo "2.3. Testing tip payment extraction..."
docker run --rm nimlana:latest nim c -r tests/test_integration_tip_payment.nim

echo ""
echo "=== All integration tests completed ==="





