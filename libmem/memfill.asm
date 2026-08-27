; memfill.asm - Fill memory with a repeating 16-bit pattern
; void *memfill(void *dest, unsigned short pattern, size_t count)
;
; Fills count bytes with the 16-bit pattern repeated.
; In little-endian, the low byte is written first.
; Example: memfill(d, 0xBEEF, 5) -> d = {EF BE EF BE EF}

global memfill

section .text

memfill:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  edi, [ebp + 8]          ; dest
    mov  ax,  [ebp + 12]         ; pattern (16-bit)
    mov  ecx, [ebp + 16]         ; count (bytes)

    test edi, edi
    jz   .done
    test ecx, ecx
    jz   .done

    ; Process pairs of bytes
    shr  ecx, 1                  ; ecx = count / 2 (number of pairs)

.pairs_loop:
    mov  [edi], al               ; low byte of pattern
    mov  [edi + 1], ah            ; high byte
    add  edi, 2
    dec  ecx
    jnz  .pairs_loop

    ; Handle odd trailing byte
    test dword [ebp + 16], 1     ; was original count odd?
    jz   .done
    mov  [edi], al               ; write low byte only

.done:
    mov  eax, [ebp + 8]
    pop  edi
    pop  esi
    pop  ebp
    ret
