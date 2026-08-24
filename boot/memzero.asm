; memzero.asm — Forward zero-fill memory (16-bit real-mode port)
; void *memzero16(void *dest, size_t count)
;
; Port of libmem/memzero.asm.  Thin wrapper that delegates to memsetw
; by setting the fill byte to 0.
;
; Register convention: DI=dest  CX=count   (AL set to 0 internally)
; Preserves: AX, DI, CX

global memzero16
extern memsetw

memzero16:
    push ax
    xor  al, al                ; c = 0
    call memsetw               ; memset(dest, 0, count)
    pop  ax
    ret
