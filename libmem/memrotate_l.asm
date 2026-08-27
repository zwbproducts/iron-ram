; memrotate_l.asm - Rotate bytes left by shift positions (triple-reverse method)
; void *memrotate_l(void *dest, unsigned int shift, size_t count)
;
; Left rotation by k using 3 in-place reverses:
;   1. reverse [dest, dest+shift)
;   2. reverse [dest+shift, dest+count)
;   3. reverse [dest, dest+count)
;
; shift is normalized to shift % count.
; Uses an inline macro to avoid call/ret overhead and stack complexity.

%macro REV_RANGE 2
    ; %1 = start register, %2 = end register (exclusive)
    dec %2                           ; make end inclusive
.rev_%{++}:
    cmp %1, %2
    jae .rev_done_%{++}
    mov al, [%1]
    mov dl, [%2]
    mov [%1], dl
    mov [%2], al
    inc %1
    dec %2
    jmp .rev_%{++}
.rev_done_%{++}:
%endmacro

global memrotate_l

section .text

memrotate_l:
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
    jz   .done                     ; no rotation needed
    mov  ebx, edx                  ; ebx = normalized shift

    ; 1. reverse [dest, dest+shift)
    mov  esi, edi                  ; esi = start
    lea  edi, [esi + ebx]          ; edi = end (exclusive)
    dec  edi                       ; make inclusive
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

    ; 2. reverse [dest+shift, dest+count)
    mov  eax, [ebp + 16]          ; count
    lea  esi, [esi + 0]           ; reload: start = dest+shift = (esi is already at middle)
    mov  esi, [ebp + 8]           ; dest
    add  esi, ebx                 ; start = dest + shift
    mov  eax, [ebp + 16]          ; count
    add  eax, [ebp + 8]           ; end = dest + count
    mov  edi, eax
    dec  edi                       ; make inclusive
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

    ; 3. reverse [dest, dest+count)
    mov  esi, [ebp + 8]           ; start = dest
    mov  eax, [ebp + 16]          ; count
    lea  edi, [esi + eax]         ; end = dest + count (exclusive)
    dec  edi                       ; make inclusive
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
