###############################################################################
## Tool paths
###############################################################################
VERILATOR_SRC ?= /usr/share/verilator/include
SYSTEMC_HOME  ?= /usr/local/systemc-2.3.1

ifeq ($(wildcard $(SYSTEMC_HOME)/include/systemc.h),)
SYSTEMC_INCLUDE ?= /usr/include
else
SYSTEMC_INCLUDE ?= $(SYSTEMC_HOME)/include
endif

ifeq ($(wildcard $(SYSTEMC_HOME)/lib-linux64/libsystemc.a),)
SYSTEMC_LIBDIR ?= /usr/lib/x86_64-linux-gnu
else
SYSTEMC_LIBDIR ?= $(SYSTEMC_HOME)/lib-linux64
endif

TEST_IMAGE ?= ../../isa_sim/images/basic.elf

CORE       ?= riscv

export VERILATOR_SRC
export SYSTEMC_HOME
export SYSTEMC_INCLUDE
export SYSTEMC_LIBDIR
unexport SRC
unexport NAME

###############################################################################
## Makefile
###############################################################################
all: build

build:
	env -u SRC -u NAME $(MAKE) -C ../../isa_sim lib
	env -u SRC -u NAME $(MAKE) -f makefile.generate_verilated CORE=$(CORE) SRC=riscv_tcm_top NAME=riscv_tcm_top
	env -u SRC -u NAME $(MAKE) -f makefile.build_verilated
	env -u SRC -u NAME $(MAKE) -f makefile.build_sysc_tb

clean:
	env -u SRC -u NAME $(MAKE) -f makefile.generate_verilated  CORE=$(CORE) SRC=riscv_tcm_top NAME=riscv_tcm_top $@
	env -u SRC -u NAME $(MAKE) -f makefile.build_verilated $@
	env -u SRC -u NAME $(MAKE) -f makefile.build_sysc_tb $@
	-rm -f *.vcd

run: build
	./build/test.x -f $(TEST_IMAGE)
