; ===========================================================================
; userland.asm — Ring-3 entry stub that launches the C shell.
; Runs in ring 3, can ONLY access kernel via int 0x80.
;
; Target: 32-bit x86 protected mode, ring 3
; Memory: Loaded at 0x200000
; ===========================================================================

[BITS 32]
GLOBAL _start
EXTERN shell_main
EXTERN shell_selftest
EXTERN shell_demo

section .text._start
_start:
    ; Run automated demo: proves all 28 syscalls via int 0x80.
    call shell_demo
    ; Then start the interactive shell.
    call shell_main
    ; If shell ever returns, halt.
.halt:
    cli
    hlt
    jmp  .halt
