; boot.asm — BIOS bootloader: exercises 16-bit memory routines on the BIOS console
;
; In 16-bit real mode the 32-bit libmem objects cannot be linked, so this
; sector ships 16-bit ports of the same five algorithms:
;
;   memsetw, memzero16, memsetw_rev, memzero_rev16, secure_wipe16
;
; Each test fills a 16-byte scratch buffer, invokes the routine, verifies
; the result, and prints  [PASS]  (green) or  [FAIL]  (red)  via
; BIOS INT 0x10 teletype.
;
; Register calling convention for the memory routines:
;   DI = dest    AL = fill byte    CX = count
;
; Build:  nasm -f bin boot.asm -o boot.bin
; Run:    qemu-system-x86_64 -drive format=raw,file=boot.bin
;
; ──────────────────────────────────────────────────────────────────────────
;  16-bit REAL MODE
;  BIOS loads this sector at physical 0x7C00 (CS:IP = 0x0000:0x7C00).
; ──────────────────────────────────────────────────────────────────────────

BITS 16
ORG 0x7C00

%define COL_CYAN    0x0B
%define COL_YELLOW  0x0E
%define COL_GREEN   0x0A
%define COL_RED     0x0C

%define BS          16          ; scratch-buffer size (bytes)

; ── scratch buffer (resides inside the 512-byte boot sector image) ──
buf:    times BS db 0

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    ; ── header ──
    mov  si, header
    mov  bl, COL_CYAN
    call puts

    ; ═══════════════════════════════════════════════════
    ;  T1 — memsetw  (forward fill)
    ; ═══════════════════════════════════════════════════
    mov  si, name_memset
    mov  bl, COL_YELLOW
    call puts
    mov  di, buf
    xor  al, al
    mov  cx, BS
    call memsetw            ; clear buffer (CX preserved)
    mov  al, 0xAB
    call memsetw            ; fill 0xAB (no need to reload CX)
    mov  si, buf
    mov  al, 0xAB
    call vbuf               ; verify all 0xAB
    call result

    ; ═══════════════════════════════════════════════════
    ;  T2 — memzero16  (delegates to memsetw)
    ; ═══════════════════════════════════════════════════
    mov  si, name_memzero
    mov  bl, COL_YELLOW
    call puts
    mov  di, buf
    mov  al, 0xFF
    mov  cx, BS
    call memsetw            ; pre-fill 0xFF (CX preserved)
    mov  di, buf
    call memzero16          ; zero (no need to reload CX)
    mov  si, buf
    xor  al, al
    call vbuf
    call result

    ; ═══════════════════════════════════════════════════
    ;  T3 — memsetw_rev  (backward fill)
    ; ═══════════════════════════════════════════════════
    mov  si, name_msrev
    mov  bl, COL_YELLOW
    call puts
    mov  di, buf
    xor  al, al
    mov  cx, BS
    call memsetw            ; clear (CX preserved)
    mov  al, 0xCD
    call memsetw_rev        ; fill backward 0xCD
    mov  si, buf
    mov  al, 0xCD
    call vbuf
    call result

    ; ═══════════════════════════════════════════════════
    ;  T4 — memzero_rev16  (delegates to memsetw_rev)
    ; ═══════════════════════════════════════════════════
    mov  si, name_mzrev
    mov  bl, COL_YELLOW
    call puts
    mov  di, buf
    mov  al, 0xEE
    mov  cx, BS
    call memsetw            ; pre-fill 0xEE (CX preserved)
    mov  di, buf
    call memzero_rev16      ; zero backward
    mov  si, buf
    xor  al, al
    call vbuf
    call result

    ; ═══════════════════════════════════════════════════
    ;  T5 — secure_wipe16  (black-box, delegates to memsetw_rev)
    ; ═══════════════════════════════════════════════════
    mov  si, name_secure
    mov  bl, COL_YELLOW
    call puts
    mov  di, buf
    mov  al, 0x77
    mov  cx, BS
    call memsetw            ; pre-fill sensitive data
    mov  di, buf
    call secure_wipe16      ; secure zero
    mov  si, buf
    xor  al, al
    call vbuf
    call result

    ; ── done ──
    mov  si, done_msg
    mov  bl, COL_YELLOW
    call puts
