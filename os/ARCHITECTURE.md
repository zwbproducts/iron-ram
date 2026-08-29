# iron-ram Architecture Document

**Target:** 32-bit x86 protected mode
**Emulator:** QEMU 6.2.0 (`qemu-system-x86_64 -drive format=raw,file=disk.img -nographic`)
**Boot protocol:** Custom bootloader (stage1.asm) loads kernel + userland from disk

---

## 1. Memory Map

| Region | Address Range | Size | Owner | Description |
|--------|---------------|------|-------|-------------|
| Boot sector | 0x7C00 - 0x7DFF | 512B | Bootloader | Stage 1 boot code |
| Kernel code | 0x100000 - 0x102B8F | ~11KB | Kernel | .text section |
| Kernel rodata | 0x102B90 - 0x103B42 | ~4KB | Kernel | .rodata section |
| Kernel data | 0x103B44 - 0x107B49 | ~16KB | Kernel | .data section |
| Kernel BSS | 0x107B60 - 0x1083E4 | ~2KB | Kernel | .bss section |
| Userland code | 0x200000 - 0x200FFF | ~4KB | Userland | User shell |
| Kernel stack | 0x9FC00 - 0x9FFFF | ~1KB | Kernel | Grows downward |
| User stack | 0x90000 - 0x9FFFF | ~64KB | Userland | Grows downward |
| VGA memory | 0xB8000 - 0xBFFFF | ~32KB | Hardware | Text mode video |
| GDT | 0x900 - 0x927 | 40B | Bootloader | 5 entries × 8 bytes |
| IDT | 0x103B44+ | 2KB | Kernel | 256 entries × 8 bytes |

---

## 2. GDT Layout

| Index | Selector | Base | Limit | DPL | Type |
|-------|----------|------|-------|-----|------|
| 0 | 0x00 | - | - | - | Null |
| 1 | 0x08 | 0 | 4GB | 0 | Kernel code |
| 2 | 0x10 | 0 | 4GB | 0 | Kernel data |
| 3 | 0x1B | 0 | 4GB | 3 | User code |
| 4 | 0x23 | 0 | 4GB | 3 | User data |

---

## 3. Syscall Interface

### Mechanism
- **Entry:** `int 0x80` (interrupt gate, DPL=3 for userland)
- **Handler:** `isr80_handler` in `os/kernel/isr80.asm`
- **Dispatcher:** `syscall_dispatch()` in `os/kernel/syscalls.c`

### Calling Convention
| Register | Purpose |
|----------|---------|
| EAX | Syscall number (input) / Return value (output) |
| EBX | Argument 0 |
| ECX | Argument 1 |
| EDX | Argument 2 |

### Syscall Numbers
| # | Name | Description | Status |
|---|------|-------------|--------|
| 0 | SYS_MEM_STATUS | Return magic number (0xDEADBEEF) | ✓ Implemented |
| 1 | SYS_PUTC | Output character to serial | ✓ Implemented |
| 2 | SYS_PUTS | Output string to serial | ✓ Implemented |
| 3 | SYS_GETC | Read character | Planned |
| 4 | SYS_GETS | Read string | Planned |
| 5 | SYS_MEMSET | Fill memory | ✓ Implemented |
| 6 | SYS_MEMCPY | Copy memory | ✓ Implemented |
| 7 | SYS_MEMMOV | Move memory (overlap-safe) | ✓ Implemented |
| 8 | SYS_MEMCMP | Compare memory | ✓ Implemented |
| 9 | SYS_MEMCHR | Find byte in memory | Planned |
| 10 | SYS_HEAP_ALLOC | Allocate heap memory | Planned |
| 11 | SYS_HEAP_FREE | Free heap memory | Planned |
| 12 | SYS_SEC_WIPE | Secure wipe memory | Planned |

---

## 4. Userland/Kernel Boundary

### Kernel-Owned (NOT exported to userland)
- All `kern_*` functions in `syscalls.c`
- All `console_*` functions in `console.c`
- All `memset`, `memcpy`, etc. from `libmem/`
- `syscall_dispatch()` function

### Userland-Accessible (exported via usys.S)
- `usys_mem_status()` → SYS_MEM_STATUS
- `usys_putc()` → SYS_PUTC
- `usys_puts()` → SYS_PUTS
- `usys_getc()` → SYS_GETC
- `usys_gets()` → SYS_GETS
- `usys_memset()` → SYS_MEMSET
- `usys_memcpy()` → SYS_MEMCPY
- `usys_memmov()` → SYS_MEMMOV
- `usys_memcmp()` → SYS_MEMCMP
- `usys_memchr()` → SYS_MEMCHR
- `usys_heap_alloc()` → SYS_HEAP_ALLOC
- `usys_heap_free()` → SYS_HEAP_FREE
- `usys_sec_wipe()` → SYS_SEC_WIPE

### Enforcement
1. **Build-time:** `verify-shell` target uses `nm -u` to prove `shell.o` only references `usys_*` symbols
2. **Link-time:** Kernel and userland are separate ELF binaries with separate symbol tables
3. **Runtime:** Userland runs in ring 3, can only access kernel via `int 0x80` (DPL=3 gate)
4. **Memory:** Userland cannot access kernel memory (page-level protection could be added)

---

## 5. Boot Sequence

