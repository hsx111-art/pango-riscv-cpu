OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00002000;

  .text.init : { *(.text.init) }
  .text      : { *(.text) }
  .rodata    : { *(.rodata*) }
  .tohost    : { *(.tohost) }
  .data      : { *(.data*) }
  .bss       : { *(.bss*) *(COMMON) }

  . = ALIGN(4);
  _end = .;
}
