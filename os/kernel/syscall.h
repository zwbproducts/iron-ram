/* syscall.h — syscall numbers and int 0x80 gate ABI */
#ifndef SYSCALL_H
#define SYSCALL_H

/* kernel-side declaration (called from isr80.asm)
 * Dispatches a syscall number + 3 args to the kernel-owned function.
 * This is the ONLY interface through which userland (shell.c) may
 * invoke libmem or console routines — protection by separation.
 */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2);

/* Signal interrupt dispatch (int 0x81)
 * Invoked by bootloader during init to verify libmem readiness.
 */
unsigned long signal_dispatch(unsigned long sig, unsigned long a0,
                              unsigned long a1, unsigned long a2);

/* exported function prototypes so C files can reference libmem/console */
void *memset(void *dest, int c, unsigned int count);
void *memzero(void *dest, unsigned int count);
void *memset_rev(void *dest, int c, unsigned int count);
void *memzero_rev(void *dest, unsigned int count);
void *memcpy(void *dest, const void *src, unsigned int count);
void *memmove(void *dest, const void *src, unsigned int count);
int   memcmp(const void *s1, const void *s2, unsigned int count);
void *memchr(const void *s, int c, unsigned int count);
void *memsetw(void *dest, unsigned short c, unsigned int count);
void *secure_wipe_stack_rev(void *stack_dest, unsigned int wipe_count);
void *secure_wipe_heap_rev(void *heap_dest, unsigned int wipe_count);

void console_putc(char c);
void console_puts(const char *s);
void console_puthex(unsigned long v);
void console_gets(char *buf, unsigned int maxlen);
void console_cls(void);

/* syscall numbers — original 12 */
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

/* sysfs numbers — new libmem functions (Phase 2 expansion) */
#define SYS_memcpy         13
#define SYS_memmove        14
#define SYS_memcmp         15
#define SYS_memchr         16
#define SYS_memsetw        17
#define SYS_secure_wipe_heap 18

/* signal numbers (int 0x81) */
#define SIG_LIBMEM_READY    1   /* verify libmem subsystem initialized */
#define SIG_LIBMEM_WIPE     2   /* secure-wipe request via signal path */

#endif

/* ABI (used by user/usys.S):
 *   eax = syscall number, ebx = arg0, ecx = arg1, edx = arg2
 *   invoke with: int 0x80
 *   result returned in eax
 *
 * Signals (int 0x81):
 *   eax = signal number, ebx = arg0, ecx = arg1, edx = arg2
 *   invoke with: int 0x81
 *   result returned in eax
 */