.hlt_loop:
    hlt
    jmp .hlt_loop

; ═══════════════════════════════════════════════════
;  16-BIT MEMORY ROUTINES  (real-mode ports of libmem)
;  DI=dest  AL=fill  CX=count
; ═══════════════════════════════════════════════════

; ── memsetw ── forward byte fill (NULL + count==0 guards) ──
memsetw:
    push di
    push cx
    test di, di
    jz   .done
    test cx, cx
    jz   .done
.loop:
    mov  [di], al
    inc  di
    dec  cx
    jnz  .loop
.done:
    pop  cx
    pop  di
    ret

; ── memzero16 ── forward zero, delegates to memsetw ──
memzero16:
    push ax
    xor  al, al
    call memsetw
    pop  ax
    ret

; ── memsetw_rev ── backward byte fill ──
;     Computes DI = dest + count - 1, then decrements backward.
;     The count==0 guard prevents dest-1 underflow.
memsetw_rev:
    push di
    push cx
    test di, di
    jz   .done
    test cx, cx
    jz   .done
    add  di, cx
    dec  di
.loop:
    mov  [di], al
    dec  di
    dec  cx
    jnz  .loop
.done:
    pop  cx
    pop  di
    ret

; ── memzero_rev16 ── backward zero, delegates to memsetw_rev ──
memzero_rev16:
    push ax
    xor  al, al
    call memsetw_rev
    pop  ax
    ret

; ── secure_wipe16 ── secure backward wipe (black-box) ──
;     In libmem this lives in libmysecure.a and calls memset_rev
;     via an extern so the compiler treats it as an opaque black box.
;     Here it simply delegates to memsetw_rev with c=0.
secure_wipe16:
    push ax
    xor  al, al
    call memsetw_rev
    pop  ax
    ret

; ═══════════════════════════════════════════════════
;  BIOS CONSOLE I/O  (INT 0x10 teletype, AH=0x0E)
; ═══════════════════════════════════════════════════

; ── puts ── print NUL-terminated string  (SI=pointer, BL=colour) ──
puts:
    push ax
    push bx
    push si
.put:
    lodsb
    test al, al
    jz   .out
    mov  ah, 0x0E
    mov  bh, 0
    int  0x10
    jmp  .put
.out:
    pop  si
    pop  bx
    pop  ax
    ret

; ── result ── print [PASS]/[FAIL] based on carry flag ──
;     Carry clear → green PASS    Carry set → red FAIL
;     Does not preserve registers (caller doesn't rely on them).
result:
    jc   .fail
    mov  si, pass_str
    mov  bl, COL_GREEN
    call puts
    jmp  .done
.fail:
    mov  si, fail_str
    mov  bl, COL_RED
    call puts
.done:
    ret

; ── vbuf ── verify CX bytes at [SI] all equal AL ──
;     Carry clear = all match   Carry set = mismatch
vbuf:
    push cx
    push si
.loop:
    cmp  al, [si]
    jne  .fail
    inc  si
    loop .loop
    pop  si
    pop  cx
    clc
    ret
.fail:
    pop  si
    pop  cx
    stc
    ret

; ═══════════════════════════════════════════════════
;  DATA
; ═══════════════════════════════════════════════════

header:         db "  === BIOS BOOT TEST ===", 13, 10, 0
name_memset:    db "  memset", 13, 10, 0
name_memzero:   db "  memzero", 13, 10, 0
name_msrev:     db "  memset_rev", 13, 10, 0
name_mzrev:     db "  memzero_rev", 13, 10, 0
name_secure:    db "  secure_wipe", 13, 10, 0
pass_str:       db "  [PASS]", 13, 10, 0
fail_str:       db "  [FAIL]", 13, 10, 0
done_msg:       db 13, 10, "  boot halted.", 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
