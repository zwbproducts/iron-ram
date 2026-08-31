; entry.asm — 32-bit kernel entry (_start)
; BITS 32
GLOBAL _start
GLOBAL tss
EXTERN __bss_start
EXTERN __bss_end
EXTERN idt_init

USER_CODE  equ 0x1B
USER_DATA  equ 0x23
USER_STACK equ 0x209000
KERNEL_STACK equ 0x9FC00
TSS_SEL   equ 0x28

section .text._start
_start:
    cli
    ; Heartbeat: S = kernel entry
    mov  al, 'S'
    mov  dx, 0xe9
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
    mov  dx, 0xe9
    out  dx, al

    ; Install IDT (int 0x80 gate) and load TSS
    call idt_init

    ; Heartbeat: I = IDT installed
    mov  al, 'I'
    mov  dx, 0xe9
    out  dx, al

    ; ─── Enter userland in ring 3 via iret ───
    mov  ax, USER_DATA
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax

    ; Heartbeat: E = about to enter userland
    mov  al, 'E'
    mov  dx, 0xe9
    out  dx, al

    push dword USER_DATA      ; SS (ring 3)
    push dword USER_STACK     ; ESP (ring 3)
    push dword 0x00000002     ; EFLAGS (IF cleared)
    push dword USER_CODE      ; CS (ring 3, DPL=3)
    push dword 0x200000       ; EIP = userland entry
    iret

.halt:
    cli
    hlt
    jmp  .halt

section .data
; 32-bit TSS — provides ESP0/SS0 for ring-0 stack on privilege changes.
; esp0/ss0 filled here; the rest is zero.
tss:
    dd 0                      ; back link
    dd KERNEL_STACK           ; esp0
    dd 0x10                   ; ss0
    dd 0, 0, 0, 0, 0          ; esp1, ss1, esp2, ss2, cr3
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0   ; eip, eflags, eax, ecx, edx, ebx, esp, ebp, esi
    dd 0, 0, 0, 0, 0, 0      ; edi, es, cs, ss, ds, fs
    dd 0                      ; gs
    dd 0                      ; ldt
    dw 0                      ; trap
    dw 104                    ; iomap base

section .text
; keep other code here
