/* console.h — Kernel console interface (KERNEL-ONLY) */
/* This header must NOT be included in userland code. */

#ifndef CONSOLE_H
#define CONSOLE_H

void console_init(void);
void console_cls(void);
void console_putc(char c);
void console_puts(const char *s);

#endif /* CONSOLE_H */
