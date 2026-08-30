/* syscalls.c — Syscall dispatcher and kernel-owned functions */
/* These functions are KERNEL-ONLY and NOT exported to userland. */

#include "syscall.h"

#define SER_PORT 0x3F8
#define HEAP_SIZE 0x10000
#define HEAP_BASE 0x300000

static char heap[HEAP_SIZE];
static unsigned long heap_used = 0;

static void ser_out(char c) {
    __asm__ volatile (
        "mov $0x3F8, %%dx\n\t"
        "out %%al, %%dx"
        :
        : "a"((unsigned char)c)
        : "dx"
    );
}

static unsigned char ser_in(void) {
    unsigned char c;
    __asm__ volatile (
        "mov $0x3F8, %%dx\n\t"
        "in %%dx, %%al"
        : "=a"(c)
        :
        : "dx"
    );
    return c;
}

static int ser_ready(void) {
    unsigned char status;
    __asm__ volatile (
        "mov $0x3FD, %%dx\n\t"
        "in %%dx, %%al"
        : "=a"(status)
        :
        : "dx"
    );
    return status & 0x01;
}

/* Kernel-owned function implementations */
static unsigned long kern_mem_status(void) {
    return 0xDEADBEEF;
}

static int kern_putc(char c) {
    ser_out(c);
    return 0;
}

static int kern_puts(const char *s) {
    while (*s) {
        ser_out(*s++);
    }
    return 0;
}

static int kern_getc(void) {
    while (!ser_ready()) {
        __asm__ volatile ("hlt");
    }
    return (int)ser_in();
}

static int kern_gets(char *buf, int maxlen) {
    int i = 0;
    while (i < maxlen - 1) {
        int c = kern_getc();
        if (c == '\r' || c == '\n') {
            buf[i] = '\0';
            return i;
        }
        if (c == 127 || c == 8) {
            if (i > 0) {
                i--;
                ser_out('\b');
                ser_out(' ');
                ser_out('\b');
            }
            continue;
        }
        buf[i++] = (char)c;
        ser_out((char)c);
    }
    buf[i] = '\0';
    return i;
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

static void *kern_memmov(void *dest, const void *src, unsigned long count) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    if (d < s) {
        for (unsigned long i = 0; i < count; i++) d[i] = s[i];
    } else {
        for (unsigned long i = count; i > 0; i--) d[i-1] = s[i-1];
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

static void *kern_memchr(const void *ptr, int value, unsigned long count) {
    const unsigned char *p = (const unsigned char *)ptr;
    for (unsigned long i = 0; i < count; i++) {
        if (p[i] == (unsigned char)value) return (void *)(p + i);
    }
    return 0;
}

static void *kern_heap_alloc(unsigned long size) {
    size = (size + 15) & ~15UL;
    if (heap_used + size > HEAP_SIZE) return 0;
    void *ptr = heap + heap_used;
    heap_used += size;
    return ptr;
}

static int kern_heap_free(void *ptr) {
    (void)ptr;
    return 0;
}

static int kern_sec_wipe(void *ptr, unsigned long count) {
    volatile unsigned char *p = (volatile unsigned char *)ptr;
    for (unsigned long i = 0; i < count; i++) {
        p[i] = 0xFF;
        p[i] = 0x00;
        p[i] = 0x00;
    }
    __asm__ volatile ("mfence" ::: "memory");
    return 0;
}

/* Syscall jump table — kernel-owned, not exported */
static syscall_fn_t syscall_table[] = {
    (syscall_fn_t)kern_mem_status,  /* 0 */
    (syscall_fn_t)kern_putc,        /* 1 */
    (syscall_fn_t)kern_puts,        /* 2 */
    (syscall_fn_t)kern_getc,        /* 3 */
    (syscall_fn_t)kern_gets,        /* 4 */
    (syscall_fn_t)kern_memset,      /* 5 */
    (syscall_fn_t)kern_memcpy,      /* 6 */
    (syscall_fn_t)kern_memmov,      /* 7 */
    (syscall_fn_t)kern_memcmp,      /* 8 */
    (syscall_fn_t)kern_memchr,      /* 9 */
    (syscall_fn_t)kern_heap_alloc,  /* 10 */
    (syscall_fn_t)kern_heap_free,   /* 11 */
    (syscall_fn_t)kern_sec_wipe,    /* 12 */
};

#define MAX_SYSCALLS (sizeof(syscall_table) / sizeof(syscall_table[0]))

/* Syscall dispatcher — called from isr80_handler */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2) {
    if (num >= MAX_SYSCALLS || !syscall_table[num]) {
        return (unsigned long)-1;
    }
    return syscall_table[num](a0, a1, a2);
}
