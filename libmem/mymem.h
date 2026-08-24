#ifndef MYMEM_H
#define MYMEM_H

#include <stddef.h>

/* General memory routines — libmymem.a */
void *memset(void *dest, int c, size_t count);
void *memzero(void *dest, size_t count);
void *memset_rev(void *dest, int c, size_t count);
void *memzero_rev(void *dest, size_t count);

/* Secure stack wiping — libmysecure.a */
void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count);

#endif /* MYMEM_H */
