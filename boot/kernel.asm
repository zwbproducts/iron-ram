; kernel.asm — custom 16-bit real-mode kernel
;
; Handed off by boot.asm: the bootloader reads this image (loaded at the
; start of sector 2) into physical 0x8000 and `jmp 0x0000:0x8000`.
;
; This kernel does NOT use ANY BIOS services for its console — the only I/O
; routines here are the 16-bit real-mode ports of the libmem memory functions
; we wrote ourselves (memset.asm, memzero.asm, memset_rev.asm, memzero_rev.asm,
; secure_wipe.asm).  The kernel console is the VGA text frame buffer at
; 0xB8000, and its screen-clear is performed by calling memzero16() on the
; 4000-byte video memory.  Each character is then written with a direct
; store.  To let the host observe the kernel console under `qemu -nographic`,
; each character is also teed to the serial port (0x3F8) by a raw `out` —
; that is itself hand-written 16-bit I/O, not a BIOS call.
;
; Memory-function calling convention (kept identical to boot.asm):
;     DI = dest    AL = fill byte    CX = count    (operates on ES:[DI])
;     memzero16 / memzero_rev16 / secure_wipe16 take only DI + CX (AL=0).
;
; Build: see ../Makefile  (nasm -f bin kernel.asm -o kernel.bin)

BITS 16
ORG 0x8000

; -- constants --
%define VIDEO_SEG   0xB800
%define COLS        80
%define ROWS        25
%define VCHARS      (COLS * ROWS)          ; 2000 cells
%define VBYTES      (VCHARS * 2)           ; 4000 bytes (char + attr each)
%define ROW_BYTES   (COLS * 2)             ; 160 bytes per text row
%define ATTR        0x0F                   ; light gray on black
%define SERIAL      0x3F8                  ; COM1 (host debug mirror)
%define KBUF_LEN    64                     ; scratch buffer for demos

; ═══════════════════════════════════════════════════════
;  ENTRY POINT
; ═══════════════════════════════════════════════════════
start:
    cli
    xor  ax, ax
    mov  ds, ax              ; our data lives in segment 0 (loaded at 0x8000)
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    ; kernel console init: clear the VGA text screen with OUR memzero
    call kclear

    mov  si, k_header
    call kputs

    ; exercise every custom memory function, report on the kernel console
    call demo_memsetw
    call demo_memzero
    call demo_memset_rev
    call demo_memzero_rev
    call demo_secure_wipe

    ; edge cases: NULL-dest safety + count==0 no-op (mirrors the bootloader
    ; edge tests, demonstrated here on the kernel console instead)
    call demo_edge_null
    call demo_edge_zero

    mov  si, k_summary
    call kputs

.halt:
    hlt
    jmp  .halt

; ═══════════════════════════════════════════════════════
;  KERNEL CONSOLE  (VGA text buffer @ 0xB8000)
;  screen clearing uses our custom memory functions;
;  every emitted char is also teed to the serial port (raw `out`).
; ═══════════════════════════════════════════════════════

cursor: dw 0                 ; byte offset into video memory

; ── kclear ── blank the whole screen using memzero16 (our custom fn) ──
kclear:
    push ax
    push cx
    push es
    push di
    mov  ax, VIDEO_SEG
    mov  es, ax              ; video segment
    xor  di, di              ; start of video memory
    mov  cx, VBYTES          ; 4000 bytes
    call memzero16           ; <── our custom routine zeros the screen
    mov  word [cursor], 0
    pop  di
    pop  es
    pop  cx
    pop  ax
    ret

; ── kputc ── emit AL to the cursor cell (ES must = 0xB800), tee to serial ──
;     advances cursor; '\n' = next row, '\r' = column 0.
kputc:
    push ax
    push dx
    push cx
    push bx
    mov  bx, [cursor]

    cmp  al, 0x0A            ; '\n' -> advance one row, keep column
    je  .lf
    cmp  al, 0x0D            ; '\r' -> column 0 of current row
    je  .cr

    ; printable: write char + attribute cell, advance by 2
    mov  [es:bx], al
    mov  byte [es:bx+1], ATTR
    add  bx, 2
    mov  [cursor], bx
    jmp  .serial             ; AL still holds the char

.cr:
    ; cursor = (cursor / ROW_BYTES) * ROW_BYTES  -> start of current row
    mov  ax, bx
    xor  dx, dx
    mov  cx, ROW_BYTES
    div  cx
    mul  cx                  ; ax = row * ROW_BYTES
    mov  bx, ax
    mov  [cursor], bx
    mov  al, 0x0D            ; emit CR to serial (restored char)
    jmp  .serial

.lf:
    ; cursor = next row start, wrap to top if off the bottom
    mov  ax, bx
    xor  dx, dx
    mov  cx, ROW_BYTES
    div  cx                  ; ax = row number
    inc  ax                  ; next row
    xor  dx, dx
    mov  cx, ROW_BYTES
    mul  cx                  ; ax = next row start
    cmp  ax, VBYTES
    jb  .set
    xor  ax, ax              ; wrap to top of screen
.set:
    mov  bx, ax
    mov  [cursor], bx
    mov  al, 0x0A            ; emit LF to serial (restored char)

.serial:
    ; tee this character to the serial port (raw out, NOT bios)
    mov  dx, SERIAL
    out  dx, al
.out:
    pop  bx
    pop  cx
    pop  dx
    pop  ax
    ret

; ── kputs ── print NUL-terminated string at DS:[SI] ──
kputs:
    push ax
    push bx
    push si
    push es
    mov  ax, VIDEO_SEG
    mov  es, ax              ; console writes to video segment
