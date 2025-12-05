.PHONY: all build test clean shim bindings

all: shim bindings build

# Build the Rust shim library
shim:
	@echo "Building Rust shim..."
	cd shim && cargo build --release
	@echo "Shim built successfully"

# Generate C header (happens automatically during cargo build)
header: shim
	@echo "C header generated at shim/target/release/nito_shim.h"

# Generate Nim bindings from C header (requires futhark)
bindings: header
	@echo "Generating Nim bindings..."
	@if command -v futhark >/dev/null 2>&1; then \
		futhark --header:shim/target/release/nito_shim.h --output:src/nito_solana.nim; \
	else \
		echo "Warning: futhark not found. Using manual bindings in src/nimlana/ffi.nim"; \
	fi

# Build Nim project
build: bindings
	@echo "Building Nimlana..."
	nimble build

# Run tests
test: build
	@echo "Running tests..."
	nimble test

# Clean build artifacts
clean:
	@echo "Cleaning..."
	cd shim && cargo clean
	rm -rf nimlana
	find . -name "*.exe" -delete
	find . -name "*.pdb" -delete

# Development: watch and rebuild
watch:
	@echo "Watching for changes..."
	@command -v entr >/dev/null 2>&1 || (echo "Install entr for file watching" && exit 1)
	find src shim/src -name "*.nim" -o -name "*.rs" | entr -c make build

