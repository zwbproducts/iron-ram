; memset.asm - Forward fill memory with a byte value
; void *memset(void *dest, int c, size_t count)
;
; Standard cdecl stack frame. Checks dest != NULL before execution.
; Byte-by-byte forward fill using inc edi and dec ecx.

global memset

section .text

memset:
    push ebp
    mov  ebp, esp
    push edi                    ; callee-saved

    mov  edi, [ebp + 8]         ; dest
    mov  al,  [ebp + 12]        ; c  (lowest byte of int)
    mov  ecx, [ebp + 16]        ; count

    test edi, edi                ; check dest == NULL
    jz   .done

    test ecx, ecx                ; check count == 0
    jz   .done

.fill_loop:
    mov  [edi], al               ; store fill byte
    inc  edi                     ; advance dest pointer forward
    dec  ecx                     ; decrement count
    jnz  .fill_loop

.done:
    mov  eax, [ebp + 8]          ; return original dest
    pop  edi
    pop  ebp
    ret
