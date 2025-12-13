# Docker Setup for Linux Integration Tests

This directory contains Docker configuration for running Linux-specific integration tests and builds.

## Quick Start

### Build and Test

```bash
# Build Docker image (auto-detects architecture)
make docker-build

# Run all integration tests
make docker-test

# Or use the test script
./scripts/docker-test.sh
```

### Architecture-Specific Builds

The build process automatically detects your architecture:

- **x86_64/amd64**: Uses choosenim for fast Nim installation
- **ARM64/aarch64**: Builds Nim from source (takes 10-15 minutes)

You can also build manually:

```bash
# For x86_64 (uses choosenim)
docker build -t nimlana:latest .

# For ARM64 (builds from source)
docker build -f Dockerfile.arm64 -t nimlana:latest .
```

### Using Docker Compose

```bash
# Start services (includes mock gRPC server)
docker-compose up --build

# Stop services
docker-compose down
```

## Integration Tests

### 1. gRPC Client with Full gRPC Support

Tests the gRPC client with `-d:useFullGrpc` flag enabled:

```bash
# In Docker
make test-integration-grpc

# Or directly
docker run --rm nimlana:latest nim c -d:useFullGrpc -r tests/test_integration_grpc.nim
```

**Test File:** `tests/test_integration_grpc.nim`

**What it tests:**
- gRPC client creation and connection
- Bundle submission via gRPC
- Full HTTP/2 gRPC implementation (when `-d:useFullGrpc` is set)

### 2. recvmmsg Batch Packet Receiving

Tests the Linux-specific `recvmmsg` optimization:

```bash
# In Docker
make test-integration-recvmmsg

# Or directly
docker run --rm nimlana:latest nim c -r tests/test_integration_recvmmsg.nim
```

**Test File:** `tests/test_integration_recvmmsg.nim`

**What it tests:**
- `recvmmsg` module loading on Linux
- Batch packet receiving functionality
- TPU ingestor integration with recvmmsg

**Note:** This test requires Linux. On non-Linux systems, it will use stub implementations.

### 3. Tip Payment Extraction

Tests tip payment extraction from real Solana transaction structures:

```bash
# In Docker
make test-integration-tip-payment

# Or directly
docker run --rm nimlana:latest nim c -r tests/test_integration_tip_payment.nim
```

**Test File:** `tests/test_integration_tip_payment.nim`

**What it tests:**
- Transaction parsing with messages
- Message structure parsing (header, accounts, instructions)
- Compute Budget program detection
- Tip payment instruction extraction
- Full transaction tip extraction

## Docker Image Details

### Base Image
- Ubuntu 22.04

### Architecture Support
- **x86_64/amd64**: Uses choosenim for fast installation (default Dockerfile)
- **ARM64/aarch64**: Builds Nim from source (both Dockerfile and Dockerfile.arm64)

### Dockerfiles
- **Dockerfile**: Main Dockerfile that auto-detects architecture
  - x86_64: Uses choosenim (fast)
  - ARM64: Builds Nim from source (10-15 minutes)
- **Dockerfile.arm64**: Optimized for ARM64 builds
  - Builds Nim from source with optimized structure
  - Same functionality as main Dockerfile but organized for ARM64

### Installed Tools
- Build essentials (gcc, make, etc.)
- Rust (for building shim)
- Nim 2.2.6 (via choosenim)
- Nimble (Nim package manager)
- System dependencies (libssl-dev, etc.)

### Build Process

**For x86_64:**
1. Installs system dependencies
2. Installs Rust
3. Installs Nim via choosenim (fast)
4. Builds Rust shim (`shim/`)
5. Installs Nim dependencies
6. Builds Nim project (default)
7. Attempts build with `-d:useFullGrpc` flag

**For ARM64:**
1. Installs system dependencies
2. Installs Rust
3. Builds Nim from source (10-15 minutes)
4. Builds Rust shim (`shim/`)
5. Installs Nim dependencies
6. Builds Nim project (default)
7. Attempts build with `-d:useFullGrpc` flag

## Running Tests Locally (Non-Docker)

### Prerequisites
- Linux system (for recvmmsg tests)
- Nim 2.2.6+
- Rust 1.91.1+
- All project dependencies

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

The TPU ingestor now supports batch packet receiving on Linux:

```nim
# Enable recvmmsg mode
let ingestor = newTPUIngestor(Port(8001), useRecvmmsg = true)
```

**Benefits:**
- Receives multiple UDP packets in a single system call
- Reduces context switches
- Improves throughput for high packet rates

**Usage:**
- Automatically enabled on Linux when `useRecvmmsg = true`
- Falls back to chronos DatagramTransport on non-Linux or if disabled

## Troubleshooting

### Docker Build Fails on ARM64

**Issue:** `choosenim` doesn't support ARM64 Linux

**Solution:**
- The Dockerfile automatically detects ARM64 and builds Nim from source
- This takes 10-15 minutes but will complete successfully
- Both `Dockerfile` and `Dockerfile.arm64` work on ARM64

**If build still fails:**
- Ensure Docker has sufficient resources (memory, disk space)
- Check network connectivity for downloading dependencies
- Try building with `--no-cache` to avoid cached layer issues:
  ```bash
  docker build --no-cache -t nimlana:latest .
  ```

### gRPC Tests Fail

If gRPC tests fail with `-d:useFullGrpc`:
- Ensure the `grpc` package is properly installed
- Check that protobuf definitions are correct
- Verify network connectivity to gRPC server
- Note: Full gRPC build may be skipped if package setup is incomplete (this is expected)

### recvmmsg Tests Fail

If recvmmsg tests fail:
- Ensure you're running on Linux (Docker container is Linux)
- Check that the socket is properly bound
- Verify permissions for socket operations

### Tip Payment Tests Fail

If tip payment extraction tests fail:
- Verify message structure matches Solana format
- Check that Compute Budget program ID is correct
- Ensure instruction data format is valid

### Build Takes Too Long on ARM64

**Issue:** Building Nim from source takes 10-15 minutes

**Solution:**
- This is expected behavior on ARM64 (choosenim doesn't support it)
- The build will complete successfully, just be patient
- Consider using Docker layer caching for faster rebuilds

## CI/CD Integration

The Docker setup can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Build and test
  run: |
    docker build -t nimlana:latest .
    docker run --rm nimlana:latest make test-integration-all
```

## Architecture Detection

The `make docker-build` command automatically detects your system architecture:

```bash
# Auto-detects architecture and uses appropriate Dockerfile
make docker-build
```

**How it works:**
- Detects Docker server architecture (or falls back to host architecture)
- For ARM64: Tries `Dockerfile.arm64` first (optimized), falls back to main `Dockerfile`
- For x86_64: Uses main `Dockerfile` with choosenim

**Manual override:**
```bash
# Force use of specific Dockerfile
docker build -f Dockerfile -t nimlana:latest .        # Main Dockerfile
docker build -f Dockerfile.arm64 -t nimlana:latest .  # ARM64 optimized
```

## Next Steps

1. **Add more test cases** for edge cases and error handling
2. **Performance benchmarks** for recvmmsg vs. standard receiving
3. **Real Solana transaction samples** for tip payment tests
4. **Mock gRPC server** for offline testing
5. **Multi-platform builds** using Docker Buildx for both x86_64 and ARM64

