; secure_wipe_heap_rev.asm - Secure backward heap wipe
; void *secure_wipe_heap_rev(void *heap_dest, size_t wipe_count)
;
; Isolated in libmysecure.a (separate from libmymem.a).
; Delegates to memset_rev which lives in libmymem.a.
; Because memset_rev is an external symbol the compiler cannot see,
; Dead-Store Elimination cannot strip the wipe when clearing sensitive
; heap data.
;
; The _rev suffix ensures backward wipe (highest address first), which
; matches stack-unwinding order and prevents DSE by compiler heuristics
; that might optimize forward passes more aggressively.

global secure_wipe_heap_rev
extern memset_rev

section .text

secure_wipe_heap_rev:
    push ebp
    mov  ebp, esp

    ; Build arguments for memset_rev(heap_dest, 0, wipe_count) — right-to-left
    push dword [ebp + 12]        ; wipe_count (3rd arg)
    push 0                       ; c = 0      (2nd arg)
    push dword [ebp + 8]         ; heap_dest  (1st arg)
    call memset_rev
    add  esp, 12                 ; cdecl caller cleanup

    ; Return the destroyed pointer (like free's input contract)
    mov  eax, [ebp + 8]

    pop  ebp
    ret
