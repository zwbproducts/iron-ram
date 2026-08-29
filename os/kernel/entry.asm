; entry.asm — 32-bit kernel entry (_start)
; BITS 32
GLOBAL _start
EXTERN __bss_start
EXTERN __bss_end
EXTERN kmain

section .text._start
_start:
    cli
    ; Heartbeat: S = kernel entry
    mov  al, 'S'
    mov  dx, 0x3F8
    out  dx, al

    ; Zero BSS
    cld
    mov  edi, __bss_start
    mov  ecx, __bss_end
    sub  ecx, edi
    shr  ecx, 2
    xor  eax, eax
    rep  stosd

    ; Heartbeat: B = BSS cleared
    mov  al, 'B'
    mov  dx, 0x3F8
    out  dx, al

    ; Install IDT
    call idt_init

    ; Heartbeat: I = IDT installed
    mov  al, 'I'
    mov  dx, 0x3F8
    out  dx, al

    ; Call kmain
    call kmain

    ; Heartbeat: R = kmain returned
    mov  al, 'R'
    mov  dx, 0x3F8
    out  dx, al

.halt:
    cli
    hlt
    jmp  .halt

section .text
; keep other code here
