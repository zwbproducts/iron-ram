; usys.S — Userland syscall wrappers (all 28 functions)
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
%define SYS_MEM_STATUS   0
%define SYS_PUTC         1
%define SYS_PUTS         2
%define SYS_GETC         3
%define SYS_GETS         4
%define SYS_MEMSET       5
%define SYS_MEMCPY       6
%define SYS_MEMMOV       7
%define SYS_MEMCMP       8
%define SYS_MEMCHR       9
%define SYS_HEAP_ALLOC   10
%define SYS_HEAP_FREE    11
%define SYS_SEC_WIPE     12
%define SYS_MEMZERO      13
%define SYS_MEMSET_REV   14
%define SYS_MEMZERO_REV  15
%define SYS_MEMSETW      16
%define SYS_MEMFILL      17
%define SYS_MEMSWAP      18
%define SYS_MEMREVERSE   19
%define SYS_MEMROTATE_L  20
%define SYS_MEMROTATE_R  21
%define SYS_MEMFIND      22
%define SYS_MEMCOUNT     23
%define SYS_MEMCHECKSUM  24
%define SYS_MEMEQ        25
%define SYS_MEMMOVE_REV  26
%define SYS_SEC_WIPE_STACK 27

; Global exports
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
GLOBAL usys_memzero
GLOBAL usys_memset_rev
GLOBAL usys_memzero_rev
GLOBAL usys_memsetw
GLOBAL usys_memfill
GLOBAL usys_memswap
GLOBAL usys_memreverse
GLOBAL usys_memrotate_l
GLOBAL usys_memrotate_r
GLOBAL usys_memfind
GLOBAL usys_memcount
GLOBAL usys_memchecksum
GLOBAL usys_memeq
GLOBAL usys_memmove_rev
GLOBAL usys_sec_wipe_stack

; ── Helper: single EAX arg syscall ──
%macro SYSCALL_0 2
%1:
    mov  eax, %2
    int  0x80
    ret
%endmacro

%macro SYSCALL_1 2
%1:
    mov  eax, %2
    mov  ebx, [esp + 4]
    int  0x80
    ret
%endmacro

%macro SYSCALL_2 2
%1:
    mov  eax, %2
    mov  ebx, [esp + 4]
    mov  ecx, [esp + 8]
    int  0x80
    ret
%endmacro

%macro SYSCALL_3 2
%1:
    mov  eax, %2
    mov  ebx, [esp + 4]
    mov  ecx, [esp + 8]
    mov  edx, [esp + 12]
    int  0x80
    ret
%endmacro

SYSCALL_0 usys_mem_status, SYS_MEM_STATUS
SYSCALL_1 usys_putc, SYS_PUTC
SYSCALL_1 usys_puts, SYS_PUTS
SYSCALL_0 usys_getc, SYS_GETC
SYSCALL_2 usys_gets, SYS_GETS
SYSCALL_3 usys_memset, SYS_MEMSET
SYSCALL_3 usys_memcpy, SYS_MEMCPY
SYSCALL_3 usys_memmov, SYS_MEMMOV
SYSCALL_3 usys_memcmp, SYS_MEMCMP
SYSCALL_3 usys_memchr, SYS_MEMCHR
SYSCALL_1 usys_heap_alloc, SYS_HEAP_ALLOC
SYSCALL_1 usys_heap_free, SYS_HEAP_FREE
SYSCALL_2 usys_sec_wipe, SYS_SEC_WIPE
SYSCALL_2 usys_memzero, SYS_MEMZERO
SYSCALL_3 usys_memset_rev, SYS_MEMSET_REV
SYSCALL_2 usys_memzero_rev, SYS_MEMZERO_REV
SYSCALL_3 usys_memsetw, SYS_MEMSETW
SYSCALL_3 usys_memfill, SYS_MEMFILL
SYSCALL_3 usys_memswap, SYS_MEMSWAP
SYSCALL_2 usys_memreverse, SYS_MEMREVERSE
SYSCALL_3 usys_memrotate_l, SYS_MEMROTATE_L
SYSCALL_3 usys_memrotate_r, SYS_MEMROTATE_R
SYSCALL_3 usys_memfind, SYS_MEMFIND
SYSCALL_3 usys_memcount, SYS_MEMCOUNT
SYSCALL_2 usys_memchecksum, SYS_MEMCHECKSUM
SYSCALL_3 usys_memeq, SYS_MEMEQ
SYSCALL_3 usys_memmove_rev, SYS_MEMMOVE_REV
SYSCALL_2 usys_sec_wipe_stack, SYS_SEC_WIPE_STACK
