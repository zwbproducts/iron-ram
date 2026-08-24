; secure_wipe_stack_rev.asm - Secure backward stack wipe
; void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count)
;
; Isolated in its own file and compiled into libmysecure.a (separate
; from libmymem.a).  Delegates to memset_rev which lives in libmymem.a.
; Because the memset_rev symbol is external (treated as a black box by
; the C compiler), Dead-Store Elimination cannot strip the wipe when
; clearing sensitive stack frames.

global secure_wipe_stack_rev
extern memset_rev

section .text

secure_wipe_stack_rev:
    push ebp
    mov  ebp, esp

    ; Build arguments for memset_rev(stack_dest, 0, wipe_count) — right-to-left
    push dword [ebp + 12]        ; wipe_count (3rd arg)
    push 0                       ; c = 0      (2nd arg)
    push dword [ebp + 8]         ; stack_dest (1st arg)
    call memset_rev
    add  esp, 12                 ; cdecl caller cleanup

    pop  ebp
    ret
