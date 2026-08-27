; memmove_rev.asm - Backward overlapping-safe byte copy
; void *memmove_rev(void *dest, const void *src, size_t count)
;
; Always copies backward (from end to start), regardless of
; pointer comparison. Like memmove, handles overlapping regions,
; but uses backward iteration which is safe when dest > src.
; When dest < src and overlapping, the caller should prefer memmove.

global memmove_rev

section .text

memmove_rev:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  edi, [ebp + 8]          ; dest
    mov  esi, [ebp + 12]         ; src
    mov  ecx, [ebp + 16]         ; count

    test edi, edi
    jz   .done
    test esi, esi
    jz   .done
    test ecx, ecx
    jz   .done

    ; Start from the end of both regions
    lea  edi, [edi + ecx - 1]    ; dest + count - 1
    lea  esi, [esi + ecx - 1]    ; src + count - 1

.backward_loop:
    mov  al, [esi]
    mov  [edi], al
    dec  esi
    dec  edi
    dec  ecx
    jnz  .backward_loop

.done:
    mov  eax, [ebp + 8]          ; return original dest
    pop  edi
    pop  esi
    pop  ebp
    ret