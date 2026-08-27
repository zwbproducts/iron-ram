; memreverse.asm — Reverse bytes in a region in-place (16-bit real-mode port)
; void *memreverse16(void *dest, size_t count)
;
; Port of libmem/memreverse.asm.
; Register convention: DI=dest  CX=count
; Two pointers converge from both ends.

global memreverse16

memreverse16:
    push di
    push cx
    push dx
    push si

    test di, di
    jz   .done
    test cx, cx
    jz   .done

    mov  si, di                  ; si = start
    add  di, cx                  ; di = start + count
    dec  di                      ; di = end (last byte)

.rev:
    cmp  si, di
    jae  .done
    mov  al, [si]
    mov  dl, [di]
    mov  [si], dl
    mov  [di], al
    inc  si
    dec  di
    jmp  .rev

.done:
    pop  si
    pop  dx
    pop  cx
    pop  di
    ret
