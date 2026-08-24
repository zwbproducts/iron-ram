; boot.asm — Minimal 512-byte boot sector
; Prints a multi-colour banner to the BIOS console (int 0x10 teletype).
;
; Assemble:  nasm -f bin boot.asm -o boot.bin
; Run:       qemu-system-x86_64 -drive format=raw,file=boot.bin
;
; ─────────────────────────────────────────────────────────────────────────
;  16-bit REAL MODE
;  BIOS loads this sector at 0x7C00 and jumps to it with CS:IP = 0x0000:0x7C00
;  (or 0x07C0:0x0000 — we normalise to ORG 0x7C00).
; ─────────────────────────────────────────────────────────────────────────

BITS 16
ORG 0x7C00

%define VIDEO_PAGE    0x00        ; BH = page number
%define COLOUR_GOLD   0x0E        ; yellow
%define COLOUR_CYAN   0x0B
%define COLOUR_GREEN  0x0A
%define COLOUR_MAGENTA 0x0D

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00           ; safe stack in real mode
    sti

    ; ── print the golden heading ──────────────────────────────────────
    mov  si, banner
    mov  bl, COLOUR_GOLD
    call print_string

    ; ── print the cyan sub-heading ────────────────────────────────────
    mov  si, subhead
    mov  bl, COLOUR_CYAN
    call print_string

    ; ── print the green tagline ───────────────────────────────────────
    mov  si, tagline
    mov  bl, COLOUR_GREEN
    call print_string

    ; ── print the magenta signature ───────────────────────────────────
    mov  si, sig
    mov  bl, COLOUR_MAGENTA
    call print_string

    ; ── spin forever ──────────────────────────────────────────────────
    cli
    hlt_loop:
        hlt
        jmp hlt_loop

; ─────────────────────────────────────────────────────────────────────────
;  print_string — print a $ -terminated string
;  Input:  SI = pointer to string (terminated by '$')
;          BL = colour
;  Destroys: AX, SI
; ─────────────────────────────────────────────────────────────────────────
print_string:
    pusha
    .next_char:
        lodsb                       ; AL = [SI],  SI++
        cmp  al, '$'                ; end-of-string marker
        je   .done
        mov  ah, 0x0E               ; BIOS teletype
        mov  bh, VIDEO_PAGE
        int  0x10                   ; write char in AL
        jmp  .next_char
    .done:
        popa
        ret

; ─────────────────────────────────────────────────────────────────────────
;  Data (strings)
; ─────────────────────────────────────────────────────────────────────────

banner    db 13, 10, "  ____  _    _ _____ _____ _   _  ____ ", 13, 10, \
            " | __ )| |  | | ____|_   _| \ | | / ___|", 13, 10, \
            " |  _ \| |  | |  _|   | | |  \| | |    ", 13, 10, \
            " | |_) | |__| | |___  | | | |\  | |___ ", 13, 10, \
            " |____/ \____/|_____| |_| |_| \_|\____|", 13, 10, 13, 10, "$"

subhead   db "  512 bytes | 16-bit real mode | BIOS INT 10h teletype", 13, 10, "$"

tagline   db "  Booting from raw assembly... no OS, no problem. :)", 13, 10, 13, 10, "$"

sig       db "  -- kilo-dev stack --", 13, 10, "$"

; ─────────────────────────────────────────────────────────────────────────
;  Boot signature (must be at offset 510)
; ─────────────────────────────────────────────────────────────────────────
times 510 - ($ - $$) db 0
dw 0xAA55
