; memmove_rev.asm — Backward memmove variant (16-bit real-mode port)
; void *memmove_rev16(void *dest, const void *src, size_t count)
;
; Port of libmem/memmove_rev.asm. Always copies from end to start.
; Register convention: DI=dest  SI=src  CX=count
; Returns: DI = original dest

global memmove_rev16

memmove_rev16:
    push si
    push cx
    push ax
    push dx

    test di, di
    jz   .done
    test si, si
    jz   .done
    test cx, cx
    jz   .done

    push di                       ; save original dest for return

    ; Point both pointers at the LAST byte
    add  di, cx                  ; di = dest + count
    dec  di                    ; di = dest + count - 1
    add  si, cx
    dec  si                    ; si = src + count - 1

.bwd:
    mov  al, [si]               ; load from src end
    mov  [di], al              ; store to dest end
    dec  si
    dec  di
    dec  cx
    jnz  .bwd

    pop  di                       ; restore original dest return value
    ; fall through

.done:
    pop  dx
    pop  ax
    pop  cx
    pop  si
    ret
