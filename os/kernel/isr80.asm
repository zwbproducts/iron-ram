; isr80.asm — Syscall handler (int 0x80)
; This is the ONLY entry point from userland to kernel.
;
; ABI:
;   EAX = syscall number
;   EBX = arg0
;   ECX = arg1
;   EDX = arg2
;   Returns: EAX = result
;
; The handler validates the syscall number, dispatches to the kernel
; implementation, and returns a controlled result.

[BITS 32]
GLOBAL isr80_handler
EXTERN syscall_dispatch

section .text
isr80_handler:
    ; Save all registers (syscall args + scratch)
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Validate syscall number (table has entries 0..27, so 28 is invalid)
    cmp  eax, 28             ; SYS_MAX
    jae  .invalid

    ; Save syscall number and args on stack for C dispatcher
    push edx                  ; arg2
    push ecx                  ; arg1
    push ebx                  ; arg0
    push eax                  ; syscall number

    ; Call C dispatcher
    call syscall_dispatch

    ; Clean up args (cdecl: caller cleanup, but we pushed them)
    add  esp, 16

    ; Restore registers (except EAX which holds return value)
    pop  ebp
    pop  edi
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    iret

.invalid:
    mov  eax, -1              ; Return error for invalid syscall
    pop  ebp
    pop  edi
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    iret
