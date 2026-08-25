/* syscall.h — syscall numbers and int 0x80 gate ABI */
#ifndef SYSCALL_H
#define SYSCALL_H

/* kernel-side declaration (called from isr80.asm) */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2);

/* exported function prototypes so C files can reference libmem/console */
void *memset(void *dest, int c, unsigned int count);
void console_putc(char c);
void console_puts(const char *s);
void console_puthex(unsigned long v);

/* syscall numbers */
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

#endif

/* ABI (used by user/usys.S):
 *   eax = syscall number
 *   ebx = arg0, ecx = arg1, edx = arg2
 *   invoke with: int 0x80
 *   result returned in eax
 */
