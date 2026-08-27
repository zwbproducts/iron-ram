; isr81.asm — handler for signal interrupt (int 0x81)
;
; ABI:
;   eax = signal number, ebx = arg0, ecx = arg1, edx = arg2
;   result returned in eax.
;
; Signals are "simple interrupts acting as jumps": the bootloader
; (or kernel init) triggers int 0x81 to verify libmem readiness.
; The handler routes to signal_dispatch() — the kernel-owned function
; that only calls libmem routines.  Usermode code cannot access this
; path except through the designated interrupt gate.
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
; No error code is pushed for vector 0x81, so the stack is exactly the
; pusha block.

[bits 32]
global isr81_handler
extern signal_dispatch

isr81_handler:
    pusha
    push edx
    push ecx
    push ebx
    push eax
    call signal_dispatch
    add  esp, 16                  ; pop the four arg pushes
    mov  [esp + 0], eax           ; write result into saved EAX slot
    popa
    iret
