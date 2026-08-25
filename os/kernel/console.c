/* console.c — VGA 0xB8000 driver + PS/2 polled keyboard, teed to COM1 (0x3F8) */

#include "console.h"
#include "syscall.h"   /* memset declaration (libmem) */

#define VGA_BASE 0xB8000u
#define COLUMNS 80
#define ROWS    25
#define VIDEO_MEM  ((volatile unsigned short *)VGA_BASE)
#define COM1 0x3F8u
#define ATTR 0x0Fu

static unsigned int col = 0;
static unsigned int row = 0;

static void outb(unsigned short port, unsigned char val) {
    __asm__ volatile ("outb %0, %1" :: "a"(val), "Nd"(port));
}
static unsigned char inb(unsigned short port) {
    unsigned char r;
    __asm__ volatile ("inb %1, %0" : "=a"(r) : "Nd"(port));
    return r;
}

static void scroll_if_needed(void) {
    if (row >= ROWS) {
        for (unsigned int y = 1; y < ROWS; y++)
            for (unsigned int x = 0; x < COLUMNS; x++)
                VIDEO_MEM[(y-1)*COLUMNS+x] = VIDEO_MEM[y*COLUMNS+x];
        for (unsigned int x = 0; x < COLUMNS; x++)
            VIDEO_MEM[(ROWS-1)*COLUMNS+x] = (' ' | (ATTR<<8));
        row = ROWS - 1;
    }
}

void console_init(void) {
    /* nothing; COM1 is served by QEMU -serial */
}

void console_cls(void) {
    /* clear VGA using kernel-owned libmem memset */
    memset((void*)VGA_BASE, 0, COLUMNS * ROWS * 2);
    col = 0; row = 0;
}

void console_putc(char c) {
    scroll_if_needed();
    if (c == '\n') { col = 0; row++; }
    else {
        unsigned int idx = row * COLUMNS + col;
        if (idx < COLUMNS * ROWS)
            VIDEO_MEM[idx] = ((unsigned short)c) | (ATTR << 8);
        col++;
        if (col >= COLUMNS) { col = 0; row++; }
    }
    scroll_if_needed();
    outb((unsigned short)COM1, (unsigned char)c);
}

void console_puts(const char *s) {
    while (*s) console_putc(*s++);
}

void console_puthex(unsigned long v) {
    char buf[10];
    const char hexd[] = "0123456789ABCDEF";
    if (v == 0) { console_puts("0"); return; }
    int i = 0;
    while (v) { buf[i++] = hexd[v & 0xF]; v >>= 4; }
    while (i > 0) console_putc(buf[--i]);
}

/* PS/2 keyboard polling */
static unsigned char wait_key(void) {
    while (!(inb(0x64) & 0x01)) ;
    return inb(0x60);
}

static char scancode_to_ascii(unsigned char sc) {
    if (sc >= 0x02 && sc <= 0x0D) {
        const char *t = "1234567890-=+";  /* 1..0,-,=,+ */
        return t[sc - 0x02];
    }
    if (sc == 0x1C) return '\n';     /* enter */
    if (sc == 0x0E) return '\b';     /* backspace */
    if (sc == 0x39) return ' ';      /* space */
    if (sc >= 0x1E && sc <= 0x29)    /* a..z */
        return (char)(sc - 0x1E + 'a');
    return 0;
}

void console_gets(char *buf, unsigned int maxlen) {
    unsigned int len = 0;
    col = 0;
    while (len + 1 < maxlen) {
        unsigned char sc = wait_key();
        char c = scancode_to_ascii(sc);
        if (c == '\b') {
            if (len > 0) { len--; buf[len] = 0; }
            continue;
        }
        if (c == '\n') { buf[len] = 0; console_putc('\n'); return; }
        if (c) { buf[len++] = c; buf[len] = 0; console_putc(c); }
    }
    buf[len] = 0;
}
