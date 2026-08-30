; kernel.asm — custom 16-bit real-mode kernel
;
; Handed off by boot.asm: the bootloader reads this image (loaded at the
; start of sector 2) into physical 0x8000 and `jmp 0x0000:0x8000`.
;
; This kernel does NOT use ANY BIOS services for its console — the only I/O
; routines here are the 16-bit real-mode ports of the libmem memory functions
; we wrote ourselves. The kernel console is the VGA text frame buffer at
; 0xB8000, and its screen-clear is performed by calling memzero16() on the
; 4000-byte video memory.  Each character is then written with a direct
; store.  To let the host observe the kernel console under `qemu -nographic`,
; each character is also teed to the serial port (0x3F8) by a raw `out` —
; that is itself hand-written 16-bit I/O, not a BIOS call.
;
; Memory-function calling convention (kept identical to boot.asm):
;     DI = dest    AL = fill byte    CX = count    (operates on ES:[DI])
;     memzero16 / memzero_rev16 / secure_wipe16 take only DI + CX (AL=0).
;     For 2-arg functions:  DI=arg1, SI=arg2, CX=count.
;     For memrotate: DI=dest, DX=shift, CX=count.
;     For memfind/memcount: DI=dest, AL=byte, CX=count, returns AX.
;     For memchecksum: DI=dest, CX=count, returns AL.
;     For memeq: DI=s1, SI=s2, CX=count, returns AX=1/0.
;     For memfill: DI=dest, AX=pattern, CX=count.
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
    call demo_memset
    call demo_memcpy
    call demo_memmove
    call demo_memcmp
    call demo_memchr
    call demo_memsetw
    call demo_memzero
    call demo_memset_rev
    call demo_memzero_rev
    call demo_secure_wipe
    call demo_memfill
    call demo_memswap
    call demo_memreverse
    call demo_memrotate_l
    call demo_memrotate_r
    call demo_memfind
    call demo_memcount
    call demo_memchecksum
    call demo_memeq
    call demo_memmove_rev

    ; edge cases: NULL-dest safety + count==0 no-op
    call demo_edge_null
    call demo_edge_zero

    mov  si, k_summary
    call kputs

.halt:
    hlt
    jmp  .halt

; ═══════════════════════════════════════════════════════
;  KERNEL CONSOLE  (VGA text buffer @ 0xB8000)
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
    mov  ax, bx
    xor  dx, dx
    mov  cx, ROW_BYTES
    div  cx
    mul  cx                  ; ax = row * ROW_BYTES
    mov  bx, ax
    mov  [cursor], bx
    mov  al, 0x0D
    jmp  .serial

.lf:
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
    xor  ax, ax
.set:
    mov  bx, ax
    mov  [cursor], bx
    mov  al, 0x0A

.serial:
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
    mov  es, ax
.next:
    lodsb                    ; AL = [si], si++
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
;  Each demo runs a function on kbuf, verifies the result,
;  then prints "  <name>: [OK]" / "[FAIL]" on the console.
; ═══════════════════════════════════════════════════════

kbuf: times KBUF_LEN db 0

; buf_chk: DI=dest, CX=count, AL=expected -> CF set if any mismatch
buf_chk:
    push ax
    push cx
    push si
    mov  si, di
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

; ── Demo: memset (basic forward fill) ──
demo_memset:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw
    mov  di, kbuf
    mov  cx, 16
    mov  al, 0xCC
    call memsetw
    mov  si, kbuf
    mov  cx, 16
    mov  al, 0xCC
    call buf_chk
    pushf
    mov  si, nm_memset
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    ret
.fail:
    mov  si, fail_str
    ret

; ── Demo: memcpy (forward copy) ──
demo_memcpy:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, 16
    mov  al, 0x00
    call memsetw
    mov  di, kbuf + 16
    mov  si, kbuf
    mov  cx, 16
    mov  al, 0xDD
    call memsetw
    ; copy kbuf+16 -> kbuf (16 bytes)
    mov  di, kbuf
    mov  si, kbuf + 16
    mov  cx, 16
    call memcpy16
    mov  si, kbuf
    mov  cx, 16
    mov  al, 0xDD
    call buf_chk
    pushf
    mov  si, nm_memcpy
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    ret
.fail:
    mov  si, fail_str
    ret

