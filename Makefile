# Makefile for Lune - LuaJIT interpreter and package manager

CC ?= cc
LUAJIT_DIR ?= /opt/homebrew

CFLAGS = -O2 -Wall -I$(LUAJIT_DIR)/include/luajit-2.1

# macOS: link against static library
ifeq ($(shell uname),Darwin)
    LDFLAGS = $(LUAJIT_DIR)/lib/libluajit-5.1.a -lm
endif

# Linux specific flags
ifeq ($(shell uname),Linux)
    LDFLAGS = -L$(LUAJIT_DIR)/lib -lluajit-5.1 -Wl,-E -ldl -lm -lpthread
endif

PREFIX ?= /usr/local

.PHONY: all clean lune install uninstall test test-compiled test-all

all: lune

# Build the lunert runtime
runtime/lunert: runtime/lunert.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Build self-contained lune binary
lune: runtime/lunert
	@echo "Creating lune source bundle..."
	@rm -f runtime/lune-src.zip
	@zip -r -0 runtime/lune-src.zip src/ vendor/ -x "*.swp" -x "*~"
	@echo "Fusing runtime with source bundle..."
	@cat runtime/lunert runtime/lune-src.zip > runtime/lune
	@chmod +x runtime/lune
	@rm -f runtime/lune-src.zip
	@echo "Created: runtime/lune ($$(du -h runtime/lune | cut -f1))"

install: lune
	@echo "Installing lune to $(PREFIX)/bin..."
	@mkdir -p $(PREFIX)/bin
	@cp runtime/lune $(PREFIX)/bin/lune
	@echo "Installed: $(PREFIX)/bin/lune"

uninstall:
	@echo "Removing $(PREFIX)/bin/lune..."
	@rm -f $(PREFIX)/bin/lune

clean:
	rm -f runtime/lunert runtime/lune runtime/lune-src.zip

# Run tests with uncompiled lune (bin/lune)
test:
	@./tests/run_tests.sh

# Run tests with compiled lune (runtime/lune)
test-compiled: lune
	@./tests/run_tests.sh --compiled

# Run all tests (both modes)
test-all: lune
	@echo "Running tests with uncompiled lune..."
	@./tests/run_tests.sh
	@echo ""
	@echo "Running tests with compiled lune..."
	@./tests/run_tests.sh --compiled
