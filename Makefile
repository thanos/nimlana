.PHONY: all build test clean shim bindings coverage coverage-html

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

# Run all tests (including coverage tests)
test-all: build
	@echo "Running all tests..."
	nimble test
	nimble test_coverage
	nimble test_udp_socket
	nimble test_blockengine_mock

# Run tests with code coverage
coverage: shim
	@echo "Running tests with code coverage..."
	@COCO_BIN=$$(command -v coco 2>/dev/null || echo ""); \
	if [ -z "$$COCO_BIN" ] && [ -f "$$HOME/.asdf/installs/nim/2.2.6/nimble/bin/coco" ]; then \
		COCO_BIN="$$HOME/.asdf/installs/nim/2.2.6/nimble/bin/coco"; \
	fi; \
	if [ -n "$$COCO_BIN" ] && [ -x "$$COCO_BIN" ]; then \
		echo "Running coverage on test_all.nim..."; \
		./scripts/run_coverage.sh "$$COCO_BIN" "tests/test_all.nim" "!tests,!nimcache" || true; \
		echo "Running coverage on test_coverage.nim..."; \
		./scripts/run_coverage.sh "$$COCO_BIN" "tests/test_coverage.nim" "!tests,!nimcache" || true; \
		if [ -f lcov.info ]; then \
			echo "✓ Final coverage data in lcov.info"; \
		else \
			echo "Warning: lcov.info not generated. Coverage may have failed."; \
		fi; \
	else \
		echo "Error: coco not found. Install with: nimble install coco"; \
		echo "Running tests without coverage..."; \
		nimble test; \
		exit 1; \
	fi

# Generate HTML coverage report
coverage-html: coverage
	@echo "Generating HTML coverage report..."
	@if [ ! -f lcov.info ]; then \
		echo "Error: lcov.info not found. Run 'make coverage' first."; \
		exit 1; \
	fi
	@if command -v genhtml >/dev/null 2>&1; then \
		mkdir -p coverage/html; \
		genhtml --ignore-errors range,source,unused -o coverage/html lcov.info 2>&1 | grep -v "^Reading\|^Found\|^Writing" || true; \
		if [ -f coverage/html/index.html ]; then \
			echo ""; \
			echo "✓ Coverage report generated at: coverage/html/index.html"; \
		fi; \
	else \
		echo "Error: genhtml (lcov) not found."; \
		echo "Install lcov:"; \
		echo "  macOS: brew install lcov"; \
		echo "  Linux: sudo apt-get install lcov  # Debian/Ubuntu"; \
		echo "         sudo yum install lcov      # RHEL/CentOS"; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning..."
	cd shim && cargo clean
	rm -rf nimlana
	rm -rf coverage
	rm -f lcov.info
	find . -name "*.exe" -delete
	find . -name "*.pdb" -delete

# Development: watch and rebuild
watch:
	@echo "Watching for changes..."
	@command -v entr >/dev/null 2>&1 || (echo "Install entr for file watching" && exit 1)
	find src shim/src -name "*.nim" -o -name "*.rs" | entr -c make build

