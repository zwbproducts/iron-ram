; isr_gpf.asm — General Protection Fault handler (vector 13)
;
; On x86, a GPF pushes an error code automatically.
; Error code bit 0 = 0 → software-triggered (e.g., from SIG_LIBMEM_TEST_ALL
; smoke testing), bit 0 = 1 → hardware fault.
;
; Software-triggered GPFs are logged to serial but DO NOT halt —
; signal_dispatch can continue and report the failure.
; Hardware GPFs are logged and halt the CPU.

[bits 32]
global gpf_handler

; Stack layout after CPU push + pusha + push ds:
;   [esp+0..7]   = pusha (eax..edi)
;   [esp+8..11]  = ds   ; actually pusha saves 8 regs, ds is pushed after
;   Let me document it properly:
;   [esp+0..3]   = eax (pushed by pusha)
;   [esp+4..7]   = ecx
;   [esp+8..11]  = edx
;   [esp+12..15] = ebx
;   [esp+16..19] = original esp (pusha saves current)
;   [esp+20..23] = ebp
;   [esp+24..27] = esi
;   [esp+28..31] = edi
;   [esp+32..35] = ds (pushed by `push ds`)
;   [esp+36]     = error_code (pushed by CPU)
;   [esp+40]     = eip
;   [esp+44]     = cs
;   [esp+48]     = eflags

gpf_handler:
    ; pusha saves 8 registers (eax, ecx, edx, ebx, esp, ebp, esi, edi)
    pusha
    ; save ds on top of pusha
    push ds

    ; Read error_code from stack (below pusha + push ds)
    mov  eax, [esp + 32 + 4]   ; = [esp+36] = error_code
    mov  edx, 0xe9            ; serial port

    test eax, 1
    jnz  .hw                    ; bit 0 set → hardware fault

    ; ---- Software-triggered GPF: log and iret ----
    mov  al, 'g'
    out  dx, al
    mov  al, 'p'
    out  dx, al
    mov  al, 'f'
    out  dx, al
    mov  al, ' '
    out  dx, al

    ; print error code as 8 hex nibbles
    mov  esi, eax              ; save error code
    mov  ecx, 8
.hex_loop:
    rol  esi, 4                 ; rotate leftmost nibble into low bits
    mov  eax, esi              ; copy to eax
    and  al, 0x0F              ; isolate low nibble (al is byte-accessible)
    add  al, '0'
    cmp  al, '9'
    jbe  .hex_ok
    add  al, 7                  ; adjust for A-F
.hex_ok:
    out  dx, al
    loop .hex_loop

    mov  al, 0x0D
    out  dx, al
    mov  al, 0x0A
    out  dx, al

    ; Restore and return
    pop  ds
    popa
    add  esp, 4                 ; discard CPU-pushed error_code
    iret

.hw:
    ; Hardware GPF: log and halt
    mov  al, 'G'
    out  dx, al
    mov  al, 'P'
    out  dx, al
    mov  al, 'F'
    out  dx, al
    mov  al, '!'
    out  dx, al
.halt:
    cli
    hlt
    jmp .halt
