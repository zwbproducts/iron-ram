; memrotate_r.asm — Rotate bytes right by shift (16-bit real-mode port)
; void *memrotate_r16(void *dest, unsigned int shift, size_t count)
;
; Port of libmem/memrotate_r.asm. Triple-reverse:
;   1. reverse [dest, dest+count)      (full)
;   2. reverse [dest, dest+shift)       (first shift)
;   3. reverse [dest+shift, dest+count) (rest)
;
; Register convention: DI=dest  DX=shift  CX=count

global memrotate_r16

memrotate_r16:
    push bp
    mov  bp, sp
    push si
    push cx
    push dx
    push ax
    push bx

    mov  [bp - 2], di              ; save dest
    mov  [bp - 4], cx              ; save count

    test di, di
    jz   .done
    test cx, cx
    jz   .done
    test dx, dx
    jz   .done

    ; shift = shift % count
    xor  ax, ax
    xchg ax, dx
    div  cx
    test dx, dx
    jz   .done
    mov  bx, dx                    ; bx = normalized shift

    ; 1. reverse full [dest, dest+count)
    mov  si, [bp - 2]
    mov  ax, [bp - 4]
    call memrotate_r_rev

    ; 2. reverse [dest, dest+shift)
    mov  si, [bp - 2]
    mov  ax, bx
    call memrotate_r_rev

    ; 3. reverse [dest+shift, dest+count)
    mov  si, [bp - 2]
    add  si, bx
    mov  ax, [bp - 4]
    sub  ax, bx
    call memrotate_r_rev

.done:
    pop  bx
    pop  ax
    pop  dx
    pop  cx
    pop  si
    pop  bp
    ret

; in-place reverse: SI=start, AX=count
memrotate_r_rev:
    push ax
    push si
    push di
    push bx
    test ax, ax
    jz   .rr_done
    mov  di, si
    add  di, ax
    dec  di
.rr_loop:
    cmp  si, di
    jae  .rr_done
    mov  bl, [si]
    mov  bh, [di]
    mov  [si], bh
    mov  [di], bl
    inc  si
    dec  di
    jmp  .rr_loop
.rr_done:
    pop  bx
    pop  di
    pop  si
    pop  ax
    ret
