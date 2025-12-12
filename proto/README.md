# Jito Block Engine Protobuf Definitions

This directory contains protobuf definitions for the Jito Block Engine gRPC API.

## Files

- `jito.proto` - Main protobuf definitions for bundle submission

## Generating Nim Code

To generate Nim code from the protobuf files:

```bash
# Install protobuf compiler and nim-protobuf3
nimble install protobuf

# Generate Nim code (when protobuf tooling is set up)
protoc --nim_out=. proto/jito.proto
```

## Notes

- The protobuf definitions are based on Jito's Block Engine API
- Bundle submission requires serialized Solana transactions
- Tip payment information is included in the bundle request
- Status checking allows tracking bundle confirmation

## Integration

The generated protobuf code will be used in `src/nimlana/blockengine.nim` for gRPC communication with the Jito Block Engine.