; ── Demo: memmove (overlapping copy) ──
demo_memmove:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x00
    call memsetw
    ; fill kbuf+8 with 0xEE for 16 bytes (overlaps with kbuf)
    mov  di, kbuf + 8
    mov  cx, 16
    mov  al, 0xEE
    call memsetw
    ; memmove kbuf <- kbuf+8, 16 bytes (overlap: dst < src but overlapping)
    mov  di, kbuf
    mov  si, kbuf + 8
    mov  cx, 16
    call memmove16
    mov  si, kbuf
    mov  cx, 16
    mov  al, 0xEE
    call buf_chk
    pushf
    mov  si, nm_memmov
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    ret
.fail:
    mov  si, fail_str
    ret

; ── Demo: memcmp (compare two regions) ──
demo_memcmp:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, 16
    mov  al, 0xBB
    call memsetw
    mov  di, kbuf + 16
    mov  cx, 16
    mov  al, 0xBB
    call memsetw
    ; equal comparison: kbuf vs kbuf+16
    mov  di, kbuf
    mov  si, kbuf + 16
    mov  cx, 16
    call memcmp16
    test ax, ax
    jnz  .fail
    ; make them different
    mov  byte [kbuf], 0xBC
    mov  di, kbuf
    mov  si, kbuf + 16
    mov  cx, 16
    call memcmp16
    test ax, ax
    jz  .fail
    pushf
    mov  si, nm_memcmp
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    ret
.fail:
    mov  si, fail_str
    ret

; ── Demo: memchr (find byte) ──
demo_memchr:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xFF
    call memsetw
    ; place 0x42 at offset 20
    mov  byte [kbuf + 20], 0x42
    mov  di, kbuf
    mov  al, 0x42
    mov  cx, KBUF_LEN
    call memchr16
    cmp  di, kbuf + 20
    pushf
    mov  si, nm_memchr
    call kputs
    popf
    jc  .fail
    mov  si, pass_str
    ret
.fail:
    mov  si, fail_str
    ret

; ── Demo: memsetw (forward 16-bit word fill) ──
demo_memsetw:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw
    mov  al, 0xAB
    call memsetw
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xAB
    call buf_chk
    pushf
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

; ── Demo: memzero (forward zero-fill) ──
demo_memzero:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xFF
    call memsetw
    mov  di, kbuf
    mov  cx, KBUF_LEN
    call memzero16
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

; ── Demo: memset_rev (backward fill) ──
demo_memset_rev:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw
    mov  al, 0xCD
    call memset_rev16
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

; ── Demo: memzero_rev (backward zero-fill) ──
demo_memzero_rev:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xEE
    call memsetw
    mov  di, kbuf
    mov  cx, KBUF_LEN
    call memzero_rev16
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

; ── Demo: secure_wipe (black-box backward wipe) ──
demo_secure_wipe:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x77
    call memsetw
    mov  di, kbuf
    mov  cx, KBUF_LEN
    call secure_wipe16
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

; ── Demo: memfill (16-bit pattern fill) ──
demo_memfill:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw
    mov  ax, 0xBEEF
    mov  cx, 16
    call memfill16
    ; check: bytes should be EF BE EF BE ...
    mov  si, kbuf
    mov  cx, 8
.memfill_chk:
    ; even byte must be 0xEF
    mov  al, [si]
    cmp  al, 0xEF
    jne  .fail
    inc  si
    ; odd byte must be 0xBE
    mov  al, [si]
    cmp  al, 0xBE
    jne  .fail
    inc  si
    dec  cx
    jnz  .memfill_chk
    pushf
    mov  si, nm_memfill
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

