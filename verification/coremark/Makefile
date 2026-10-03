SHELL := /bin/bash

ROOT := $(abspath $(CURDIR)/../..)
COREMARK := $(ROOT)/third_party/coremark
PORT := $(CURDIR)
OUT ?= $(ROOT)/.build/coremark
CROSS ?= riscv64-unknown-elf
CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
READELF := $(CROSS)-readelf

ITERATIONS ?= 1
TOTAL_DATA_SIZE ?= 2000
CLOCK_HZ ?= 1000000
RUN_TYPE ?= validation
OUTPUT_DEVICE ?= sim

ifeq ($(RUN_TYPE),performance)
RUN_DEFINE := -DPERFORMANCE_RUN=1
else ifeq ($(RUN_TYPE),validation)
RUN_DEFINE := -DVALIDATION_RUN=1
else ifeq ($(RUN_TYPE),profile)
RUN_DEFINE := -DPROFILE_RUN=1
else
$(error RUN_TYPE must be performance, validation, or profile)
endif

ifeq ($(OUTPUT_DEVICE),sim)
OUTPUT_DEFINE :=
else ifeq ($(OUTPUT_DEVICE),competition-uart)
OUTPUT_DEFINE := -DCOREMARK_MMIO_UART=1
else
$(error OUTPUT_DEVICE must be sim or competition-uart)
endif

CFLAGS := -march=rv32im_zicsr_zifencei -mabi=ilp32 -mcmodel=medany \
           -O2 -ffreestanding -fno-builtin -fno-pic -fno-stack-protector \
           -fno-asynchronous-unwind-tables -nostdlib -nostartfiles -static \
           -mno-relax -I$(PORT) -I$(COREMARK) \
           -DITERATIONS=$(ITERATIONS) -DTOTAL_DATA_SIZE=$(TOTAL_DATA_SIZE) \
           -DCOREMARK_CLOCK_HZ=$(CLOCK_HZ) $(RUN_DEFINE) $(OUTPUT_DEFINE)
LDFLAGS := -T$(PORT)/link_coremark.ld -Wl,--no-relax -Wl,--build-id=none

SRCS := $(COREMARK)/core_list_join.c $(COREMARK)/core_main.c \
        $(COREMARK)/core_matrix.c $(COREMARK)/core_state.c \
        $(COREMARK)/core_util.c $(PORT)/core_portme.c \
        $(PORT)/ee_printf.c
ELF := $(OUT)/coremark.elf

.PHONY: all clean info

all: $(ELF)

$(OUT):
	mkdir -p $@

$(ELF): $(SRCS) $(PORT)/core_portme.h $(COREMARK)/coremark.h \
        $(PORT)/start.S $(PORT)/link_coremark.ld | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) $(PORT)/start.S $(SRCS) -o $@
	$(OBJDUMP) -d $@ > $(@:.elf=.dump)
	$(READELF) -h -S $@ > $(@:.elf=.readelf)

info:
	@echo "ELF=$(ELF)"
	@echo "ITERATIONS=$(ITERATIONS) TOTAL_DATA_SIZE=$(TOTAL_DATA_SIZE) CLOCK_HZ=$(CLOCK_HZ) RUN_TYPE=$(RUN_TYPE) OUTPUT_DEVICE=$(OUTPUT_DEVICE)"
	@echo "CFLAGS=$(CFLAGS)"

clean:
	rm -rf $(OUT)
