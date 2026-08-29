/* syscalls.c — Syscall dispatcher and kernel-owned functions */
/* These functions are KERNEL-ONLY and NOT exported to userland. */

#include "syscall.h"

/* Kernel-owned function implementations */
static unsigned long kern_mem_status(void) {
    return 0xDEADBEEF;  /* Magic number proving syscall worked */
}

static int kern_putc(char c) {
    __asm__ volatile (
        "mov $0x3F8, %%dx\n\t"
        "out %%al, %%dx"
        :
        : "a"((unsigned char)c)
        : "dx"
    );
    return 0;
}

static int kern_puts(const char *s) {
    while (*s) {
        kern_putc(*s++);
    }
    return 0;
}

static void *kern_memset(void *dest, int c, unsigned long count) {
    unsigned char *d = (unsigned char *)dest;
    for (unsigned long i = 0; i < count; i++) {
        d[i] = (unsigned char)c;
    }
    return dest;
}

static void *kern_memcpy(void *dest, const void *src, unsigned long count) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    for (unsigned long i = 0; i < count; i++) {
        d[i] = s[i];
    }
    return dest;
}

static int kern_memcmp(const void *a, const void *b, unsigned long count) {
    const unsigned char *pa = (const unsigned char *)a;
    const unsigned char *pb = (const unsigned char *)b;
    for (unsigned long i = 0; i < count; i++) {
        if (pa[i] != pb[i]) return pa[i] - pb[i];
    }
    return 0;
}

/* Syscall jump table — kernel-owned, not exported */
static syscall_fn_t syscall_table[] = {
    (syscall_fn_t)kern_mem_status,  /* 0 */
    (syscall_fn_t)kern_putc,        /* 1 */
    (syscall_fn_t)kern_puts,        /* 2 */
    0,                              /* 3: getc (not implemented) */
    0,                              /* 4: gets (not implemented) */
    (syscall_fn_t)kern_memset,      /* 5 */
    (syscall_fn_t)kern_memcpy,      /* 6 */
    (syscall_fn_t)kern_memcpy,      /* 7: memmov = memcpy for now */
    (syscall_fn_t)kern_memcmp,      /* 8 */
    0,                              /* 9: memchr (not implemented) */
    0,                              /* 10: heap_alloc (not implemented) */
    0,                              /* 11: heap_free (not implemented) */
    0,                              /* 12: sec_wipe (not implemented) */
};

#define MAX_SYSCALLS (sizeof(syscall_table) / sizeof(syscall_table[0]))

/* Syscall dispatcher — called from isr80_handler */
/* Args pushed on stack: syscall_number, arg0, arg1, arg2 */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2) {
    if (num >= MAX_SYSCALLS || !syscall_table[num]) {
        return (unsigned long)-1;  /* Invalid syscall */
    }
    return syscall_table[num](a0, a1, a2);
}