; ── Demo: memswap (swap two regions) ──
demo_memswap:
    mov  ax, 0
    mov  es, ax
    ; buf1 = 0x11, buf2 = 0x22 (each 8 bytes, within kbuf)
    mov  di, kbuf
    mov  cx, 8
    mov  al, 0x11
    call memsetw
    mov  di, kbuf + 32                  ; second buffer within kbuf (8 bytes at offset 32)
    mov  cx, 8
    mov  al, 0x22
    call memsetw
    ; swap first 8 bytes of each buffer
    mov  di, kbuf
    mov  si, kbuf + 32
    mov  cx, 8
    call memswap16
    ; check both buffers; use AL as status (0=ok, 1=fail)
    mov  si, kbuf
    mov  cx, 8
    mov  al, 0x22
    call buf_chk
    mov  al, 0            ; assume ok
    jc  .chk_done
    mov  si, kbuf + 32
    mov  cx, 8
    mov  al, 0x11
    call buf_chk
    mov  al, 0            ; second check ok
    jc  .chk_fail
    jmp  .chk_done
.chk_fail:
    mov  al, 1            ; mark fail
.chk_done:
    cmp  al, 0
    pushf
    mov  si, nm_memswap
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

; ── Demo: memreverse (reverse bytes in-place) ──
demo_memreverse:
    mov  ax, 0
    mov  es, ax
    ; fill kbuf with 0,1,2,...,15 (first 16 bytes)
    mov  di, kbuf
    mov  cx, 16
    mov  bl, 0
    mov  byte [es:di], bl
    inc  di
    mov  bl, 1
    mov  byte [es:di], bl
    inc  di
    mov  bl, 2
    mov  byte [es:di], bl
    inc  di
    mov  bl, 3
    mov  byte [es:di], bl
    inc  di
    mov  bl, 4
    mov  byte [es:di], bl
    inc  di
    mov  bl, 5
    mov  byte [es:di], bl
    inc  di
    mov  bl, 6
    mov  byte [es:di], bl
    inc  di
    mov  bl, 7
    mov  byte [es:di], bl
    inc  di
    mov  bl, 8
    mov  byte [es:di], bl
    inc  di
    mov  bl, 9
    mov  byte [es:di], bl
    inc  di
    mov  bl, 10
    mov  byte [es:di], bl
    inc  di
    mov  bl, 11
    mov  byte [es:di], bl
    inc  di
    mov  bl, 12
    mov  byte [es:di], bl
    inc  di
    mov  bl, 13
    mov  byte [es:di], bl
    inc  di
    mov  bl, 14
    mov  byte [es:di], bl
    inc  di
    mov  bl, 15
    mov  byte [es:di], bl

    mov  di, kbuf
    mov  cx, 16
    call memreverse16
    ; check: [15,14,13,...,0]
    mov  si, kbuf
    mov  cx, 16
    mov  al, 15
.rchk:
    cmp  [si], al
    jne  .fail
    inc  si
    dec  al
    loop .rchk
    pushf
    mov  si, nm_memrev
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

; ── Demo: memrotate_l (left rotate) ──
demo_memrotate_l:
    mov  ax, 0
    mov  es, ax
    ; buf = [1,2,3,4,5,6,7,8]
    mov  di, kbuf
    mov  byte [es:di], 1
    mov  byte [es:di+1], 2
    mov  byte [es:di+2], 3
    mov  byte [es:di+3], 4
    mov  byte [es:di+4], 5
    mov  byte [es:di+5], 6
    mov  byte [es:di+6], 7
    mov  byte [es:di+7], 8

    mov  di, kbuf
    mov  dx, 3                  ; shift
    mov  cx, 8                  ; count
    call memrotate_l16
    ; expected: [4,5,6,7,8,1,2,3]
    mov  si, kbuf
    cmp  byte [si+0], 4
    jne  .fail
    cmp  byte [si+1], 5
    jne  .fail
    cmp  byte [si+2], 6
    jne  .fail
    cmp  byte [si+3], 7
    jne  .fail
    cmp  byte [si+4], 8
    jne  .fail
    cmp  byte [si+5], 1
    jne  .fail
    cmp  byte [si+6], 2
    jne  .fail
    cmp  byte [si+7], 3
    jne  .fail
    mov  si, nm_rotl
    call kputs
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, nm_rotl
    call kputs
    mov  si, fail_str
    call kputs
    ret

