# Active Context: Next.js Starter Template

## Current State

**Template Status**: ✅ Ready for development

The template is a clean Next.js 16 starter with TypeScript and Tailwind CSS 4. It's ready for AI-assisted expansion to build any type of application.

## Recently Completed

## Current State

**All builds & tests pass.** Phase 2 libmem expansion complete (9 general + 2 secure functions, 17 tests).

### Build & Test Results (2026-08-27)

| Component | Build | Run |
|-----------|-------|-----|
| `libmem/` (32-bit x86 memory library, 26 functions in libmymem.a + 2 in libmysecure.a) | ✅ 0 warnings | ✅ **27/27 tests PASS** (test_suite), **24/24 tests PASS** (test_link) |
| `os/` (32-bit protected-mode kernel) | ✅ 0 warnings | Builds (28 syscalls + int 0x81 signal + int 0x0D GPF) |
| `boot/` (16-bit BIOS boot stack) | ✅ 0 warnings | ✅ 6/6 + edge cases PASS in QEMU |
| Next.js 16 frontend | ✅ typecheck + lint clean | N/A |
| `sanity_check.sh` | ✅ All checks passed | |
| `regression_test.sh` | ✅ 4/4 commits PASS | |
| Git push | ✅ Pushed to `6d0796d` | |

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
- [x] **Phase 2 expansion**: `memcpy`, `memmove` (overlap-safe), `memcmp`, `memchr`, `memsetw` → `libmymem.a`; `secure_wipe_heap_rev` → `libmysecure.a`; tests expanded to 17 (suite) / 14 (link), all PASS
- [x] **32-bit protected-mode kernel** (`os/`): 18 syscalls via `int 0x80` (DPL=3), signal interrupt `int 0x81` (`isr81.asm`) for `SIG_LIBMEM_READY`/`SIG_LIBMEM_WIPE`, `kmain` triggers libmem readiness signal, shell commands for all new functions, `libmymem.a` functions exposed only through syscall interface
- [x] **Repo hygiene**: `os/.gitignore` added; removed tracked binary artifacts; `BUILD_OUTPUT.log` updated; `sanity_check.sh` added
- [x] **Phase 3 expansion (2026-08-27)**: 10 more GP functions in `libmymem.a`: `memfill`, `memswap`, `memreverse`, `memrotate_l`/`r` (triple-reverse algo), `memfind`, `memcount`, `memchecksum`, `memeq`, `memmove_rev` — now 26 functions total in libmymem.a
- [x] **28 syscalls** in os kernel (SYS 1-28 via `int 0x80`); 10 new syscalls (19-28) for Phase 3 functions; shell extended with all new commands
- [x] **GPF exception handler** (`isr_gpf.asm`, vector 0x0D): software GPF logs+iret (non-fatal), hardware GPF logs+halt; installed in IDT alongside `int 0x80`/`0x81`
- [x] **`SIG_LIBMEM_TEST_ALL`** signal: runs all 21 libmem functions through kernel dispatch with GPF exception handling as a bare-metal smoke test
- [x] **test_suite.c**: 17→27 tests (all PASS); **test_link.c**: 14→24 tests (all PASS)
- [x] **`regression_test.sh`**: root-level git history backtest — extracts libmem/ at each commit, builds, tests; 4/4 historical commits PASS
- [x] **README.md** updated: 32 functions documented, 28 syscalls, GPF handler docs, os/ deep-dive, regression_test docs

## Current Structure

| File/Directory | Purpose | Status |
|----------------|---------|--------|
| `src/app/page.tsx` | Home page | ✅ Ready |
| `src/app/layout.tsx` | Root layout | ✅ Ready |
| `src/app/globals.css` | Global styles | ✅ Ready |
| `.kilocode/` | AI context & recipes | ✅ Ready |
| `libmem/` | 32-bit x86 memory library (26 functions, 2 archives) | ✅ Built, 27/27 tests pass |
| `boot/` | 16-bit BIOS boot stack (stage-1 + stage-2 kernel) | ✅ Built, 6/6 tests pass in QEMU |
| `os/` | 32-bit protected-mode kernel: 28 syscalls + signal interrupt + GPF handler, VGA console, PS/2 keyboard, shell | ✅ Builds, 0 warnings |
| `sanity_check.sh` | Root build + test verification script | ✅ All checks pass |
| `regression_test.sh` | Git history backtest for libmem (4/4 PASS) | ✅ All commits pass |

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
  4. `libmymem.a` — general memory routines archive (26 functions)
  5. `libmysecure.a` — isolated secure stack/heap wipe preventing DSE
  6. Phase 3: `memfill`, `memswap`, `memreverse`, `memrotate_l`/`r`, `memfind`,
     `memcount`, `memchecksum`, `memeq`, `memmove_rev` — kernel syscalls 19-28
  7. GPF exception handler (vector 0x0D) — bare-metal exception handling

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
- [x] **Phase 2 expansion** (2026-08-26): `memcpy`, `memmove`, `memcmp`, `memchr`, `memsetw` → `libmymem.a`; `secure_wipe_heap_rev` → `libmysecure.a`; tests 17/14 → 17/14; 18 syscalls
- [x] **Phase 3 expansion** (2026-08-27): 10 new GP functions — `memfill`, `memswap`, `memreverse`, `memrotate_l`/`memrotate_r`, `memfind`, `memcount`, `memchecksum`, `memeq`, `memmove_rev`; now 26 functions in `libmymem.a`
- [x] **28 syscalls**: 10 new SYS_ numbers (19-28) for Phase 3 functions; `shell.c` + `usys.S` + `usys.h` extended
- [x] **GPF exception handler** (`isr_gpf.asm`, vector 0x0D): simple bare-metal exception handling — software GPF logs to serial + iret (non-fatal), hardware GPF logs + halts
- [x] **`SIG_LIBMEM_TEST_ALL`** signal: `signal_dispatch` runs all 21 functions through kernel dispatch with GPF exception handling as smoke test; triggered from `kmain()` during init
- [x] **test_suite.c**: 17→27 tests (all PASS); **test_link.c**: 14→24 tests (all PASS)
- [x] **`regression_test.sh`**: root-level git history backtest — extracts libmem/ at each commit, builds, tests; 4/4 historical commits PASS
- [x] **README.md** updated: 32 functions, 28 syscalls, GPF handler docs, os/ deep-dive, regression_test docs
- [x] **Committed as `6d0796d`**: 27 files changed, 1971 insertions — pushed to `iron-ram` main

