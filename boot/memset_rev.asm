; memset_rev.asm — Backward fill memory with a byte value (16-bit real-mode port)
; void *memset_rev(void *dest, int c, size_t count)
;
; Port of libmem/memset_rev.asm to 16-bit real mode.
; Register calling convention: DI=dest  AL=fill byte  CX=count
;
; Starts at dest + count - 1, decrements backward (dec di).
; The count == 0 guard is CRITICAL here: without it, dest+count-1
; would underflow to dest-1.
;
;   32-bit → 16-bit:  EDI → DI   ECX → CX   lea edi,[edi+ecx-1] → add di,cx; dec di

global memset_rev16

memset_rev16:
    push di
    push cx

    test di, di                ; check dest == NULL
    jz   .done

    test cx, cx                ; check count == 0
    jz   .done

    add  di, cx                ; DI = dest + count
    dec  di                    ; DI = dest + count - 1 (start byte)

.bwd_loop:
    mov  [di], al              ; store fill byte
    dec  di                    ; advance dest pointer backward
    dec  cx                    ; decrement count
    jnz  .bwd_loop

.done:
    pop  cx
    pop  di                    ; restore + return original dest in DI
    ret
