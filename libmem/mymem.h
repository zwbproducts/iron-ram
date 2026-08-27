#ifndef MYMEM_H
#define MYMEM_H

#include <stddef.h>

/* General memory routines — libmymem.a */
void *memset(void *dest, int c, size_t count);
void *memzero(void *dest, size_t count);
void *memset_rev(void *dest, int c, size_t count);
void *memzero_rev(void *dest, size_t count);
void *memcpy(void *dest, const void *src, size_t count);
void *memmove(void *dest, const void *src, size_t count);
int   memcmp(const void *s1, const void *s2, size_t count);
void *memchr(const void *s, int c, size_t count);
void *memsetw(void *dest, unsigned short c, size_t count);

/* Secure stack/heap wiping — libmysecure.a */
void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count);
void *secure_wipe_heap_rev(void *heap_dest, size_t wipe_count);

#endif /* MYMEM_H */
