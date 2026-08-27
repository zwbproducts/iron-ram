; memeq.asm — Check if two memory regions are identical (16-bit real-mode port)
; int memeq16(const void *s1, const void *s2, size_t count)
;
; Port of libmem/memeq.asm.
; Register convention: DI=s1  SI=s2  CX=count
; Returns: AX = 1 if equal, 0 if not

global memeq16

memeq16:
    push di
    push si
    push cx

    test cx, cx
    jz   .equal

.cmp:
    mov  al, [di]
    cmp  al, [si]
    jne  .not_equal
    inc  di
    inc  si
    dec  cx
    jnz  .cmp

.equal:
    mov  ax, 1
    pop  cx
    pop  si
    pop  di
    ret

.not_equal:
    mov  ax, 0
    pop  cx
    pop  si
    pop  di
    ret
