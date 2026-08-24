# boot/Makefile — build & run the 512-byte boot sector

ASM = nasm
ASMFLAGS = -f bin

.PHONY: all run clean

all: boot.bin

boot.bin: boot.asm
	$(ASM) $(ASMFLAGS) $< -o $@

run: boot.bin
	qemu-system-x86_64 -drive format=raw,file=boot.bin

clean:
	rm -f boot.bin
