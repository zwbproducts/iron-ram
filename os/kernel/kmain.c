/* kmain.c — kernel entry in C */
#include "syscall.h"
#include "console.h"

extern void *memset(void *dest, int c, unsigned int count);

void shell_main(void);

void kmain(void) {
    console_init();
    console_cls();
    console_puts("K 32-bit kernel booted\r\n");
    shell_main();
    /* if shell returns, halt */
    for (;;) __asm__ volatile ("cli; hlt");
}
