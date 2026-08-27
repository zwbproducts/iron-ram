; memmove.asm — Overlapping-safe memory move (16-bit real-mode port)
; void *memmove16(void *dest, const void *src, size_t count)
;
; Port of libmem/memmove.asm.
; Detects overlap direction: if dest < src, copy forward;
; if dest > src, copy backward.
; Register convention: DI=dest  SI=src  CX=count

global memmove16

memmove16:
    push bp
    mov  bp, sp
    push si
    push cx
    push dx

    ; save original dest for return value
    mov  [bp - 2], di

    test di, di
    jz   .done
    test cx, cx
    jz   .done

    cmp  di, si
    ja   .backward              ; dest > src: copy backward

.forward:
    mov  al, [si]
    mov  [di], al
    inc  si
    inc  di
    dec  cx
    jnz  .forward
    jmp  .done

.backward:
    ; dest > src: copy from end to start
    ; dest_end = dest + count - 1, src_end = src + count - 1
    mov  dx, [bp - 2]           ; dx = dest
    add  dx, cx
    dec  dx                     ; dx = dest + count - 1
    mov  bx, si                 ; bx = src
    add  bx, cx
    dec  bx                     ; bx = src + count - 1
    mov  di, dx                 ; di = dest_end
    mov  si, bx                 ; si = src_end
    mov  ax, cx                 ; save count

.bw_loop:
    mov  bl, [si]
    mov  [di], bl
    dec  si
    dec  di
    dec  ax
    jnz  .bw_loop
    ; fall through to .done

.done:
    mov  di, [bp - 2]           ; return original dest
    pop  dx
    pop  cx
    pop  si
    pop  bp
    ret
