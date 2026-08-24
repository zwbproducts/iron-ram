# Development Log — libmem Project

> **Project**: Modular 32-bit x86 Memory Library (NASM + GCC -m32)
> **Started**: 2026-08-24
> **Status**: ✅ Phase 1–5 Complete

---

## Overview

A modular 32-bit x86 memory library built with NASM assembly and C (GCC `-m32`,
cdecl calling convention). The architecture deliberately separates general memory
routines from security-critical functions to prevent compiler optimizations
(such as **Dead-Store Elimination**) from stripping security wipe calls.

---

## Phase 1 — Forward Fill (`memset.asm`)

<span style="color:#369631; font-weight:bold;">✅ COMPLETE</span>

| Detail | Value |
|--------|-------|
| **File** | `memset.asm` |
| **Prototype** | `void *memset(void *dest, int c, size_t count)` |
| **Stack frame** | Standard cdecl (`push ebp` / `mov ebp, esp`) |
| **Safety** | NULL `dest` check via `test edi, edi` |
| **Algorithm** | Byte-by-byte forward fill |
| **Key instructions** | `inc edi`, `dec ecx`, `jnz .fill_loop` |

### What was built

The function loads `dest` into `EDI`, the fill byte into `AL`, and `count` into
`ECX`. Before entering the fill loop it checks whether `dest` is `NULL` and
whether `count` is `0`, jumping to `.done` in either case. The main loop stores
`AL` at `[EDI]`, then advances `EDI` forward (`inc`) and decrements `ECX`
(`dec`) until `ECX` reaches zero (`jnz`).

### Key decisions

- **EDI saved/restored** (`push edi` / `pop edi`) because it is caller-saved in
  the i386 GCC ABI.
- **AL holds the fill byte** — `mov al, [ebp+12]` reads only the low byte of
  the `int c` argument, which is the correct semantics for `memset`.
- **Return value** — `mov eax, [ebp+8]` restores the original `dest` pointer in
  `EAX` at function exit.

---

## Phase 2 — Forward Zeroing (`memzero.asm`)

<span style="color:#369631; font-weight:bold;">✅ COMPLETE</span>

| Detail | Value |
|--------|-------|
| **File** | `memzero.asm` |
| **Prototype** | `void *memzero(void *dest, size_t count)` |
| **Strategy** | Delegates directly to `memset` |

### What was built

A thin wrapper that pushes three arguments onto the stack (right-to-left per
cdecl) and calls `memset`:

```nasm
push dword [ebp + 12]   ; count  (3rd arg)
push 0                  ; c = 0  (2nd arg)
push dword [ebp + 8]    ; dest   (1st arg)
call memset
add  esp, 12            ; caller cleanup
```

The return value from `memset` (in `EAX`) is passed through as `memzero`'s
return value.

---

## Phase 3 — Backward Fill & Zeroing

### 3a. `memset_rev.asm`

<span style="color:#369631; font-weight:bold;">✅ COMPLETE</span>

| Detail | Value |
|--------|-------|
| **File** | `memset_rev.asm` |
| **Prototype** | `void *memset_rev(void *dest, int c, size_t count)` |
| **Direction** | Backward (high address → low address) |
| **Start address** | `dest + count - 1` (via `lea edi, [edi + ecx - 1]`) |
| **Key instructions** | `dec edi`, `dec ecx`, `jnz .bwd_loop` |

### 3b. `memzero_rev.asm`

<span style="color:#369631; font-weight:bold;">✅ COMPLETE</span>

| Detail | Value |
|--------|-------|
| **File** | `memzero_rev.asm` |
| **Prototype** | `void *memzero_rev(void *dest, size_t count)` |
| **Strategy** | Delegates directly to `memset_rev` (same pattern as Phase 2) |

### What was built

`memset_rev` loads `dest`, fill byte, and count as in Phase 1, but before
entering the loop it computes `EDI = dest + count - 1` using a single `lea`
instruction. The loop then stores `AL` at `[EDI]`, decrements `EDI` (moving
backward), and decrements `ECX` until zero. The `count == 0` guard is critical
here — without it, `dest + count - 1` would underflow to `dest - 1`.

`memzero_rev` follows the exact same delegation pattern as `memzero`, calling
`memset_rev` with `c = 0`.

---

## Phase 4 — C Header & General Library Archive

<span style="color:#369631; font-weight:bold;">✅ COMPLETE</span>

### `mymem.h`

Exposes all five prototypes:

```c
void *memset(void *dest, int c, size_t count);
void *memzero(void *dest, size_t count);
void *memset_rev(void *dest, int c, size_t count);
void *memzero_rev(void *dest, size_t count);
void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count);
```

Includes `<stddef.h>` for `size_t`.

### `Makefile`

| Target | Description |
|--------|-------------|
| `all` | Assemble all `.asm` → `.o` via `nasm -f elf32`, archive into `libmymem.a` and `libmysecure.a` |
| `test` | Build and run the basic 8-test harness (`test_link.c`) |
| `test-suite` | Build and run the comprehensive 10-test harness (`test_suite.c`) |
| `clean` | Remove all build artifacts |

**Key build flags**:

