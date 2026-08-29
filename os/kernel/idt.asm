; idt.asm — Interrupt Descriptor Table setup
; BITS 32
GLOBAL idt
GLOBAL idt_desc
GLOBAL idt_init
EXTERN isr80_handler

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

    ; Load IDT
    lidt [idt_desc]

    pop  eax
    pop  edi
    ret
