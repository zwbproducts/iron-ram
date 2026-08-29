; idt.asm — Interrupt Descriptor Table setup
; BITS 32
GLOBAL idt
GLOBAL idt_desc
GLOBAL idt_init
EXTERN isr80_handler
EXTERN gpf_handler
EXTERN dblf_handler
EXTERN tss

section .data
align 16
idt: times 256 * 8 db 0

idt_desc:
    dw 256 * 8 - 1
    dd idt

section .text
idt_init:
    push edi
    push eax

    ; Build IDT entry for int 0x80 at idt + 0x80*8
    mov  edi, idt + 0x80 * 8

    ; Offset low (0..15)
    mov  eax, isr80_handler
    mov  [edi + 0], ax

    ; Selector (kernel code)
    mov  word [edi + 2], 0x08

    ; Reserved
    mov  byte [edi + 4], 0

    ; Access: present, DPL=3, 32-bit interrupt gate
    mov  byte [edi + 5], 0xEE

    ; Offset high (16..31)
    shr  eax, 16
    mov  [edi + 6], ax

    ; Build GPF handler at vector 13 (DPL=0, present, 32-bit interrupt gate)
    mov  edi, idt + 13 * 8
    mov  eax, gpf_handler
    mov  [edi + 0], ax
    mov  word [edi + 2], 0x08
    mov  byte [edi + 4], 0
    mov  byte [edi + 5], 0x8E
    shr  eax, 16
    mov  [edi + 6], ax

    ; Double Fault handler at vector 8 (present, DPL=0, 32-bit interrupt gate)
    mov  edi, idt + 8 * 8
    mov  eax, dblf_handler
    mov  [edi + 0], ax
    mov  word [edi + 2], 0x08
    mov  byte [edi + 4], 0
    mov  byte [edi + 5], 0x8E
    shr  eax, 16
    mov  [edi + 6], ax

    ; ─── Install TSS descriptor into GDT (entry 5) and load TR ───
    ; GDT is at linear 0x900; entry 5 descriptor at 0x900 + 5*8 = 0x928.
    ; Fill the base field with the linear address of tss.
    mov  eax, tss
    mov  edi, 0x928 + 2       ; base[0:15] field
    mov  [edi], ax            ; base low
    shr  eax, 16
    mov  [edi + 2], al        ; base[16:23] at 0x92C
    mov  [edi + 5], ah        ; base[24:31] at 0x92F

    mov  ax, 0x28            ; TSS selector
    ltr  ax

    ; Load IDT
    lidt [idt_desc]

    pop  eax
    pop  edi
    ret
