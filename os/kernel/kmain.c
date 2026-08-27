/* kmain.c — kernel entry in C */
#include "syscall.h"
#include "console.h"

extern void *memset(void *dest, int c, unsigned int count);

void shell_main(void);

/* Trigger libmem readiness signal via int 0x81.
 * This is the bootloader/kernel "signal path": a simple interrupt
 * that jumps the CPU from init context into the kernel's signal
 * handler, which only touches kernel-owned routines (never userland).
 * The kernel responds only through kernel-owned functions.
 */
static void libmem_signal(void) {
    __asm__ volatile (
        "movl %0, %%eax\n\t"
        "xorl %%ebx, %%ebx\n\t"
        "xorl %%ecx, %%ecx\n\t"
        "xorl %%edx, %%edx\n\t"
        "int $0x81"
        :
        : "i" (SIG_LIBMEM_READY)
    );
}

void kmain(void) {
    console_init();
    console_cls();
    console_puts("K 32-bit kernel booted\r\n");

    /* Signal: verify libmem subsystem is reachable via interrupt */
    libmem_signal();

    shell_main();
    /* if shell returns, halt */
    for (;;) __asm__ volatile ("cli; hlt");
}
