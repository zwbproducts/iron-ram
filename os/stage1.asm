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

    ; ─── Load kernel from disk ───
    SEROUT 'L'

    mov  cx, KERNEL_SECTORS
    mov  byte [sector], 2
    mov  word [buf_seg], 0x0800
    mov  word [buf_off], 0

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
    inc  byte [sector]
    loop  .read_loop

    SEROUT 'K'

    ; ─── Load userland from disk (after kernel) ───
    SEROUT 'U'

    mov  cx, USER_SECTORS
    mov  word [buf_seg], 0x1000
    mov  word [buf_off], 0

.user_read_loop:
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
    jb  .user_no_wrap
    add  word [buf_seg], 0x0800
    sub  word [buf_off], 0x8000
.user_no_wrap:
    inc  byte [sector]
    loop  .user_read_loop

    SEROUT 'W'

    ; ─── Copy kernel from 0x8000 to 0x100000 ───
    SEROUT 'C'
    mov  ax, 0x0800
    mov  ds, ax
    xor  si, si
    mov  ax, 0xFFFF
    mov  es, ax
    mov  di, 0x0010
    mov  cx, KERNEL_SECTORS
    shl  cx, 8
    cld
    rep  movsw

    ; ─── Copy userland from 0x1000 to 0x200000 ───
    SEROUT 'D'
    mov  ax, 0x1000
    mov  ds, ax
    xor  si, si
    mov  ax, 0xFFFF
    mov  es, ax
    mov  di, 0x0020
    mov  cx, USER_SECTORS
    shl  cx, 8
    cld
    rep  movsw

    SEROUT 'P'
    cli

    ; Reset DS and ES to 0
    xor  ax, ax
    mov  ds, ax
    mov  es, ax

    ; ─── Build GDT at 0x900 ───
    ; Entry 0: null
    ; Entry 1: kernel code (0x08)
    ; Entry 2: kernel data (0x10)
    ; Entry 3: user code (0x1B)
    ; Entry 4: user data (0x23)
    mov  di, 0x900

    ; Null entry
    mov  dword [es:di], 0
    mov  dword [es:di+4], 0

    ; Kernel code: base=0, limit=4GB, DPL=0, code
    mov  word [es:di+8], 0xFFFF       ; limit low
    mov  word [es:di+10], 0           ; base low
    mov  byte [es:di+12], 0           ; base mid
    mov  byte [es:di+13], 0x9A        ; access: present, DPL=0, code, readable
    mov  byte [es:di+14], 0xCF        ; flags: G=1, D=1, limit high=0xF
    mov  byte [es:di+15], 0           ; base high

    ; Kernel data: base=0, limit=4GB, DPL=0, data
    mov  word [es:di+16], 0xFFFF
    mov  word [es:di+18], 0
    mov  byte [es:di+20], 0
    mov  byte [es:di+21], 0x92        ; access: present, DPL=0, data, writable
    mov  byte [es:di+22], 0xCF
    mov  byte [es:di+23], 0

    ; User code: base=0, limit=4GB, DPL=3, code
    mov  word [es:di+24], 0xFFFF
    mov  word [es:di+26], 0
    mov  byte [es:di+28], 0
    mov  byte [es:di+29], 0xFA        ; access: present, DPL=3, code, readable
    mov  byte [es:di+30], 0xCF
    mov  byte [es:di+31], 0

    ; User data: base=0, limit=4GB, DPL=3, data
    mov  word [es:di+32], 0xFFFF
    mov  word [es:di+34], 0
    mov  byte [es:di+36], 0
    mov  byte [es:di+37], 0xF2        ; access: present, DPL=3, data, writable
    mov  byte [es:di+38], 0xCF
    mov  byte [es:di+39], 0

    ; GDT descriptor at 0x9F0
    mov  di, 0x9F0
    mov  word [es:di], 40 - 1          ; limit = 5*8 - 1 = 39
    mov  dword [es:di+2], 0x900        ; base = 0x900
    mov  word [es:di+6], 0             ; alignment

    lgdt  [es:di]

    ; Set CR0.PE
    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax

    ; Far jump to kernel code
    db  0x66, 0xEA
    dd  0x7D00 + (pm_entry - start)    ; pm_entry absolute address
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

    ; Set kernel segment registers
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x9FC00

    ; Jump to kernel _start
    mov  eax, 0x100000
    jmp  eax

; ─── Data variables ───
bootdrv  db 0
sector   db 0
buf_seg  dw 0
buf_off  dw 0

times 510-($-$$) db 0
dw 0xAA55
