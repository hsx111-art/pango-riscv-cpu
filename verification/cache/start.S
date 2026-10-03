    .section .text.init
    .align 2
    .globl _start
    .type _start, @function
_start:
    li sp, 0x00005ff0
    li gp, 0
    call main
1:
    j 1b