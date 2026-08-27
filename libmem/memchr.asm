; memchr.asm - Find first occurrence of a byte in memory
; void *memchr(const void *s, int c, size_t count)
;
; Scans count bytes starting at s for byte value c.
; Returns pointer to first match, or NULL if not found.

global memchr

section .text

memchr:
    push ebp
    mov  ebp, esp
    push esi

    mov  esi, [ebp + 8]          ; s
    mov  al, [ebp + 12]          ; c (lowest byte)
    mov  ecx, [ebp + 16]         ; count

    test esi, esi                 ; NULL guard
    jz   .notfound
    test ecx, ecx                 ; count == 0 → not found
    jz   .notfound

.scan_loop:
    cmp  [esi], al               ; compare current byte with target
    je   .found
    inc  esi
    dec  ecx
    jnz  .scan_loop

.notfound:
    xor  eax, eax                 ; return NULL
    pop  esi
    pop  ebp
    ret

.found:
    mov  eax, esi                 ; return pointer to match
    pop  esi
    pop  ebp
    ret
