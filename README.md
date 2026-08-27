<p align="center">
  <img src="src/app/favicon.ico" width="64" height="64" alt="Logo">
</p>

<h1 align="center" style="color:#0ea5e9; font-size:2.2em; font-weight:800; letter-spacing:1px;">
  ⚡ kilo<span style="color:#f59e0b;">dev</span>.stack
</h1>

<p align="center">
  <span style="color:#94a3b8; font-size:1.05em;">
    A full-stack developer scaffold — <span style="color:#0ea5e9; font-weight:700;">Next.js 16</span> ⚛️
    frontend + <span style="color:#f59e0b; font-weight:700;">libmem</span> ⚙️
    a hand-written 32-bit x86 assembly memory library.
  </span>
</p>

<p align="center">
  <span style="color:#22c55e; font-weight:700;">✓ typecheck clean</span>
  &nbsp;|&nbsp;
  <span style="color:#22c55e; font-weight:700;">✓ lint clean</span>
  &nbsp;|&nbsp;
  <span style="color:#22c55e; font-weight:700;">✓ 27/27 assembly tests passing</span>
</p>

---

<table>
<tr>

<td style="vertical-align:top; padding:0 24px 0 0;">

## 🗺️ Contents

- [🔮 What Is This?](#-what-is-this)
- [🧩 Stack](#-stack)
- [🚀 Quick Start](#-quick-start)
  - [Web Frontend](#web-frontend)
  - [libmem (Assembly)](#libmem-assembly)
- [📂 Project Structure](#-project-structure)
- [📚 libmem Deep Dive](#-libmem-deep-dive)
  - [Functions Overview](#functions-overview)
  - [Phase-by-Phase Build](#phase-by-phase-build)
  - [📊 DSE Prevention Architecture](#-dse-prevention-architecture)
  - [🐚 os/ Kernel (32-bit Protected Mode)](#-os-kernel-32-bit-protected-mode)
  - [🧪 Tests](#-tests)
  - [🥾 Bootloader (BIOS Console)](#-bootloader-bios-console)
  - [🛠️ Development Scripts](#️-development-scripts)

</td>

<td style="vertical-align:top; border-left:1px solid #334159; padding-left:24px;">

## 🔮 What Is This?

This repository is a **dual-purpose developer platform**:

| Layer | Path | Description |
|-------|------|-------------|
| <span style="color:#0ea5e9;">**Web**</span> | `./src/` | A <span style="color:#0ea5e9; font-weight:600;">Next.js 16</span> server-rendered application seeded with TypeScript, Tailwind CSS v4, and ESLint — the UI scaffold for any product built on top. |
| <span style="color:#f59e0b;">**libmem**</span> | `./libmem/` | A <span style="color:#f59e0b; font-weight:600;">modular 32-bit x86 memory library</span> written from scratch in NASM assembly (`.asm`), compiled with `GCC -m32` under the `cdecl` calling convention, and packaged into two static archives with a dedicated 27-test harness. |

</td>
</table>

---

## <span style="color:#0ea5e9;">🧩</span> Stack

<div align="center">

| <span style="color:#f59e0b;">Frontend</span> | <span style="color:#0ea5e9;">Backend / Systems</span> | <span style="color:#22c55e;">Tooling</span> |
|:---|:---|:---|
| <img src="https://img.shields.io/badge/Next.js-16-black?logo=nextdotjs" alt="Next.js"> | <img src="https://img.shields.io/badge/NASM-2.x-6ba539?logo=asm" alt="NASM"> | <img src="https://img.shields.io/badge/Bun-1.x-000000?logo=bun" alt="Bun"> |
| <img src="https://img.shields.io/badge/React-19-baeb17?logo=react" alt="React"> | <img src="https://img.shields.io/badge/GCC%20-m32-6ba539?logo=gnu" alt="GCC"> | <img src="https://img.shields.io/badge/ESLint-9-4b32b8?logo=eslint" alt="ESLint"> |
| <img src="https://img.shields.io/badge/Tailwind%20v4-06b6d4?logo=tailwindcss" alt="Tailwind"> | <img src="https://img.shields.io/badge/ELF32-8be9fd?logo=elf" alt="ELF 32-bit"> | <img src="https://img.shields.io/badge/TypeScript-5.9-0eabff?logo=typescript" alt="TypeScript"> |
| <img src="https://img.shields.io/badge/TSDX-8a2be2" alt="TS"> | <img src="https://img.shields.io/badge/cdec-8a2be2?logo=c" alt="cdecl"> | <img src="https://img.shields.io/badge/ar-gold?logo=ar" alt="ar"> |

</div>

---

## 🚀 Quick Start

### Web Frontend

```bash
# The sandbox manages the dev server automatically. To run locally:
bun install     # install dependencies (node_modules)
bun dev         # starts http://localhost:3000  (❌ do NOT run next dev / bun dev inside the sandbox)
bun build       # production build → .next/
bun lint        # run ESLint
bun typecheck    # run tsc --noEmit
```

### libmem (Assembly)

```bash
cd libmem
make all          # assemble all .asm → .o, archive into libmymem.a + libmysecure.a
make test         # 24-test harness (test_link.c)
make test-suite   # 27-test comprehensive colour-coded harness (test_suite.c)
```

> **Prerequisites** for `libmem`: `nasm`, `gcc-multilib` (`gcc -m32`), `ar`, and the 32-bit C runtime (`libc6-dev-i386` on Debian/Ubuntu).

---

## 📂 Project Structure

```
.
├── README.md                     ← ─────── this file
├── AGENTS.md                     # kilo agent instructions & recipes
├── BUILD_OUTPUT.log             # last known-good build log
├── package.json                 # Next.js 16 / Bun scripts & deps
├── tsconfig.json                # strict TypeScript config
├── next.config.ts               # Next.js config
├── postcss.config.mjs           # Tailwind via PostCSS
├── eslint.config.mjs            # ESLint flat config
│
├── src/
│   └── app/
│       ├── layout.tsx           # Root layout • Geist fonts
│       ├── globals.css          # @import "tailwindcss"
│       ├── favicon.ico
│       └── page.tsx             # Home page (stub)
│
└── libmem/                      # ← ─────── 32-bit x86 assembly library (32 functions)
    ├── mymem.h                  # Public header (28 prototypes)
    ├── memset.asm               # Phase 1: forward byte fill
    ├── memzero.asm              # delegates to memset (c=0)
    ├── memset_rev.asm           # Phase 3: backward byte fill
    ├── memzero_rev.asm          # delegates to memset_rev (c=0)
    ├── memcpy.asm               # Phase 5-A: forward copy (no overlap)
    ├── memmove.asm              # Phase 5-B: overlap-safe copy
    ├── memcmp.asm               # Phase 5-C: compare regions
    ├── memchr.asm               # Phase 5-D: find byte in memory
    ├── memsetw.asm              # Phase 5-E: 16-bit word fill
    ├── memfill.asm              # Phase 8-A: 16-bit pattern fill
    ├── memswap.asm              # Phase 8-B: swap two regions
    ├── memreverse.asm           # Phase 8-C: reverse bytes in region
    ├── memrotate_l.asm          # Phase 8-D: left rotate
    ├── memrotate_r.asm          # Phase 8-E: right rotate
    ├── memfind.asm              # Phase 8-F: find byte (returns offset)
    ├── memcount.asm             # Phase 8-G: count byte occurrences
    ├── memchecksum.asm          # Phase 8-H: XOR checksum
    ├── memeq.asm                # Phase 8-I: boolean equality test
    ├── memmove_rev.asm          # Phase 8-J: backward memmove variant
    ├── secure_wipe_stack_rev.asm # Phase 5: → memset_rev (libmysecure.a)
    ├── secure_wipe_heap_rev.asm # Phase 7: → memset_rev (libmysecure.a)
    ├── Makefile                 # Build + test rules (27-test + 24-test harnesses)
    ├── test_link.c              # 24-test basic harness
    ├── test_suite.c             # 27-test comprehensive colour-coded harness
    └── .gitignore               # Excludes *.o, *.a, binaries
│
└── boot/                        # ← ─────── BIOS boot sector (16-bit real mode)
    ├── boot.asm                 # entry point + table-driven test runner
    ├── memset.asm               # 16-bit memset (port of libmem/memset.asm)
    ├── memzero.asm              # delegates to memset (extern)
    ├── memset_rev.asm           # 16-bit backward fill
    ├── memzero_rev.asm          # delegates to memset_rev
    ├── secure_wipe.asm          # black-box secure wipe (extern memset_rev)
    ├── Makefile                 # make / make run / make clean
    ├── README.md                # Bootloader documentation
    └── .gitignore               # boot.bin, *.lst
```

---

## 🐚 os/ — 32-bit Protected-Mode Kernel

```
├── os/
│   ├── kernel/
│   │   ├── entry.asm            # 32-bit protected mode entry (GDT, A20, IDT call)
│   │   ├── idt.asm              # IDT: vectors 0x80 (syscalls), 0x81 (signals), 0x0D (GPF)
│   │   ├── isr80.asm            # int 0x80 → syscall_dispatch (28 syscalls)
│   │   ├── isr81.asm            # int 0x81 → signal_dispatch (libmem verification)
│   │   ├── isr_gpf.asm          # int 0x0D → gpf_handler (bare-metal exception handling)
│   │   ├── syscall.h            # All syscall + signal + prototype declarations
│   │   ├── syscalls.c           # syscall_dispatch (28 cases) + signal_dispatch + GPF-aware
│   │   ├── kmain.c              # Kernel init: triggers SIG_LIBMEM_READY + SIG_LIBMEM_TEST_ALL
│   │   ├── console.c            # BIOS-style text console (80×25)
│   │   └── link.ld              # Linker script (flat 1MB load)
│   ├── user/
│   │   ├── usys.h               # 28 syscall prototypes + 3 signal defines
│   │   ├── usys.S               # 28 int 0x80 syscall wrappers (ASM)
│   │   └── shell.c              # C shell with 28 memory commands
│   └── Makefile
```

**Key design:** Userland (shell.c) calls libmem functions **only** through syscall wrappers (`usys.S` → `int 0x80` → `syscall_dispatch`). The kernel runs all 21 libmem functions during `kmain()` via the signal interrupt (`int 0x81` → `signal_dispatch` → `SIG_LIBMEM_TEST_ALL`). If any function triggers an invalid memory access, the **GPF handler** (`isr_gpf.asm`, vector 0x0D) logs it to serial (non-fatal for software-triggered exceptions) and the kernel continues.

```
$ make -C os          # or: cd os && make all
[ BUILD OK — 0 warnings, kernel sectors=55 ]
```

---

## 🛠️ Scripts & Commands

### Root (Next.js)

| Command | Purpose |
|:--|:--|
| `bun install` | Install dependencies |
| `bun dev` | Start dev server (❌ disabled in sandbox) |
| `bun build` | Production build |
| `bun lint` | Run ESLint flat config |
| `bun typecheck` | `tsc --noEmit` |

### `libmem/`

| Command | Purpose |
|:--|:--|
| `make all` | Assemble all `.asm` → `libmymem.a` + `libmysecure.a` |
| `make test` | Build & run 24-test harness |
| `make test-suite` | Build & run 27-test colour-coded harness |
| `make clean` | Remove all build artifacts |

### `os/`

| Command | Purpose |
|:--|:--|
| `make all` | Build kernel.elf → disk.img (55 sectors) |
| `make clean` | Remove all build artifacts |

### `boot/`

| Command | Purpose |
|:--|:--|
| `make all` | Build 16-bit BIOS boot disk image |
| `make run` | Build + launch in QEMU |
| `make clean` | Remove build artifacts |

### Root Scripts

### `sanity_check.sh` — Full build & test verification

```bash
./sanity_check.sh         # builds libmem + os + boot, runs all tests
# ALL CHECKS PASSED
```

Verifies: libmem (27/27 tests), os kernel (28 syscalls + GPF handler), boot (6/6 QEMU), Next.js (typecheck + lint).

### `regression_test.sh` — Git history backtest

## 📚 libmem Deep Dive

> A modular 32-bit x86 memory library built with **NASM** + **GCC `-m32`** (cdecl).
> The architecture deliberately separates general memory routines from
> security-critical functions to prevent the compiler from optimising away
> sensitive wipe calls (**Dead-Store Elimination**).

### Functions Overview

| Function | Library | Prototype | Description |
|:--|:--|:--|:--|
| <span style="color:#0ea5e9;">`memset`</span> | `libmymem.a` | `void *memset(void *dest, int c, size_t count)` | Forward byte-by-byte fill. |
| <span style="color:#0ea5e9;">`memzero`</span> | `libmymem.a` | `void *memzero(void *dest, size_t count)` | Delegates to `memset` with `c = 0`. |
| <span style="color:#f59e0b;">`memset_rev`</span> | `libmymem.a` | `void *memset_rev(void *dest, int c, size_t count)` | Backward fill from `dest+count-1`. |
| <span style="color:#f59e0b;">`memzero_rev`</span> | `libmymem.a` | `void *memzero_rev(void *dest, size_t count)` | Delegates to `memset_rev` with `c = 0`. |
| <span style="color:#0ea5e9;">`memcpy`</span> | `libmymem.a` | `void *memcpy(void *dest, const void *src, size_t count)` | Forward byte copy (non-overlapping). |
| <span style="color:#0ea5e9;">`memmove`</span> | `libmymem.a` | `void *memmove(void *dest, const void *src, size_t count)` | Overlapping-safe copy (direction-detect). |
| <span style="color:#0ea5e9;">`memcmp`</span> | `libmymem.a` | `int memcmp(const void *s1, const void *s2, size_t count)` | Compare regions (returns <0/0/>0). |
| <span style="color:#0ea5e9;">`memchr`</span> | `libmymem.a` | `void *memchr(const void *s, int c, size_t count)` | Find first byte match, return pointer. |
| <span style="color:#0ea5e9;">`memsetw`</span> | `libmymem.a` | `void *memsetw(void *dest, unsigned short c, size_t count)` | Forward 16-bit word fill. |
| <span style="color:#22c55e;">`memfill`</span> | `libmymem.a` | `void *memfill(void *dest, unsigned short pattern, size_t count)` | Repeating 16-bit pattern fill (handles odd count). |
| <span style="color:#22c55e;">`memswap`</span> | `libmymem.a` | `void memswap(void *a, void *b, size_t count)` | Swap two equal-length regions. |
| <span style="color:#22c55e;">`memreverse`</span> | `libmymem.a` | `void *memreverse(void *dest, size_t count)` | Reverse bytes in-place (two-pointer converge). |
| <span style="color:#22c55e;">`memrotate_l`</span> | `libmymem.a` | `void *memrotate_l(void *dest, unsigned int shift, size_t count)` | Left rotate (triple-reverse algorithm). |
| <span style="color:#22c55e;">`memrotate_r`</span> | `libmymem.a` | `void *memrotate_r(void *dest, unsigned int shift, size_t count)` | Right rotate (triple-reverse algorithm). |
| <span style="color:#22c55e;">`memfind`</span> | `libmymem.a` | `int memfind(const void *s, int c, size_t count)` | Find byte, return offset (or -1). |
| <span style="color:#22c55e;">`memcount`</span> | `libmymem.a` | `int memcount(const void *s, int c, size_t count)` | Count occurrences of a byte value. |
| <span style="color:#22c55e;">`memchecksum`</span> | `libmymem.a` | `unsigned char memchecksum(const void *s, size_t count)` | XOR checksum of region. |
| <span style="color:#22c55e;">`memeq`</span> | `libmymem.a` | `int memeq(const void *s1, const void *s2, size_t count)` | Boolean equality (1 = equal, 0 = not). |
| <span style="color:#22c55e;">`memmove_rev`</span> | `libmymem.a` | `void *memmove_rev(void *dest, const void *src, size_t count)` | Backward memmove variant (always reverse-direction). |
| <span style="color:#22c55e;">`secure_wipe_stack_rev`</span> | `libmysecure.a` | `void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count)` | Secure backward wipe — see [DSE section](#-dse-prevention-architecture). |
| <span style="color:#22c55e;">`secure_wipe_heap_rev`</span> | `libmysecure.a` | `void *secure_wipe_heap_rev(void *heap_dest, size_t wipe_count)` | Secure backward heap wipe (DSE-protected). |

---

### Phase-by-Phase Build

#### Phase 1 — Forward Fill (`<span style="color:#0ea5e9;">memset.asm</span>`)  ✅

```nasm
global memset
section .text
memset:
    push ebp
    mov  ebp, esp
    push edi                    ; callee-saved (i386 GCC ABI)

    mov  edi, [ebp + 8]         ; dest
    mov  al,  [ebp + 12]        ; c  (low byte of int)
    mov  ecx, [ebp + 16]        ; count

    test edi, edi               ; NULL guard
    jz   .done
    test ecx, ecx               ; count == 0 guard
    jz   .done

.fill_loop:
    mov  [edi], al
    inc  edi
    dec  ecx
    jnz  .fill_loop

.done:
    mov  eax, [ebp + 8]         ; return original dest
    pop  edi
    pop  ebp
    ret
```

---

#### Phase 2 — Forward Zeroing (`<span style="color:#0ea5e9;">memzero.asm</span>`)  ✅

Thin wrapper that pushes args right-to-left (cdecl) and calls `memset`:

```nasm
global memzero
extern memset
section .text
memzero:
    push ebp
    mov  ebp, esp
    push dword [ebp + 12]   ; count   (3rd arg)
    push 0                  ; c = 0   (2nd arg)
    push dword [ebp + 8]    ; dest    (1st arg)
    call memset
    add  esp, 12            ; caller cleanup
    pop  ebp
    ret
```

---

#### Phase 3 — Backward Fill & Zeroing  ✅

**`memset_rev.asm`** — starts at `dest + count - 1` via a single `lea`:

```nasm
    lea  edi, [edi + ecx - 1]    ; compute start address safely
    ...
.bwd_loop:
    mov  [edi], al
    dec  edi
    dec  ecx
    jnz  .bwd_loop
```

> The `count == 0` guard is **critical** for backward routines — without it,
> `dest + count - 1` would underflow to `dest - 1`.

**`memzero_rev.asm`** — same delegation pattern as Phase 2, calling `memset_rev`.

---

#### Phase 4 — Header & Archives  ✅

**`mymem.h`** exposes all five prototypes and includes `<stddef.h>` for `size_t`.

The **Makefile** produces two static archives:

| Archive | Contains | Purpose |
|:--|:--|:--|
| <span style="color:#0ea5e9;">`libmymem.a`</span> | `memset`, `memzero`, `memset_rev`, `memzero_rev` | General-purpose memory routines. |
| <span style="color:#22c55e;">`libmysecure.a`</span> | `secure_wipe_stack_rev` | Security-critical wipe (links to `memset_rev` at final link). |

**Key build flags:**

| Flag | Purpose |
|:--|:--|
| `-f elf32` | NASM output: 32-bit ELF object |
| `-m32` | GCC: generate 32-bit code |
| `-fno-builtin` | Prevent GCC replacing `memset` with `__builtin_memset` — ensures **our** library is actually linked & tested |
| `-fno-stack-protector` | Disable stack canaries (irrelevant for flat binary tests) |
| `-Wall -Wextra` | All warnings — **0 warnings achieved** |

---

#### Phase 5 — Secure Stack Unwinding (`<span style="color:#22c55e;">secure_wipe_stack_rev.asm</span>`)  ✅

```nasm
global secure_wipe_stack_rev
extern memset_rev               ; ← external symbol (black box to C compiler)
section .text
secure_wipe_stack_rev:
    push ebp
    mov  ebp, esp
    push dword [ebp + 12]       ; wipe_count
    push 0                      ; c = 0
    push dword [ebp + 8]        ; stack_dest
    call memset_rev
    add  esp, 12
    pop  ebp
    ret
```

### 📊 DSE Prevention Architecture

```
┌──────────────────────────┐    extern memset_rev    ┌──────────────────────┐
│  secure_wipe_stack_rev   │ ──────────────────────→ │  memset_rev          │
│  (libmysecure.a)         │    (unresolved symbol   │  (libmymem.a)        │
│                          │     in obj, resolved    │                      │
│                          │     at final link)      │                      │
└──────────────────────────┘                         └──────────────────────┘
         ▲                                                     ▲
         │                                                     │
    C compiler calls                                           │
    secure_wipe_stack_rev                                   Assembly
    as a BLACK BOX —                                          implementation
    no visibility into                                       (no DSE possible
    the memset call)                                           here)
```

Because `memset_rev` is an **external symbol** the C compiler cannot see,
the entire `secure_wipe_stack_rev` call is treated as a black box with
unknown side effects. **Dead-Store Elimination** — which might strip
`memset(buf, 0, n)` when the compiler knows the buffer is never read again —
**cannot** eliminate the wipe through this boundary.

By placing `secure_wipe_stack_rev` and `secure_wipe_heap_rev` in `libmysecure.a`
(separate from `libmymem.a`), the security boundary is enforced at the **linker level**.

---

## 🐚 os/ — Kernel Syscall Interface & Exception Handling

The 32-bit protected-mode kernel in `os/` wires all 28 libmem functions into a
syscall dispatch + signal verification path with bare-metal GPF exception handling.

### Syscall ABI (int 0x80)

| Register | Purpose |
|:--|:--|
| `eax` | Syscall number (1–28) |
| `ebx` | arg0 (dest / addr / byte) |
| `ecx` | arg1 (src / byte / count) |
| `edx` | arg2 (count) |
| Result | `eax` |

Userland (`shell.c`) calls these through thin wrappers in `usys.S` — it never
references kernel memory functions directly.

### Signal Path (int 0x81)

During `kmain()`, the kernel triggers `SIG_LIBMEM_READY` to verify libmem is
linked correctly, then `SIG_LIBMEM_TEST_ALL` runs a smoke test of **all 21
functions** (19 in `libmymem.a` + 2 in `libmysecure.a`) through the kernel-owned
dispatch path:

```
kmain.c → int 0x81 (SIG_LIBMEM_TEST_ALL) → isr81_handler → signal_dispatch()
```

### GPF Exception Handling (int 0x0D)

The **General Protection Fault handler** (`isr_gpf.asm`, vector 0x0D) provides
simple bare-metal exception handling:

- **Software-triggered GPF** (error code bit 0 = 0): logs `"gpf "` + error code
  to serial port 0x3F8, then `iret` — non-fatal, allows `signal_dispatch` to
  continue and report failures.
- **Hardware-triggered GPF** (error code bit 0 = 1): logs `"GPF!"` to serial
  and halts (`cli; hlt` loop).

```
┌─────────────┐    invalid mem access    ┌──────────────┐
│  any kernel │ ───────────────────────→ │  GPF handler │
│  function   │                           │  (vector 0x0D) │
└─────────────┘                           └──────┬───────┘
       ▲                                         │
       │                     soft GPF → log + iret
       │                     hard GPF → log + halt
       │
       │  tested via
       │  SIG_LIBMEM_TEST_ALL
```

---

## 🧪 Tests

Two harnesses ship with `libmem`:

### `test_link.c` — 24-Test Harness

```bash
make test      # builds & runs ./test_link
All 24 tests passed (libmymem.a + libmysecure.a)
```

### `test_suite.c` — 27-Test Colour-Coded Harness

| # | Test | Library | Result |
|---|------|:------:|:------:|
| 1 | `memset` forward fill | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 2 | `memset` partial fill (boundary) | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 3 | `memzero` forward zeroing | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 4 | `memset_rev` backward fill | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 5 | `memzero_rev` backward zeroing | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 6 | `secure_wipe_stack_rev` | `libmysecure.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 7 | `count == 0` edge cases | both | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 8 | `NULL` dest safety | both | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 9 | Return value correctness | both | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 10 | `memset_rev` partial fill (boundary) | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 11 | `memcpy` forward copy | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 12 | `memmove` overlap forward | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 13 | `memmove` overlap backward | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 14 | `memcmp` equality | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 15 | `memchr` found & not-found | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 16 | `memsetw` word fill | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 17 | `secure_wipe_heap_rev` | `libmysecure.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 18 | `memfill` pattern fill | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 19 | `memswap` two regions | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 20 | `memreverse` bytes | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 21 | `memrotate_l` left rotation | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 22 | `memrotate_r` right rotation | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 23 | `memfind` offset search | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 24 | `memcount` occurrences | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 25 | `memchecksum` XOR | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 26 | `memeq` equality | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |
| 27 | `memmove_rev` backward copy | `libmymem.a` | <span style="color:#22c55e; font-weight:700;">✅ PASS</span> |

ANSI colour legend (mirrors `test_suite.c`):

<span style="color:#0ea5e9;">● Cyan</span> — section headers &nbsp;|&nbsp;
<span style="color:#f59e0b;">● Yellow</span> — test names &nbsp;|&nbsp;
<span style="color:#22c55e;">● Green</span> — PASS &nbsp;|&nbsp;
<span style="color:#ef4444;">● Red</span> — FAIL

---

### `libmem/`

8-test harness (colour-coded cyan/yellow/green/red)...

---

## 🥾 Bootloader (BIOS Console)

> **Live-tested** — 6/6 tests PASS in QEMU (5 functions + edge cases).

A **512-byte boot sector** in `boot/` that runs its **own 16-bit memory
routines** (not BIOS libraries) and prints PASS/FAIL results to the BIOS
console via **INT 0x10 teletype**.

Each function lives in its own `.asm` file with `global`/`extern` directives
mirroring the 32-bit `libmem/` structure; `boot.asm` pulls them in via
`%include` and tests them with a **table-driven runner** plus **edge-case
tests** (NULL safety + count==0).

| Property | Value |
|:--|:--|
| Mode | 16-bit real mode |
| Entry | `CS:IP` = `0x0000:0x7C00` |
| Output | BIOS video teletype (`AH=0x0E`) |
| Colours | cyan / yellow / green / red (`BL`) |
| Size | exactly 512 bytes (510 + `0xAA55` signature) |

| Test | Algorithm | Result |
|----|:------:|:------:|
| `memset` | forward fill (`inc di`) | ✅ PASS |
| `memzero` | delegates to `memset` | ✅ PASS |
| `memset_rev` | backward fill (`dec di`) | ✅ PASS |
| `memzero_rev` | delegates to `memset_rev` | ✅ PASS |
| `secure_wipe` | black-box → `memset_rev` | ✅ PASS |
| `edge: NULL+0` | NULL safety + count==0 | ✅ PASS |

```
cd boot && make run    # builds + launches in QEMU (6/6 PASS)
```

See [`boot/README.md`](boot/README.md) for the modular file structure and full docs.
cd boot
nasm -f bin boot.asm -o boot.bin
qemu-system-x86_64 -drive format=raw,file=boot.bin
```

---

<p align="center" style="color:#94a3b8; font-size:0.9em;">
  Built with <span style="color:#0ea5e9;"> Next.js </span> ·
  <span style="color:#f59e0b;"> NASM </span> ·
  <span style="color:#22c55e;"> GCC </span> ·
  <span style="color:#ef4444;"> Bun </span>.
</p>
