; memchecksum.asm - Compute XOR checksum of a memory region
; unsigned char memchecksum(const void *s, size_t count)
;
; Returns the XOR of all bytes in the region. A simple integrity check.

global memchecksum

section .text

memchecksum:
    push ebp
    mov  ebp, esp
    push esi

    mov  esi, [ebp + 8]          ; s
    mov  ecx, [ebp + 12]         ; count

    test esi, esi
    jz   .done
    test ecx, ecx
    jz   .done

    xor  al, al                   ; checksum = 0

.checksum_loop:
    xor  al, [esi]
    inc  esi
    dec  ecx
    jnz  .checksum_loop

.done:
    pop  esi
    pop  ebp
    ret
