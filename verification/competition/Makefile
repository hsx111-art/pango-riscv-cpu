SHELL := /bin/bash

ROOT  := $(abspath $(CURDIR)/../..)
OUT   ?= $(ROOT)/.build/competition
CROSS ?= riscv64-unknown-elf
CC    := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
READELF := $(CROSS)-readelf

CFLAGS := -march=rv32im_zicsr_zifencei -mabi=ilp32 -mcmodel=medany \
           -O2 -ffreestanding -fno-builtin -fno-pic -fno-stack-protector \
           -fno-asynchronous-unwind-tables -nostdlib -nostartfiles -static \
           -mno-relax
LDFLAGS := -T$(CURDIR)/link_competition.ld -Wl,--no-relax -Wl,--build-id=none
ELF := $(OUT)/competition_smoke.elf

.PHONY: all clean info

all: $(ELF)

$(OUT):
	mkdir -p $@

$(ELF): $(CURDIR)/start.S $(CURDIR)/competition_smoke.c $(CURDIR)/link_competition.ld | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) $(CURDIR)/start.S $(CURDIR)/competition_smoke.c -o $@
	$(OBJDUMP) -d $@ > $(@:.elf=.dump)
	$(READELF) -h -S $@ > $(@:.elf=.readelf)

info:
	@echo "ELF=$(ELF)"
	@echo "CFLAGS=$(CFLAGS)"

clean:
	rm -rf $(OUT)
