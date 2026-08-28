# Active Context: iron-ram (libmem + os + boot + Next.js)

## Current State

**All builds & tests pass.** Full system complete: 19 libmem functions + 2 secure, 28 syscalls, 17 QEMU boot demos, security boundary enforcement.

### Build & Test Results (2026-08-28)

| Component | Build | Run |
|-----------|-------|-----|
| `libmem/` (32-bit x86 memory library, 19 functions in libmymem.a + 2 in libmysecure.a) | ✅ 0 warnings | ✅ **27/27 tests PASS** (test_suite), **24/24 tests PASS** (test_link) |
| `os/` (32-bit protected-mode kernel) | ✅ 0 warnings | Builds (28 syscalls + int 0x81 signal + int 0x0D GPF) |
| `boot/` (16-bit BIOS boot stack) | ✅ 0 warnings | ✅ **17/17 tests PASS** in QEMU (15 functions + NULL safety + count==0) |
| Security boundary | ✅ shell.c: 0 direct kernel calls | All via usys_* wrappers → int 0x80 |
| Next.js 16 frontend | ✅ typecheck + lint clean | N/A |
| `build_and_test.sh` | ✅ All checks pass | 6/6 stages pass |
| `sanity_check.sh` | ✅ All checks pass | |
| `regression_test.sh` | ✅ 4/4 commits PASS | |
| `timeline_regression.sh` | ✅ 23/23 commits PASS | Full timeline + coverage evolution |

## Current Focus

The iron-ram system is complete with:

1. **libmem/** — 19 general-purpose memory functions in `libmymem.a` + 2 secure wipes in `libmysecure.a`
2. **os/** — 32-bit kernel with 28 syscalls, signal interrupt (int 0x81), GPF handler (int 0x0D)
3. **boot/** — 16-bit BIOS boot stack with 17 QEMU demos (15 functions + 2 edge cases)
4. **Security** — shell.c enforces strict userland/kernel separation via syscall wrappers only
5. **build_and_test.sh** — one-command full build + test pipeline with security verification

### Security Model

- **shell.c** NEVER calls libmem or console_* functions directly
- **EVERY** kernel service is reached exclusively through `usys_*` wrappers → `int 0x80`
- **Linker-enforced boundary**: shell.o is verified via `nm -u` to reference ONLY `usys_*` symbols — zero kernel function symbols
- **Runtime audit logging**: every `int 0x80` syscall is logged with a monotonic audit ID and syscall number
- **int 0x81** (signals) is kernel-only, used during boot (kmain.c) to verify libmem staging
- **int 0x0D** (GPF) catches invalid memory accesses and logs them
- Build scripts verify 0 direct kernel function calls from shell.c
- Makefile `verify-shell` target uses `nm -u` to prove shell.o only references usys_* symbols

## Quick Start

```bash
./build_and_test.sh           # full build + test pipeline
./build_and_test.sh --qemu    # also launch interactive QEMU
./sanity_check.sh             # sanity checks only
./regression_test.sh          # git history backtest (libmem)
./timeline_regression.sh      # full timeline + all-commit backtest
```

## Session History

| Date | Changes |
|------|---------|
| 2026-08-24 | Built modular 32-bit x86 memory library (`libmem/`) across 5 phases |
| 2026-08-24 | Created epic colour-coded `README.md` |
| 2026-08-24 | Bootloaded restructured: modular 16-bit .asm files |
| 2026-08-25 | Added custom 16-bit kernel (`boot/kernel.asm`) |
| 2026-08-25 | **32-bit protected-mode kernel** added (`os/`) |
| 2026-08-25 | **Repo hygiene** — `os/.gitignore` added |
| 2026-08-27 | **Phase 2 libmem expansion**: memcpy, memmove, memcmp, memchr, memsetw |
| 2026-08-27 | **Phase 3 expansion**: memfill, memswap, memreverse, memrotate_l/r, memfind, memcount, memchecksum, memeq, memmove_rev |
| 2026-08-27 | **28 syscalls** + GPF handler + SIG_LIBMEM_TEST_ALL |
| 2026-08-27 | **regression_test.sh** — git history backtest |
| 2026-08-28 | **boot/** expanded to 17 demos (all 15 functions + 2 edge cases) — all PASS in QEMU |
| 2026-08-28 | **kmain.c** enumerates all 28 syscalls during boot verification |
| 2026-08-28 | **shell.c** rewritten with security boundary enforcement + secinfo command |
| 2026-08-28 | **build_and_test.sh** + **sanity_check.sh** with security verification |
| 2026-08-28 | **timeline_regression.sh** — comprehensive colour-coded full git history backtest with per-commit build + test for libmem/, os/, boot/; coverage evolution tracking; 23/23 commits PASS |
| 2026-08-28 | **timeline_regression.sh security audit** — added per-commit security invariant verification (A-F checks) across all commits; 26/26 SECURITY PASS |
| 2026-08-28 | **Fixed**: eliminated grep regex errors (ANSI color codes interpreted as character classes) — switched from `echo|grep` to `printf|grep` for color matching |
| 2026-08-28 | **Fixed**: false-positive F (bypass) checks — now strips comments and strings before searching shell.c for kernel function references |
| 2026-08-28 | **Security hardening**: shell.c rewritten as Unix-philosophy shell, runtime syscall audit logging, linker-enforced boundary via `nm -u` verification in Makefile + sanity_check.sh |

## Recently Completed

- [x] Fixed grep regex errors in timeline_regression.sh security audit (ANSI color codes no longer misinterpreted as regex character classes)
- [x] Fixed false-positive F-check bypass alerts (now strips block comments and string literals before scanning)
- [x] All 26 git commits pass security audit with zero false positives and zero errors
- [x] Rewrote shell.c as Unix-philosophy shell — all 28 commands route through usys_* wrappers only
- [x] Added runtime syscall audit logging in syscalls.c (monotonic ID + syscall number to serial)
- [x] Added `nm -u` verification of shell.o (0 non-usys undefined symbols)
- [x] Makefile `verify-shell` target enforces linker-level boundary at build time
- [x] sanity_check.sh includes nm-based undefined symbol verification
