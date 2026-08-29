; gpf.asm — General Protection Fault handler (vector 13)
; Prints 'G' to serial and halts, for debugging ring-transition faults.
[bits 32]
global gpf_handler

section .text
gpf_handler:
    ; CPU pushed error code, then EIP, CS, EFLAGS, (ESP, SS if ring change)
    mov  al, 'G'
    mov  dx, 0x3F8
    out  dx, al
.halt:
    cli
    hlt
    jmp  .halt
