## Project Nimlana - Hyper-Fast MEV Relayer
## Phase 2: The "Speed Demon" Relayer

import std/strutils
import std/parseopt
import chronos
import nimcrypto
import nimlana/types
import nimlana/ffi
import nimlana/borsh
import nimlana/buffer
import nimlana/errors
import nimlana/relayer

# TODO: Import generated bindings when futhark is set up
# import nito_solana

# Global relayer for signal handler access
var gRelayer: Relayer = nil

proc runRelayer(relayer: Relayer) {.async.} =
  ## Async function to run the relayer
  # Start relayer in background
  asyncCheck relayer.start()
  
  # Keep running and print stats periodically
  while relayer.running:
    await sleepAsync(1000)  # Sleep 1 second
    let (packets, bundles, dedupSize, queueSize) = relayer.getStats()
    if packets > 0:
      echo "Stats: packets=", packets, " bundles=", bundles, " dedup=", dedupSize, " queue=", queueSize

proc main() =
  var
    tpuPort = Port(8001)  # Default TPU port
    blockEngineEndpoint = "block-engine.jito.wtf:443"
    testMode = false
  
  # Parse command line arguments
  var p = initOptParser()
  for kind, key, val in p.getopt():
    case kind:
    of cmdLongOption, cmdShortOption:
      case key:
      of "port", "p":
        tpuPort = Port(parseInt(val))
      of "block-engine", "b":
        blockEngineEndpoint = val
      of "test", "t":
        testMode = true
      of "help", "h":
        echo "Nimlana - Hyper-Fast MEV Relayer"
        echo ""
        echo "Usage: nimlana [options]"
        echo ""
        echo "Options:"
        echo "  -p, --port PORT          TPU listening port (default: 8001)"
        echo "  -b, --block-engine URL   Block Engine endpoint (default: block-engine.jito.wtf:443)"
        echo "  -t, --test               Run in test mode (Phase 1 tests)"
        echo "  -h, --help               Show this help"
        quit(0)
    of cmdArgument:
      discard
    of cmdEnd:
      discard
  
  if testMode:
    # Phase 1 test mode
    echo "=========================================="
    echo "Nimlana - Phase 1 Test Mode"
    echo "=========================================="
    echo ""
    
    # Get shim version
    let version = nito_shim_version()
    if version != nil:
      echo "✓ Rust shim loaded: ", $version
    else:
      echo "✗ Failed to load Rust shim"
      return
    
    # Test hash computation
    let testData = "nimlana"
    let computedHash = computeHash(testData.toOpenArrayByte(0, testData.high))
    echo "✓ Hash computed: ", types.toHex(computedHash)
    
    echo ""
    echo "Phase 1 tests complete!"
    return
  
  # Phase 2: Start the relayer
  echo "=========================================="
  echo "Nimlana - Hyper-Fast MEV Relayer"
  echo "Phase 2: The 'Speed Demon' Relayer"
  echo "=========================================="
  echo ""
  
  # Verify shim is loaded
  let version = nito_shim_version()
  if version == nil:
    echo "✗ Failed to load Rust shim"
    echo "  Make sure to run 'make shim' first to build the library"
    quit(1)
  
  echo "✓ Rust shim loaded: ", $version
  echo ""
  
  # Create and start relayer
  gRelayer = newRelayer(tpuPort, blockEngineEndpoint)
  
  # Set up signal handlers for graceful shutdown
  proc signalHandler() {.noconv.} =
    echo ""
    echo "Shutting down..."
    if gRelayer != nil:
      gRelayer.stop()
      let (packets, bundles, dedupSize, queueSize) = gRelayer.getStats()
      echo ""
      echo "Final Statistics:"
      echo "  Packets received: ", packets
      echo "  Bundles received: ", bundles
      echo "  Deduplication set size: ", dedupSize
      echo "  Queue size: ", queueSize
    quit(0)
  
  setControlCHook(signalHandler)
  
  # Start the relayer
  try:
    asyncCheck runRelayer(gRelayer)
    # Run event loop
    runForever()
  except Exception as e:
    echo "Error: ", e.msg
    if gRelayer != nil:
      gRelayer.stop()
    quit(1)

when isMainModule:
  main()

