/* syscalls.c — Syscall dispatcher and kernel-owned functions */
/* These functions are KERNEL-ONLY and NOT exported to userland. */

#include "syscall.h"

/* libmem function declarations (linked into kernel from libmem/) */
extern void *memset(void *dest, int c, unsigned long count);
extern void *memzero(void *dest, unsigned long count);
extern void *memset_rev(void *dest, int c, unsigned long count);
extern void *memzero_rev(void *dest, unsigned long count);
extern void *memcpy(void *dest, const void *src, unsigned long count);
extern void *memmove(void *dest, const void *src, unsigned long count);
extern int   memcmp(const void *s1, const void *s2, unsigned long count);
extern void *memchr(const void *s, int c, unsigned long count);
extern void *memsetw(void *dest, unsigned short c, unsigned long count);
extern void *memfill(void *dest, unsigned short pattern, unsigned long count);
extern void  memswap(void *a, void *b, unsigned long count);
extern void *memreverse(void *dest, unsigned long count);
extern void *memrotate_l(void *dest, unsigned int shift, unsigned long count);
extern void *memrotate_r(void *dest, unsigned int shift, unsigned long count);
extern int   memfind(const void *s, int c, unsigned long count);
extern int   memcount(const void *s, int c, unsigned long count);
extern unsigned char memchecksum(const void *s, unsigned long count);
extern int   memeq(const void *s1, const void *s2, unsigned long count);
extern void *memmove_rev(void *dest, const void *src, unsigned long count);
extern void *secure_wipe_stack_rev(void *stack_dest, unsigned long wipe_count);
extern void *secure_wipe_heap_rev(void *heap_dest, unsigned long wipe_count);

#define SER_PORT 0x3F8
#define HEAP_SIZE 0x10000

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

/* ─── 0: mem_status ─── */
static unsigned long kern_mem_status(unsigned long a0, unsigned long a1, unsigned long a2) {
    (void)a0; (void)a1; (void)a2;
    return 0xDEADBEEF;
}

/* ─── 1: putc ─── */
static unsigned long kern_putc(unsigned long c, unsigned long a1, unsigned long a2) {
    (void)a1; (void)a2;
    ser_out((char)c);
    return 0;
}

/* ─── 2: puts ─── */
static unsigned long kern_puts(unsigned long s, unsigned long a1, unsigned long a2) {
    (void)a1; (void)a2;
    const char *p = (const char *)s;
    while (*p) ser_out(*p++);
    return 0;
}

/* ─── 3: getc ─── */
static unsigned long kern_getc(unsigned long a0, unsigned long a1, unsigned long a2) {
    (void)a0; (void)a1; (void)a2;
    while (!ser_ready()) { __asm__ volatile ("hlt"); }
    return (unsigned long)ser_in();
}

/* ─── 4: gets ─── */
static unsigned long kern_gets(unsigned long buf, unsigned long maxlen, unsigned long a2) {
    (void)a2;
    char *b = (char *)buf;
    unsigned long i = 0;
    while (i < maxlen - 1) {
        unsigned long c = kern_getc(0, 0, 0);
        if (c == '\r' || c == '\n') { b[i] = '\0'; return i; }
        if (c == 127 || c == 8) {
            if (i > 0) { i--; ser_out('\b'); ser_out(' '); ser_out('\b'); }
            continue;
        }
        b[i++] = (char)c;
        ser_out((char)c);
    }
    b[i] = '\0';
    return i;
}

/* ─── 5: memset ─── */
static unsigned long kern_memset(unsigned long dest, unsigned long c, unsigned long count) {
    return (unsigned long)memset((void *)dest, (int)c, count);
}

/* ─── 6: memcpy ─── */
static unsigned long kern_memcpy(unsigned long dest, unsigned long src, unsigned long count) {
    return (unsigned long)memcpy((void *)dest, (const void *)src, count);
}

/* ─── 7: memmov ─── */
static unsigned long kern_memmov(unsigned long dest, unsigned long src, unsigned long count) {
    return (unsigned long)memmove((void *)dest, (const void *)src, count);
}

/* ─── 8: memcmp ─── */
static unsigned long kern_memcmp(unsigned long a, unsigned long b, unsigned long count) {
    return (unsigned long)memcmp((const void *)a, (const void *)b, count);
}

/* ─── 9: memchr ─── */
static unsigned long kern_memchr(unsigned long ptr, unsigned long c, unsigned long count) {
    return (unsigned long)memchr((const void *)ptr, (int)c, count);
}

/* ─── 10: heap_alloc ─── */
static unsigned long kern_heap_alloc(unsigned long size, unsigned long a1, unsigned long a2) {
    (void)a1; (void)a2;
    size = (size + 15) & ~15UL;
    if (heap_used + size > HEAP_SIZE) return 0;
    void *ptr = heap + heap_used;
    heap_used += size;
    return (unsigned long)ptr;
}

/* ─── 11: heap_free ─── */
static unsigned long kern_heap_free(unsigned long ptr, unsigned long a1, unsigned long a2) {
    (void)ptr; (void)a1; (void)a2;
    return 0;
}

