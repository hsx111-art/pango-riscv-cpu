OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00002000;
  .text.init : { KEEP(*(.text.init)) }
  .text      : { *(.text .text.*) }
  .rodata    : { *(.rodata .rodata.*) }
  .data      : { *(.data .data.*) }
  .sdata     : { *(.sdata .sdata.*) }
  .bss (NOLOAD) : { *(.bss .bss.* COMMON) }
  .sbss (NOLOAD) : { *(.sbss .sbss.*) }

  .stack 0x00005000 :
  {
    . += 0x1000;
  }

  .cache_a 0x00010000 : ALIGN(32) { KEEP(*(.cache_a)) }
  .cache_b 0x00012000 : ALIGN(32) { KEEP(*(.cache_b)) }
  .cache_c 0x00014000 : ALIGN(32) { KEEP(*(.cache_c)) }
  .cache_d 0x00016000 : ALIGN(32) { KEEP(*(.cache_d)) }

  . = ALIGN(4);
  _end = .;
}