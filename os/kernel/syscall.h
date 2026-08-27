/* syscall.h — syscall numbers and interrupt gate ABI
 */
#ifndef SYSCALL_H
#define SYSCALL_H

/* kernel-side declaration (called from isr80.asm)
 * Dispatches a syscall number + 3 args to the kernel-owned function.
 * This is the ONLY interface through which userland (shell.c) may
 * invoke libmem or console routines — protection by separation.
 */
unsigned long syscall_dispatch(unsigned long num, unsigned long a0,
                               unsigned long a1, unsigned long a2);

/* signal dispatch (int 0x81) — bootloader/kernel-initiated
 * Verifies libmem subsystem readiness and triggers secure operations.
 */
unsigned long signal_dispatch(unsigned long sig, unsigned long a0,
                              unsigned long a1, unsigned long a2);

/* GPF exception handler (vector 13) — bare-metal exception handling
 * Catches invalid memory accesses (NULL derefs, bad addresses)
 * and logs them via serial before returning.
 */
void gpf_handler(void);

/* exported function prototypes — kernel-owned */
void *memset(void *dest, int c, unsigned long count);
void *memzero(void *dest, unsigned long count);
void *memset_rev(void *dest, int c, unsigned long count);
void *memzero_rev(void *dest, unsigned long count);
void *memcpy(void *dest, const void *src, unsigned long count);
void *memmove(void *dest, const void *src, unsigned long count);
int   memcmp(const void *s1, const void *s2, unsigned long count);
void *memchr(const void *s, int c, unsigned long count);
void *memsetw(void *dest, unsigned short c, unsigned long count);
void *memfill(void *dest, unsigned short pattern, unsigned long count);
void  memswap(void *a, void *b, unsigned long count);
void *memreverse(void *dest, unsigned long count);
void *memrotate_l(void *dest, unsigned long shift, unsigned long count);
void *memrotate_r(void *dest, unsigned long shift, unsigned long count);
int   memfind(const void *s, int c, unsigned long count);
int   memcount(const void *s, int c, unsigned long count);
unsigned char memchecksum(const void *s, unsigned long count);
int   memeq(const void *s1, const void *s2, unsigned long count);
void *memmove_rev(void *dest, const void *src, unsigned long count);
void *secure_wipe_stack_rev(void *stack_dest, unsigned long wipe_count);
void *secure_wipe_heap_rev(void *heap_dest, unsigned long wipe_count);

void console_putc(char c);
void console_puts(const char *s);
void console_puthex(unsigned long v);
void console_gets(char *buf, unsigned int maxlen);
void console_cls(void);

/* syscall numbers — original 12 */
#define SYS_memset          1
#define SYS_memzero         2
#define SYS_memset_rev      3
#define SYS_memzero_rev     4
#define SYS_secure_wipe     5
#define SYS_cls             6
#define SYS_putc            7
#define SYS_puts            8
#define SYS_puthex          9
#define SYS_peek            10
#define SYS_gets            11
#define SYS_halt            12

/* Phase 2: new libmem syscalls */
#define SYS_memcpy             13
#define SYS_memmove            14
#define SYS_memcmp             15
#define SYS_memchr             16
#define SYS_memsetw            17
#define SYS_secure_wipe_heap   18

/* Phase 3: 10 more general-purpose memory functions */
#define SYS_memfill            19
#define SYS_memswap            20
#define SYS_memreverse         21
#define SYS_memrotate_l        22
#define SYS_memrotate_r        23
#define SYS_memfind            24
#define SYS_memcount           25
#define SYS_memchecksum        26
#define SYS_memeq              27
#define SYS_memmove_rev        28

/* signal numbers (int 0x81) */
#define SIG_LIBMEM_READY        1
#define SIG_LIBMEM_WIPE         2
#define SIG_LIBMEM_TEST_ALL     3

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
