; memeq.asm - Check if two memory regions are identical
; int memeq(const void *s1, const void *s2, size_t count)
;
; Returns 1 if all count bytes in s1 and s2 are equal, 0 otherwise.
; (Unlike memcmp which returns a signed difference, this returns
;  a simple boolean.)

global memeq

section .text

memeq:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  esi, [ebp + 8]          ; s1
    mov  edi, [ebp + 12]         ; s2
    mov  ecx, [ebp + 16]         ; count

    test ecx, ecx
    jz   .equal

    xor  eax, eax                 ; assume equal (1 = true)

.cmp_loop:
    mov  dl, [esi]
    cmp  dl, [edi]
    jne  .not_equal
    inc  esi
    inc  edi
    dec  ecx
    jnz  .cmp_loop

.equal:
    mov  eax, 1
    pop  edi
    pop  esi
    pop  ebp
    ret

.not_equal:
    xor  eax, eax
    pop  edi
    pop  esi
    pop  ebp
    ret
