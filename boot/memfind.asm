; memfind.asm — Find a byte in memory, return offset (16-bit real-mode port)
; int memfind16(const void *s, int c, size_t count)
;
; Port of libmem/memfind.asm.
; Register convention: DI=dest  AL=byte to find  CX=count
; Returns: AX = offset of first match, or -1 (0xFFFF) if not found

global memfind16

memfind16:
    push di
    push cx

    test di, di
    jz   .notfound
    test cx, cx
    jz   .notfound

    xor  bx, bx                  ; offset = 0

.find:
    cmp  al, [di]
    je   .found
    inc  di
    inc  bx
    dec  cx
    jnz  .find

.notfound:
    mov  ax, -1                  ; 0xFFFF
    pop  cx
    pop  di
    ret

.found:
    mov  ax, bx
    pop  cx
    pop  di
    ret
