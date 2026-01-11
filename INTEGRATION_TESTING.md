# Integration Testing Guide

This document describes the Docker-based integration testing setup for Nimlana.

## Overview

Integration tests verify that the three major enhancements work correctly:
1. gRPC client with full HTTP/2 support (`-d:useFullGrpc` flag)
2. recvmmsg batch packet receiving (Linux optimization)
3. Tip payment extraction from Solana transactions

## Prerequisites

- Docker installed and running
- Sufficient disk space for Docker images (~2GB)

## Quick Start

### Run All Integration Tests

```bash
# Using the test script
./scripts/docker-integration-test.sh

# Or using Makefile
make docker-build
make docker-test

# Or using Docker Compose
docker-compose up --build
```

## Test Suites

### 1. gRPC Client Tests

**File:** `tests/test_integration_grpc.nim`

**What it tests:**
- gRPC client creation and configuration
- Connection establishment
- Bundle submission via gRPC
- Full HTTP/2 gRPC implementation (when `-d:useFullGrpc` is enabled)

**Running:**
```bash
# Simplified mode (default)
docker run --rm nimlana:latest nim c -r tests/test_integration_grpc.nim

# Full gRPC mode
docker run --rm nimlana:latest nim c -d:useFullGrpc -r tests/test_integration_grpc.nim
```

**Expected behavior:**
- Simplified mode: Tests pass with mock responses
- Full gRPC mode: May require additional grpc package setup

### 2. recvmmsg Batch Receiving Tests

**File:** `tests/test_integration_recvmmsg.nim`

**What it tests:**
- recvmmsg module loading on Linux
- Batch packet receiving functionality
- TPU ingestor integration with recvmmsg support
- Socket creation and binding

**Running:**
```bash
docker run --rm nimlana:latest nim c -r tests/test_integration_recvmmsg.nim
```

**Expected behavior:**
- On Linux: Tests verify recvmmsg functionality
- On non-Linux: Tests verify stub implementation

**Note:** This test requires Linux. The Docker container runs Ubuntu 22.04, so recvmmsg is available.

### 3. Tip Payment Extraction Tests

**File:** `tests/test_integration_tip_payment.nim`

**What it tests:**
- Transaction parsing with message structures
- Solana message format parsing (header, accounts, instructions)
- Compute Budget program detection
- Tip payment instruction extraction
- Full transaction tip extraction workflow

**Running:**
```bash
docker run --rm nimlana:latest nim c -r tests/test_integration_tip_payment.nim
```

**Expected behavior:**
- All tests pass with correctly formatted Solana transaction structures
- Tip amounts are correctly extracted from Compute Budget instructions

## Docker Image Details

### Base Image
- Ubuntu 22.04 LTS

### Installed Components
- Build tools (gcc, make, pkg-config)
- Rust 1.91.1+ (via rustup)
- Nim 2.2.6 (via choosenim)
- System libraries (libssl-dev, ca-certificates)

### Build Process
1. Installs system dependencies
2. Installs Rust toolchain
3. Installs Nim compiler
4. Builds Rust shim library
5. Installs Nim dependencies
6. Builds Nim project (default)
7. Attempts build with `-d:useFullGrpc` flag

## Running Tests Locally (Without Docker)

### Prerequisites
- Linux system (for recvmmsg tests)
- Nim 2.2.6+
- Rust 1.91.1+
- All project dependencies installed

### Commands

```bash
# Run all integration tests
make test-integration-all

# Run individual test suites
make test-integration-grpc
make test-integration-recvmmsg
make test-integration-tip-payment
```

## TPU Ingestor with recvmmsg

The TPU ingestor supports batch packet receiving on Linux:

```nim
# Enable recvmmsg mode
let ingestor = newTPUIngestor(Port(8001), useRecvmmsg = true)
```

**Benefits:**
- Receives multiple UDP packets in a single system call
- Reduces context switches
- Improves throughput for high packet rates

**Implementation:**
- Automatically enabled on Linux when `useRecvmmsg = true`
- Falls back to chronos DatagramTransport on non-Linux or if disabled
- Uses `recvmmsg` syscall for batch receiving (up to 32 packets per call)

## Troubleshooting

### Docker Build Fails

**Issue:** Docker build fails during Rust or Nim installation

**Solution:**
- Ensure Docker has sufficient resources (memory, disk space)
- Check network connectivity for downloading dependencies
- Verify Docker daemon is running

### gRPC Tests Fail with -d:useFullGrpc

**Issue:** Full gRPC tests fail

**Solution:**
- This is expected if the grpc package needs additional setup
- The simplified gRPC implementation works without the flag
- Full gRPC integration requires proper protobuf code generation

### recvmmsg Tests Fail

**Issue:** recvmmsg tests fail

**Solution:**
- Ensure you're running on Linux (Docker container is Linux)
- Check that socket permissions are correct
- Verify the recvmmsg syscall is available (Linux kernel 2.6.33+)

### Tip Payment Tests Fail

**Issue:** Tip payment extraction tests fail

**Solution:**
- Verify message structure matches Solana format
- Check that Compute Budget program ID is correct
- Ensure instruction data format is valid
- Review test data structure in `test_integration_tip_payment.nim`

## CI/CD Integration

The Docker setup can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and test
        run: |
          docker build -t nimlana:latest .
          docker run --rm nimlana:latest make test-integration-all
```

## Test Coverage

Integration tests cover:
- gRPC client functionality (simplified and full modes)
- recvmmsg batch receiving (Linux-specific)
- Tip payment extraction from Solana transactions
- Message parsing and instruction extraction
- Error handling and edge cases

## Next Steps

1. Add performance benchmarks for recvmmsg vs. standard receiving
2. Add real Solana transaction samples for tip payment tests
3. Set up mock gRPC server for offline testing
4. Add integration tests for end-to-end bundle processing





