; memcpy.asm - Forward byte-copy from src to dest
; void *memcpy(void *dest, const void *src, size_t count)
;
; Standard cdecl frame. Copies count bytes forward.
; Does NOT handle overlapping regions (caller's responsibility).

global memcpy

section .text

memcpy:
    push ebp
    mov  ebp, esp
    push esi                     ; callee-saved
    push edi

    mov  edi, [ebp + 8]          ; dest
    mov  esi, [ebp + 12]         ; src
    mov  ecx, [ebp + 16]         ; count

    test edi, edi                 ; NULL dest guard
    jz   .done
    test esi, esi                 ; NULL src guard
    jz   .done
    test ecx, ecx                 ; count == 0 guard
    jz   .done

.copy_loop:
    mov  al, [esi]               ; read byte from src
    mov  [edi], al               ; write byte to dest
    inc  esi                     ; advance src
    inc  edi                     ; advance dest
    dec  ecx
    jnz  .copy_loop

.done:
    mov  eax, [ebp + 8]          ; return original dest
    pop  edi
    pop  esi
    pop  ebp
    ret