.next:
    lodsb                    ; AL = [si], si++  (DS-based)
    test al, al
    jz  .out
    call kputc
    jmp  .next
.out:
    pop  es
    pop  si
    pop  bx
    pop  ax
    ret

; ═══════════════════════════════════════════════════════
;  MEMORY-FUNCTION DEMOS
;  Each demo runs a function on the scratch buffer `kbuf`, verifies the
;  result, then prints "  <name>: [OK]" / "[FAIL]" on the kernel console.
;  Scratch operations use ES=0 (kbuf lives in our segment 0).
; ═══════════════════════════════════════════════════════

kbuf: times KBUF_LEN db 0

; buf_chk: DS:[SI], CX=count, AL=expected -> CF set if any mismatch
buf_chk:
    push ax
    push cx
    push si
.ck:
    cmp  al, [si]
    jne  .bad
    inc  si
    loop .ck
    pop  si
    pop  cx
    pop  ax
    clc
    ret
.bad:
    pop  si
    pop  cx
    pop  ax
    stc
    ret

demo_memsetw:
    mov  ax, 0
    mov  es, ax             ; kbuf is in segment 0
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw            ; prefill kbuf with 0
    mov  al, 0xAB
    call memsetw            ; memsetw(kbuf, 0xAB, KBUF_LEN)
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xAB
    call buf_chk
    pushf                   ; save CF from buf_chk across the prints below
    mov  si, nm_memsetw
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

demo_memzero:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xFF
    call memsetw            ; prefill kbuf with 0xFF
    mov  di, kbuf
    mov  cx, KBUF_LEN
    call memzero16          ; memzero16(kbuf, KBUF_LEN) -> zeros
    mov  si, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call buf_chk
    pushf
    mov  si, nm_memzero
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

demo_memset_rev:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw            ; prefill kbuf with 0
    mov  al, 0xCD
    call memset_rev16       ; memset_rev16(kbuf, 0xCD, KBUF_LEN)
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xCD
    call buf_chk
    pushf
    mov  si, nm_msrev
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

demo_memzero_rev:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xEE
    call memsetw            ; prefill kbuf with 0xEE
    mov  di, kbuf
    mov  cx, KBUF_LEN
    call memzero_rev16      ; memzero_rev16(kbuf, KBUF_LEN) -> zeros
    mov  si, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call buf_chk
    pushf
    mov  si, nm_mzrev
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

demo_secure_wipe:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x77
    call memsetw            ; prefill kbuf with 0x77
    mov  di, kbuf
    mov  cx, KBUF_LEN
    call secure_wipe16      ; secure_wipe16(kbuf, KBUF_LEN) -> zeros (black-box)
    mov  si, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call buf_chk
    pushf
    mov  si, nm_swip
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

; ── edge: NULL dest safety ──
;     Fill kbuf with 0x55, call every routine with DI=0 (NULL).  None may
;     write (they early-return on DI==0), so kbuf must stay 0x55.
demo_edge_null:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x55
    call memsetw            ; kbuf = 0x55
    mov  cx, KBUF_LEN
    ; each call below uses DI=0 (NULL) -> guard must make them no-ops
    mov  di, 0
    mov  al, 0xFF
    call memsetw
    xor  di, di
    call memset_rev16
    xor  di, di
    call memzero16
    xor  di, di
    call memzero_rev16
    xor  di, di
    call secure_wipe16
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x55
    call buf_chk
    pushf
    mov  si, nm_null
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

; ── edge: count == 0 ──
;     Fill kbuf with 0x42, then memsetw with CX=0 must leave it untouched.
demo_edge_zero:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x42
    call memsetw            ; kbuf = 0x42
    mov  di, kbuf
    mov  al, 0xFF
    xor  cx, cx             ; count = 0 -> no-op
    call memsetw
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x42
    call buf_chk
    pushf
    mov  si, nm_zero
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

; ═══════════════════════════════════════════════════════
;  16-BIT MEMORY ROUTINES (modular ports of libmem)
;  included here (after start) so the kernel ENTRY (first byte) is `start:`,
;  while NASM still resolves all forward `call` references.
;  DI=dest  AL=fill  CX=count   (operates on ES:[DI]); zero-funcs: DI,CX only
; ═══════════════════════════════════════════════════════
%include "memset.asm"        ; memsetw       (DI,AL,CX)
%include "memzero.asm"       ; memzero16     (DI,CX)   -> calls memsetw
%include "memset_rev.asm"    ; memset_rev16  (DI,AL,CX)
%include "memzero_rev.asm"   ; memzero_rev16 (DI,CX)   -> calls memset_rev16
%include "secure_wipe.asm"   ; secure_wipe16 (DI,CX)   -> calls memset_rev16 (black-box)

; ═══════════════════════════════════════════════════════
;  DATA
; ═══════════════════════════════════════════════════════
k_header:   db 13, 10, "  KERNEL CONSOLE (custom mem)", 13, 10, 0
k_summary:  db "  kernel memory functions live", 13, 10, 0

nm_memsetw:    db "  memsetw     :", 0
nm_memzero:    db "  memzero16   :", 0
nm_msrev:      db "  memset_rev16:", 0
nm_mzrev:      db "  memzero_rev16:", 0
nm_swip:       db "  secure_wipe16:", 0
nm_null:       db "  NULL safety :", 0
nm_zero:       db "  count==0    :", 0

pass_str:      db " [OK]", 13, 10, 0
fail_str:      db " [FAIL]", 13, 10, 0
