; isr80.asm — handler for `int 0x80` syscalls
;
; ABI:
;   eax = syscall number, ebx = arg0, ecx = arg1, edx = arg2
;   result returned in eax.
;
; pusha layout (after pusha, esp points here):
;   [esp+0]  = EAX (saved)  -> this is where we write the result
;   [esp+4]  = ECX
;   [esp+8]  = EDX
;   [esp+12] = EBX
;   [esp+16] = ESP (original, ignored)
;   [esp+20] = EBP
;   [esp+24] = ESI
;   [esp+28] = EDI
; No error code is pushed for vector 0x80, so the stack is exactly the
; pusha block. We call syscall_dispatch(num,a0,a1,a2) -> result in eax,
; then store eax into the saved-EAX slot so popa restores it.

[bits 32]
global isr80_handler
extern syscall_dispatch

isr80_handler:
    pusha
    push edx
    push ecx
    push ebx
    push eax
    call syscall_dispatch
    add  esp, 16                  ; pop the four arg pushes
    mov  [esp + 0], eax           ; write result into saved EAX slot
    popa
    iret
