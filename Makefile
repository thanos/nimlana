.PHONY: all build test clean shim bindings coverage coverage-html format check lint check-all check-linux build-check

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

# Format code with NPH
format:
	@echo "Formatting Nim code with NPH..."
	@NPH_BIN=$$(find ~/.asdf/installs/nim -name "nph" -type f 2>/dev/null | head -1); \
	if [ -z "$$NPH_BIN" ] && [ -f "$$HOME/.asdf/installs/nim/2.2.6/nimble/pkgs2/nph-0.6.1-5202779f46888bf90a6bc92807ee7865b1207ac0/nph" ]; then \
		NPH_BIN="$$HOME/.asdf/installs/nim/2.2.6/nimble/pkgs2/nph-0.6.1-5202779f46888bf90a6bc92807ee7865b1207ac0/nph"; \
	fi; \
	if [ -n "$$NPH_BIN" ] && [ -x "$$NPH_BIN" ]; then \
		$$NPH_BIN src/nimlana/*.nim src/*.nim tests/*.nim 2>&1 || true; \
		echo "✓ Code formatted"; \
	else \
		echo "Error: nph not found. Install with: nimble install nph"; \
		exit 1; \
	fi

# Check code formatting with NPH
format-check:
	@echo "Checking code formatting with NPH..."
	@NPH_BIN=$$(find ~/.asdf/installs/nim -name "nph" -type f 2>/dev/null | head -1); \
	if [ -z "$$NPH_BIN" ] && [ -f "$$HOME/.asdf/installs/nim/2.2.6/nimble/pkgs2/nph-0.6.1-5202779f46888bf90a6bc92807ee7865b1207ac0/nph" ]; then \
		NPH_BIN="$$HOME/.asdf/installs/nim/2.2.6/nimble/pkgs2/nph-0.6.1-5202779f46888bf90a6bc92807ee7865b1207ac0/nph"; \
	fi; \
	if [ -n "$$NPH_BIN" ] && [ -x "$$NPH_BIN" ]; then \
		$$NPH_BIN --check src/nimlana/*.nim src/*.nim tests/*.nim 2>&1 || exit 1; \
		echo "✓ Code formatting is correct"; \
	else \
		echo "Error: nph not found. Install with: nimble install nph"; \
		exit 1; \
	fi

# Development: watch and rebuild
watch:
	@echo "Watching for changes..."
	@command -v entr >/dev/null 2>&1 || (echo "Install entr for file watching" && exit 1)
	find src shim/src -name "*.nim" -o -name "*.rs" | entr -c make build

# Docker targets
docker-build:
	@echo "Building Docker image..."
	@echo "Note: Run 'make build' first to catch compilation errors locally (much faster)"
	@ARCH=$$(docker version --format '{{.Server.Arch}}' 2>/dev/null || echo "$$(uname -m)") && \
	echo "Detected architecture: $$ARCH" && \
	if [ "$$ARCH" = "arm64" ] || [ "$$ARCH" = "aarch64" ]; then \
		echo "Using Dockerfile.arm64 (faster for ARM64)..." && \
		docker build -f Dockerfile.arm64 -t nimlana:latest . || \
		(echo "Dockerfile.arm64 failed, trying standard Dockerfile with source build..." && \
		 docker build -t nimlana:latest .); \
	else \
		echo "Using standard Dockerfile (x86_64)..." && \
		docker build -t nimlana:latest .; \
	fi

# Quick local build check (catches errors before Docker)
build-check:
	@echo "Running quick local build check..."
	@echo "This catches compilation errors in seconds instead of waiting for Docker"
	@nimble build || (echo "Build failed! Fix errors before running docker-build" && exit 1)
	@echo "Local build successful - safe to run docker-build"

# Run all checks (check + lint + build-check)
check-all: check lint build-check
	@echo "All checks passed!"

# Check code with nim check (static analysis, catches more errors)
# Note: nim check may show warnings but exits with 0 if no errors
check:
	@echo "Running nim check (static analysis)..."
	@nim check src/nimlana.nim 2>&1 | grep -E "^Error:" && (echo "Check failed! Fix errors before running docker-build" && exit 1) || echo "Static check passed (warnings are OK)"

# Run code linting checks using nim check with warnings
# This catches common code quality issues like unused imports, deprecated usage, etc.
lint:
	@echo "Running code linting checks (using nim check)..."
	@echo "Checking all source files for common issues..."
	@echo ""; \
	LINT_ERRORS=0; \
	for file in $$(find src -name "*.nim"); do \
		echo "Checking $$file..."; \
		if nim check --hints:on "$$file" 2>&1 | grep -qE "^Error:"; then \
			echo "  ERROR: Found errors in $$file"; \
			nim check --hints:on "$$file" 2>&1 | grep "^Error:"; \
			LINT_ERRORS=1; \
		fi; \
	done; \
	if [ $$LINT_ERRORS -eq 1 ]; then \
		echo ""; \
		echo "Lint failed! Fix errors above"; \
		exit 1; \
	else \
		echo ""; \
		echo "Lint check passed (no errors found)"; \
	fi

# Check with Linux flag (catches Linux-specific code issues)
check-linux:
	@echo "Running nim check with -d:linux flag..."
	@echo "This catches Linux-specific code issues that Docker would find"
	@if nim check -d:linux src/nimlana.nim 2>&1 | grep -q "^Error:"; then \
		echo "Linux check failed! Found errors:"; \
		nim check -d:linux src/nimlana.nim 2>&1 | grep "^Error:"; \
		exit 1; \
	else \
		echo "Linux check successful - safe to run docker-build"; \
	fi

docker-test:
	@echo "Running Docker tests..."
	docker run --rm nimlana:latest

docker-shell:
	@echo "Opening Docker shell..."
	docker run --rm -it nimlana:latest /bin/bash

docker-compose-up:
	@echo "Starting Docker Compose services..."
	docker-compose up --build

docker-compose-down:
	@echo "Stopping Docker Compose services..."
	docker-compose down

# Integration tests
test-integration-grpc:
	@echo "Running gRPC integration tests..."
	nim c -d:useFullGrpc -r tests/test_integration_grpc.nim

test-integration-recvmmsg:
	@echo "Running recvmmsg integration tests..."
	nim c -r tests/test_integration_recvmmsg.nim

test-integration-tip-payment:
	@echo "Running tip payment integration tests..."
	nim c -r tests/test_integration_tip_payment.nim

test-integration-all:
	@echo "Running all integration tests..."
	$(MAKE) test-integration-grpc
	$(MAKE) test-integration-recvmmsg
	$(MAKE) test-integration-tip-payment

test-integration-docker:
	@echo "Running integration tests in Docker..."
	@./scripts/docker-integration-test.sh || $(MAKE) test-integration-all

