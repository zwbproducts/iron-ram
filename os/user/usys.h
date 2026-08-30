/* usys.h — Userland syscall interface (all 28 functions) */
/* These are the ONLY functions userland code may call to reach the kernel. */

#ifndef USYS_H
#define USYS_H

/* Syscall numbers */
#define SYS_MEM_STATUS   0
#define SYS_PUTC         1
#define SYS_PUTS         2
#define SYS_GETC         3
#define SYS_GETS         4
#define SYS_MEMSET       5
#define SYS_MEMCPY       6
#define SYS_MEMMOV       7
#define SYS_MEMCMP       8
#define SYS_MEMCHR       9
#define SYS_HEAP_ALLOC   10
#define SYS_HEAP_FREE    11
#define SYS_SEC_WIPE     12
#define SYS_MEMZERO      13
#define SYS_MEMSET_REV   14
#define SYS_MEMZERO_REV  15
#define SYS_MEMSETW      16
#define SYS_MEMFILL      17
#define SYS_MEMSWAP      18
#define SYS_MEMREVERSE   19
#define SYS_MEMROTATE_L  20
#define SYS_MEMROTATE_R  21
#define SYS_MEMFIND      22
#define SYS_MEMCOUNT     23
#define SYS_MEMCHECKSUM  24
#define SYS_MEMEQ        25
#define SYS_MEMMOVE_REV  26
#define SYS_SEC_WIPE_STACK 27

/* Syscall wrappers — implemented in usys.S */
extern unsigned long usys_mem_status(void);
extern int usys_putc(char c);
extern int usys_puts(const char *s);
extern int usys_getc(void);
extern int usys_gets(char *buf, int maxlen);
extern void *usys_memset(void *dest, int c, unsigned long count);
extern void *usys_memcpy(void *dest, const void *src, unsigned long count);
extern void *usys_memmov(void *dest, const void *src, unsigned long count);
extern int usys_memcmp(const void *a, const void *b, unsigned long count);
extern void *usys_memchr(const void *ptr, int value, unsigned long count);
extern void *usys_heap_alloc(unsigned long size);
extern int usys_heap_free(void *ptr);
extern int usys_sec_wipe(void *ptr, unsigned long count);
extern void *usys_memzero(void *dest, unsigned long count);
extern void *usys_memset_rev(void *dest, int c, unsigned long count);
extern void *usys_memzero_rev(void *dest, unsigned long count);
extern void *usys_memsetw(void *dest, unsigned short c, unsigned long count);
extern void *usys_memfill(void *dest, unsigned short pattern, unsigned long count);
extern void usys_memswap(void *a, void *b, unsigned long count);
extern void *usys_memreverse(void *dest, unsigned long count);
extern void *usys_memrotate_l(void *dest, unsigned int shift, unsigned long count);
extern void *usys_memrotate_r(void *dest, unsigned int shift, unsigned long count);
extern int usys_memfind(const void *ptr, int value, unsigned long count);
extern int usys_memcount(const void *ptr, int value, unsigned long count);
extern unsigned char usys_memchecksum(const void *ptr, unsigned long count);
extern int usys_memeq(const void *a, const void *b, unsigned long count);
extern void *usys_memmove_rev(void *dest, const void *src, unsigned long count);
extern int usys_sec_wipe_stack(void *ptr, unsigned long count);

#endif /* USYS_H */
