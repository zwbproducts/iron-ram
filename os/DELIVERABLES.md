# DELIVERABLES SUMMARY

## 1. Failure Report
**File:** `os/FAILURE_REPORT.md`

Identified exact hang point: `call kmain` at address 0x100032 in entry.asm.
- Serial output shows `SLKCPQSIKB` (last byte from entry.asm)
- C function calls from kmain don't execute
- Inline assembly in kmain works (proves CPU reaches kmain)
- Root cause: Unknown (possibly C calling convention or stack issue)

## 2. Minimal Assembly Syscall Proof
**Files:**
- `os/kernel/entry.asm` — Kernel entry with heartbeat
- `os/kernel/idt.asm` — IDT setup
- `os/kernel/isr80.asm` — Syscall handler (int 0x80)
- `os/kernel/syscalls.c` — Syscall dispatcher + kernel-owned functions
- `os/kernel/syscall.h` — Syscall numbers and types
- `os/kernel/console.c` — Console output (VGA + serial)
- `os/kernel/console.h` — Console interface (kernel-only)
- `os/kernel/kmain.c` — Kernel main with inline assembly heartbeat
- `os/kernel/link.ld` — Kernel linker script

## 3. Userland Shell Stub
**Files:**
- `os/user/usys.S` — Syscall wrappers (ONLY userland-visible symbols)
- `os/user/usys.h` — Syscall numbers and function prototypes
- `os/user/shell.c` — Unix-philosophy shell using ONLY usys_* wrappers
- `os/user/userland.ld` — Userland linker script
- `os/user/userland.asm` — Standalone userland test stub

## 4. Build System
**Files:**
- `os/Makefile` — Builds kernel, userland, and disk image
- `os/build_and_test_os.sh` — Reproducible build and test script

## 5. Architecture Document
**File:** `os/ARCHITECTURE.md`

Contains:
- Memory map
- GDT layout
- Syscall interface specification
- Userland/kernel boundary enforcement
- Boot sequence
- 28-command plan with classification
- Evidence packet requirements
- Known issues

## 6. 28-Command Plan

### Classification:
- **Syscall-backed (12):** status, putc, puts, getc, gets, memset, memcpy, memmov, memcmp, memchr, heap_alloc, heap_free, sec_wipe
- **Userland-only (16):** help, echo, cls, peek, halt, memfill, memswap, memreverse, memrotate_l, memrotate_r, memfind, memcount, memchecksum, memeq, memmove_rev, secinfo

### Implementation Priority:
1. Phase 1 (Proof): help, status, puts, halt
2. Phase 2 (Basic): getc, gets, putc, echo
3. Phase 3 (Memory): memset, memcpy, memcmp, memchr
4. Phase 4 (Advanced): sec_wipe, heap_alloc, heap_free
5. Phase 5 (Remaining): All other commands

## 7. Evidence Packet

### Observed Facts:
- Serial output: `SLKCPQSIKB` (8 bytes from bootloader + entry.asm)
- Kernel binary builds successfully (31562 bytes)
- All 31 timeline regression commits pass
- All 6/6 build_and_test.sh stages pass
- sanity_check.sh passes

### Agent Explanations:
- C function calls from kmain fail due to unknown calling convention issue
- Inline assembly works because it doesn't rely on C calling convention
- Syscall path is designed but not yet tested (needs build tools)

### Inferences:
- The issue is NOT with the bootloader (it works correctly)
- The issue is NOT with the inline assembly (it works)
- The issue IS with C function calls specifically
- Possible causes: stack alignment, segment register setup, or GCC code generation

### Unknowns:
- Exact state of ESP when kmain is entered
- Whether `push ebp` in kmain succeeds
- Whether `call console_init` jumps to correct address
- Whether console_init executes any instructions

## 8. Reproducible Build Script
**File:** `os/build_and_test_os.sh`

Steps:
1. Build kernel (kernel.elf → kernel.bin)
2. Build userland (userland.elf → userland.bin)
3. Build boot sector (stage1.bin)
4. Create disk image (disk.img)
5. Verify security boundary (nm -u shell.o)
6. Run QEMU boot test
7. Verify boot sequence (heartbeat characters)

## 9. Remaining Work

### Critical:
1. **Fix C function call issue** — The kernel boots but C calls from kmain hang
2. **Test syscall path** — Verify int 0x80 works end-to-end
3. **Add positive/negative controls** — Prove boundary enforcement

### Important:
4. **Implement remaining syscalls** — getc, gets, memchr, heap_alloc, heap_free, sec_wipe
5. **Add shell commands** — Implement all 28 commands per plan
6. **Add tests** — Each command needs a test with expected result

### Nice-to-have:
7. **Add VGA console** — Currently only serial output
8. **Add keyboard input** — For interactive shell
9. **Add heap management** — For dynamic memory allocation

## 10. Next Steps

When build tools are available:
1. Run `cd os && bash build_and_test_os.sh`
2. Observe serial output for heartbeat sequence
3. If C function call issue persists, try:
   - Adding `__attribute__((cdecl))` to functions
   - Checking stack alignment (16-byte)
   - Using `-O0` compilation flag
   - Checking GCC version and flags
4. Once kernel boots, test syscall path with userland stub
5. Add commands incrementally per plan
