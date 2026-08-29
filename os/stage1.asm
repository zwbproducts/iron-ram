; stage1.asm — 32-bit protected-mode bootloader (stage 1)
BITS 16
ORG 0x7C00

%ifndef KERNEL_SECTORS
    %define KERNEL_SECTORS 8
%endif

SER_PORT equ 0x3F8

%macro SEROUT 1
    push ax
    mov  al, %1
    mov  dx, SER_PORT
    out  dx, al
    pop  ax
%endmacro

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7B00
    sti

    mov  [bootdrv], dl

    ; ─── Enable A20 ───
    in   al, 0x92
    or   al, 0x02
    out  0x92, al

    SEROUT 'S'

    ; ─── Load kernel from disk ───
    SEROUT 'L'

    mov  cx, KERNEL_SECTORS
    mov  byte [sector], 2
    mov  word [buf_seg], 0x0800
    mov  word [buf_off], 0

read_loop:
    mov  ax, [buf_seg]
    mov  es, ax
    mov  bx, [buf_off]
    push cx
    mov  ah, 0x02
    mov  al, 1
    mov  ch, 0
    mov  cl, [sector]
    mov  dh, 0
    mov  dl, [bootdrv]
    int  0x13
    pop  cx
    jc  disk_error

    add  word [buf_off], 512
    mov  ax, [buf_off]
    cmp  ax, 0x8000
    jb  no_wrap
    add  word [buf_seg], 0x0800
    sub  word [buf_off], 0x8000
no_wrap:
    inc  byte [sector]
    loop  read_loop

    SEROUT 'K'

    ; ─── Copy kernel from 0x8000 to 0x100000 ───
    SEROUT 'C'
    mov  ax, 0x0800
    mov  ds, ax
    xor  si, si
    mov  ax, 0xFFFF
    mov  es, ax
    mov  di, 0x0010
    mov  cx, KERNEL_SECTORS
    shl  cx, 7
    cld
    rep  movsw

    ; ─── Switch to protected mode ───
    SEROUT 'P'
    cli

    ; Reset DS and ES to 0 (was changed during kernel copy)
    xor  ax, ax
    mov  ds, ax
    mov  es, ax

    ; ─── Build GDT at 0x900 using byte stores ───
    mov  di, 0x900
    ; null entry
    mov  word [es:di], 0
    mov  word [es:di+2], 0
    mov  word [es:di+4], 0
    mov  word [es:di+6], 0
    ; code entry at 0x908
    mov  word [es:di+8], 0xFFFF
    mov  word [es:di+10], 0
    mov  byte [es:di+12], 0
    mov  byte [es:di+13], 0x9A
    mov  byte [es:di+14], 0xCF
    mov  byte [es:di+15], 0
    ; data entry at 0x910
    mov  word [es:di+16], 0xFFFF
    mov  word [es:di+18], 0
    mov  byte [es:di+20], 0
    mov  byte [es:di+21], 0x92
    mov  byte [es:di+22], 0xCF
    mov  byte [es:di+23], 0

    ; GDT descriptor at 0x9F0
    mov  di, 0x9F0
    mov  word [es:di], 23
    mov  word [es:di+2], 0x0900
    mov  word [es:di+4], 0
    mov  word [es:di+6], 0

    lgdt  [es:di]

    ; Set CR0.PE
    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax

    ; Far jump to 32-bit code segment
    ; The 32-bit code (pm_entry) immediately follows this instruction
    db  0x66, 0xEA
    dd  0x7D3B                    ; pm_entry absolute address
    dw  0x08

    ; ─── pm_entry: 32-bit code begins right here ───
    [bits 32]
pm_entry:
    mov  al, 'Q'       ; verify we reached 32-bit mode
    mov  dx, 0x3F8
    out  dx, al

    mov  ax, 0x10      ; data segment selector
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x9FC00

    ; Jump to kernel _start (linked at 0x100000)
    mov  eax, 0x100000
    jmp  eax

disk_error:
    SEROUT 'E'
    SEROUT '!'
.halt:
    cli
    hlt
    jmp  .halt

; ─── Data variables ───
bootdrv  db 0
sector   db 0
buf_seg  dw 0
buf_off  dw 0

times 510-($-$$) db 0
dw 0xAA55
