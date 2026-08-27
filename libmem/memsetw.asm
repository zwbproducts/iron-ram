; memsetw.asm - Forward fill memory with a 16-bit word value
; void *memsetw(void *dest, unsigned short c, size_t count)
;
; Fills count 16-bit words starting at dest with value c.
; Useful for VGA text buffer initialization.

global memsetw

section .text

memsetw:
    push ebp
    mov  ebp, esp
    push edi

    mov  edi, [ebp + 8]          ; dest
    mov  ax,  [ebp + 12]         ; c (16-bit)
    mov  ecx, [ebp + 16]         ; count

    test edi, edi                 ; NULL guard
    jz   .done
    test ecx, ecx                 ; count == 0 guard
    jz   .done

.word_fill_loop:
    mov  [edi], ax               ; store 16-bit word
    add  edi, 2                  ; advance by word size
    dec  ecx
    jnz  .word_fill_loop

.done:
    mov  eax, [ebp + 8]          ; return original dest
    pop  edi
    pop  ebp
    ret
