; memmove.asm - Overlapping-safe byte copy
; void *memmove(void *dest, const void *src, size_t count)
;
; Chooses copy direction based on pointer comparison:
;   dest < src  →  forward copy  (low to high)
;   dest > src  →  backward copy (high to low)
;   dest == src →  no-op
; This prevents data corruption when regions overlap.

global memmove

section .text

memmove:
    push ebp
    mov  ebp, esp
    push esi
    push edi

    mov  edi, [ebp + 8]          ; dest
    mov  esi, [ebp + 12]         ; src
    mov  ecx, [ebp + 16]         ; count

    test edi, edi                 ; NULL dest guard
    jz   .done
    test esi, esi                 ; NULL src guard
    jz   .done
    test ecx, ecx                 ; count == 0 guard
    jz   .done

    cmp  edi, esi
    jb   .forward                 ; dest < src → copy forward
    je   .done                    ; dest == src → nothing to do

    ; dest > src → copy backward from end
    lea  edi, [edi + ecx - 1]    ; dest + count - 1
    lea  esi, [esi + ecx - 1]    ; src + count - 1

.backward_loop:
    mov  al, [esi]
    mov  [edi], al
    dec  esi
    dec  edi
    dec  ecx
    jnz  .backward_loop
    jmp  .done

.forward:
    ; dest < src → copy forward
.copy_loop:
    mov  al, [esi]
    mov  [edi], al
    inc  esi
    inc  edi
    dec  ecx
    jnz  .copy_loop

.done:
    mov  eax, [ebp + 8]          ; return original dest
    pop  edi
    pop  esi
    pop  ebp
    ret
