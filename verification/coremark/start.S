    .section .text.init
    .align 2
    .globl _start
    .type _start, @function
_start:
    li sp, 0x0000fff0
    li gp, 0
    call main
    li a0, 0x01000050
    csrw dscratch, a0
    li a0, 0
    csrw dscratch, a0
1:
    j 1b
