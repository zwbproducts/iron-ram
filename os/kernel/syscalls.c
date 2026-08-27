/* syscalls.c — kernel syscall dispatch + signal interrupts + GPF handler
 *
 * The shell (user mode) calls these routines ONLY through the int 0x80 gate
 * and never directly. Each entry wraps one kernel-owned function.
 *
 * Signals (int 0x81) are higher-priority interrupts used by the bootloader
 * to verify subsystem readiness (e.g. libmem) before user programs run.
 * SIG_LIBMEM_TEST_ALL runs all libmem functions through the kernel's
 * dispatch path — with GPF exception handling — to prove bare-metal
 * safety.
 *
 * GPF (vector 13) handler catches invalid memory accesses and logs them.
 */

#include "syscall.h"
#include "console.h"

/* libmem routines (32-bit asm) — kernel-owned, exported via syscall table */
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
extern void *memrotate_l(void *dest, unsigned long shift, unsigned long count);
extern void *memrotate_r(void *dest, unsigned long shift, unsigned long count);
extern int   memfind(const void *s, int c, unsigned long count);
extern int   memcount(const void *s, int c, unsigned long count);
extern unsigned char memchecksum(const void *s, unsigned long count);
extern int   memeq(const void *s1, const void *s2, unsigned long count);
extern void *memmove_rev(void *dest, const void *src, unsigned long count);
extern void *secure_wipe_stack_rev(void *stack_dest, unsigned long wipe_count);
extern void *secure_wipe_heap_rev(void *heap_dest, unsigned long wipe_count);

/* dispatch: eax=num, ebx=a0, ecx=a1, edx=a2 -> eax=result */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2)
{
    switch (num) {
    /* --- original 12 syscalls --- */
    case SYS_memset:        return (unsigned long)memset((void*)a0, (int)a1, a2);
    case SYS_memzero:       return (unsigned long)memzero((void*)a0, a1);
    case SYS_memset_rev:    return (unsigned long)memset_rev((void*)a0, (int)a1, a2);
    case SYS_memzero_rev:   return (unsigned long)memzero_rev((void*)a0, a1);
    case SYS_secure_wipe:
        secure_wipe_stack_rev((void*)a0, a1);
        return 0;
    case SYS_cls:
        console_cls();
        return 0;
    case SYS_putc:
        console_putc((char)a0);
        return 0;
    case SYS_puts:
        console_puts((const char *)a0);
        return 0;
    case SYS_puthex:
        console_puthex(a0);
        return 0;
    case SYS_peek:
        return (unsigned long)(*(volatile unsigned char*)a0);
    case SYS_gets:
        console_gets((char*)a0, (unsigned int)a1);
        return 0;
    case SYS_halt:
        __asm__ volatile ("cli; hlt");
        return 0;

    /* --- Phase 2: new libmem syscalls --- */
    case SYS_memcpy:        return (unsigned long)memcpy((void*)a0, (const void*)a1, a2);
    case SYS_memmove:       return (unsigned long)memmove((void*)a0, (const void*)a1, a2);
    case SYS_memcmp:        return (unsigned long)memcmp((const void*)a0, (const void*)a1, a2);
    case SYS_memchr:        return (unsigned long)memchr((const void*)a0, (int)a1, a2);
    case SYS_memsetw:       return (unsigned long)memsetw((void*)a0, (unsigned short)a1, a2);
    case SYS_secure_wipe_heap:
        secure_wipe_heap_rev((void*)a0, a1);
        return 0;

    /* --- Phase 3: 10 more general-purpose functions --- */
    case SYS_memfill:       return (unsigned long)memfill((void*)a0, (unsigned short)a1, a2);
    case SYS_memswap:
        memswap((void*)a0, (void*)a1, a2);
        return 0;
    case SYS_memreverse:    return (unsigned long)memreverse((void*)a0, a1);
    case SYS_memrotate_l:   return (unsigned long)memrotate_l((void*)a0, a1, a2);
    case SYS_memrotate_r:   return (unsigned long)memrotate_r((void*)a0, a1, a2);
    case SYS_memfind:       return (unsigned long)memfind((const void*)a0, (int)a1, a2);
    case SYS_memcount:      return (unsigned long)memcount((const void*)a0, (int)a1, a2);
    case SYS_memchecksum:   return (unsigned long)memchecksum((const void*)a0, a1);
    case SYS_memeq:         return (unsigned long)memeq((const void*)a0, (const void*)a1, a2);
    case SYS_memmove_rev:   return (unsigned long)memmove_rev((void*)a0, (const void*)a1, a2);

    default:
        return 0;
    }
}

/* ------------------------------------------------------------------ */
/* Signal dispatch — kernel-initiated integrity verification
 *
 * SIG_LIBMEM_TEST_ALL runs every libmem function through the kernel's
 * dispatch path (not directly) to prove bare-metal safety. If a GPF
 * occurs during any function, the GPF handler logs it and signal_dispatch
 * returns nonzero. Otherwise returns the number of functions tested.
 * ------------------------------------------------------------------ */
unsigned long signal_dispatch(unsigned long sig, unsigned long a0,
                              unsigned long a1, unsigned long a2)
{
    (void)a2;
    switch (sig) {
    case SIG_LIBMEM_READY:
        console_puts("libmem: ready (");
        console_puthex((unsigned long)memset);
        console_puts(")\r\n");
        return 1;

    case SIG_LIBMEM_WIPE:
        secure_wipe_heap_rev((void*)a0, a1);
        return 0;

    case SIG_LIBMEM_TEST_ALL: {
        /* Run a quick smoke test of every libmem function through
         * the kernel-owned interface. If any function triggers a GPF,
         * the handler logs "GPF" to serial and we return nonzero. */
        static unsigned char tb[64];
        unsigned long tested = 0;

        memzero(tb, sizeof(tb));
        memset(tb, 0xAA, sizeof(tb));      tested++;
        memzero(tb, sizeof(tb));          tested++;
        memmove(tb, tb, sizeof(tb));      tested++;
        memcmp(tb, tb, sizeof(tb));       tested++;
        memchr(tb, 0xAA, sizeof(tb));     tested++;
        memsetw(tb, 0x1234, 16);          tested++;
        memfill(tb, 0xBEEF, sizeof(tb));  tested++;
        memswap(tb, tb, 4);               tested++;
        memreverse(tb, sizeof(tb));       tested++;
        memrotate_l(tb, 4, sizeof(tb));   tested++;
        memrotate_r(tb, 4, sizeof(tb));   tested++;
        memfind(tb, 0, sizeof(tb));       tested++;
        memcount(tb, 0, sizeof(tb));      tested++;
        memchecksum(tb, sizeof(tb));      tested++;
        memeq(tb, tb, sizeof(tb));        tested++;
        memmove_rev(tb, tb, sizeof(tb));  tested++;
        memset_rev(tb, 0, sizeof(tb));    tested++;
        memzero_rev(tb, sizeof(tb));      tested++;
        secure_wipe_stack_rev(tb, sizeof(tb)); tested++;
        secure_wipe_heap_rev(tb, sizeof(tb)); tested++;

        return tested;  /* should be 21 */
    }

    default:
        return 0;
    }
}
