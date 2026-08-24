; memzero_rev.asm — Backward zero-fill memory (16-bit real-mode port)
; void *memzero_rev(void *dest, size_t count)
;
; Port of libmem/memzero_rev.asm.  Delegates to memset_rev with c=0.
;
; Register convention: DI=dest  CX=count   (AL set to 0 internally)

global memzero_rev16
extern memset_rev16

memzero_rev16:
    push ax
    xor  al, al                ; c = 0
    call memset_rev16          ; memset_rev(dest, 0, count)
    pop  ax
    ret
