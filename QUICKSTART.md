# Quick Start Guide

## Prerequisites

1. **Nim 2.2.6+** - Install via [choosenim](https://github.com/dom96/choosenim) or your package manager
2. **Rust 1.91.1+** - Install via [rustup](https://rustup.rs/)
3. **cbindgen** - Install via `cargo install cbindgen`
4. **futhark** (optional) - For auto-generating Nim bindings: `nimble install futhark`

## First Build

```bash
# 1. Build the Rust shim library
cd shim
cargo build --release
cd ..

# 2. Install Nim dependencies
nimble install -d

# 3. Build the Nim project
nimble build

# 4. Run the proof of concept
./nimlana
```

Or use the Makefile:

```bash
make all
./nimlana
```

## Project Structure

```
nimlana/
├── src/
│   ├── nimlana.nim          # Main entry point
│   └── nimlana/
│       ├── types.nim        # Basic Solana types (Pubkey, Hash)
│       └── ffi.nim          # FFI bindings to Rust shim
├── shim/                    # Rust C-ABI shim
│   ├── Cargo.toml
│   ├── src/lib.rs           # C exports
│   └── build.rs             # Generates C header
└── tests/
    └── test_all.nim         # Test suite
```

## What's Working

Phase 1 Foundation is complete:
- Rust shim crate with panic-safe FFI
- Ed25519 signature verification function
- Nim FFI bindings (manual, will be auto-generated later)
- Basic Solana types (Pubkey, Hash)
- Build system (Makefile + nimble)
- C header generation with cbindgen

## Next Steps

1. **Test the FFI**: Once the shim is built, the main program will test the FFI integration
2. **Generate bindings**: Run `futhark` to auto-generate bindings from the C header
3. **Add more functions**: Extend the shim with more Solana SDK functions
4. **Phase 2**: Start building the TPU ingestor

## Troubleshooting

### "Library not found" errors

Make sure you've built the Rust shim:
```bash
cd shim && cargo build --release
```

### "futhark not found"

This is optional. The manual bindings in `src/nimlana/ffi.nim` work fine for now.

### Build errors

- Ensure you're using Nim 2.2+ and Rust 1.91+
- Check that all dependencies are installed: `nimble install -d`

