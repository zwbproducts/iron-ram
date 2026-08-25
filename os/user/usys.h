/* usys.h — userspace syscall wrappers (shell sees ONLY this) */
#ifndef USYS_H
#define USYS_H

long syscall(long num, long a0, long a1, long a2);

void *usys_memset(void *dest, int c, unsigned int count);
void *usys_memzero(void *dest, unsigned int count);
void *usys_memset_rev(void *dest, int c, unsigned int count);
void *usys_memzero_rev(void *dest, unsigned int count);
int   usys_secure_wipe(void *stack_dest, unsigned int wipe_count);
void  usys_cls(void);
void  usys_putc(char c);
void  usys_puts(const char *s);
void  usys_puthex(unsigned long v);
unsigned char usys_peek(unsigned long addr);
void  usys_gets(char *buf, unsigned int maxlen);
void  usys_halt(void);

/* syscall numbers (must match kernel side) */
#define SYS_memset        1
#define SYS_memzero       2
#define SYS_memset_rev    3
#define SYS_memzero_rev   4
#define SYS_secure_wipe   5
#define SYS_cls           6
#define SYS_putc          7
#define SYS_puts          8
#define SYS_puthex        9
#define SYS_peek          10
#define SYS_gets          11
#define SYS_halt          12

void shell_main(void);

#endif
