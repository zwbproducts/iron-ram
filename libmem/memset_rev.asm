; memset_rev.asm - Backward fill memory with a byte value
; void *memset_rev(void *dest, int c, size_t count)
;
; Starts at dest + count - 1 and decrements backward using dec edi.

global memset_rev

section .text

memset_rev:
    push ebp
    mov  ebp, esp
    push edi                     ; callee-saved

    mov  edi, [ebp + 8]          ; dest
    mov  al,  [ebp + 12]         ; c  (lowest byte)
    mov  ecx, [ebp + 16]         ; count

    test edi, edi                 ; check dest == NULL
    jz   .done

    test ecx, ecx                 ; check count == 0
    jz   .done

    lea  edi, [edi + ecx - 1]    ; EDI = dest + count - 1

.bwd_loop:
    mov  [edi], al               ; store fill byte
    dec  edi                     ; advance dest pointer backward
    dec  ecx                     ; decrement count
    jnz  .bwd_loop

.done:
    mov  eax, [ebp + 8]          ; return original dest
    pop  edi
    pop  ebp
    ret
