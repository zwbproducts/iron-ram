/* usys.h — Userland syscall interface */
/* These are the ONLY functions userland code may call to reach the kernel. */

#ifndef USYS_H
#define USYS_H

/* Syscall numbers */
#define SYS_MEM_STATUS  0
#define SYS_PUTC        1
#define SYS_PUTS        2
#define SYS_GETC        3
#define SYS_GETS        4
#define SYS_MEMSET      5
#define SYS_MEMCPY      6
#define SYS_MEMMOV      7
#define SYS_MEMCMP      8
#define SYS_MEMCHR      9
#define SYS_HEAP_ALLOC  10
#define SYS_HEAP_FREE   11
#define SYS_SEC_WIPE    12

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

#endif /* USYS_H */
