; stage1.asm — 32-bit protected-mode bootloader with kernel + userland loading
; BITS 16
ORG 0x7C00

%ifndef KERNEL_SECTORS
    %define KERNEL_SECTORS 8
%endif

%ifndef USER_SECTORS
    %define USER_SECTORS 2
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

    ; ─── Load kernel + userland in one loop ───
    ; Kernel -> 0x0800:0 (RM 0x8000), Userland -> 0x1000:0 (RM 0x10000)
    SEROUT 'L'

    mov  cx, KERNEL_SECTORS + USER_SECTORS
    mov  byte [sector], 2
    mov  word [buf_seg], 0x0800
    mov  word [buf_off], 0
    mov  byte [kern_rem], KERNEL_SECTORS

.read_loop:
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
    jc  .disk_error

    add  word [buf_off], 512
    mov  ax, [buf_off]
    cmp  ax, 0x8000
    jb  .no_wrap
    add  word [buf_seg], 0x0800
    sub  word [buf_off], 0x8000
.no_wrap:
    dec  byte [kern_rem]
    jnz  .still_kernel
    ; Switch userland destination to 0x1000:0 once kernel sectors done
    cmp  word [buf_seg], 0x0800
    jne  .still_kernel
    mov  word [buf_seg], 0x1000
    mov  word [buf_off], 0
.still_kernel:
    inc  byte [sector]
    loop  .read_loop

    SEROUT 'K'

    ; ─── Copy kernel 0x8000 -> 0x100000 (real mode, via 0xFFFF:0x10) ───
    SEROUT 'C'
    mov  ax, 0x0800
    mov  ds, ax
    xor  si, si
    mov  ax, 0xFFFF
    mov  es, ax
    mov  di, 0x0010            ; 0xFFFF0 + 0x10 = 0x100000
    mov  cx, KERNEL_SECTORS
    shl  cx, 8
    cld
    rep  movsw

    SEROUT 'P'
    cli

    xor  ax, ax
    mov  ds, ax
    mov  es, ax

    ; ─── Copy static GDT to 0x900 ───
    mov  si, gdt_data
    mov  di, 0x900
    mov  cx, gdt_end - gdt_data
    cld
    rep  movsb

    lgdt  [gdt_desc]

    ; Set CR0.PE
    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax

    ; Far jump to 32-bit pm_entry (absolute = ORG + offset)
    db  0x66, 0xEA
    dd  0x7C00 + (pm_entry - start)
    dw  0x08

.disk_error:
    SEROUT 'E'
    SEROUT '!'
.halt:
    cli
    hlt
    jmp  .halt

; ─── 32-bit protected mode entry ───
[bits 32]
pm_entry:
    mov  al, 'Q'
    mov  dx, 0x3F8
    out  dx, al

    ; Flat kernel data segments (base 0, limit 4GB)
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x9FC00

    ; ─── Copy userland 0x10000 -> 0x200000 (flat 32-bit) ───
    SEROUT 'D'
    mov  esi, 0x10000          ; RM load address of userland
    mov  edi, 0x200000         ; target
    xor  ecx, ecx
    mov  cl, [kern_rem2]       ; userland sector count (set below)
    shl  ecx, 7                ; sectors * 128 dwords = sectors * 512 bytes
    cld
    rep  movsd

    ; Jump to kernel _start
    mov  eax, 0x100000
    jmp  eax

; ─── Data variables ───
bootdrv  db 0
sector   db 0
buf_seg  dw 0
buf_off  dw 0
kern_rem db 0
kern_rem2 db USER_SECTORS

; ─── Static GDT (5 entries) ───
gdt_data:
    dd 0, 0                                  ; null
    dw 0xFFFF, 0, 0x9A00, 0x00CF            ; kcode 0x08
    dw 0xFFFF, 0, 0x9200, 0x00CF            ; kdata 0x10
    dw 0xFFFF, 0, 0xFB00, 0x00CF            ; ucode 0x1B (conforming, DPL=3)
    dw 0xFFFF, 0, 0xF200, 0x00CF            ; udata 0x23
    ; TSS descriptor placeholder (entry 5, selector 0x28); base filled by kernel
    dw 0x0067, 0, 0x8900, 0x0000            ; limit=103, base=0, TSS32, DPL=0
gdt_end:

gdt_desc:
    dw gdt_end - gdt_data - 1
    dd 0x900

times 510-($-$$) db 0
dw 0xAA55
