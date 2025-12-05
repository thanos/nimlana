## Test suite for Nimlana

import unittest
import nimlana/types
import nimlana/ffi

suite "Basic Types":
  test "Pubkey creation":
    let pk = zeroPubkey()
    check pk.len == 32
  
  test "Hash creation":
    let h = zeroHash()
    check h.len == 32

suite "FFI Integration":
  test "Shim version":
    let version = nito_shim_version()
    check version != nil
    echo "Shim version: ", $version

  test "Ed25519 verification (will fail without proper setup)":
    # This test requires the shim library to be built
    # Skip for now in CI, but useful for manual testing
    skip()

