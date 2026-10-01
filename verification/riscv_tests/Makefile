SHELL := /bin/bash

ROOT       := $(abspath $(CURDIR)/../..)
TESTS_ROOT := $(ROOT)/third_party/riscv-tests/isa
ENV_ROOT   := $(ROOT)/third_party/riscv-test-env

CROSS   ?= riscv64-unknown-elf
CC      := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
READELF := $(CROSS)-readelf

OUT ?= /tmp/ultraembedded-riscv-regression

CPPFLAGS := -I$(ENV_ROOT)/p -I$(TESTS_ROOT)/macros/scalar
CFLAGS   := -march=rv32im_zicsr_zifencei -mabi=ilp32 -mcmodel=medany \
            -ffreestanding -fno-pic -nostdlib -nostartfiles -static \
            -mno-relax
LDFLAGS  := -T$(CURDIR)/link_tcm.ld -Wl,--no-relax

UI_TESTS := add addi and andi auipc beq bge bgeu blt bltu bne fence_i \
            jal jalr lb lbu lh lhu lw ld_st lui ma_data or ori sb sh sw \
            st_ld sll slli slt slti sltiu sltu sra srai srl srli sub xor xori
UM_TESTS := div divu mul mulh mulhsu mulhu rem remu
MI_TESTS := mcsr ma_addr shamt

TEST_NAMES := $(addprefix rv32ui/,$(UI_TESTS)) \
              $(addprefix rv32um/,$(UM_TESTS)) \
              $(addprefix rv32mi/,$(MI_TESTS))
ELFS := $(addprefix $(OUT)/,$(addsuffix .elf,$(TEST_NAMES)))

.PHONY: all clean list

all: $(ELFS)

list:
	@printf '%s\n' $(TEST_NAMES)

$(OUT)/rv32ui/%.elf: $(TESTS_ROOT)/rv32ui/%.S $(CURDIR)/link_tcm.ld $(ENV_ROOT)/p/riscv_test.h | $(OUT)/rv32ui
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $< -o $@
	$(OBJDUMP) -d $@ > $(@:.elf=.dump)
	$(READELF) -h -S $@ > $(@:.elf=.readelf)

$(OUT)/rv32um/%.elf: $(TESTS_ROOT)/rv32um/%.S $(CURDIR)/link_tcm.ld $(ENV_ROOT)/p/riscv_test.h | $(OUT)/rv32um
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $< -o $@
	$(OBJDUMP) -d $@ > $(@:.elf=.dump)
	$(READELF) -h -S $@ > $(@:.elf=.readelf)

$(OUT)/rv32mi/%.elf: $(TESTS_ROOT)/rv32mi/%.S $(CURDIR)/link_tcm.ld $(ENV_ROOT)/p/riscv_test.h | $(OUT)/rv32mi
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $< -o $@
	$(OBJDUMP) -d $@ > $(@:.elf=.dump)
	$(READELF) -h -S $@ > $(@:.elf=.readelf)

$(OUT)/rv32ui $(OUT)/rv32um $(OUT)/rv32mi:
	mkdir -p $@

clean:
	rm -rf $(OUT)
