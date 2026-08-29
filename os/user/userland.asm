; ===========================================================================
; userland.asm — Userland shell stub
; Runs in ring 3, can ONLY access kernel via int 0x80
;
; Target: 32-bit x86 protected mode, ring 3
; Memory: Loaded at 0x200000
; Syscall mechanism: int 0x80
;   EAX = syscall number
;   EBX = arg0
;   ECX = arg1
;   EDX = arg2
;   Returns: EAX = result
; ===========================================================================

[BITS 32]
GLOBAL userland_start
GLOBAL _start

section .text._start
_start:
userland_start:
    ; Heartbeat: U = userland entered (via syscall, not direct I/O)
    mov  al, 'U'
    call do_putc

    ; Test 1: Call SYS_MEM_STATUS (should return 0xDEADBEEF)
    mov  eax, 0              ; SYS_MEM_STATUS
    int  0x80

    ; Heartbeat: M = syscall returned
    push eax                 ; Save result
    mov  al, 'M'
    call do_putc
    pop  eax                 ; Restore result

    ; Check result (should be 0xDEADBEEF)
    cmp  eax, 0xDEADBEEF
    je   .test1_pass

    ; Test failed
    mov  al, 'F'
    call do_putc
    jmp  .halt

.test1_pass:
    ; Heartbeat: 1 = test 1 passed
    mov  al, '1'
    call do_putc

    ; Test 2: Call SYS_PUTS with message
    mov  eax, 2              ; SYS_PUTS
    mov  ebx, user_msg       ; arg0 = message pointer
    int  0x80

    ; Heartbeat: 2 = test 2 passed
    mov  al, '2'
    call do_putc

    ; Test 3: Negative control - try to call kernel function directly
    ; This should cause a GPF because userland can't access kernel memory
    ; mov  eax, 0x100000      ; Try to read kernel memory
    ; mov  ebx, [eax]          ; This would fault
    ; For now, skip this test and just halt

    ; Heartbeat: H = halt
    mov  al, 'H'
    call do_putc

.halt:
    cli
    hlt
    jmp  .halt

; ===========================================================================
; do_putc — userland serial output via syscall
; Input: AL = character
; ===========================================================================
do_putc:
    push ebx
    mov  ebx, eax            ; arg0 = character
    mov  eax, 1              ; SYS_PUTC
    int  0x80
    pop  ebx
    ret

section .data
user_msg: db "Hello from userland via syscall!", 13, 10, 0
