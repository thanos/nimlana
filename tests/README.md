# Test Suite

## Overview

Nimlana has a comprehensive test suite covering all major components:

1. **Basic Tests** (`test_all.nim`) - Core functionality tests
2. **Coverage Tests** (`test_coverage.nim`) - Edge cases and additional coverage
3. **UDP Socket Tests** (`test_udp_socket.nim`) - UDP socket and DatagramTransport functionality
4. **Block Engine Mock Tests** (`test_blockengine_mock.nim`) - Block Engine client mock tests

## Running Tests

### All Tests

```bash
# Using Makefile
make test-all

# Using Nimble
nimble test_all
```

### Individual Test Suites

```bash
# Basic tests only
nimble test

# Coverage tests only
nimble test_coverage

# UDP socket tests
nimble test_udp_socket

# Block Engine mock tests
nimble test_blockengine_mock
```

## Test Coverage

### Phase 1 Components
- ✅ Basic Types (Pubkey, Hash, Signature)
- ✅ Borsh Serialization (all types)
- ✅ Buffer Management (SharedBuffer, BufferView)
- ✅ FFI Integration (Ed25519, Hash computation)
- ✅ Error Handling

### Phase 2 Components
- ✅ TPU Ingestor (packet parsing, deduplication)
- ✅ UDP Socket (DatagramTransport integration, packet handling)
- ✅ Block Engine Client (structure, bundle handling)
- ✅ Relayer (coordination)
- ✅ Edge cases and error paths
- ✅ Mock tests for network functionality

## Coverage Statistics

Run `make coverage` to generate coverage reports:

```bash
make coverage      # Generate lcov.info
make coverage-html # Generate HTML report
```

## Adding New Tests

When adding new functionality:

1. Add unit tests to `test_all.nim` for core functionality
2. Add edge case tests to `test_coverage.nim`
3. Test error paths and boundary conditions
4. Run `make test-all` to verify
5. Check coverage with `make coverage-html`

## Test Organization

- **Basic functionality**: `test_all.nim`
- **Edge cases**: `test_coverage.nim`
- **Test vectors**: `test_ed25519_vectors.nim`

