/* syscall.h — Kernel syscall numbers and types */
/* This header is KERNEL-ONLY and must NOT be included in userland code. */

#ifndef SYSCALL_H
#define SYSCALL_H

typedef unsigned long (*syscall_fn_t)(unsigned long, unsigned long, unsigned long);

/* Syscall numbers — must match usys.S */
#define SYS_MEM_STATUS  0
#define SYS_PUTC        1
#define SYS_PUTS        2
#define SYS_GETC        3
#define SYS_GETS        4
#define SYS_MEMSET      5
#define SYS_MEMCPY      6
#define SYS_MEMMOV      7
#define SYS_MEMCMP      8
#define SYS_MEMCHR      9
#define SYS_HEAP_ALLOC  10
#define SYS_HEAP_FREE   11
#define SYS_SEC_WIPE    12

/* Syscall dispatcher */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2);

#endif /* SYSCALL_H */
