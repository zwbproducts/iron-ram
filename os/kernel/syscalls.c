/* syscalls.c — kernel syscall dispatch table
 *
 * The shell (user mode) calls these routines ONLY through the int 0x80 gate
 * and never directly. Each entry wraps one kernel-owned function.
 */

#include "syscall.h"
#include "console.h"

/* libmem routines (32-bit asm) — kernel-owned, exported via syscall table */
extern void *memset(void *dest, int c, unsigned int count);
extern void *memzero(void *dest, unsigned int count);
extern void *memset_rev(void *dest, int c, unsigned int count);
extern void *memzero_rev(void *dest, unsigned int count);
extern void *secure_wipe_stack_rev(void *stack_dest, unsigned int wipe_count);

/* local helper for peek */
static void outb_local(unsigned short port, unsigned char val) {
    __asm__ volatile ("outb %0, %1" :: "a"(val), "Nd"(port));
}

/* dispatch: eax=num, ebx=a0, ecx=a1, edx=a2 -> eax=result */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2)
{
    (void)a2;
    switch (num) {
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
    case SYS_peek:                       /* peek a byte at a0 */
        return (unsigned long)(*(volatile unsigned char*)a0);
    case SYS_gets:
        console_gets((char*)a0, (unsigned int)a1);
        return 0;
    case SYS_halt:
        __asm__ volatile ("cli; hlt");
        return 0;
    default:
        return 0;                        /* unknown -> 0 */
    }
}
