# Active Context: Next.js Starter Template

## Current State

**Template Status**: ✅ Ready for development

The template is a clean Next.js 16 starter with TypeScript and Tailwind CSS 4. It's ready for AI-assisted expansion to build any type of application.

## Recently Completed

## Current State

**All builds & tests pass.** Repo cleaned of tracked binary artifacts; `os/.gitignore` added.

### Build & Test Results (2026-08-25)

| Component | Build | Run |
|-----------|-------|-----|
| `libmem/` (32-bit x86 memory library) | ✅ 0 warnings | ✅ 10/10 tests PASS |
| `os/` (32-bit protected mode kernel) | ✅ 0 warnings | Builds into `disk.img` (stage1 stub) |
| `boot/` (16-bit BIOS boot stack) | ✅ 0 warnings | ✅ 6/6 + edge cases PASS in QEMU |
| Next.js 16 frontend | ✅ typecheck + lint clean | N/A |

## Recently Completed

- [x] Base Next.js 16 setup with App Router
- [x] TypeScript configuration with strict mode
- [x] Tailwind CSS 4 integration
- [x] ESLint configuration
- [x] Memory bank documentation
- [x] Recipe system for common features
- [x] **Phase 1**: `memset.asm` — forward fill (byte-by-byte, `inc edi` / `dec ecx`)
- [x] **Phase 2**: `memzero.asm` — forward zeroing (delegates to `memset`)
- [x] **Phase 3**: `memset_rev.asm` + `memzero_rev.asm` — backward fill/zeroing (delegates to `memset_rev`)
- [x] **Phase 4**: `mymem.h` header + `Makefile` → `libmymem.a`
- [x] **Phase 5**: `secure_wipe_stack_rev.asm` → `libmysecure.a` (delegates to `memset_rev`)
- [x] C test harness `test_link.c` — 8 functional tests, zero warnings, links `libmymem.a` + `libmysecure.a`
- [x] **32-bit protected mode kernel** (`os/`): `entry.asm` (_start, BSS zero, IDT), `idt.asm` (256-entry IDT, vector 0x80 interrupt gate), `isr80.asm` (pusha/call dispatch), `syscall.h` (12 syscall numbers), `syscalls.c` (dispatch switch), `console.c/.h` (VGA 0xB8000 + PS/2 keyboard + COM1 tee), `kmain.c`, `user/shell.c` (interactive shell), `user/usys.S`/`usys.h` (int 0x80 wrappers)
- [x] **`os/.gitignore`** — excluded all build artifacts (`.o`, `.bin`, `.elf`, `.img`)
- [x] **Rebuild & test verification**: all components rebuilt, all tests pass, committed

## Current Structure

| File/Directory | Purpose | Status |
|----------------|---------|--------|
| `src/app/page.tsx` | Home page | ✅ Ready |
| `src/app/layout.tsx` | Root layout | ✅ Ready |
| `src/app/globals.css` | Global styles | ✅ Ready |
| `.kilocode/` | AI context & recipes | ✅ Ready |
| `libmem/` | 32-bit x86 memory library (NASM + GCC -m32) | ✅ Built, 10/10 tests pass |
| `boot/` | 16-bit BIOS boot sector (stage-1 loader) + custom 16-bit kernel (stage-2) | ✅ Built, 6/6 tests pass in QEMU |
| `os/` | 32-bit protected mode kernel + 12-syscall int 0x80 ABI + VGA console + PS/2 keyboard + userspace shell | ✅ Builds, stage1 stub incomplete (no PM switch) |

