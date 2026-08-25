# Development Log — `boot/` (BIOS Bootloader + Custom 16-bit Kernel)

> **Project**: `boot/` — stage-1 BIOS bootloader + stage-2 custom 16-bit kernel
> **Scope**: port the 32-bit `libmem/` memory routines to 16-bit real mode and
> build a kernel that drives its *own* (non-BIOS) console with them
> **Status**: <span style="color:#369631; font-weight:bold;">COMPLETE — 8/8 kernel console tests PASS in QEMU
> **Toolchain**: `nasm` 2.15.05, `qemu-system-x86_64` 6.2, `bun` (host lint/typecheck)

---

## 0. Where this started (what was already in the repo)

Before this session, `boot/` already contained a **complete** 512-byte
boot sector:

- `boot.asm` — entry point, a BIOS-teletype console (`puts`/`result`/`vbuf`),
  a table-driven test runner (`run_tests`), edge-case tests (`edge_tests`),
  and `%include` of the five 16-bit memory routine files.
- `memset.asm`, `memzero.asm`, `memset_rev.asm`, `memzero_rev.asm`,
  `secure_wipe.asm` — modular 16-bit ports of `libmem/` with `global`/`extern`.
- It printed a 6/6 `[PASS]` report and ended in `hlt`.
- `MAKEFILE` built a single `boot.bin` (512 B, `0xAA55`).

That existing work was correct and verified. The request was to **go further**:
instead of stopping at a bootloader that tests things on the BIOS console,
*add a custom kernel on top of the bootloader* that calls the memory routines
and shows output on a **kernel console that is itself using** those routines.

---

## 1. The plan that was wrong (and the constraint that killed it)

The natural first idea: keep `boot.asm` *exactly as is* (all the self-tests
still run), and just **append** a kernel-load step at the very end: after the
halting message, read extra sectors and `jmp` into the kernel.

That failed immediately at assemble time:

```
boot.asm:269: error: TIMES value -47 is negative
```

The boot sector had grown to **557 bytes** — 47 bytes over the 510-byte limit
(512 minus the `0xAA55` signature). The new `load_kernel` routine, the
`boot_drv` storage, and the `disk_err` string pushed it past the line, and the
bootloader's own test runner (`run_tests` + `edge_tests` + `vbuf` + the test
dispatch table + the 8 name/result strings) is the bulk of those bytes.

Options considered:

| Option | Verdict |
|--------|---------|
| Keep every bootloader self-test and squeeze `load_kernel` into the remaining ~5 bytes | Impossible (need ~47) |
| Trim strings / drop the NULL edge test from the bootloader | Fragile, ugly, ~509/510 — one change from overflow |
| Delete the modular `.asm` files from the bootloader and inline everything | Loses the modular, libmem-mirrored structure |

The constraint is **hard**: a boot sector is 510 bytes, no more.

---

## 2. The decision: make the bootloader a thin loader, move the demos to the kernel

The cleanest resolution that *loses no capability*: the bootloader becomes a
**stage-1 loader only**, and the **stage-2 kernel hosts every demonstration**
on its own console. The same five routines are still ported and still tested
with the same NULL-safety + count==0 edge cases — they just run in the kernel,
on a console that is driven by the routines themselves (not by the BIOS).

This has three nice properties:

1. It **fits** (the loader is ~50 bytes; the kernel is uncapped).
2. It **matches the request precisely** — the kernel calls the routines and
   reports on a console that uses them.
3. It is the textbook **stage-1/stage-2** split the phrase "a kernel on top
   of the bootloader" describes.

The five modular `.asm` files are unchanged — they are now `%include`-d by
`kernel.asm` instead of `boot.asm`, and `boot.asm` keeps only `puts` (BIOS
teletype, used solely for the disk-error message).

---

## 3. Building the pipeline

### `boot/Makefile`

The Makefile grew from "assemble one file" to a small pipeline. The trickiest
part is that **the bootloader must be told how many sectors to load**, but that
number is only known *after* the kernel is assembled and padded. The final
Makefile computes it and feeds it back via a NASM `-D` define:

```text
kernel.bin  --(dd conv=sync)-->  kernel.pad   (sector-padded)
                                  |
                                  | stat -c%s ; (size+511)/512
                                  v
boot.asm  --(-DKERNEL_SECTORS=N)--> boot.bin  (510 bytes + 0xAA55)
                                  |
                                  v
disk.img = boot.bin + kernel.pad
```

The intermediate `kernel.pad` target (instead of padding `kernel.bin` in
place) keeps `kernel.bin` honest (it shows the *true* kernel size) and makes the
sector count explicit.

---

## 4. Bugs found and fixed while building the kernel

### 4.1 The kernel never ran — and `boot.bin` was 557 bytes (two birds)

- Symptom A: `TIMES value -47 is negative`. Boot sector over budget.
- Root cause: trying to keep the full bootloader self-test.
- Fix: thin-loader restructure (Section 2). After this, `boot.bin` is exactly
  512 bytes.

### 4.2 The kernel's first instruction was `memsetw`, not `start:`

- Symptom: bootloader printed the banner, emitted the loader markers, did the
  `int 13h` read, far-jumped to `0x8000`… and then **nothing** — no output.
