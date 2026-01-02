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

clean:
	rm -f lunert