| 2026-08-24 | Bootloaded restructured: modular 16-bit .asm files (memset/memzero/memset_rev/memzero_rev/secure_wipe) with global/extern directives, `%include`d into boot.asm; table-driven test runner with indirect `call word [bp+2]`; added edge-case tests (NULL + count==0); fixed BX corruption bug (switched table pointer to BP); all 6/6 tests PASS in QEMU, verified 512-byte size + 0xAA55 signature |
| 2026-08-25 | Added custom 16-bit kernel (`boot/kernel.asm`): stage-2 kernel loaded by the bootloader at 0x8000. Implements a non-BIOS VGA-text kernel console (0xB8000) whose screen-clear uses `memzero16`; demos all 5 ported memory routines + NULL-safety + count==0 edge cases on a scratch buffer with a `buf_chk` verifier, printing `[OK]`/`[FAIL]`; chars also teed to serial 0x3F8 for `-nographic` observability. Bootloader trimmed to a 512-byte stage-1 loader (int 13h read + far-jmp; disk-error via BIOS teletype). `boot/Makefile` now builds `disk.img` (boot.bin + sector-padded kernel.bin) and computes `KERNEL_SECTORS` automatically. Verified 8/8 PASS in QEMU, zero warnings. |
| 2026-08-25 | **32-bit protected-mode kernel** added (`os/`): 12-syscall ABI (`int 0x80` via `pusha`+`call` in `isr80.asm` → `syscall_dispatch` in `syscalls.c`), VGA text-mode console (`console.c`: 0xB8000 + PS/2 polled keyboard + COM1 serial tee), userside C shell (`shell.c`) with `xtoi`/`next_token` parser, `usys.S` int 0x80 wrappers, `link.ld` flat-binary at 0x100000, `stage1.asm` 16-bit stub (reads 1 sector into 0x8000). Kernel links & builds with 0 warnings. |
| 2026-08-25 | **Repo hygiene**: added `os/.gitignore` excluding `.o`/`.bin`/`.elf`/`.img` build artifacts; removed 15 previously-tracked binary files from git; updated `BUILD_OUTPUT.log` with full rebuild & test verification log. All builds pass: libmem 10/10 tests, boot 6/6 QEMU, Next.js typecheck+lint clean. Committed as `81b94aa`. |

## Current Focus

The Next.js 16 starter template is ready. The modular x86-32 memory library (`libmem/`)
has been completed across all 5 phases:

1. `memset` — forward byte fill with NULL guard
2. `memzero` — forward zero-fill via `memset` delegation
3. `memset_rev` / `memzero_rev` — backward fill/zero via `memset_rev` delegation
4. `libmymem.a` — general memory routines archive
5. `libmysecure.a` — isolated secure stack wipe preventing DSE

### boot/ — two-stage boot stack (stage-1 loader + stage-2 custom kernel)

- **Stage 1 (`boot/boot.asm`)**: a 512-byte BIOS boot sector. Sets up 16-bit
  real mode, captures the boot drive (DL), reads the kernel from sectors 2+
  via BIOS `int 13h/ah=02h` into physical `0x8000`, and far-jumps into it.
  Reports disk-read failure via the BIOS teletype. Exactly 512 bytes, `55 AA`
  signature, zero warnings.
- **Stage 2 (`boot/kernel.asm`)**: a custom 16-bit kernel that owns a
  NON-BIOS kernel console — the VGA text buffer at `0xB8000`, driven by the
  ported memory routines (`memzero16` clears the 4000-byte video buffer). It
  demos every routine on a scratch buffer (with a `buf_chk` verifier) and
  prints `[OK]`/`[FAIL]` lines; each character is also teed to serial `0x3F8`
  for observability. Adds NULL-safety + count==0 edge demonstrations so no
  coverage was lost when the on-boot self-test moved into the kernel.

Build: `make` in `boot/` produces `disk.img` (boot sector + sector-padded
kernel). `make run` launches QEMU; kernel console reports **8/8 PASS**.

## Quick Start Guide

### To add a new page:

Create a file at `src/app/[route]/page.tsx`:
```tsx
export default function NewPage() {
  return <div>New page content</div>;
}
```

### To add components:

Create `src/components/` directory and add components:
```tsx
// src/components/ui/Button.tsx
export function Button({ children }: { children: React.ReactNode }) {
  return <button className="px-4 py-2 bg-blue-600 text-white rounded">{children}</button>;
}
```

### To add a database:

Follow `.kilocode/recipes/add-database.md`

### To add API routes:

Create `src/app/api/[route]/route.ts`:
```tsx
import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({ message: "Hello" });
}
```

## Available Recipes

| Recipe | File | Use Case |
|--------|------|----------|
| Add Database | `.kilocode/recipes/add-database.md` | Data persistence with Drizzle + SQLite |

## Pending Improvements

- [ ] Add more recipes (auth, email, etc.)
- [ ] Add example components
- [ ] Add testing setup recipe

## Recently Completed

