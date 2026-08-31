/* kmain.c — Kernel main */
/* Uses inline assembly for critical path to avoid C calling issues */

#include "console.h"
#include "syscall.h"

void kmain(void) {
    /* Heartbeat: M = kmain entered */
    __asm__ volatile ("movb $'M', %%al; outb %%al, $0xe9" ::: "eax");

    /* Initialize console */
    console_init();

    /* Heartbeat: I = console_init done */
    __asm__ volatile ("movb $'I', %%al; outb %%al, $0xe9" ::: "eax");

    /* Clear screen */
    console_cls();

    /* Heartbeat: C = console_cls done */
    __asm__ volatile ("movb $'C', %%al; outb %%al, $0xe9" ::: "eax");

    /* Print boot message */
    console_puts("\r\niron-ram kernel booted.\r\n");

    /* Heartbeat: P = console_puts done */
    __asm__ volatile ("movb $'P', %%al; outb %%al, $0xe9" ::: "eax");

    /* Print prompt */
    console_puts("> ");

    /* Halt for now */
    for (;;) {
        __asm__ volatile ("cli; hlt");
    }
}
