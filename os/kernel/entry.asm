; entry.asm — 32-bit kernel entry (_start)
; Called by stage1 via `jmp 0x100000`. BSS is zeroed here, then IDT is
; initialized, and finally kmain() runs. If kmain returns we halt.

[bits 32]
GLOBAL _start
EXTERN __bss_start
EXTERN __bss_end
EXTERN idt_init
EXTERN kmain

section .text._start
_start:
    cli
    mov  al, 'S'
    mov  dx, 0x3F8
    out  dx, al
    ; --- zero .bss ---
    cld
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, edi
    shr ecx, 2
    xor eax, eax
    rep stosd

    ; --- install IDT (vector 0x80) ---
    call idt_init

    mov  al, 'I'
    mov  dx, 0x3F8
    out  dx, al

    ; --- debug: serial 'K' ---
    mov  al, 'K'
    mov  dx, 0x3F8
    out  dx, al

    mov  al, 'B'
    out  dx, al

    ; --- hand off to C ---
    call kmain

.halt:
    cli
    hlt
    jmp .halt

section .text
; keep other code here
