; memfill.asm — Fill memory with a repeating 16-bit pattern (16-bit real-mode port)
; void *memfill16(void *dest, unsigned short pattern, size_t count)
;
; Port of libmem/memfill.asm to 16-bit real mode.
; Register convention: DI=dest  AX=pattern  CX=count (bytes)
; Writes pattern as 16-bit words, handles odd trailing byte.

global memfill16

memfill16:
    push di
    push cx
    push dx
    push bx

    test di, di
    jz   .done
    test cx, cx
    jz   .done

    ; save original count for odd-byte check
    mov  dx, cx                  ; DX = original count

    ; CX = count / 2 (word count)
    shr  cx, 1

.pairs:
    mov  [es:di], al            ; low byte of pattern
    mov  [es:di + 1], ah        ; high byte of pattern
    add  di, 2
    dec  cx
    jnz  .pairs

    ; Handle odd trailing byte
    test dx, 1
    jz   .done
    mov  [es:di], al

.done:
    pop  bx
    pop  dx
    pop  cx
    pop  di
    ret
