; dblf.asm — Double Fault handler (vector 8) for diagnostics
[bits 32]
global dblf_handler

section .text
dblf_handler:
    mov  al, 'X'
    mov  dx, 0xe9
    out  dx, al
.halt:
    cli
    hlt
    jmp  .halt
