CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -fPIC

all: gem5_system_shim.so

gem5_system_shim.so: 03-biodynamo-system-shim.c
	$(CC) $(CFLAGS) -shared -o $@ $<

clean:
	rm -f gem5_system_shim.so

.PHONY: all clean
