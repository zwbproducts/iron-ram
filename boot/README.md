# 🥅 `boot/` — BIOS Bootloader + Custom 16-bit Kernel

A two-stage x86 boot stack built entirely on **our own** hand-written 16-bit
memory routines (no BIOS memory helpers, no libc):

- **Stage 1 — `boot.asm`** : a 512-byte BIOS boot sector. It sets up 16-bit
  real mode, captures the boot drive, and uses BIOS `int 13h/ah=02h` to read
  the kernel (sectors 2+) into physical `0x8000`, then far-jumps into it.
  On disk-read failure it reports via the BIOS teletype and halts.
- **Stage 2 — `kernel.asm`** : a custom 16-bit real-mode kernel that owns the
  **kernel console**. Its console is the VGA text frame buffer at `0xB8000`,
  and it drives that console with the memory routines we ported — `memzero16`
  zeroes the 4000-byte video buffer to clear the screen — instead of wrapping
  any BIOS console service. Each character is also teed to the serial port
  (`0x3F8`) via raw `out` so the console is observable under
  `qemu -nographic -serial mon:stdio`.

The five memory routines are **modular ports** of the 32-bit `libmem/`
library — each lives in its own `.asm` file with `global`/`extern` directives
mirroring the original, and are `%include`d by `kernel.asm`.

## Files

| File | Mirrors | Function |
|------|---------|----------|
| `memset.asm` | `libmem/memset.asm` | Forward byte fill (`inc di`) |
| `memzero.asm` | `libmem/memzero.asm` | Delegates to `memset` (`extern memsetw`) |
| `memset_rev.asm` | `libmem/memset_rev.asm` | Backward fill (`dec di`) |
| `memzero_rev.asm` | `libmem/memzero_rev.asm` | Delegates to `memset_rev16` (`extern`) |
| `secure_wipe.asm` | `libmem/secure_wipe_stack_rev.asm` | Black-box wipe (`extern memset_rev16`) |
| `boot.asm` | — | Stage-1 loader (512 bytes, `0xAA55`) |
| `kernel.asm` | — | Stage-2 kernel: kernel console + demos |
| `Makefile` | — | Builds `disk.img` (boot + kernel sectors) |

## Architecture

```
 BIOS loads sector 1 -> 0x7C00
        |
        v
 ┌─────────────────────────────────────┐
 │ boot.asm  (512-byte boot sector)     │  BIOS int 13h reads sectors 2..N
 │   - real-mode setup                  │  into 0x0000:0x8000, then
 │   - load KERNEL_SECTORS sectors      │  far-jumps to the kernel
 │   - jmp 0x0000:0x8000                │
 └─────────────────────────────────────┘
        |
        v  physical 0x8000
 ┌─────────────────────────────────────┐
 │ kernel.asm (our custom kernel)      │  NO BIOS for the console:
 │   - includes the 5 memory .asm      │  VGA text buffer @ 0xB8000
 │   - kclear() uses memzero16() to    │  cleared with memzero16(),
 │     zero the 4000-byte video buffer │  chars written by hand.
 │   - demos every memory routine on a │  chars teed to serial 0x3F8.
 │     scratch buffer + prints [OK]/   │
 │     [FAIL] on the kernel console    │
 └─────────────────────────────────────┘
```

### DSE-Prevention Mirror (unchanged)

```
┌─────────────────────┐    extern memset_rev16    ┌─────────────────────┐
│  secure_wipe16      │ ─────────────────────────→│  memset_rev16       │
│  (opaque wipe)       │   (black-box call the     │  (backward fill)    │
│                      │    compiler can't see)   │                      │
└─────────────────────┘                          └─────────────────────┘
```

Because `memset_rev16` is declared `extern` (an opaque boundary), dead-store
elimination cannot strip the wipe even when the caller has no further use of
the buffer.

## Calling Convention

All memory routines share a compact register-based convention (no stack-arg
overhead — ideal for the boot stage):

```
  DI = dest    AL = fill byte    CX = count    (operates on ES:[DI])
  memzero16 / memzero_rev16 / secure_wipe16 take only DI + CX (AL = 0)
```

**Safety guards** (mirrors `libmem/`):

- `DI == 0` (NULL dest) → early return
- `CX == 0` (count zero) → early return (critical for the backward routines
  so `dest + count - 1` cannot underflow)

## Requirements

| Tool | Purpose |
|------|---------|
| `nasm` | Assemble the boot sector + kernel |
| `qemu-system-x86_64` | Emulate & view output |

```bash
sudo apt install nasm qemu-system-x86
```

## Build & Run

```bash
make            # → boot.bin (512B), kernel.bin, disk.img (boot + kernel sectors)
make run        # build + launch in QEMU
```

Manual:

```bash
nasm -f bin kernel.asm -o kernel.bin
dd if=kernel.bin of=kernel.pad bs=512 conv=sync      # sector-pad kernel
ksect=$(($(stat -c%s kernel.pad) + 511) / 512)
nasm -f bin -DKERNEL_SECTORS=$ksect boot.asm -o boot.bin
cat boot.bin kernel.pad > disk.img
qemu-system-x86_64 -drive format=raw,file=disk.img -nographic -serial mon:stdio
```

The Makefile computes `KERNEL_SECTORS` automatically and passes it to the
bootloader so it reads exactly the right number of sectors.

## Kernel Console

The kernel console is memory-driven, not BIOS-driven:

- `kclear()` calls **`memzero16`** on the 4000-byte VGA text buffer
  (`0xB8000`) — the screen is wiped by our own routine, not `int 10h`.
- `kputc`/`kputs` write character+attribute cells directly into the
  frame buffer and advance a cursor (carriage-return / newline handling,
  row wrap), then `out` the character to COM1 for host capture.
- The memory routines are exercised on a 64-byte scratch buffer with a
  `buf_chk` verifier, so every `[OK]`/`[FAIL]` is a real assertion.

## Live Output (QEMU)

```
  KERNEL CONSOLE (custom mem)
  memsetw     : [OK]
  memzero16   : [OK]
  memset_rev16: [OK]
  memzero_rev16: [OK]
  secure_wipe16: [OK]
  NULL safety : [OK]
  count==0    : [OK]
  kernel memory functions live
```

## Colours

| Colour | VGA attribute nibbles | Usage |
|--------|------------------------|-------|
| light gray on black | `0x0F` | kernel console text (VGA) |
| red | `0x0C` | bootloader disk-error message (BIOS teletype `BL`) |

## Verified

- ✅ `boot.bin` assembles to exactly **512 bytes** with the `55 AA` signature
- ✅ `kernel.bin` assembles, is sector-padded, and is concatenated into `disk.img`
- ✅ Runs in QEMU — kernel console brings up and reports **8/8 PASS**
  (5 memory routines + NULL-safety + count==0 + live banner)
- ✅ Zero assembler warnings
