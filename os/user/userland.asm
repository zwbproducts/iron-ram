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

section .text._start
_start:
    ; Run the automated self-test first (proves all syscalls work).
    call shell_selftest
    ; Then start the interactive shell.
    call shell_main
    ; If shell ever returns, halt.
.halt:
    cli
    hlt
    jmp  .halt
