; memsetw.asm — Forward fill memory with a byte value (16-bit real-mode port)
; void *memsetw(void *dest, int c, size_t count)
;
; Port of libmem/memset.asm to 16-bit real mode.
; Register calling convention: DI=dest  AL=fill byte  CX=count
;
; Preserves: DI, CX (push/pop)   Returns original DI in DI.
; Guards:    NULL dest check    count == 0 check
;
; Key 32-bit → 16-bit mapping:
;   EDI → DI   AL → AL   ECX → CX   inc edi → inc di   dec ecx → dec cx

global memsetw

memsetw:
    push di                    ; callee-saved
    push cx                    ; preserve count

    test di, di                ; check dest == NULL
    jz   .done

    test cx, cx                ; check count == 0
    jz   .done

.fill_loop:
    mov  [di], al              ; store fill byte
    inc  di                    ; advance dest pointer forward
    dec  cx                    ; decrement count
    jnz  .fill_loop

.done:
    pop  cx
    pop  di                    ; restore + return original dest in DI
    ret
