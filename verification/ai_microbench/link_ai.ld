OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00002000;

  .text.init : { *(.text.init) }
  .text      : { *(.text*) }
  .rodata    : { *(.rodata*) }
  .data      : { *(.data*) }
  .bss       : { *(.bss*) *(COMMON) }

  . = ALIGN(16);
  _stack_bottom = .;
  . += 0x1000;
  _stack_top = .;
  _end = .;
}