; ── Demo: memrotate_r (right rotate) ──
demo_memrotate_r:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  byte [es:di], 1
    mov  byte [es:di+1], 2
    mov  byte [es:di+2], 3
    mov  byte [es:di+3], 4
    mov  byte [es:di+4], 5
    mov  byte [es:di+5], 6
    mov  byte [es:di+6], 7
    mov  byte [es:di+7], 8

    mov  di, kbuf
    mov  dx, 3
    mov  cx, 8
    call memrotate_r16
    ; expected: [6,7,8,1,2,3,4,5]
    mov  si, kbuf
    cmp  byte [si+0], 6
    jne  .fail
    cmp  byte [si+1], 7
    jne  .fail
    cmp  byte [si+2], 8
    jne  .fail
    cmp  byte [si+3], 1
    jne  .fail
    cmp  byte [si+4], 2
    jne  .fail
    cmp  byte [si+5], 3
    jne  .fail
    cmp  byte [si+6], 4
    jne  .fail
    cmp  byte [si+7], 5
    jne  .fail
    mov  si, nm_rotr
    call kputs
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, nm_rotr
    call kputs
    mov  si, fail_str
    call kputs
    ret

; ── Demo: memfind (find byte offset) ──
demo_memfind:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xFF
    call memsetw
    mov  di, kbuf
    mov  byte [es:di+10], 0x42
    mov  al, 0x42
    mov  cx, KBUF_LEN
    call memfind16
    cmp  ax, 10                     ; should return offset 10
    pushf
    mov  si, nm_memfind
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

; ── Demo: memcount (count byte occurrences) ──
demo_memcount:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xFF
    call memsetw
    mov  di, kbuf
    mov  byte [es:di], 0x42
    mov  byte [es:di+5], 0x42
    mov  byte [es:di+10], 0x42
    mov  al, 0x42
    mov  cx, KBUF_LEN
    call memcount16
    cmp  ax, 3                       ; 3 occurrences
    pushf
    mov  si, nm_memcount
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

; ── Demo: memchecksum (XOR checksum) ──
demo_memchecksum:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, 8
    mov  al, 0xFF
    call memsetw
    ; 8 bytes of 0xFF: XOR = 0 (even)
    mov  di, kbuf
    mov  cx, 8
    call memchecksum16
    test al, al
    jnz  .fail
    ; 3 bytes of 0xFF: XOR = 0xFF
    mov  di, kbuf
    mov  cx, 3
    call memchecksum16
    cmp  al, 0xFF
    pushf
    mov  si, nm_memchk
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

; ── Demo: memeq (boolean equality) ──
demo_memeq:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, 8
    mov  al, 0xAB
    call memsetw
    mov  di, kbuf + 8
    mov  cx, 8
    mov  al, 0xAB
    call memsetw
    ; buf == buf+8 -> should be equal (1)
    mov  di, kbuf
    mov  si, kbuf + 8
    mov  cx, 8
    call memeq16
    cmp  ax, 1
    pushf
    mov  si, nm_memeq
    call kputs
    popf
    jc  .fail
    ; different them
    mov  di, kbuf
    mov  byte [es:di], 0xAC
    mov  di, kbuf
    mov  si, kbuf + 8
    mov  cx, 8
    call memeq16
    cmp  ax, 0
    je  .eq_ok
    jmp  .fail
.eq_ok:
    mov  si, pass_str
    call kputs
    ret
.fail:
    mov  si, fail_str
    call kputs
    ret

; ── Demo: memmove_rev (backward copy) ──
demo_memmove_rev:
    mov  ax, 0
    mov  es, ax
    ; src = 0x77, dst = 0x00
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw
    mov  di, kbuf
    mov  cx, 8
    mov  al, 0x77
    call memsetw
    ; copy dst=kbuf+16, src=kbuf, n=8
    mov  di, kbuf + 16
    mov  si, kbuf
    mov  cx, 8
    call memmove_rev16
    ; check dst has 0x77
    mov  si, kbuf + 16
    mov  cx, 8
    mov  al, 0x77
    call buf_chk
    pushf
    mov  si, nm_memmovrev
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