## Session History

| Date | Changes |
|------|---------|
| Initial | Template created with base setup |
| 2026-08-24 | Built modular 32-bit x86 memory library (`libmem/`) across 5 phases: memset, memzero, memset_rev, memzero_rev, secure_wipe_stack_rev — assembled via NASM -f elf32, archived into `libmymem.a` + `libmysecure.a`, verified with C test harness (8 tests + 10-test colour-coded suite, zero warnings) |
| 2026-08-24 | Created epic colour-coded `README.md` in repo root documenting both the Next.js 16 frontend stack and the libmem assembly library, including architecture diagrams, phase-by-phase build notes, DSE-prevention explanation, and full test results table |
| 2026-08-24 | Bootloaded restructured: modular 16-bit .asm files (memset/memzero/memset_rev/memzero_rev/secure_wipe) with global/extern directives, %include'd into boot.asm; table-driven test runner with indirect `call word [bp+2]`; added edge-case tests (NULL + count==0); fixed BX corruption bug (switched table pointer to BP); all 6/6 tests PASS in QEMU, verified 512-byte size + 0xAA55 signature |
| 2026-08-25 | Added custom 16-bit kernel (`boot/kernel.asm`): stage-2 kernel loaded by the bootloader at 0x8000. Implements a non-BIOS VGA-text kernel console (0xB8000) whose screen-clear uses `memzero16`; demos all 5 ported memory routines + NULL-safety + count==0 edge cases on a scratch buffer with a `buf_chk` verifier, printing `[OK]`/`[FAIL]`; chars also teed to serial 0x3F8 for `-nographic` observability. Bootloader trimmed to a 512-byte stage-1 loader (int 13h read + far-jmp; disk-error via BIOS teletype). `boot/Makefile` now builds `disk.img` (boot.bin + sector-padded kernel.bin) and computes `KERNEL_SECTORS` automatically. Verified 8/8 PASS in QEMU, zero warnings. |
| 2026-08-25 | **32-bit protected-mode kernel** added (`os/`): 12-syscall ABI (`int 0x80` via `pusha`+`call` in `isr80.asm` → `syscall_dispatch` in `syscalls.c`), VGA text-mode console (`console.c`: 0xB8000 + PS/2 polled keyboard + COM1 serial tee), userside C shell (`shell.c`) with `xtoi`/`next_token` parser, `usys.S` int 0x80 wrappers, `link.ld` flat-binary at 0x100000, `stage1.asm` 16-bit stub (reads 1 sector into 0x8000). Kernel links & builds with 0 warnings. |
| 2026-08-25 | **Repo hygiene**: added `os/.gitignore` excluding `.o`/`.bin`/`.elf`/`.img` build artifacts; removed 15 previously-tracked binary files from git; updated `BUILD_OUTPUT.log` with full rebuild & test verification log. All builds pass: libmem 10/10 tests, boot 6/6 QEMU, Next.js typecheck+lint clean. Committed as `81b94aa`. |
| 2026-08-27 | **Phase 2 libmem expansion**: added `memcpy`, `memmove` (overlap-safe backward/forward), `memcmp`, `memchr`, `memsetw` to `libmymem.a`; added `secure_wipe_heap_rev` to `libmysecure.a`. Tests expanded: `test_suite.c` 10→17, `test_link.c` 8→14, all PASS (0 warnings). Extended os kernel syscall table 12→18 (`int 0x80` DPL=3). Added signal interrupt `int 0x81` (`isr81.asm`) with `SIG_LIBMEM_READY`/`SIG_LIBMEM_WIPE` — kernel-initiated signal path. `kmain.c` triggers libmem readiness signal during init. Shell extended with commands for all 6 new functions. Added `sanity_check.sh` root script. Committed as `ca635b7`. |
| 2026-08-27 | **Phase 3 expansion**: 10 new GP functions (`memfill`, `memswap`, `memreverse`, `memrotate_l`/`memrotate_r`, `memfind`, `memcount`, `memchecksum`, `memeq`, `memmove_rev`) in `libmymem.a`; now 26 functions total. Added 10 syscalls (SYS 19-28). **GPF exception handler** (`isr_gpf.asm`, vector 0x0D) for bare-metal exception handling — software GPF logs+iret (non-fatal), hardware GPF logs+halt. **`SIG_LIBMEM_TEST_ALL`** signal runs all 21 functions through kernel dispatch. Tests: `test_suite.c` 17→27 PASS, `test_link.c` 14→24 PASS. Added **`regression_test.sh`** git history backtest (4/4 commits PASS). Committed as `6d0796d` (27 files, 1971 insertions, pushed to `iron-ram` main). |
