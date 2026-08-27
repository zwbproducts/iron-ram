; memcmp.asm — Compare two memory regions (16-bit real-mode port)
; int memcmp16(const void *s1, const void *s2, size_t count)
;
; Port of libmem/memcmp.asm.
; Register convention: DI=s1  SI=s2  CX=count
; Returns AX = <0, 0, or >0 (signed difference)

global memcmp16

memcmp16:
    push di
    push si
    push cx
    push bx

    test cx, cx
    jz   .equal                  ; count==0 → equal

.cmp_loop:
    mov  al, [di]
    mov  bl, [si]
    cmp  al, bl
    jne  .diff
    inc  di
    inc  si
    loop .cmp_loop

.equal:
    xor  ax, ax                  ; 0
    pop  bx
    pop  cx
    pop  si
    pop  di
    ret

.diff:
    mov  al, [di]
    mov  bl, [si]
    mov  ah, 0
    mov  bh, 0
    sub  ax, bx                  ; signed difference in AX
    pop  bx
    pop  cx
    pop  si
    pop  di
    ret
