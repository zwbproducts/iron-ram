; memswap.asm — Swap two equal-length memory regions (16-bit real-mode port)
; void memswap16(void *a, void *b, size_t count)
;
; Port of libmem/memswap.asm to 16-bit real mode.
; Register convention: DI=a  SI=b  CX=count

global memswap16

memswap16:
    push di
    push si
    push cx
    push ax

    test di, di
    jz   .done
    test si, si
    jz   .done
    test cx, cx
    jz   .done

.swap:
    mov  al, [di]
    mov  ah, [si]
    mov  [di], ah
    mov  [si], al
    inc  di
    inc  si
    dec  cx
    jnz  .swap

.done:
    pop  ax
    pop  cx
    pop  si
    pop  di
    ret
