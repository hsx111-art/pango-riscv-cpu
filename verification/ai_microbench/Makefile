SHELL := /bin/bash

ROOT := $(abspath $(CURDIR)/../..)
OUT ?= $(ROOT)/.build/ai_microbench
CROSS ?= riscv64-unknown-elf
CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
READELF := $(CROSS)-readelf

AI_REPEAT ?= 16

CFLAGS := -march=rv32im_zicsr_zifencei -mabi=ilp32 -mcmodel=medany \
           -O2 -ffreestanding -fno-builtin -fno-pic -fno-stack-protector \
           -fno-asynchronous-unwind-tables -nostdlib -nostartfiles -static \
           -mno-relax -I$(CURDIR) -DAI_REPEAT=$(AI_REPEAT)
LDFLAGS := -T$(CURDIR)/link_ai.ld -Wl,--no-relax

WORKLOADS := dot_i8 gemm_i8 conv_i8 relu_i8
ELFS := $(addprefix $(OUT)/,$(addsuffix .elf,$(WORKLOADS)))

.PHONY: all clean list

all: $(ELFS)

list:
	@printf '%s\n' $(WORKLOADS)

define build_workload
$(OUT)/$(1).elf: $(CURDIR)/start.S $(CURDIR)/ai_microbench.c $(CURDIR)/link_ai.ld | $(OUT)
	$$(CC) $$(CFLAGS) -DWORKLOAD_$(2) $$(LDFLAGS) $$(CURDIR)/start.S $$(CURDIR)/ai_microbench.c -o $$@
	$$(OBJDUMP) -d $$@ > $$(@:.elf=.dump)
	$$(READELF) -h -S $$@ > $$(@:.elf=.readelf)
endef

$(eval $(call build_workload,dot_i8,DOT_I8))
$(eval $(call build_workload,gemm_i8,GEMM_I8))
$(eval $(call build_workload,conv_i8,CONV_I8))
$(eval $(call build_workload,relu_i8,RELU_I8))

$(OUT):
	mkdir -p $@

clean:
	rm -rf $(OUT)
