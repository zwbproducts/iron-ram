; memrotate_r.asm - Rotate bytes right by shift positions (triple-reverse method)
; void *memrotate_r(void *dest, unsigned int shift, size_t count)
;
; Right rotation by k using 3 in-place reverses:
;   1. reverse [dest, dest+count)      (full)
;   2. reverse [dest, dest+shift)       (first k)
;   3. reverse [dest+shift, dest+count) (rest)
;
; shift is normalized to shift % count.

global memrotate_r

section .text

memrotate_r:
    push ebp
    mov  ebp, esp
    push esi
    push edi
    push ebx

    mov  edi, [ebp + 8]            ; dest
    mov  eax, [ebp + 12]           ; shift
    mov  ecx, [ebp + 16]           ; count

    test edi, edi
    jz   .done
    test ecx, ecx
    jz   .done
    test eax, eax
    jz   .done

    ; shift = shift % count
    xor  edx, edx
    div  ecx                       ; eax = q, edx = r
    test edx, edx
    jz   .done
    mov  ebx, edx                  ; ebx = normalized shift

    ; 1. reverse full [dest, dest+count)
    mov  esi, [ebp + 8]           ; start = dest
    mov  eax, [ebp + 16]           ; count
    lea  edi, [esi + eax]         ; end = dest + count (exclusive)
    dec  edi                        ; make inclusive
.rev1_loop:
    cmp  esi, edi
    jae  .rev1_done
    mov  al, [esi]
    mov  dl, [edi]
    mov  [esi], dl
    mov  [edi], al
    inc  esi
    dec  edi
    jmp  .rev1_loop
.rev1_done:

    ; 2. reverse [dest, dest+shift)
    mov  esi, [ebp + 8]           ; start = dest
    lea  edi, [esi + ebx]         ; end = dest + shift (exclusive)
    dec  edi                        ; make inclusive
.rev2_loop:
    cmp  esi, edi
    jae  .rev2_done
    mov  al, [esi]
    mov  dl, [edi]
    mov  [esi], dl
    mov  [edi], al
    inc  esi
    dec  edi
    jmp  .rev2_loop
.rev2_done:

    ; 3. reverse [dest+shift, dest+count)
    mov  esi, [ebp + 8]           ; dest
    add  esi, ebx                 ; start = dest + shift
    mov  eax, [ebp + 16]
    add  eax, [ebp + 8]           ; end = dest + count
    mov  edi, eax
    dec  edi                        ; make inclusive
.rev3_loop:
    cmp  esi, edi
    jae  .rev3_done
    mov  al, [esi]
    mov  dl, [edi]
    mov  [esi], dl
    mov  [edi], al
    inc  esi
    dec  edi
    jmp  .rev3_loop
.rev3_done:

.done:
    mov  eax, [ebp + 8]           ; return dest
    pop  ebx
    pop  edi
    pop  esi
    pop  ebp
    ret
