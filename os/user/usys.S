; usys.S — Userland syscall wrappers
; These are the ONLY functions userland code can call to reach the kernel.
; Each wrapper loads arguments into registers and triggers int 0x80.
;
; Calling convention: cdecl (stack-based, caller cleanup)
; Syscall ABI:
;   EAX = syscall number
;   EBX = arg0
;   ECX = arg1
;   EDX = arg2
;   Returns: EAX = result

[BITS 32]
SECTION .text

; Syscall numbers
%define SYS_MEM_STATUS  0
%define SYS_PUTC        1
%define SYS_PUTS        2
%define SYS_GETC        3
%define SYS_GETS        4
%define SYS_MEMSET      5
%define SYS_MEMCPY      6
%define SYS_MEMMOV      7
%define SYS_MEMCMP      8
%define SYS_MEMCHR      9
%define SYS_HEAP_ALLOC  10
%define SYS_HEAP_FREE   11
%define SYS_SEC_WIPE    12

; Global exports — only these symbols are visible to userland
GLOBAL usys_mem_status
GLOBAL usys_putc
GLOBAL usys_puts
GLOBAL usys_getc
GLOBAL usys_gets
GLOBAL usys_memset
GLOBAL usys_memcpy
GLOBAL usys_memmov
GLOBAL usys_memcmp
GLOBAL usys_memchr
GLOBAL usys_heap_alloc
GLOBAL usys_heap_free
GLOBAL usys_sec_wipe

; ─── SYS_MEM_STATUS (0) — return memory status marker ───
usys_mem_status:
    mov  eax, SYS_MEM_STATUS
    int  0x80
    ret

; ─── SYS_PUTC (1) — output character ───
; Input: [ESP+4] = character
usys_putc:
    mov  eax, SYS_PUTC
    mov  ebx, [esp + 4]
    int  0x80
    ret

; ─── SYS_PUTS (2) — output string ───
; Input: [ESP+4] = pointer to string
usys_puts:
    mov  eax, SYS_PUTS
    mov  ebx, [esp + 4]
    int  0x80
    ret

; ─── SYS_GETC (3) — read character ───
usys_getc:
    mov  eax, SYS_GETC
    int  0x80
    ret

; ─── SYS_GETS (4) — read string ───
; Input: [ESP+4] = buffer pointer, [ESP+8] = max length
usys_gets:
    mov  eax, SYS_GETS
    mov  ebx, [esp + 4]
    mov  ecx, [esp + 8]
    int  0x80
    ret

; ─── SYS_MEMSET (5) — fill memory ───
; Input: dest, value, count
usys_memset:
    mov  eax, SYS_MEMSET
    mov  ebx, [esp + 4]    ; dest
    mov  ecx, [esp + 8]    ; value
    mov  edx, [esp + 12]   ; count
    int  0x80
    ret

; ─── SYS_MEMCPY (6) — copy memory ───
; Input: dest, src, count
usys_memcpy:
    mov  eax, SYS_MEMCPY
    mov  ebx, [esp + 4]    ; dest
    mov  ecx, [esp + 8]    ; src
    mov  edx, [esp + 12]   ; count
    int  0x80
    ret

; ─── SYS_MEMMOV (7) — move memory (overlap-safe) ───
usys_memmov:
    mov  eax, SYS_MEMMOV
    mov  ebx, [esp + 4]    ; dest
    mov  ecx, [esp + 8]    ; src
    mov  edx, [esp + 12]   ; count
    int  0x80
    ret

; ─── SYS_MEMCMP (8) — compare memory ───
usys_memcmp:
    mov  eax, SYS_MEMCMP
    mov  ebx, [esp + 4]    ; ptr1
    mov  ecx, [esp + 8]    ; ptr2
    mov  edx, [esp + 12]   ; count
    int  0x80
    ret

; ─── SYS_MEMCHR (9) — find byte in memory ───
usys_memchr:
    mov  eax, SYS_MEMCHR
    mov  ebx, [esp + 4]    ; ptr
    mov  ecx, [esp + 8]    ; value
    mov  edx, [esp + 12]   ; count
    int  0x80
    ret

; ─── SYS_HEAP_ALLOC (10) — allocate heap memory ───
usys_heap_alloc:
    mov  eax, SYS_HEAP_ALLOC
    mov  ebx, [esp + 4]    ; size
    int  0x80
    ret

; ─── SYS_HEAP_FREE (11) — free heap memory ───
usys_heap_free:
    mov  eax, SYS_HEAP_FREE
    mov  ebx, [esp + 4]    ; ptr
    int  0x80
    ret

; ─── SYS_SEC_WIPE (12) — secure wipe memory ───
usys_sec_wipe:
    mov  eax, SYS_SEC_WIPE
    mov  ebx, [esp + 4]    ; ptr
    mov  ecx, [esp + 8]    ; count
    int  0x80
    ret
