# Package

version       = "0.1.0"
author        = "Nimlana Team"
description   = "Hyper-Fast MEV Relayer and Validator client for Solana"
license       = "Apache-2.0"
srcDir        = "src"
bin           = @["nimlana"]

# Dependencies

requires "nim >= 2.2.0"
requires "chronos >= 4.0.0"
requires "nimcrypto >= 0.5.0"
requires "futhark >= 0.5.0"
requires "protobuf >= 0.5.0"

# Build tasks

task test, "Run tests":
  exec "nim c -r tests/test_all.nim"

task test_coverage, "Run coverage tests":
  exec "nim c -r tests/test_coverage.nim"

task test_udp_socket, "Run UDP socket tests":
  exec "nim c -r tests/test_udp_socket.nim"

task test_blockengine_mock, "Run Block Engine mock tests":
  exec "nim c -r tests/test_blockengine_mock.nim"

task test_all, "Run all tests (basic + coverage + new functionality)":
  exec "nim c -r tests/test_all.nim"
  exec "nim c -r tests/test_coverage.nim"
  exec "nim c -r tests/test_udp_socket.nim"
  exec "nim c -r tests/test_blockengine_mock.nim"

task build_shim, "Build the Rust shim library":
  exec "cd shim && cargo build --release"

task gen_bindings, "Generate Nim bindings from C header":
  exec "futhark --header:shim/target/release/nito_shim.h --output:src/nito_solana.nim"

