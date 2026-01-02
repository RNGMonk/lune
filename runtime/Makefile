# Makefile for lunert runtime

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

.PHONY: all clean

all: lunert

lunert: lunert.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Build self-contained lune binary
# This bundles lune's own source code into the runtime
lune: lunert
	@echo "Creating lune source bundle..."
	@rm -f lune-src.zip
	@cd .. && zip -r -0 runtime/lune-src.zip src/ vendor/ -x "*.swp" -x "*~"
	@echo "Fusing runtime with source bundle..."
	@cat lunert lune-src.zip > lune
	@chmod +x lune
	@rm -f lune-src.zip
	@echo "Created: lune ($$(du -h lune | cut -f1))"

clean:
	rm -f lunert lune lune-src.zip
