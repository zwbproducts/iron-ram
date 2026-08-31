/* console.c — VGA text + COM1 serial driver */
/* Kernel-owned: these functions are NOT exported to userland. */

#include "console.h"

#define VGA_BASE 0xB8000u
#define COLUMNS 80
#define ROWS    25
#define ATTR    0x0F

static unsigned int col = 0;
static unsigned int row = 0;

void console_init(void) {
    /* COM1 is already initialized by QEMU */
}

void console_cls(void) {
    volatile unsigned short *vmem = (volatile unsigned short *)VGA_BASE;
    for (unsigned int i = 0; i < COLUMNS * ROWS; i++) {
        vmem[i] = (' ' | (ATTR << 8));
    }
    col = 0;
    row = 0;
}

void console_putc(char c) {
    /* Output to serial */
    __asm__ volatile (
        "mov $0xe9, %%dx\n\t"
        "out %%al, %%dx"
        :: "a"((unsigned char)c)
        : "dx"
    );

    /* Output to VGA */
    if (c == '\n') {
        col = 0;
        row++;
    } else {
        volatile unsigned short *vmem = (volatile unsigned short *)VGA_BASE;
        unsigned int idx = row * COLUMNS + col;
        if (idx < COLUMNS * ROWS) {
            vmem[idx] = ((unsigned short)c) | (ATTR << 8);
        }
        col++;
        if (col >= COLUMNS) { col = 0; row++; }
    }

    /* Scroll if needed */
    if (row >= ROWS) {
        volatile unsigned short *vmem = (volatile unsigned short *)VGA_BASE;
        for (unsigned int y = 1; y < ROWS; y++) {
            for (unsigned int x = 0; x < COLUMNS; x++) {
                vmem[(y-1)*COLUMNS+x] = vmem[y*COLUMNS+x];
            }
        }
        for (unsigned int x = 0; x < COLUMNS; x++) {
            vmem[(ROWS-1)*COLUMNS+x] = (' ' | (ATTR<<8));
        }
        row = ROWS - 1;
    }
}

void console_puts(const char *s) {
    while (*s) console_putc(*s++);
}
