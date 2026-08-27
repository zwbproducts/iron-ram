/* kmain.c — kernel entry in C */
#include "syscall.h"
#include "console.h"

extern void *memset(void *dest, int c, unsigned long count);

void shell_main(void);

/* Trigger libmem readiness + full test signal via int 0x81.
 * The bootloader/kernel "signal path" jumps the CPU through the
 * interrupt gate into signal_dispatch(), which runs all libmem
 * functions through the kernel-owned interface. If a GPF occurs
 * during testing, the handler logs it to serial and continues.
 */
static void libmem_signals(void) {
    unsigned long ready, tested;

    __asm__ volatile (
        "movl %1, %%eax\n\t"
        "xorl %%ebx, %%ebx\n\t"
        "xorl %%ecx, %%ecx\n\t"
        "xorl %%edx, %%edx\n\t"
        "int $0x81\n\t"
        "movl %%eax, %0"
        : "=m" (ready)
        : "i" (SIG_LIBMEM_READY)
    );
    console_puts("libmem ready: ");
    console_puthex(ready);
    console_puts("\r\n");

    __asm__ volatile (
        "movl %1, %%eax\n\t"
        "xorl %%ebx, %%ebx\n\t"
        "xorl %%ecx, %%ecx\n\t"
        "xorl %%edx, %%edx\n\t"
        "int $0x81\n\t"
        "movl %%eax, %0"
        : "=m" (tested)
        : "i" (SIG_LIBMEM_TEST_ALL)
    );
    console_puts("libmem tested: ");
    console_puthex(tested);
    console_puts(" functions\r\n");
}

void kmain(void) {
    console_init();
    console_cls();
    console_puts("K 32-bit kernel booted\r\n");

    /* Signal: verify libmem subsystem via interrupt path */
    libmem_signals();

    shell_main();
    /* if shell returns, halt */
    for (;;) __asm__ volatile ("cli; hlt");
}
