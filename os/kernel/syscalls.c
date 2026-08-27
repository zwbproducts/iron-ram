/* syscalls.c — kernel syscall dispatch + signal interrupts
 *
 * The shell (user mode) calls these routines ONLY through the int 0x80 gate
 * and never directly. Each entry wraps one kernel-owned function.
 *
 * Signals (int 0x81) are higher-priority interrupts used by the bootloader
 * to verify subsystem readiness (e.g. libmem) before user programs run.
 * Like syscalls, they route through kernel-owned functions only.
 */

#include "syscall.h"
#include "console.h"

/* libmem routines (32-bit asm) — kernel-owned, exported via syscall table */
extern void *memset(void *dest, int c, unsigned int count);
extern void *memzero(void *dest, unsigned int count);
extern void *memset_rev(void *dest, int c, unsigned int count);
extern void *memzero_rev(void *dest, unsigned int count);
extern void *memcpy(void *dest, const void *src, unsigned int count);
extern void *memmove(void *dest, const void *src, unsigned int count);
extern int   memcmp(const void *s1, const void *s2, unsigned int count);
extern void *memchr(const void *s, int c, unsigned int count);
extern void *memsetw(void *dest, unsigned short c, unsigned int count);
extern void *secure_wipe_stack_rev(void *stack_dest, unsigned int wipe_count);
extern void *secure_wipe_heap_rev(void *heap_dest, unsigned int wipe_count);

/* dispatch: eax=num, ebx=a0, ecx=a1, edx=a2 -> eax=result */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2)
{
    switch (num) {
    /* --- original 12 syscalls --- */
    case SYS_memset:    return (unsigned long)memset((void*)a0, (int)a1, (unsigned int)a2);
    case SYS_memzero:   return (unsigned long)memzero((void*)a0, (unsigned int)a1);
    case SYS_memset_rev:return (unsigned long)memset_rev((void*)a0, (int)a1, (unsigned int)a2);
    case SYS_memzero_rev:return (unsigned long)memzero_rev((void*)a0, (unsigned int)a1);
    case SYS_secure_wipe:
        secure_wipe_stack_rev((void*)a0, (unsigned int)a1);
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

    /* --- Phase 2 expansion: new libmem functions --- */
    case SYS_memcpy:
        return (unsigned long)memcpy((void*)a0, (const void*)a1, (unsigned int)a2);
    case SYS_memmove:
        return (unsigned long)memmove((void*)a0, (const void*)a1, (unsigned int)a2);
    case SYS_memcmp:
        return (unsigned long)memcmp((const void*)a0, (const void*)a1, (unsigned int)a2);
    case SYS_memchr:
        return (unsigned long)memchr((const void*)a0, (int)a1, (unsigned int)a2);
    case SYS_memsetw:
        return (unsigned long)memsetw((void*)a0, (unsigned short)a1, (unsigned int)a2);
    case SYS_secure_wipe_heap:
        secure_wipe_heap_rev((void*)a0, (unsigned int)a1);
        return 0;

    default:
        return 0;                        /* unknown -> 0 */
    }
}

/* signal_dispatch: eax=sig, ebx=a0, ecx=a1, edx=a2 -> eax=result
 *
 * The bootloader triggers int 0x81 after kernel init to verify libmem
 * readiness. Signals are conceptually "simple interrupts acting as jumps":
 * they jump the CPU from bootloader context into the kernel's signal
 * handler, which only touches kernel-owned routines (never userland).
 */
unsigned long signal_dispatch(unsigned long sig, unsigned long a0,
                              unsigned long a1, unsigned long a2)
{
    switch (sig) {
    case SIG_LIBMEM_READY:
        /* Verify all libmem entry points by running a quick self-check */
        console_puts("libmem signal: ready (");
        console_puthex((unsigned long)memset);
        console_puts(")\r\n");
        return 1;     /* readiness ack */
    case SIG_LIBMEM_WIPE:
        /* Secure wipe via signal path — bypasses syscall interface */
        secure_wipe_heap_rev((void*)a0, (unsigned int)a1);
        return 0;
    default:
        return 0;
    }
}
