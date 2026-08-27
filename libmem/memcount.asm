; memcount.asm - Count occurrences of a byte value in memory
; int memcount(const void *s, int c, size_t count)
;
; Returns the number of bytes equal to c within the count bytes starting at s.

global memcount

section .text

memcount:
    push ebp
    mov  ebp, esp
    push esi

    mov  esi, [ebp + 8]          ; s
    mov  al, [ebp + 12]          ; c
    mov  ecx, [ebp + 16]         ; count

    test esi, esi
    jz   .done
    test ecx, ecx
    jz   .done

    xor  edx, edx                 ; count = 0

.count_loop:
    cmp  [esi], al
    jne  .skip
    inc  edx

.skip:
    inc  esi
    dec  ecx
    jnz  .count_loop

.done:
    mov  eax, edx
    pop  esi
    pop  ebp
    ret
