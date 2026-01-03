FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    luajit \
    libluajit-5.1-dev \
    zip \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set LuaJIT directory for Linux
ENV LUAJIT_DIR=/usr

# Set working directory
WORKDIR /app

# Copy project files (excludes macOS binaries via .dockerignore)
COPY . .

# Make test scripts executable
RUN chmod +x tests/*.sh

# Build the lune binary for Linux
RUN make

# Default command: run all tests
CMD ["make", "test-all"]
