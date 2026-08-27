; usys.S — int 0x80 syscall wrappers for the C shell (NASM syntax)
; ABI: eax=num, ebx=arg0, ecx=arg1, edx=arg2 ; result in eax
; Caller leaves args in ebx/ecx/edx already (cdecl-ish register args).

global syscall
global usys_memset, usys_memzero, usys_memset_rev, usys_memzero_rev
global usys_secure_wipe, usys_cls, usys_putc, usys_puts, usys_puthex
global usys_memcpy, usys_memmove, usys_memcmp, usys_memchr, usys_memsetw
global usys_memfill, usys_memswap, usys_memreverse, usys_memrotate_l
global usys_memrotate_r, usys_memfind, usys_memcount, usys_memchecksum
global usys_memeq, usys_memmove_rev, usys_secure_wipe_heap
global usys_peek, usys_gets, usys_halt

syscall:
    int 0x80
    ret

; --- original 12 syscalls ---
usys_memset:
    mov eax, 1
    int 0x80
    ret

usys_memzero:
    mov eax, 2
    int 0x80
    ret

usys_memset_rev:
    mov eax, 3
    int 0x80
    ret

usys_memzero_rev:
    mov eax, 4
    int 0x80
    ret

usys_secure_wipe:
    mov eax, 5
    int 0x80
    ret

usys_cls:
    mov eax, 6
    int 0x80
    ret

usys_putc:
    mov eax, 7
    int 0x80
    ret

usys_puts:
    mov eax, 8
    int 0x80
    ret

usys_puthex:
    mov eax, 9
    int 0x80
    ret

usys_peek:
    mov eax, 10
    int 0x80
    ret

usys_gets:
    mov eax, 11
    int 0x80
    ret

usys_halt:
    mov eax, 12
    int 0x80
    ret

; --- Phase 2: new libmem syscalls (13-18) ---
usys_memcpy:
    mov eax, 13
    int 0x80
    ret

usys_memmove:
    mov eax, 14
    int 0x80
    ret

usys_memcmp:
    mov eax, 15
    int 0x80
    ret

usys_memchr:
    mov eax, 16
    int 0x80
    ret

usys_memsetw:
    mov eax, 17
    int 0x80
    ret

usys_secure_wipe_heap:
    mov eax, 18
    int 0x80
    ret

; --- Phase 3: 10 more functions (19-28) ---
usys_memfill:
    mov eax, 19
    int 0x80
    ret

usys_memswap:
    mov eax, 20
    int 0x80
    ret

usys_memreverse:
    mov eax, 21
    int 0x80
    ret

usys_memrotate_l:
    mov eax, 22
    int 0x80
    ret

usys_memrotate_r:
    mov eax, 23
    int 0x80
    ret

usys_memfind:
    mov eax, 24
    int 0x80
    ret

usys_memcount:
    mov eax, 25
    int 0x80
    ret

usys_memchecksum:
    mov eax, 26
    int 0x80
    ret

usys_memeq:
    mov eax, 27
    int 0x80
    ret

usys_memmove_rev:
    mov eax, 28
    int 0x80
    ret
