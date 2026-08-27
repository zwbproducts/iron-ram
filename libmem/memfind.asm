; memfind.asm - Find a byte in memory, return offset
; int memfind(const void *s, int c, size_t count)
;
; Scans count bytes starting at s for byte value c.
; Returns the byte offset of the first match, or -1 if not found.
; (Unlike memchr which returns a pointer, this returns an index.)

global memfind

section .text

memfind:
    push ebp
    mov  ebp, esp
    push esi

    mov  esi, [ebp + 8]          ; s
    mov  al, [ebp + 12]          ; c
    mov  ecx, [ebp + 16]         ; count

    test esi, esi
    jz   .notfound
    test ecx, ecx
    jz   .notfound

    xor  edx, edx                 ; offset = 0

.scan_loop:
    cmp  [esi], al
    je   .found
    inc  esi
    inc  edx
    dec  ecx
    jnz  .scan_loop

.notfound:
    mov  eax, -1
    pop  esi
    pop  ebp
    ret

.found:
    mov  eax, edx
    pop  esi
    pop  ebp
    ret
