; stage1.asm — mirror boot.asm read exactly + markers
BITS 16
ORG 0x7C00

bootdrv db 0

%macro SER 0
    push dx
    push ax
    mov  dx, 0x3F8
    out  dx, al
    pop  ax
    pop  dx
%endmacro

start:
    xor  ax, ax
    mov  [bootdrv], dl
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    call load_kernel
    jmp  .ok
.fail:  mov  al, 'X'
    SER
    hlt
    jmp  $
.ok:    mov  al, 'O'
    SER
.halt: cli
    hlt
    jmp .halt

load_kernel:
    mov  dl, [bootdrv]
    mov  ax, 0x0000
    mov  es, ax
    mov  bx, 0x8000
    mov  ah, 0x02
    mov  al, 1
    xor  cx, cx
    mov  cl, 2
    xor  dh, dh
    sti
    int  0x13
    cli
    mov  al, 'r'
    SER
    mov  al, '0'
    adc  al, 0
    SER                 ; cf
    mov  al, ah
    call hex2
    mov  bx, 0x8000
    mov  al, [bx]
    call hex2           ; byte@0x8000

hex2:
    push eax
    push ecx
    mov  cl, 2
.h1:
    rol  al, 4
    push ecx
    call .n
    pop  ecx
    loop .h1
    pop  ecx
    pop  eax
    ret
.n:
    push eax
    and  al, 0x0F
    add  al, '0'
    cmp  al, '9'
    jbe  .n1
    add  al, 7
.n1:
    mov  dx, 0x3F8
    out  dx, al
    pop  eax
    ret

times 510-($-$$) db 0
dw 0xAA55