- [x] Base Next.js 16 setup with App Router
- [x] TypeScript configuration with strict mode
- [x] Tailwind CSS 4 integration
- [x] ESLint configuration
- [x] Memory bank documentation
- [x] Recipe system for common features
- [x] **Phase 1**: `memset.asm` — forward fill (byte-by-byte, `inc edi` / `dec ecx`)
- [x] **Phase 2**: `memzero.asm` — forward zeroing (delegates to `memset`)
- [x] **Phase 3**: `memset_rev.asm` + `memzero_rev.asm` — backward fill/zeroing (delegates to `memset_rev`)
- [x] **Phase 4**: `mymem.h` header + `Makefile` → `libmymem.a`
- [x] **Phase 5**: `secure_wipe_stack_rev.asm` → `libmysecure.a` (delegates to `memset_rev`)
- [x] C test harness `test_link.c` — 8 functional tests, zero warnings, links `libmymem.a` + `libmysecure.a`
- [x] C test harness `test_suite.c` — 10-test comprehensive colour-coded harness
- [x] **Epic colour-coded `README.md`** added to repo root covering both Next.js frontend and libmem assembly library
- [x] **BIOS boot stack** (`boot/`) — stage-1 loader (`boot.asm`, 512-byte boot sector, `0xAA55`) reads the custom stage-2 kernel (`kernel.asm`) from sectors 2+ via BIOS `int 13h` into `0x8000` and far-jumps into it; the kernel owns a non-BIOS VGA-text console (cleared with `memzero16`) that demos all 5 ported memory routines + NULL-safety + count==0 edge cases and prints `[OK]`; **8/8 PASS** in QEMU, zero warnings
- [x] **32-bit protected mode kernel** (`os/`) — 12-syscall `int 0x80` ABI (`isr80.asm` → `syscalls.c`), VGA 0xB8000 console + PS/2 keyboard + COM1 tee (`console.c`), userside shell (`shell.c`), linker script (`link.ld` at 0x100000), stage1 stub (`stage1.asm`)
- [x] **Repo hygiene** — `os/.gitignore` added; removed 15 tracked binary artifacts from git; updated `BUILD_OUTPUT.log`

## Session History

| Date | Changes |
|------|---------|
| Initial | Template created with base setup |
| 2026-08-24 | Built modular 32-bit x86 memory library (`libmem/`) across 5 phases: memset, memzero, memset_rev, memzero_rev, secure_wipe_stack_rev — assembled via NASM -f elf32, archived into `libmymem.a` + `libmysecure.a`, verified with C test harness (8 tests + 10-test colour-coded suite, zero warnings) |
| 2026-08-24 | Created epic colour-coded `README.md` in repo root documenting both the Next.js 16 frontend stack and the libmem assembly library, including architecture diagrams, phase-by-phase build notes, DSE-prevention explanation, and full test results table |
| 2026-08-24 | Bootloaded restructured: modular 16-bit .asm files (memset/memzero/memset_rev/memzero_rev/secure_wipe) with global/extern directives, %include'd into boot.asm; table-driven test runner with indirect `call word [bp+2]`; added edge-case tests (NULL + count==0); fixed BX corruption bug (switched table pointer to BP); all 6/6 tests PASS in QEMU, verified 512-byte size + 0xAA55 signature |
| 2026-08-25 | Added custom 16-bit kernel (`boot/kernel.asm`): stage-2 kernel loaded by the bootloader at 0x8000. Implements a non-BIOS VGA-text kernel console (0xB8000) whose screen-clear uses `memzero16`; demos all 5 ported memory routines + NULL-safety + count==0 edge cases on a scratch buffer with a `buf_chk` verifier, printing `[OK]`/`[FAIL]`; chars also teed to serial 0x3F8 for `-nographic` observability. Bootloader trimmed to a 512-byte stage-1 loader (int 13h read + far-jmp; disk-error via BIOS teletype). `boot/Makefile` now builds `disk.img` (boot.bin + sector-padded kernel.bin) and computes `KERNEL_SECTORS` automatically. Verified 8/8 PASS in QEMU, zero warnings. |
| 2026-08-25 | **32-bit protected-mode kernel** added (`os/`): 12-syscall ABI (`int 0x80` via `pusha`+`call` in `isr80.asm` → `syscall_dispatch` in `syscalls.c`), VGA text-mode console (`console.c`: 0xB8000 + PS/2 polled keyboard + COM1 serial tee), userside C shell (`shell.c`) with `xtoi`/`next_token` parser, `usys.S` int 0x80 wrappers, `link.ld` flat-binary at 0x100000, `stage1.asm` 16-bit stub (reads 1 sector into 0x8000). Kernel links & builds with 0 warnings. |
| 2026-08-25 | **Repo hygiene**: added `os/.gitignore` excluding `.o`/`.bin`/`.elf`/`.img` build artifacts; removed 15 previously-tracked binary files from git; updated `BUILD_OUTPUT.log` with full rebuild & test verification log. All builds pass: libmem 10/10, boot 6/6 QEMU, Next.js typecheck+lint clean. Committed as `81b94aa`. |
