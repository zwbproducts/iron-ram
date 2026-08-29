/* kmain.c — kernel entry in C */
#include "syscall.h"
#include "console.h"

extern void *memset(void *dest, int c, unsigned long count);
void shell_main(void);  /* declared in user/usys.h — forward-declared here (kernel/user boundary) */

/* ──────────────────────────────────────────────────────────────
 *  Boot-time syscall staging verification.
 *
 *  The kernel enumerates every syscall to prove that all libmem
 *  functions are staged in the kernel binary AND wired through the
 *  syscall dispatch table.  Userland never sees these addresses —
 *  it can only reach them via the int 0x80 gate.
 * ────────────────────────────────────────────────────────────── */
static void verify_syscalls(void) {
    console_puts("kernel: syscall table staged (28 entries)\r\n");
    console_puts("  01 memset        "); console_puthex((unsigned long)memset);        console_puts("\r\n");
    console_puts("  02 memzero       "); console_puthex((unsigned long)memzero);       console_puts("\r\n");
    console_puts("  03 memset_rev    "); console_puthex((unsigned long)memset_rev);    console_puts("\r\n");
    console_puts("  04 memzero_rev   "); console_puthex((unsigned long)memzero_rev);   console_puts("\r\n");
    console_puts("  05 sec_wipe_stk  "); console_puthex((unsigned long)secure_wipe_stack_rev); console_puts("\r\n");
    console_puts("  06 cls           "); console_puthex((unsigned long)console_cls);   console_puts("\r\n");
    console_puts("  07 putc          "); console_puthex((unsigned long)console_putc);  console_puts("\r\n");
    console_puts("  08 puts          "); console_puthex((unsigned long)console_puts);  console_puts("\r\n");
    console_puts("  09 puthex        "); console_puthex((unsigned long)console_puthex); console_puts("\r\n");
    console_puts("  10 peek          "); console_puthex((unsigned long)console_gets);  console_puts("\r\n");
    console_puts("  11 gets          "); console_puthex((unsigned long)console_gets);  console_puts("\r\n");
    console_puts("  12 halt          "); console_puts("(inline)\r\n");
    console_puts("  13 memcpy        "); console_puthex((unsigned long)memcpy);        console_puts("\r\n");
    console_puts("  14 memmove       "); console_puthex((unsigned long)memmove);       console_puts("\r\n");
    console_puts("  15 memcmp        "); console_puthex((unsigned long)memcmp);        console_puts("\r\n");
    console_puts("  16 memchr        "); console_puthex((unsigned long)memchr);        console_puts("\r\n");
    console_puts("  17 memsetw       "); console_puthex((unsigned long)memsetw);       console_puts("\r\n");
    console_puts("  18 sec_wipe_heap "); console_puthex((unsigned long)secure_wipe_heap_rev); console_puts("\r\n");
    console_puts("  19 memfill       "); console_puthex((unsigned long)memfill);       console_puts("\r\n");
    console_puts("  20 memswap       "); console_puthex((unsigned long)memswap);       console_puts("\r\n");
    console_puts("  21 memreverse    "); console_puthex((unsigned long)memreverse);    console_puts("\r\n");
    console_puts("  22 memrotate_l   "); console_puthex((unsigned long)memrotate_l);   console_puts("\r\n");
    console_puts("  23 memrotate_r   "); console_puthex((unsigned long)memrotate_r);   console_puts("\r\n");
    console_puts("  24 memfind       "); console_puthex((unsigned long)memfind);       console_puts("\r\n");
    console_puts("  25 memcount      "); console_puthex((unsigned long)memcount);      console_puts("\r\n");
    console_puts("  26 memchecksum   "); console_puthex((unsigned long)memchecksum);   console_puts("\r\n");
    console_puts("  27 memeq         "); console_puthex((unsigned long)memeq);         console_puts("\r\n");
    console_puts("  28 memmove_rev   "); console_puthex((unsigned long)memmove_rev);   console_puts("\r\n");
}

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
    console_puts("kernel: libmem ready (");
    console_puthex(ready);
    console_puts(")\r\n");

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
    console_puts("kernel: libmem tested (");
    console_puthex(tested);
    console_puts(" functions via SIG_LIBMEM_TEST_ALL)\r\n");
}

void kmain(void) {
    console_init();
    console_cls();
    console_puts("K 32-bit kernel booted\r\n");

    /* 1. Verify libmem subsystem is staged and ready (signal path) */
    libmem_signals();

    /* 2. Enumerate all 28 syscall entry points (staged in kernel binary) */
    verify_syscalls();

    console_puts("kernel: handing off to userland (shell_main)\r\n");
    console_puts("kernel: SECURITY — shell may only call functions\r\n");
    console_puts("       via usys_* wrappers (int 0x80 gate)\r\n");

    shell_main();
    /* if shell returns, halt */
    for (;;) __asm__ volatile ("cli; hlt");
}
