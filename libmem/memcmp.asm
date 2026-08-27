; memcmp.asm - Compare two memory regions
; int memcmp(const void *s1, const void *s2, size_t count)
;
; Compares count bytes. Returns:
;   0   if regions are identical
;   <0  if first differing byte in s1 < s2
;   >0  if first differing byte in s1 > s2
; Result mirrors standard memcmp: (unsigned char)s1[i] - (unsigned char)s2[i].

global memcmp

section .text

memcmp:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  esi, [ebp + 8]          ; s1
    mov  edi, [ebp + 12]         ; s2
    mov  ecx, [ebp + 16]         ; count

    test ecx, ecx                 ; count == 0 → equal
    jz   .equal

    xor  eax, eax                 ; zero accumulator for subtraction

.cmp_loop:
    mov  al, [esi]               ; load byte from s1
    mov  dl, [edi]               ; load byte from s2
    test al, al                   ; (no semantic meaning, just advance)
    sub  al, dl                   ; s1_byte - s2_byte
    jnz  .done                    ; first difference found
    inc  esi
    inc  edi
    dec  ecx
    jnz  .cmp_loop

.equal:
    xor  eax, eax                 ; return 0
    jmp  .done_ret

.done:
    ; sign-extend al into eax for <0 / >0 result
    movsx eax, al

.done_ret:
    pop  edi
    pop  esi
    pop  ebp
    ret