- Diagnosis: I had written the `%include` of the memory routines *above* the
  `start:` label in `kernel.asm`. With `-f bin` the binary is emitted top to
  bottom, so the very first byte of the kernel (physical `0x8000`, where the
  bootloader jumps) was `memsetw`'s prologue (`push di; pop cx; …`), not
  `start`. `memsetw` ran with garbage registers, `ret`'d into hyperspace.
- Verification: `od -An -tx1 -N8 kernel.bin` showed `57 51 85 ff …`
  (`push di; pop cx; test di,di`) instead of the expected
  `fa 31 c0` (`cli; xor ax,ax` = `start`).
- Fix: relocate the `%include` block to the **end** of the file (before
  `DATA`). NASM resolves forward `call` references in a single translation
  unit, so all the `call memsetw` / `call memzero16` etc. in the demos still
  resolve correctly. Confirmed by the first bytes becoming `fa 31 c0 8e d8 …`.

This is why keeping an eye on the **entry-point address** matters: with
`-f bin` there is no linker relocating `.text`; the first byte you lay down is
the byte the CPU executes first.

### 4.3 `kputc` emitted garbage bytes to the serial mirror on newlines

- Symptom: the `count==0` line (and every line) arrived with junk bytes like
  `\xa0`, `\xe0`, `\xc0`, `\x80`, `0x60` (`) interspersed — and the
  bootloader's last banner character was delayed and appeared at the very end.
- Root cause: `kputc` used `AX` as scratch for the cursor math (`div`/`mul`
  are 16-bit and live in `DX:AX`). The `.lf` and `.cr` paths clobbered `AL`
  before falling into `.serial:`, so instead of emitting `\n`/`\r` to COM1 it
  emitted the **low byte of the row-offset math** (160 = 0xA0, 320 = 0x40 `@`,
  480 = 0xE0, 640 = 0x80, 800 = 0xC0, … — exactly the values seen).
- Fix: after computing the new cursor in `.lf`/`.cr`, explicitly reload the
  correct character into `AL` (`0x0A` for LF, `0x0D` for CR) before `.serial`.
  The printable path never clobbered `AL`, so it was already correct.

The "delayed last banner `l`" was a separate, SeaBIOS-side artifact: under
`-nographic` SeaBIOS buffers forwarded `int 10h` teletype output and flushed
it lazily (it showed up at shutdown). Removing the bootloader's BIOS banner
entirely (the kernel now prints first) makes the captured serial stream match
the VGA console exactly.

### 4.4 (Non-issue) direct VGA writes are invisible under `-nographic`

- Observation: writing directly to `0xB8000` does **not** appear in the QEMU
  terminal when using `-nographic` (SeaBIOS only forwards *BIOS calls* to the
  serial/stdio backend, not arbitrary video-memory writes).
- Decision: keep the VGA text buffer as the **real** kernel console (that's
  the whole point — a non-BIOS console), and tee each character to COM1
  (`0x3F8`) via a bare `out` so `make run` (`-serial mon:stdio`) is observable.
  Both halves are hand-written 16-bit code; neither touches a BIOS service.

---

## 5. The "using our custom memory functions" proof point

The request was explicit that the console should be *using* the custom memory
routines. Two places make that concrete rather than cosmetic:

1. **Clearing the screen is a `memzero16` call.** `kclear()` does not loop in
   C-like code or call `int 10h`; it sets `ES=0xB800`, `DI=0`, `CX=4000` and
   `call memzero16`. The screen is blanked by the ported routine itself.

2. **Every assertion is verified by `buf_chk`, which reads back memory the
   routines wrote.** Each demo fills `kbuf`, runs one routine, then scans the
   buffer byte-by-byte comparing to the expected value — i.e. the test of "did
   `memzero16` actually zero it?" is performed with the same kind of memory
   walk the routines use internally.

---

## 6. Final state & verification

```
boot.bin     = 512 bytes   (0xAA55 signature)      <- stage-1 loader
kernel.bin   = 984 bytes   (padded to 1024 / 2 sectors)  <- stage-2 kernel
disk.img     = 1536 bytes  (boot sector + 2 kernel sectors)
```

QEMU (`-nographic -serial mon:stdio`) output:

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

- `nasm -f bin` on both sources: **0 warnings**.
- `bun typecheck` and `bun lint` on the host project: **pass** (the host app
  is untouched; only `boot/` changed).

---

## 7. Roadmap notes / what to reach for next

With two stages in place, the natural next steps are:

- **Enter 32-bit protected mode** from the kernel (set A20, load a GDT, set
  `CR0.PE`) so the kernel can then use the *original* 32-bit `libmem/`
  routines verbatim instead of the 16-bit ports.
- **Link the kernel against `libmymem.a`** in protected mode and share one
  implementation instead of maintaining `-rev`/`_16` port pairs.
- **Multiboot / ELF loading** so the stage-1 loader doesn't hardcode sector
  math — parse an ELF and load segments.
- **Real VGA scrolling** in `kputc` (currently wraps to the top of the screen
  past the last row) using `memset_rev16` for an up-scroll.

For now the stack demonstrates the requested idea end-to-end in 16-bit real
mode: a bootloader loads a kernel, the kernel has its own console, and that
console's very first action — clearing the screen — is a call to our ported
`memzero16`.
