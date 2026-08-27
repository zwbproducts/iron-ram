; idt.asm — build and load a 256-entry 32-bit IDT
;
; Real entries installed:
;   vector 0x80 -> isr80_handler  (syscalls, DPL=3 for userland)
;   vector 0x81 -> isr81_handler  (signals,  DPL=3 for bootloader signal)
;   vector 0x0D -> gpf_handler    (GPF exception, DPL=0 kernel-only)
;
; The rest is zeroed (not-present). No hardware interrupts are enabled (cli),
; so no spurious exceptions are expected.

[bits 32]
%define IDT_VEC_SYSCALL    0x80
%define IDT_VEC_SIGNAL     0x81
%define IDT_VEC_GPF        0x0D

global idt
global idt_desc
global idt_init
extern isr80_handler
extern isr81_handler
extern gpf_handler

section .data
idt:
    times 256 * 8 dd 0, 0           ; 2048 bytes, all zero

idt_desc:
    dw 256 * 8 - 1                 ; limit
    dd idt                         ; base

section .text
idt_init:
    ; --- vector 0x80: syscall gate (DPL=3) ---
    mov  eax, isr80_handler
    mov  edi, idt + IDT_VEC_SYSCALL * 8
    mov  [edi + 0], ax             ; offset 0..15
    mov  word [edi + 2], 0x08      ; code selector (kernel)
    mov  byte [edi + 4], 0x00
    mov  byte [edi + 5], 0x8E      ; P=1, DPL=3, 32-bit interrupt gate
    shr  eax, 16
    mov  [edi + 6], ax             ; offset 16..31

    ; --- vector 0x81: signal gate (DPL=3) ---
    mov  eax, isr81_handler
    mov  edi, idt + IDT_VEC_SIGNAL * 8
    mov  [edi + 0], ax             ; offset 0..15
    mov  word [edi + 2], 0x08      ; code selector (kernel)
    mov  byte [edi + 4], 0x00
    mov  byte [edi + 5], 0x8E      ; P=1, DPL=3, 32-bit interrupt gate
    shr  eax, 16
    mov  [edi + 6], ax             ; offset 16..31

    ; --- vector 0x0D: GPF handler (DPL=0, kernel-only) ---
    mov  eax, gpf_handler
    mov  edi, idt + IDT_VEC_GPF * 8
    mov  [edi + 0], ax             ; offset 0..15
    mov  word [edi + 2], 0x08      ; code selector (kernel)
    mov  byte [edi + 4], 0x00
    mov  byte [edi + 5], 0x8E      ; P=1, DPL=0, 32-bit interrupt gate
    shr  eax, 16
    mov  [edi + 6], ax             ; offset 16..31

    lidt [idt_desc]
    ret
