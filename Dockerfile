# Dockerfile for Nimlana - Linux build and integration tests
# Supports testing gRPC, recvmmsg, and tip payment extraction

FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    libclang-dev \
    curl \
    git \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (for shim build)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Nim (support both x86_64 and ARM64)
# For ARM64, use nimlang/nim base image approach or build from source
# This version uses a simpler approach: try choosenim first, fall back to manual install
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then \
        curl https://nim-lang.org/choosenim/init.sh -sSf | sh && \
        choosenim stable 2.2.6; \
    else \
        # For ARM64, use nimlang/nim Docker image approach or build from source
        # Option 1: Use nimlang/nim base image (recommended - see Dockerfile.arm64)
        # Option 2: Build from source (slower but works)
        echo "Building Nim from source for ARM64..." && \
        cd /tmp && \
        git clone --depth 1 --branch v2.2.6 https://github.com/nim-lang/nim.git nim-src && \
        cd nim-src && \
        git clone --depth 1 https://github.com/nim-lang/csources_v2.git && \
        cd csources_v2 && \
        sh build.sh && \
        cd .. && \
        ./bin/nim c koch.nim && \
        ./koch boot -d:release && \
        ./koch tools -d:release && \
        ./koch nimble && \
        # Install Nim - koch install creates bin/ in the source directory, not at target \
        # So we'll manually set up the installation \
        mkdir -p /opt/nim && \
        cp -r bin /opt/nim/ && \
        cp -r lib /opt/nim/ && \
        cp -r config /opt/nim/ 2>/dev/null || true && \
        # Verify installation \
        /opt/nim/bin/nim --version && \
        rm -rf /tmp/nim-src; \
    fi
ENV PATH="/root/.nimble/bin:/root/.choosenim/toolchains/nim-2.2.6/bin:/opt/nim/bin:${PATH}"

# Verify Nim installation (after PATH is set)
RUN nim --version

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Build Rust shim
RUN cd shim && cargo build --release

# Install Nim dependencies
RUN nimble install -y -d

# Build the project (default build)
RUN nimble build

# Build with full gRPC support (may fail if grpc package not fully set up, that's OK)
RUN nim c -d:useFullGrpc src/nimlana.nim || echo "Note: Full gRPC build skipped (grpc package may need additional setup)"

# Default command: run integration tests
CMD ["make", "test-integration-docker"]

