; memzero_rev.asm - Backward zero-fill memory
; void *memzero_rev(void *dest, size_t count)
;
; Delegates directly to memset_rev by pushing 0 as the character byte.

global memzero_rev
extern memset_rev

section .text

memzero_rev:
    push ebp
    mov  ebp, esp

    ; Build arguments for memset_rev(dest, 0, count) — right-to-left
    push dword [ebp + 12]        ; count   (3rd arg)
    push 0                       ; c = 0   (2nd arg)
    push dword [ebp + 8]         ; dest    (1st arg)
    call memset_rev
    add  esp, 12                 ; cdecl caller cleanup

    pop  ebp
    ret