/* ─── 12: sec_wipe ─── */
static unsigned long kern_sec_wipe(unsigned long ptr, unsigned long count, unsigned long a2) {
    (void)a2;
    volatile unsigned char *p = (volatile unsigned char *)ptr;
    for (unsigned long i = 0; i < count; i++) {
        p[i] = 0xFF; p[i] = 0x00; p[i] = 0x00;
    }
    __asm__ volatile ("mfence" ::: "memory");
    return 0;
}

/* ─── 13: memzero ─── */
static unsigned long kern_memzero(unsigned long dest, unsigned long count, unsigned long a2) {
    (void)a2;
    return (unsigned long)memzero((void *)dest, count);
}

/* ─── 14: memset_rev ─── */
static unsigned long kern_memset_rev(unsigned long dest, unsigned long c, unsigned long count) {
    return (unsigned long)memset_rev((void *)dest, (int)c, count);
}

/* ─── 15: memzero_rev ─── */
static unsigned long kern_memzero_rev(unsigned long dest, unsigned long count, unsigned long a2) {
    (void)a2;
    return (unsigned long)memzero_rev((void *)dest, count);
}

/* ─── 16: memsetw ─── */
static unsigned long kern_memsetw(unsigned long dest, unsigned long c, unsigned long count) {
    return (unsigned long)memsetw((void *)dest, (unsigned short)c, count);
}

/* ─── 17: memfill ─── */
static unsigned long kern_memfill(unsigned long dest, unsigned long pattern, unsigned long count) {
    return (unsigned long)memfill((void *)dest, (unsigned short)pattern, count);
}

/* ─── 18: memswap ─── */
static unsigned long kern_memswap(unsigned long a, unsigned long b, unsigned long count) {
    memswap((void *)a, (void *)b, count);
    return 0;
}

/* ─── 19: memreverse ─── */
static unsigned long kern_memreverse(unsigned long dest, unsigned long count, unsigned long a2) {
    (void)a2;
    return (unsigned long)memreverse((void *)dest, count);
}

/* ─── 20: memrotate_l ─── */
static unsigned long kern_memrotate_l(unsigned long dest, unsigned long shift, unsigned long count) {
    return (unsigned long)memrotate_l((void *)dest, (unsigned int)shift, count);
}

/* ─── 21: memrotate_r ─── */
static unsigned long kern_memrotate_r(unsigned long dest, unsigned long shift, unsigned long count) {
    return (unsigned long)memrotate_r((void *)dest, (unsigned int)shift, count);
}

/* ─── 22: memfind ─── */
static unsigned long kern_memfind(unsigned long ptr, unsigned long c, unsigned long count) {
    return (unsigned long)memfind((const void *)ptr, (int)c, count);
}

/* ─── 23: memcount ─── */
static unsigned long kern_memcount(unsigned long ptr, unsigned long c, unsigned long count) {
    return (unsigned long)memcount((const void *)ptr, (int)c, count);
}

/* ─── 24: memchecksum ─── */
static unsigned long kern_memchecksum(unsigned long ptr, unsigned long count, unsigned long a2) {
    (void)a2;
    return (unsigned long)memchecksum((const void *)ptr, count);
}

/* ─── 25: memeq ─── */
static unsigned long kern_memeq(unsigned long a, unsigned long b, unsigned long count) {
    return (unsigned long)memeq((const void *)a, (const void *)b, count);
}

/* ─── 26: memmove_rev ─── */
static unsigned long kern_memmove_rev(unsigned long dest, unsigned long src, unsigned long count) {
    return (unsigned long)memmove_rev((void *)dest, (const void *)src, count);
}

/* ─── 27: sec_wipe_stack ─── */
static unsigned long kern_sec_wipe_stack(unsigned long ptr, unsigned long count, unsigned long a2) {
    (void)a2;
    return (unsigned long)secure_wipe_stack_rev((void *)ptr, count);
}

/* Syscall jump table — kernel-owned, not exported */
static syscall_fn_t syscall_table[SYS_MAX] = {
    kern_mem_status,
    kern_putc,
    kern_puts,
    kern_getc,
    kern_gets,
    kern_memset,
    kern_memcpy,
    kern_memmov,
    kern_memcmp,
    kern_memchr,
    kern_heap_alloc,
    kern_heap_free,
    kern_sec_wipe,
    kern_memzero,
    kern_memset_rev,
    kern_memzero_rev,
    kern_memsetw,
    kern_memfill,
    kern_memswap,
    kern_memreverse,
    kern_memrotate_l,
    kern_memrotate_r,
    kern_memfind,
    kern_memcount,
    kern_memchecksum,
    kern_memeq,
    kern_memmove_rev,
    kern_sec_wipe_stack,
};

/* Syscall dispatcher — called from isr80_handler */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2) {
    if (num >= SYS_MAX || !syscall_table[num]) {
        return (unsigned long)-1;
    }
    return syscall_table[num](a0, a1, a2);
}
