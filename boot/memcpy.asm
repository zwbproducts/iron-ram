; memcpy.asm — Forward memory copy (16-bit real-mode port)
; void *memcpy16(void *dest, const void *src, size_t count)
;
; Port of libmem/memcpy.asm.
; Register convention: DI=dest  SI=src  CX=count

global memcpy16

memcpy16:
    push di
    push cx
    push bx

    test di, di
    jz   .done
    test cx, cx
    jz   .done

    mov  bx, di

.copy:
    mov  al, [si]
    mov  [di], al
    inc  si
    inc  di
    dec  cx
    jnz  .copy

    mov  di, bx

.done:
    pop  bx
    pop  cx
    pop  di
    ret