| Flag | Purpose |
|------|---------|
| `-f elf32` | NASM output: 32-bit ELF object |
| `-m32` | GCC: generate 32-bit code |
| `-fno-builtin` | Prevent GCC from replacing `memset` with `__builtin_memset` (ensures our library is actually linked and tested) |
| `-fno-stack-protector` | Disable stack canaries (irrelevant for flat binary tests) |
| `-Wall -Wextra` | Enable all warnings |
| `ar rcs` | Create static archive with symbol index |

### Library symbols

**libmymem.a** (`ar rcs`):

```
T memset          ← exported
T memzero         ← exported
T memset_rev      ← exported
T memzero_rev     ← exported
```

**libmysecure.a** (`ar rcs`):

```
T secure_wipe_stack_rev  ← exported
U memset_rev             ← unresolved extern (resolved from libmymem.a at link time)
```

---

## Phase 5 — Secure Stack Unwinding (`secure_wipe_stack_rev.asm`)

<span style="color:#369631; font-weight:bold;">✅ COMPLETE</span>

| Detail | Value |
|--------|-------|
| **File** | `secure_wipe_stack_rev.asm` |
| **Library** | `libmysecure.a` (separate from `libmymem.a`) |
| **Prototype** | `void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count)` |
| **Strategy** | Delegates to `memset_rev` via `extern` declaration |

### DSE Prevention Architecture

```
┌─────────────────────┐     extern memset_rev     ┌─────────────────────┐
│  secure_wipe_stack  │ ─────────────────────────→│  memset_rev        │
│  (libmysecure.a)    │    (unresolved symbol in   │  (libmymem.a)      │
│                     │     object file, resolved   │                   │
│                     │     at final link)          │                   │
└─────────────────────┘                            └─────────────────────┘
        ▲                                                    ▲
        │                                                    │
   C compiler calls                                      Assembly
   secure_wipe_stack_rev                                 implementation
   as a BLACK BOX —                                        (no DSE possible
   no visibility into                                       here)
   the memset call)
```

Because `memset_rev` is an **external symbol** the C compiler cannot see,
the compiler treats the entire `secure_wipe_stack_rev` call as a black box
with unknown side effects. Dead-Store Elimination (DSE) — which might strip
`memset(buf, 0, n)` calls when the compiler can see the buffer is never read
again — **cannot** eliminate the wipe through this boundary.

### Why a separate library?

By placing `secure_wipe_stack_rev` in `libmysecure.a` (not `libmymem.a`), the
security boundary is enforced at the **linker level**. A C translation unit
that includes only `mymem.h` and links against both archives will always pull
`secure_wipe_stack_rev` from a separate object file, maintaining the
side-effect barrier.

---

## Build & Test Results

<span style="color:#369631; font-weight:bold;">✅ ALL PASSING</span>

### Compilation

```
nasm -f elf32 memset.asm             -o memset.o
nasm -f elf32 memzero.asm            -o memzero.o
nasm -f elf32 memset_rev.asm         -o memset_rev.o
nasm -f elf32 memzero_rev.asm        -o memzero_rev.o
ar rcs libmymem.a  memset.o memzero.o memset_rev.o memzero_rev.o
nasm -f elf32 secure_wipe_stack_rev.asm -o secure_wipe_stack_rev.o
ar rcs libmysecure.a  secure_wipe_stack_rev.o

gcc -m32 -fno-builtin -fno-stack-protector -Wall -Wextra -std=c11 \
    -o test_suite test_suite.c -L. -lmysecure -lmymem
```

**Compiler warnings**: 0

### Test results (10 tests)

| # | Test | Library | Result |
|---|------|---------|--------|
| 1 | `memset` forward fill | libmymem.a | ✅ PASS |
| 2 | `memset` partial fill (boundary check) | libmymem.a | ✅ PASS |
| 3 | `memzero` forward zeroing | libmymem.a | ✅ PASS |
| 4 | `memset_rev` backward fill | libmymem.a | ✅ PASS |
| 5 | `memzero_rev` backward zeroing | libmymem.a | ✅ PASS |
| 6 | `secure_wipe_stack_rev` | libmysecure.a | ✅ PASS |
| 7 | `count == 0` edge cases (all functions) | both | ✅ PASS |
| 8 | `NULL` dest safety (all functions) | both | ✅ PASS |
| 9 | Return value correctness (all functions) | both | ✅ PASS |
| 10 | `memset_rev` partial fill (boundary check) | libmymem.a | ✅ PASS |

---

## Directory Layout

```
libmem/
├── mymem.h                      # Public header (5 prototypes)
├── memset.asm                   # Phase 1: forward byte fill
├── memzero.asm                  # Phase 2: → memset delegation
├── memset_rev.asm               # Phase 3: backward byte fill
├── memzero_rev.asm              # Phase 3: → memset_rev delegation
├── secure_wipe_stack_rev.asm    # Phase 5: → memset_rev (libmysecure.a)
├── Makefile                     # Build + test rules
├── test_link.c                  # Basic 8-test harness
├── test_suite.c                 # Comprehensive 10-test harness (color-coded)
├── .gitignore                   # Excludes *.o, *.a, binaries
├── libmymem.a                   # Build artifact (gitignored)
└── libmysecure.a                # Build artifact (gitignored)
```
