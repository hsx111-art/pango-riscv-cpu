SHELL := /bin/bash

ROOT := $(abspath $(CURDIR)/../..)
OUT ?= $(ROOT)/.build/cache
CROSS ?= riscv64-unknown-elf
CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
READELF := $(CROSS)-readelf

CFLAGS := -march=rv32im_zicsr_zifencei -mabi=ilp32 -mcmodel=medany \
          -O2 -ffreestanding -fno-builtin -fno-pic -fno-stack-protector \
          -fno-asynchronous-unwind-tables -nostdlib -nostartfiles -static \
          -mno-relax -I$(CURDIR)
LDFLAGS := -T$(CURDIR)/link_cache.ld -Wl,--no-relax -Wl,--build-id=none
ELF := $(OUT)/cache_workload.elf

.PHONY: all clean info

all: $(ELF)

$(OUT):
	mkdir -p $@

$(ELF): $(CURDIR)/start.S $(CURDIR)/cache_workload.c $(CURDIR)/link_cache.ld | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) $(CURDIR)/start.S $(CURDIR)/cache_workload.c -o $@
	$(OBJDUMP) -d $@ > $(@:.elf=.dump)
	$(READELF) -h -S $@ > $(@:.elf=.readelf)

info:
	@echo "ELF=$(ELF)"
	@echo "CFLAGS=$(CFLAGS)"

clean:
	rm -rf $(OUT)