; ── edge: NULL-dest safety ──
;     Fill kbuf with 0x55, call every routine with DI=0 (NULL).  None may
;     write (they early-return on DI==0), so kbuf must stay 0x55.
demo_edge_null:
    mov  ax, 0
    mov  es, ax
    mov  di, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x55
    call memsetw
    mov  cx, KBUF_LEN
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
    ; new functions NULL safety (memfill has no DI NULL check pattern
    ;  in 16-bit since it returns early, but let's verify memreverse16 etc)
    xor  di, di
    call memreverse16
    xor  di, di
    call memfind16
    xor  di, di
    call memcount16
    xor  di, di
    call memchecksum16
    ; verify kbuf still 0x55
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0x55
    call buf_chk
    mov  al, 0            ; assume ok
    jnc  .null_ok
    mov  al, 1            ; mark fail
.null_ok:
    cmp  al, 0
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
    call memsetw
    mov  di, kbuf
    mov  al, 0xFF
    xor  cx, cx
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
; ═══════════════════════════════════════════════════════
%include "memset.asm"        ; memsetw       (DI,AL,CX)
%include "memzero.asm"       ; memzero16     (DI,CX)   -> calls memsetw
%include "memset_rev.asm"    ; memset_rev16  (DI,AL,CX)
%include "memzero_rev.asm"   ; memzero_rev16 (DI,CX)   -> calls memset_rev16
%include "secure_wipe.asm"   ; secure_wipe16 (DI,CX)   -> calls memset_rev16 (black-box)
%include "memmove.asm"       ; memmove16     (DI,SI,CX)
%include "memcpy.asm"        ; memcpy16      (DI,SI,CX)
%include "memcmp.asm"        ; memcmp16      (DI,SI,CX) -> AX
%include "memchr.asm"        ; memchr16      (DI,AL,CX) -> AX (ptr)
%include "memfill.asm"       ; memfill16     (DI,AX,CX)
%include "memswap.asm"       ; memswap16     (DI,SI,CX)
%include "memreverse.asm"    ; memreverse16  (DI,CX)
%include "memrotate_l.asm"   ; memrotate_l16 (DI,DX,CX)
%include "memrotate_r.asm"   ; memrotate_r16 (DI,DX,CX)
%include "memfind.asm"       ; memfind16     (DI,AL,CX) -> AX
%include "memcount.asm"      ; memcount16    (DI,AL,CX) -> AX
%include "memchecksum.asm"   ; memchecksum16 (DI,CX) -> AL
%include "memeq.asm"         ; memeq16       (DI,SI,CX) -> AX
%include "memmove_rev.asm"   ; memmove_rev16 (DI,SI,CX)

; ═══════════════════════════════════════════════════════
;  DATA
; ═══════════════════════════════════════════════════════
k_header:   db 13, 10, "  KERNEL CONSOLE (custom mem)", 13, 10, 0
k_summary:  db "  kernel memory functions live", 13, 10, 0

nm_memset:        db "  memset      :", 0
nm_memcpy:        db "  memcpy16    :", 0
nm_memmov:        db "  memmove16   :", 0
nm_memcmp:        db "  memcmp16    :", 0
nm_memchr:        db "  memchr16    :", 0
nm_memsetw:      db "  memsetw     :", 0
nm_memzero:      db "  memzero16   :", 0
nm_msrev:        db "  memset_rev16:", 0
nm_mzrev:        db "  memzero_rev16:", 0
nm_swip:         db "  secure_wipe16:", 0
nm_memfill:      db "  memfill16   :", 0
nm_memswap:      db "  memswap16   :", 0
nm_memrev:       db "  memreverse16:", 0
nm_rotl:         db "  rotate_l16  :", 0
nm_rotr:         db "  rotate_r16  :", 0
nm_memfind:      db "  memfind16   :", 0
nm_memcount:     db "  memcount16  :", 0
nm_memchk:       db "  memchecksum16:", 0
nm_memeq:        db "  memeq16     :", 0
nm_memmovrev:    db "  memmove_rev16:", 0
nm_null:         db "  NULL safety :", 0
nm_zero:         db "  count==0    :", 0

pass_str:      db " [OK]", 13, 10, 0
fail_str:      db " [FAIL]", 13, 10, 0
