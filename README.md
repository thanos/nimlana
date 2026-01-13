
<img height="506" alt="nimlana" src="https://github.com/user-attachments/assets/3a79502c-c79e-4f35-9f12-f361ed7bf649" />


# Project Nimlana

**High-Performance MEV Relayer and Validator client for Solana**

## Overview

Nimlana is a high-performance MEV (Maximal Extractable Value) relayer and validator client built with Nim, designed to provide sub-millisecond latency for MEV extraction on Solana.

### Core Advantages

- **Latency**: Nim's `chronos` async engine provides deterministic latency profiles with reduced jitter compared to Rust's `tokio` work-stealing scheduler for UDP packet processing
- **Architecture**: "Strangler Fig" pattern - starts as a high-performance network frontend that wraps the Solana Rust SDK, gradually replacing components
- **Safety**: Zero-copy FFI bridge with panic-safe boundaries

## Architecture

The node is split into two memory spaces:

1. **The Nimlana Shell (Nim)**: Handles networking (UDP/QUIC), packet parsing, deduplication, and MEV bundle logic (the "Hot Path")
2. **The Rusty Core (Rust Static Lib)**: Handles ledger storage (RocksDB), erasure coding, and heavy cryptography (the "Cold Path")

## Technical Stack

- **Compiler**: Nim 2.2+ (ARC/ORC memory management)
- **Async Runtime**: `chronos` (blockchain networking standard in Nim)
- **FFI Generator**: `futhark` (auto-generates Nim bindings from Rust C-ABI headers)
- **Crypto**: `bearssl`/`libsodium` wrapper; FFI to `solana-perf` for GPU signature verification
- **Protobuf**: `nim-protobuf3` for Jito Block Engine gRPC communication

## Development Phases

### Phase 1: Foundation & FFI Bridge  Complete

- [x] Project structure
- [x] Rust shim crate (`nito_shim`)
- [x] Basic FFI proof of concept
- [x] C header generation with `cbindgen`
- [x] Enhanced Rust shim with Pubkey/Hash structs
- [x] Basic Solana types (Pubkey, Hash)
- [x] Borsh serialization support
- [x] Zero-copy buffer management
- [x] Error handling infrastructure
- [x] Comprehensive test suite
- [ ] Nim bindings with `futhark` (optional - manual bindings work)

### Phase 2: The "Speed Demon" Relayer 

- TPU ingestor (UDP/QUIC)
- Block Engine client (gRPC)
- Deduplication logic

### Phase 3: The Bundle Stage 

- Bundle simulation
- Tip payment logic

### Phase 4: Native Consolidation (Months 6+) - 60% Complete

- Native gossip (CRDS) - Data structures, serialization, gossip table, network layer
- Ledger replay - Not started
- Block production - Not started
- Vote handling - Not started

**See `PRODUCTION_ROADMAP.md` for the complete path to production-ready validator.**

## Building

### Prerequisites

- Nim 2.2.6+ (see `.tool-versions`)
- Rust 1.91.1+ (see `.tool-versions`)
- `asdf` or `rtx` for version management (optional)

### Quick Start

```bash
# Build everything
make all

# Or step by step:
make shim      # Build Rust shim library
make bindings  # Generate Nim bindings (requires futhark)
make build     # Build Nim project
make test      # Run tests
make format    # Format code with NPH
```

### Using Nimble

```bash
# Install dependencies
nimble install -d

# Build
nimble build

# Run tests
nimble test

# Build shim
nimble build_shim
```

## Project Structure

```
nimlana/
├── src/
│   ├── nimlana.nim          # Main entry point
│   ├── nimlana/
│   │   ├── types.nim        # Basic Solana types (Pubkey, Hash)
│   │   └── ffi.nim          # FFI bindings to Rust shim
│   └── nito_solana.nim      # Auto-generated bindings (from futhark)
├── shim/
│   ├── Cargo.toml           # Rust shim crate
│   ├── src/
│   │   └── lib.rs           # C-ABI exports
│   └── target/
│       └── release/
│           └── nito_shim.h  # Generated C header
├── tests/
│   └── test_all.nim         # Test suite
├── Makefile                 # Build automation
└── nimlana.nimble           # Nim package definition
```

## Proof of Concept

The current implementation includes:

1. **Rust Shim** (`shim/src/lib.rs`): Exports `verify_ed25519` function with panic-safe FFI
2. **Nim FFI** (`src/nimlana/ffi.nim`): Manual bindings to the shim (will be auto-generated)
3. **Basic Types** (`src/nimlana/types.nim`): Pure Nim implementations of Pubkey and Hash

## Memory & Safety Strategy

### Zero-Copy Mandate

In the hot path (TPU → Relayer → Block Engine), we never copy packet data:
- Nim: allocate `seq[byte]` buffer in shared memory
- Rust: pass pointer `*mut u8` and length `usize`
- Rust Shim: use `std::slice::from_raw_parts` to view memory as Rust slice

### Panic Boundary

The Rust shim wraps every public function in `std::panic::catch_unwind`. If a panic occurs, it returns a C error code to Nim, preventing unwinding across the FFI boundary.

## License

Apache-2.0 (see LICENSE file)

## Production Roadmap

Nimlana is currently in **Phase 4 (60% complete)**. See the following documents for details:

- **`PRODUCTION_ROADMAP.md`** - Complete 44-week roadmap to production
- **`ROADMAP_SUMMARY.md`** - Quick overview and timeline
- **`PHASE4_PLAN.md`** - Phase 4 detailed implementation plan
- **`PHASE4_STATUS.md`** - Current status and progress
- **`NEXT.md`** - Immediate next steps

**Current Status:**
- Phases 1-3: Complete (Foundation, TPU Relayer, Bundle Simulation)
- Phase 4: 60% complete (Native Gossip - CRDS structures, table, network layer)
- Phase 5-9: Not started (Ledger Replay, Block Production, Voting, RPC, Hardening, Deployment)

**Next Steps:**
1. Complete gossip protocol (signature verification, leader schedule) - 2-3 weeks
2. Implement ledger replay - 8 weeks
3. Add block production and voting - 8 weeks
4. Add production infrastructure - 16 weeks
5. Testnet and mainnet deployment - 8 weeks

## Contributing

This project is in active development. See `PRODUCTION_ROADMAP.md` for the development roadmap and current priorities.