```
1. BIOS loads boot sector at 0x7C00
2. Boot sector (stage1.asm):
   a. Enable A20 gate
   b. Load kernel from disk sectors 2+ to 0x8000
   c. Load userland from disk after kernel to 0x1000
   d. Copy kernel from 0x8000 to 0x100000
   e. Copy userland from 0x1000 to 0x200000
   f. Build GDT with kernel + user segments
   g. Switch to protected mode
   h. Jump to kernel _start at 0x100000
3. Kernel _start (entry.asm):
   a. Zero BSS
   b. Install IDT (int 0x80 handler)
   c. Call kmain()
4. kmain():
   a. Initialize console
   b. Print boot message
   c. Halt (or jump to userland in future)
```

---

## 6. 28-Command Plan

### Classification

| Command | Type | Syscall | Description |
|---------|------|---------|-------------|
| help | Userland | - | Print command list |
| status | Syscall | SYS_MEM_STATUS | Get kernel status |
| echo | Userland | - | Echo arguments |
| putc | Syscall | SYS_PUTC | Output character |
| puts | Syscall | SYS_PUTS | Output string |
| getc | Syscall | SYS_GETC | Read character |
| gets | Syscall | SYS_GETS | Read string |
| memset | Syscall | SYS_MEMSET | Fill memory |
| memcpy | Syscall | SYS_MEMCPY | Copy memory |
| memmov | Syscall | SYS_MEMMOV | Move memory |
| memcmp | Syscall | SYS_MEMCMP | Compare memory |
| memchr | Syscall | SYS_MEMCHR | Find byte |
| memfill | Syscall | SYS_MEMSET | Pattern fill |
| memswap | Userland | - | Swap two regions |
| memreverse | Userland | - | Reverse bytes |
| memrotate_l | Userland | - | Left rotation |
| memrotate_r | Userland | - | Right rotation |
| memfind | Syscall | SYS_MEMCHR | Find byte offset |
| memcount | Userland | - | Count occurrences |
| memchecksum | Userland | - | XOR checksum |
| memeq | Userland | - | Boolean equality |
| memmove_rev | Userland | - | Backward copy |
| heap_alloc | Syscall | SYS_HEAP_ALLOC | Allocate memory |
| heap_free | Syscall | SYS_HEAP_FREE | Free memory |
| sec_wipe | Syscall | SYS_SEC_WIPE | Secure wipe |
| secinfo | Userland | - | Security model info |
| cls | Userland | - | Clear screen (local) |
| peek | Userland | - | Peek memory (local) |
| halt | Userland | - | Halt system |

### Implementation Priority

**Phase 1 (Proof):** help, status, puts, halt
**Phase 2 (Basic):** getc, gets, putc, echo
**Phase 3 (Memory):** memset, memcpy, memcmp, memchr
**Phase 4 (Advanced):** sec_wipe, heap_alloc, heap_free
**Phase 5 (Remaining):** All other commands

---

## 7. Evidence Packet

### Required Evidence for Each Milestone

**A. Boot heartbeat reaches kernel entry**
- Serial output contains 'S' (from _start)
- Address: 0x100001

**B. Kernel initializes and prints marker**
- Serial output contains 'B' (BSS cleared), 'I' (IDT installed), 'P' (print done)
- Addresses: 0x100018, 0x100021, kmain+offset

**C. Syscall entry reached from userland stub**
- Userland code executes `int 0x80`
- isr80_handler receives control

**D. Dispatcher validates and routes**
- Syscall number checked against MAX_SYSCALLS
- Jump table dispatches to correct kernel function

**E. Kernel implementation runs and returns**
- Kernel function executes, returns result in EAX

**F. Userland prints returned result**
- Userland receives EAX value, outputs to serial

**G. Negative control - direct kernel call fails**
- Attempt to call kernel function directly causes GPF
- OR: Linker refuses to resolve kernel symbol from userland

**H. Positive control - syscall succeeds**
- Syscall returns expected value (0xDEADBEEF for SYS_MEM_STATUS)

**I. Trace evidence**
- Caller address (userland)
- Entry point (isr80_handler)
- Syscall number (EAX)
- Arguments (EBX, ECX, EDX)
- Selected kernel function (from jump table)
- Return value (EAX)
- No direct-call path (verified by nm)

---

## 8. Known Issues

### Issue: C function calls from kmain hang
- **Symptom:** `call console_init` from kmain does not return
- **Evidence:** Inline assembly in kmain works (serial shows 'M')
- **Hypothesis:** C calling convention issue, possibly stack alignment
- **Workaround:** Use inline assembly for critical path until root cause is found

### Issue: Kernel copy loop was copying only half
- **Symptom:** `shl cx, 7` copied ×128 words/sector instead of ×256
- **Fix:** Changed to `shl cx, 8`
- **Status:** Fixed

---

## 9. Assumptions

1. **QEMU serial port:** COM1 at 0x3F8, already initialized by QEMU
2. **A20 gate:** Enabled via port 0x92 (fast A20)
3. **GDT location:** Built at 0x900 by bootloader, persists after PM switch
4. **Stack validity:** 0x9FC00 is in writable memory below kernel
5. **Ring transition:** IRET from kernel to userland works with proper stack frame
6. **Calling convention:** cdecl (stack-based, caller cleanup) for both kernel and userland

---

## 10. Test Results

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Boot sector loads | 'S' in serial | 'S' in serial | ✓ Pass |
| Kernel loads | 'L', 'K' in serial | 'L', 'K' in serial | ✓ Pass |
| Kernel copies | 'C' in serial | 'C' in serial | ✓ Pass |
| PM switch | 'P', 'Q' in serial | 'P', 'Q' in serial | ✓ Pass |
| Kernel entry | 'S', 'B', 'I' in serial | 'S', 'B', 'I' in serial | ✓ Pass |
| C function calls | 'M', 'I', 'C', 'P' in serial | 'M' only | ✗ Fail |
| Syscall path | Not tested | Not tested | Pending |
