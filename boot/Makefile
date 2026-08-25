# boot/Makefile — build the boot sector + custom 16-bit kernel into a disk image
#
# Pipeline:
#   kernel.asm  -> kernel.bin  (padded to a whole number of sectors)
#   boot.asm    -> boot.bin    (-DKERNEL_SECTORS=<sectors>, exactly 512 bytes)
#   boot.bin + kernel.pad -> disk.img
# Run: make run   (qemu-system-x86_64 -drive format=raw,file=disk.img)

ASM      = nasm
ASMFLAGS = -f bin
KERNEL   = kernel.bin
KPAD     = kernel.pad
BOOT     = boot.bin
DISK     = disk.img

.PHONY: all run clean

all: $(DISK)

# Assemble the custom 16-bit kernel (flat binary).
$(KERNEL): kernel.asm
	$(ASM) $(ASMFLAGS) -o $@ $<

# Pad the kernel up to a whole number of 512-byte sectors.
$(KPAD): $(KERNEL)
	dd if=$< of=$@ bs=512 conv=sync

# Assemble the boot sector; it must know how many kernel sectors to load
# so it can read them with BIOS int 13h / ah=02h.
$(BOOT): boot.asm $(KPAD)
	ksect=$$(stat -c%s $(KPAD)); \
	ksect=$$(( (ksect + 511) / 512 )); \
	$(ASM) $(ASMFLAGS) -DKERNEL_SECTORS=$$ksect boot.asm -o $@; \
	test $$(stat -c%s $@) -eq 512

# Raw disk image: boot sector (sector 1) followed by the kernel sectors.
$(DISK): $(BOOT) $(KPAD)
	cat $(BOOT) $(KPAD) > $@

run: $(DISK)
	qemu-system-x86_64 -drive format=raw,file=$(DISK) -nographic -serial mon:stdio

clean:
	rm -f $(KERNEL) $(KPAD) $(BOOT) $(DISK) *.lst
