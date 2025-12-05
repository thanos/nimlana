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
requires "grpc"

# Build tasks

task test, "Run tests":
  exec "nim c -r tests/test_all.nim"

task test_coverage, "Run coverage tests":
  exec "nim c -r tests/test_coverage.nim"

task test_udp_socket, "Run UDP socket tests":
  exec "nim c -r tests/test_udp_socket.nim"

task test_blockengine_mock, "Run Block Engine mock tests":
  exec "nim c -r tests/test_blockengine_mock.nim"

task test_bundle_parsing, "Run bundle parsing tests":
  exec "nim c -r tests/test_bundle_parsing.nim"

task test_grpc_mock, "Run gRPC mock tests":
  exec "nim c -r tests/test_grpc_mock.nim"

task test_recvmmsg_mock, "Run recvmmsg mock tests":
  exec "nim c -r tests/test_recvmmsg_mock.nim"

task test_errors_coverage, "Run errors.nim coverage tests":
  exec "nim c -r tests/test_errors_coverage.nim"

task test_relayer_coverage, "Run relayer.nim coverage tests":
  exec "nim c -r tests/test_relayer_coverage.nim"

task test_tpu_coverage, "Run tpu.nim coverage tests":
  exec "nim c -r tests/test_tpu_coverage.nim"

task test_relayer_mock, "Run relayer.nim mock tests":
  exec "nim c -r tests/test_relayer_mock.nim"

task test_tpu_mock, "Run tpu.nim mock tests":
  exec "nim c -r tests/test_tpu_mock.nim"

task test_all, "Run all tests (basic + coverage + new functionality)":
  exec "nim c -r tests/test_all.nim"
  exec "nim c -r tests/test_coverage.nim"
  exec "nim c -r tests/test_udp_socket.nim"
  exec "nim c -r tests/test_blockengine_mock.nim"
  exec "nim c -r tests/test_bundle_parsing.nim"
  exec "nim c -r tests/test_grpc_mock.nim"
  exec "nim c -r tests/test_recvmmsg_mock.nim"
  exec "nim c -r tests/test_errors_coverage.nim"
  exec "nim c -r tests/test_relayer_coverage.nim"
  exec "nim c -r tests/test_tpu_coverage.nim"
  exec "nim c -r tests/test_relayer_mock.nim"
  exec "nim c -r tests/test_tpu_mock.nim"

task build_shim, "Build the Rust shim library":
  exec "cd shim && cargo build --release"

task gen_bindings, "Generate Nim bindings from C header":
  exec "futhark --header:shim/target/release/nito_shim.h --output:src/nito_solana.nim"

