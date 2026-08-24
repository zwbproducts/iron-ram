CC = gcc
CFLAGS = -m32 -fno-builtin -fno-stack-protector -Wall -Wextra -std=c11 -c

ASM = nasm
ASMFLAGS = -f elf32

AR = ar
ARFLAGS = rcs

LIBMEM_OBJS = memset.o memzero.o memset_rev.o memzero_rev.o
LIBSECURE_OBJS = secure_wipe_stack_rev.o

.PHONY: all clean test

all: libmymem.a libmysecure.a

%.o: %.asm
	$(ASM) $(ASMFLAGS) $< -o $@

libmymem.a: $(LIBMEM_OBJS)
	$(AR) $(ARFLAGS) $@ $^

libmysecure.a: $(LIBSECURE_OBJS)
	$(AR) $(ARFLAGS) $@ $^

test: all test_link.c
	$(CC) -m32 -fno-builtin -fno-stack-protector -Wall -Wextra -std=c11 \
		-o test_link test_link.c -L. -lmysecure -lmymem
	./test_link

clean:
	rm -f *.o *.a test_link
