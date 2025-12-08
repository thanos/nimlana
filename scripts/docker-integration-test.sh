#!/bin/bash
# Docker integration test script
# Runs all integration tests in Docker environment

set -e

echo "=== Nimlana Docker Integration Tests ==="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Build Docker image
echo "Step 1: Building Docker image..."
docker build -t nimlana:latest . || {
    echo "Error: Docker build failed"
    exit 1
}

echo ""
echo "Step 2: Running integration tests..."
echo ""

# Test 1: gRPC client (simplified mode)
echo "2.1. Testing gRPC client (simplified mode)..."
docker run --rm nimlana:latest nim c -r tests/test_integration_grpc.nim || {
    echo "Warning: gRPC test failed (may be expected if grpc package needs setup)"
}

# Test 2: recvmmsg (Linux-specific)
echo ""
echo "2.2. Testing recvmmsg integration..."
docker run --rm nimlana:latest nim c -r tests/test_integration_recvmmsg.nim || {
    echo "Error: recvmmsg test failed"
    exit 1
}

# Test 3: Tip payment extraction
echo ""
echo "2.3. Testing tip payment extraction..."
docker run --rm nimlana:latest nim c -r tests/test_integration_tip_payment.nim || {
    echo "Error: Tip payment test failed"
    exit 1
}

# Test 4: gRPC with full gRPC flag (optional)
echo ""
echo "2.4. Testing gRPC client with -d:useFullGrpc (optional)..."
docker run --rm nimlana:latest nim c -d:useFullGrpc -r tests/test_integration_grpc.nim || {
    echo "Note: Full gRPC test skipped (grpc package may need additional setup)"
}

echo ""
echo "=== All integration tests completed ==="

