OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00002000;
  .text.init : { KEEP(*(.text.init)) }
  .text      : { *(.text .text.*) }
  .rodata    : { *(.rodata .rodata.*) }
  .srodata   : { *(.srodata .srodata.*) }
  .data      : { *(.data .data.*) }
  .sdata     : { *(.sdata .sdata.*) }
  .bss      (NOLOAD) : { *(.bss .bss.* COMMON) }
  .sbss     (NOLOAD) : { *(.sbss .sbss.*) }
  . = ALIGN(4);
  _end = .;
}
