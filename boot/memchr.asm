; memchr.asm — Find byte in memory (16-bit real-mode port)
; void *memchr16(const void *s, int c, size_t count)
;
; Port of libmem/memchr.asm.
; Register convention: DI=dest  AL=byte  CX=count
; Returns: DI = pointer to found byte, or 0 if not found

global memchr16

memchr16:
    push cx
    push ax

    test di, di
    jz   .notfound
    test cx, cx
    jz   .notfound

.find:
    cmp  al, [di]
    je   .found
    inc  di
    dec  cx
    jnz  .find

.notfound:
    xor  di, di                  ; return NULL
    pop  ax
    pop  cx
    ret

.found:
    pop  ax
    pop  cx
    ret                          ; DI = pointer to found byte
