; memcount.asm — Count byte occurrences in memory (16-bit real-mode port)
; int memcount16(const void *s, int c, size_t count)
;
; Port of libmem/memcount.asm.
; Register convention: DI=dest  AL=byte to count  CX=count
; Returns: AX = number of matching bytes

global memcount16

memcount16:
    push di
    push cx

    test di, di
    jz   .done
    test cx, cx
    jz   .done

    xor  bx, bx                  ; count = 0

.count:
    cmp  al, [di]
    jne  .skip
    inc  bx

.skip:
    inc  di
    dec  cx
    jnz  .count

.done:
    mov  ax, bx
    pop  cx
    pop  di
    ret
