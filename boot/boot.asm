; boot.asm — BIOS bootloader: tests 16-bit memory routines on the BIOS console
;
; This boot sector includes modular 16-bit .asm ports of every libmem/
; function, then tests them with a table-driven runner + edge-case tests.
;
; Architecture (mirrors libmem/ exactly):
;
;   ┌─────────────────────┐   extern memset_rev   ┌──────────────────┐
;   │  secure_wipe.asm    │ ─────────────────────→│  memset_rev.asm  │
;   │  (black-box wipe)   │  (opaque boundary, DSE │  (backward fill)  │
;   │                     │   cannot eliminate)   │                  │
;   └─────────────────────┘                        └──────────────────┘
;
; Build:  nasm -f bin boot.asm -o boot.bin
; Run:    qemu-system-x86_64 -drive format=raw,file=boot.bin -nographic

BITS 16
ORG 0x7C00

; ── colour / config constants ──
%define COL_CYAN    0x0B
%define COL_YELLOW  0x0E
%define COL_GREEN   0x0A
%define COL_RED     0x0C
%define BS          16

; ═══════════════════════════════════════════════════════
;  ENTRY POINT  (must be first — BIOS jumps to 0x7C00)
; ═══════════════════════════════════════════════════════
start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    ; header
    mov  si, header
    mov  bl, COL_CYAN
    call puts

    ; table-driven test suite (5 function tests)
    call run_tests

    ; edge-case tests (NULL safety + count==0)
    call edge_tests

    ; done
    mov  si, done_msg
    mov  bl, COL_YELLOW
    call puts
.halt:  hlt
    jmp  .halt

; ═══════════════════════════════════════════════════════
;  16-BIT MEMORY ROUTINES (modular ports of libmem)
;  DI=dest  AL=fill  CX=count   Preserves DI,CX
; ═══════════════════════════════════════════════════════
%include "memset.asm"
%include "memzero.asm"
%include "memset_rev.asm"
%include "memzero_rev.asm"
%include "secure_wipe.asm"

; ═══════════════════════════════════════════════════════
;  TABLE-DRIVEN TEST RUNNER
;
;  Entry (8 bytes):
;    +0  name_ptr   (word)  → test name string
;    +2  func_ptr   (word)  → memory function
;    +4  prefill    (byte)  → fill buffer before calling func
;    +5  op_val     (byte)  → AL value for memset-like funcs (ignored by zero)
;    +6  expected   (byte)  → expected buffer value after call
;    +7  (pad)
; ═══════════════════════════════════════════════════════
%macro TEST_ENTRY 5
    dw %1, %2
    db %3, %4, %5, 0
%endmacro

tests:
    TEST_ENTRY name_memset,  memsetw,        0,   0xAB, 0xAB
    TEST_ENTRY name_memzero, memzero16,      0xFF, 0,   0
    TEST_ENTRY name_msrev,   memset_rev16,   0,   0xCD, 0xCD
    TEST_ENTRY name_mzrev,   memzero_rev16,  0xEE, 0,   0
    TEST_ENTRY name_secure,  secure_wipe16,  0x77, 0,   0
    dw 0, 0
    db 0, 0, 0, 0

run_tests:
    push bp                     ; BP survives calls (not touched by puts)
    mov  bp, tests
.next:
    mov  si, [bp]            ; name_ptr
    test si, si
    jz   .done
    mov  bl, COL_YELLOW
    call puts

    mov  al, [bp+4]         ; prefill
    mov  di, buf
    mov  cx, BS
    call memsetw            ; CX/DI preserved

    mov  al, [bp+5]         ; op_val
    call word [bp+2]        ; call the function (CX/DI preserved)
    mov  si, buf            ; vbuf needs SI
    mov  al, [bp+6]         ; expected
    call vbuf               ; sets carry
    call result
    add  bp, 8
    jmp  .next
.done:
    pop  bp
    ret

; ═══════════════════════════════════════════════════════
;  EDGE-CASE TESTS  (NULL safety + count==0)
; ═══════════════════════════════════════════════════════
edge_tests:
    mov  si, name_edge
    mov  bl, COL_YELLOW
    call puts

    ; ── NULL dest safety ──
    ;   Call every function with DI=0 (NULL).  None should crash.
    mov  di, 0
    mov  al, 0xFF
    mov  cx, BS
    call memsetw
    call memset_rev16
    call memzero16
    call memzero_rev16
    call secure_wipe16

    ; ── count == 0 safety ──
    ;   Fill buf with 0x42, call memset with CX=0, verify buf unchanged.
    mov  di, buf
    mov  al, 0x42
    mov  cx, BS
    call memsetw            ; buf = all 0x42  (CX preserved=BS)
    mov  al, 0xFF
    xor  cx, cx             ; count = 0
    call memsetw            ; no-op  (CX preserved=0)
    mov  si, buf
    mov  al, 0x42           ; expected: still 0x42
    mov  cx, BS
    call vbuf
    call result
    ret

; ═══════════════════════════════════════════════════════
;  BIOS CONSOLE I/O  (INT 0x10 teletype, AH=0x0E)
; ═══════════════════════════════════════════════════════

; ── puts ── print NUL-terminated string (SI=pointer, BL=colour) ──
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

; ── result ── print [PASS]/[FAIL] from carry (green/red) ──
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

; ── vbuf ── verify CX bytes at [SI] == AL (carry=clear=match) ──
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

; ═══════════════════════════════════════════════════════
;  DATA
; ═══════════════════════════════════════════════════════
buf:    times BS db 0

header:         db "  BIOS BOOT TEST", 13, 10, 0
name_memset:    db "  memset", 13, 10, 0
name_memzero:   db "  memzero", 13, 10, 0
name_msrev:     db "  memset_rev", 13, 10, 0
name_mzrev:     db "  memzero_rev", 13, 10, 0
name_secure:    db "  secure_wipe", 13, 10, 0
name_edge:      db "  edge: NULL+0", 13, 10, 0
pass_str:       db "  [PASS]", 13, 10, 0
fail_str:       db "  [FAIL]", 13, 10, 0
done_msg:       db 13, 10, "  halt", 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
