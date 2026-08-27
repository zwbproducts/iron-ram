/* usys.h — userspace syscall wrappers (shell sees ONLY this) */
#ifndef USYS_H
#define USYS_H

long syscall(long num, long a0, long a1, long a2);

/* original 12 syscalls */
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

/* Phase 2: new libmem syscalls (13-18) */
void *usys_memcpy(void *dest, const void *src, unsigned int count);
void *usys_memmove(void *dest, const void *src, unsigned int count);
int   usys_memcmp(const void *s1, const void *s2, unsigned int count);
void *usys_memchr(const void *s, int c, unsigned int count);
void *usys_memsetw(void *dest, unsigned short c, unsigned int count);
void  usys_secure_wipe_heap(void *heap_dest, unsigned int wipe_count);

/* Phase 3: 10 more general-purpose functions (19-28) */
void *usys_memfill(void *dest, unsigned short pattern, unsigned int count);
void  usys_memswap(void *a, void *b, unsigned int count);
void *usys_memreverse(void *dest, unsigned int count);
void *usys_memrotate_l(void *dest, unsigned int shift, unsigned int count);
void *usys_memrotate_r(void *dest, unsigned int shift, unsigned int count);
int   usys_memfind(const void *s, int c, unsigned int count);
int   usys_memcount(const void *s, int c, unsigned int count);
unsigned char usys_memchecksum(const void *s, unsigned int count);
int   usys_memeq(const void *s1, const void *s2, unsigned int count);
void *usys_memmove_rev(void *dest, const void *src, unsigned int count);

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

/* Phase 3: 10 more general-purpose functions */
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

void shell_main(void);

#endif
