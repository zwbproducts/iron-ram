; memreverse.asm - Reverse bytes in a memory region in-place
; void *memreverse(void *dest, size_t count)
;
; Reverses the byte order within the region [dest, dest+count).
; Uses two pointers converging from both ends.

global memreverse

section .text

memreverse:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  edi, [ebp + 8]          ; dest (start)
    mov  ecx, [ebp + 12]         ; count

    test edi, edi
    jz   .done
    test ecx, ecx
    jz   .done

    lea  esi, [edi + ecx - 1]    ; end = dest + count - 1

.rev_loop:
    cmp  edi, esi
    jae  .done
    mov  al, [edi]
    mov  dl, [esi]
    mov  [edi], dl
    mov  [esi], al
    inc  edi
    dec  esi
    jmp  .rev_loop

.done:
    mov  eax, [ebp + 8]
    pop  edi
    pop  esi
    pop  ebp
    ret
