; memchecksum.asm — Compute XOR checksum of memory (16-bit real-mode port)
; unsigned char memchecksum16(const void *s, size_t count)
;
; Port of libmem/memchecksum.asm.
; Register convention: DI=dest  CX=count
; Returns: AL = XOR of all bytes

global memchecksum16

memchecksum16:
    push di
    push cx

    test di, di
    jz   .done
    test cx, cx
    jz   .done

    xor  al, al                  ; checksum = 0

.chk:
    xor  al, [di]
    inc  di
    dec  cx
    jnz  .chk

.done:
    pop  cx
    pop  di
    ret
