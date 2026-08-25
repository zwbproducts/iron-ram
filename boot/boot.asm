; boot.asm — stage-1 BIOS bootloader (512-byte boot sector)
;
; Role: set up 16-bit real mode, then load the custom 16-bit kernel
; (kernel.asm) from sectors 2+ (read with BIOS int 13h/ah=02h) into physical
; 0x8000 and far-jump into it.  On disk-read failure it reports via the BIOS
; teletype and halts.
;
; The kernel (stage 2) owns the user-visible console: it brings the modular
; 16-bit ports of the libmem memory routines and a NON-BIOS kernel console
; (VGA text buffer @ 0xB8000) that clears the screen with memzero16 and
; demonstrates the routines live.
;
; Build:  nasm -f bin -DKERNEL_SECTORS=<n> boot.asm -o boot.bin
; Run:    qemu-system-x86_64 -drive format=raw,file=disk.img -nographic -serial mon:stdio

BITS 16
ORG 0x7C00

; ── constants ──
%define COL_RED     0x0C
%define KERNEL_OFFSET 0x8000
%ifndef KERNEL_SECTORS
  %define KERNEL_SECTORS 8
%endif

; ═══════════════════════════════════════════════════════
;  ENTRY POINT  (BIOS loads this sector at 0x7C00 and jumps here; DL=drive)
; ═══════════════════════════════════════════════════════
start:
    cli
    xor  ax, ax
    mov  [boot_drv], dl      ; remember boot drive (DL) from BIOS
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    ; happy path: hand off straight to the custom kernel (its console drives
    ; the screen with our memory routines); the kernel prints first.
    call load_kernel         ; reads kernel sectors, jmps to 0x8000 on success
; load_kernel only returns here on disk-read failure
.fail:  hlt
        jmp  .fail

; ── load_kernel ── read KERNEL_SECTORS sectors starting at sector 2
;    (sector 1 is this boot sector) into 0x0000:KERNEL_OFFSET (0x8000),
;    then far-jump into the kernel.  CF set => disk-read error.
load_kernel:
    mov  dl, [boot_drv]      ; boot drive captured at entry
    mov  ax, 0x0000
    mov  es, ax              ; buffer segment
    mov  bx, KERNEL_OFFSET   ; buffer offset
    mov  ah, 0x02            ; BIOS int 13h: read sectors
    mov  al, byte KERNEL_SECTORS
    xor  cx, cx              ; cylinder 0 -> CH=0
    mov  cl, 2               ; sector 2 (boot sector is sector 1)
    xor  dh, dh              ; head 0
    int  0x13
    jc  .err
    jmp  0x0000:KERNEL_OFFSET   ; kernel entry (ORG 0x8000)
.err:
    mov  si, err_msg
    mov  bl, COL_RED
    call puts
    ret

; ── puts ── BIOS INT 0x10 teletype, AH=0x0E ──  (SI=pointer, BL=colour)
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

; ── data ──
boot_drv: db 0
err_msg:   db "  disk read error", 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
