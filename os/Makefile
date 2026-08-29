# os/Makefile — build the 32-bit kernel + userland and disk image

CC      = gcc -m32 -ffreestanding -nostdlib -fno-pie -fno-stack-protector
NASMF16 = nasm -f bin
NASMF32 = nasm -f elf32
LD      = ld -m elf_i386

LIBMEM = ../libmem

# Kernel objects
KOBJS = kernel/entry.o kernel/idt.o kernel/isr80.o kernel/gpf.o kernel/dblf.o \
        kernel/kmain.o kernel/console.o kernel/syscalls.o \
        $(LIBMEM)/memset.o $(LIBMEM)/memzero.o \
        $(LIBMEM)/memset_rev.o $(LIBMEM)/memzero_rev.o \
        $(LIBMEM)/memcpy.o $(LIBMEM)/memmove.o \
        $(LIBMEM)/memcmp.o $(LIBMEM)/memchr.o $(LIBMEM)/memsetw.o \
        $(LIBMEM)/memfill.o $(LIBMEM)/memswap.o $(LIBMEM)/memreverse.o \
        $(LIBMEM)/memrotate_l.o $(LIBMEM)/memrotate_r.o \
        $(LIBMEM)/memfind.o $(LIBMEM)/memcount.o \
        $(LIBMEM)/memchecksum.o $(LIBMEM)/memeq.o $(LIBMEM)/memmove_rev.o \
        $(LIBMEM)/secure_wipe_stack_rev.o $(LIBMEM)/secure_wipe_heap_rev.o

# Userland objects
UOBJS = user/userland.o user/usys.o

.PHONY: all clean verify-shell disk.img

all: disk.img verify-shell

# ─── Kernel ELF ───
kernel.elf: $(KOBJS) kernel/link.ld
	$(LD) -T kernel/link.ld -o kernel.elf $(KOBJS)

kernel.bin: kernel.elf
	objcopy -O binary kernel.elf kernel.bin

# ─── Userland ELF ───
userland.elf: $(UOBJS) user/userland.ld
	$(LD) -T user/userland.ld -o userland.elf $(UOBJS)

userland.bin: userland.elf
	objcopy -O binary userland.elf userland.bin

# ─── Boot sector ───
stage1.bin: stage1.asm kernel.bin userland.bin
	@ksz=$$(stat -c %s kernel.bin); ksect=$$(( (ksz + 511) / 512 )); \
	 usz=$$(stat -c %s userland.bin); usect=$$(( (usz + 511) / 512 )); \
	 echo "kernel sectors=$$ksect, userland sectors=$$usect"; \
	 $(NASMF16) -DKERNEL_SECTORS=$$ksect -DUSER_SECTORS=$$usect -o stage1.bin stage1.asm

# ─── Disk image ───
disk.img: stage1.bin kernel.bin userland.bin
	dd if=/dev/zero of=disk.img bs=1024 count=1440 2>/dev/null
	dd if=stage1.bin of=disk.img conv=notrunc bs=512 2>/dev/null
	dd if=kernel.bin of=disk.img conv=notrunc bs=512 seek=1 2>/dev/null
	@ksz=$$(stat -c %s kernel.bin); ksect=$$(( (ksz + 511) / 512 )); \
	 dd if=userland.bin of=disk.img conv=notrunc bs=512 seek=$$((1 + ksect)) 2>/dev/null

# ─── Verification ───
verify-shell: user/shell.o
	@echo "=== Verifying shell.o security boundary ==="
	@VIOLATIONS=$$(nm -u user/shell.o 2>/dev/null | awk '{print $$2}' | grep -vE '^_$$|^usys_|^syscall$$' || true); \
	 if [ -n "$$VIOLATIONS" ]; then \
	     echo "  VIOLATION: shell.o has non-usys references:"; \
	     echo "    $$VIOLATIONS"; \
	     exit 1; \
	 else \
	     echo "  shell.o references ONLY usys_* wrappers — security boundary verified"; \
	 fi

# ─── Build rules ───
kernel/%.o: kernel/%.c
	$(CC) -Ikernel -c $< -o $@
kernel/%.o: kernel/%.asm
	$(NASMF32) $< -o $@
user/%.o: user/%.c
	$(CC) -Iuser -c $< -o $@
user/%.o: user/%.S
	$(NASMF32) $< -o $@
user/%.o: user/%.asm
	$(NASMF32) $< -o $@

# libmem objects
define LIBMEM_RULE
$(LIBMEM)/$(1).o: $(LIBMEM)/$(1).asm
	$$(NASMF32) $$< -o $$@
endef
$(foreach f,memset memzero memset_rev memzero_rev memcpy memmove memcmp memchr memsetw memfill memswap memreverse memrotate_l memrotate_r memfind memcount memchecksum memeq memmove_rev secure_wipe_stack_rev secure_wipe_heap_rev,\
	$(eval $(call LIBMEM_RULE,$(f))))

clean:
	rm -f kernel.elf kernel.bin stage1.bin userland.elf userland.bin disk.img
	rm -f kernel/*.o user/*.o
	rm -f $(LIBMEM)/*.o
