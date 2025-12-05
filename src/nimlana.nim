## Project Nimlana - Hyper-Fast MEV Relayer
## Phase 1: Foundation & FFI Bridge

import std/strutils
import chronos
import nimcrypto
import nimlana/types
import nimlana/ffi

# TODO: Import generated bindings when futhark is set up
# import nito_solana

proc main() =
  echo "=========================================="
  echo "Nimlana - Hyper-Fast MEV Relayer"
  echo "Phase 1: Foundation & FFI Bridge"
  echo "=========================================="
  echo ""
  
  # Proof of concept: FFI integration
  echo "Testing FFI integration..."
  
  # Get shim version
  let version = nito_shim_version()
  if version != nil:
    echo "✓ Rust shim loaded: ", $version
  else:
    echo "✗ Failed to load Rust shim"
    echo "  Make sure to run 'make shim' first to build the library"
    return
  
  # Test basic types
  echo ""
  echo "Testing basic Solana types..."
  let pubkey = zeroPubkey()
  let hash = zeroHash()
  echo "✓ Pubkey size: ", pubkey.len, " bytes"
  echo "✓ Hash size: ", hash.len, " bytes"
  
  echo ""
  echo "Proof of concept complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Build the Rust shim: make shim"
  echo "  2. Generate bindings: make bindings (requires futhark)"
  echo "  3. Test Ed25519 verification with real signatures"

when isMainModule:
  main()

