; memswap.asm - Swap two equal-length memory regions in-place
; void memswap(void *a, void *b, size_t count)
;
; Swaps count bytes between region a and region b.
; Uses byte-by-byte swap via temp register to handle potential overlap.

global memswap

section .text

memswap:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  esi, [ebp + 8]          ; a (source 1)
    mov  edi, [ebp + 12]         ; b (source 2)
    mov  ecx, [ebp + 16]         ; count

    test esi, esi
    jz   .done
    test edi, edi
    jz   .done
    test ecx, ecx
    jz   .done

.swap_loop:
    mov  al, [esi]               ; load from a
    mov  dl, [edi]               ; load from b
    mov  [esi], dl               ; a gets b's byte
    mov  [edi], al               ; b gets a's byte
    inc  esi
    inc  edi
    dec  ecx
    jnz  .swap_loop

.done:
    xor  eax, eax
    pop  edi
    pop  esi
    pop  ebp
    ret
