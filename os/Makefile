# os/Makefile — build the 32-bit kernel + C shell and disk image
# Run from this directory:  make -C os
#
# Tool: bun workspace uses gcc-multilib; here we use plain gcc -m32 + nasm.
# Order: build kernel.elf -> kernel.bin first, then compute sector count,
#        then assemble stage1.asm (16-bit) with the real KERNEL_SECTORS.

CC      = gcc -m32 -ffreestanding -nostdlib -fno-pie -fno-stack-protector
NASMF16 = nasm -f bin
NASMF32 = nasm -f elf32
LD      = ld -m elf_i386

LIBMEM = ../libmem

# Kernel + shell objects (flat binary layout)
KOBJS = kernel/entry.o kernel/idt.o kernel/isr80.o kernel/isr81.o kernel/isr_gpf.o \
        kernel/kmain.o kernel/console.o kernel/syscalls.o \
        $(LIBMEM)/memset.o $(LIBMEM)/memzero.o \
        $(LIBMEM)/memset_rev.o $(LIBMEM)/memzero_rev.o \
        $(LIBMEM)/memcpy.o $(LIBMEM)/memmove.o \
        $(LIBMEM)/memcmp.o $(LIBMEM)/memchr.o $(LIBMEM)/memsetw.o \
        $(LIBMEM)/memfill.o $(LIBMEM)/memswap.o $(LIBMEM)/memreverse.o \
        $(LIBMEM)/memrotate_l.o $(LIBMEM)/memrotate_r.o \
        $(LIBMEM)/memfind.o $(LIBMEM)/memcount.o \
        $(LIBMEM)/memchecksum.o $(LIBMEM)/memeq.o $(LIBMEM)/memmove_rev.o \
        $(LIBMEM)/secure_wipe_stack_rev.o $(LIBMEM)/secure_wipe_heap_rev.o \
        user/usys.o user/shell.o

.PHONY: all clean verify-shell

all: disk.img verify-shell

# ─── Kernel ELF ───
kernel.elf: $(KOBJS) kernel/link.ld
	$(LD) -T kernel/link.ld -o kernel.elf $(KOBJS)

kernel.bin: kernel.elf
	objcopy -O binary kernel.elf kernel.bin

# ─── Verification — proves shell.o references ONLY usys_* symbols ───
# nm -u shows undefined symbols in shell.o; we check that every
# undefined symbol is a usys_* wrapper. If shell.c tries to call
# memset, console_puts, etc. directly, this FAILS — enforcing
# the security boundary at build time.
verify-shell: user/shell.o
	@echo "=== Verifying shell.o security boundary ==="
	@VIOLENCE=$$(nm -u user/shell.o 2>/dev/null | awk '{print $$2}' | grep -vE '^_$$|^usys_|^syscall$$' || true); \
	if [ -n "$$VIOLENCE" ]; then \
		echo "  ✗ VIOLATION: shell.o has non-usys references:"; \
		echo "    $$VIOLENCE"; \
		exit 1; \
	else \
		echo "  ✓ shell.o references ONLY usys_* wrappers — security boundary verified"; \
	fi

stage1.bin: stage1.asm kernel.bin
	@sz=$$(stat -c %s kernel.bin); sectors=$$(( (sz + 511) / 512 )); \
	 echo "kernel sectors=$$sectors"; \
	 $(NASMF16) -DLOAD_KERNEL_SECTORS=$$sectors -o stage1.bin stage1.asm

disk.img: stage1.bin kernel.bin
	dd if=/dev/zero of=disk.img bs=1024 count=1440
	dd if=stage1.bin of=disk.img conv=notrunc bs=512
	dd if=kernel.bin  of=disk.img conv=notrunc bs=512 seek=1

kernel/%.o: kernel/%.c
	$(CC) -Ikernel -c $< -o $@
kernel/%.o: kernel/%.asm
	$(NASMF32) $< -o $@
user/%.o: user/%.c
	$(CC) -Iuser -c $< -o $@
user/%.o: user/%.S
	$(NASMF32) $< -o $@

# Pattern rules with '..' directory components don't match in GNU make, so
# generate explicit rules for each libmem .o.
define LIBMEM_RULE
$(LIBMEM)/$(1).o: $(LIBMEM)/$(1).asm
	$$(NASMF32) $$< -o $$@
endef
$(foreach f,memset memzero memset_rev memzero_rev memcpy memmove memcmp memchr memsetw memfill memswap memreverse memrotate_l memrotate_r memfind memcount memchecksum memeq memmove_rev secure_wipe_stack_rev secure_wipe_heap_rev,\
	$(eval $(call LIBMEM_RULE,$(f))))

clean:
	rm -f kernel.elf kernel.bin stage1.bin disk.img $(KOBJS) user/shell.bin
