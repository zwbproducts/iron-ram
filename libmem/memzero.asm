; memzero.asm - Forward zero-fill memory
; void *memzero(void *dest, size_t count)
;
; Delegates directly to memset by pushing 0 as the character byte.

global memzero
extern memset

section .text

memzero:
    push ebp
    mov  ebp, esp

    ; Build arguments for memset(dest, 0, count)  — right-to-left
    push dword [ebp + 12]        ; count   (3rd arg)
    push 0                       ; c = 0   (2nd arg)
    push dword [ebp + 8]         ; dest    (1st arg)
    call memset
    add  esp, 12                 ; cdecl caller cleanup

    pop  ebp
    ret
