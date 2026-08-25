/* console.h — VGA text-mode + COM1 tee driver */
#ifndef CONSOLE_H
#define CONSOLE_H

void console_init(void);
void console_cls(void);
void console_putc(char c);
void console_puts(const char *s);
void console_puthex(unsigned long v);
void console_gets(char *buf, unsigned int maxlen);

#endif
