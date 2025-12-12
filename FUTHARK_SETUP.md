# Futhark Setup (Optional)

Futhark is a tool for auto-generating Nim bindings from C headers. While manual bindings work fine, futhark can make maintenance easier as the Rust shim grows.

## Installation

```bash
# Install futhark via nimble
nimble install futhark

# Or clone and build from source
git clone https://github.com/PMunch/futhark
cd futhark
nimble build
nimble install
```

## Usage

After building the Rust shim, generate bindings:

```bash
# Build the shim first (generates the C header)
make shim

# Generate Nim bindings
futhark --header:shim/target/release/nito_shim.h --output:src/nito_solana.nim

# Or use the Makefile target
make bindings
```

## Integration

Once bindings are generated, you can use them in `src/nimlana.nim`:

```nim
# Replace manual bindings with generated ones
import nito_solana
```

## Notes

- The generated bindings may need minor adjustments
- Manual bindings in `src/nimlana/ffi.nim` work perfectly and are easier to customize
- Futhark is most useful when the Rust shim has many functions

## Troubleshooting

If futhark fails:
1. Ensure the C header exists: `shim/target/release/nito_shim.h`
2. Check futhark version: `futhark --version`
3. Manual bindings are always available as a fallback



