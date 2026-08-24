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
  <span style="color:#22c55e; font-weight:700;">✓ 10/10 assembly tests passing</span>
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
| <span style="color:#f59e0b;">**libmem**</span> | `./libmem/` | A <span style="color:#f59e0b; font-weight:600;">modular 32-bit x86 memory library</span> written from scratch in NASM assembly (`.asm`), compiled with `GCC -m32` under the `cdecl` calling convention, and packaged into two static archives with a dedicated 10-test harness. |

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
make test         # 8-test harness (test_link.c)
make test-suite   # 10-test comprehensive colour-coded harness (test_suite.c)
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
└── libmem/                      # ← ─────── 32-bit x86 assembly library
    ├── mymem.h                  # Public header (5 prototypes)
    ├── memset.asm               # Phase 1: forward byte fill
    ├── memzero.asm              # Phase 2: → delegates to memset
    ├── memset_rev.asm           # Phase 3: backward byte fill
    ├── memzero_rev.asm          # Phase 3: → delegates to memset_rev
    ├── secure_wipe_stack_rev.asm # Phase 5: → memset_rev (libmysecure.a)
    ├── Makefile                 # Build + test rules
    ├── test_link.c              # Basic 8-test harness
    ├── test_suite.c             # Comprehensive 10-test colour-coded harness
    └── .gitignore               # Excludes *.o, *.a, binaries
│
└── boot/                        # ← ─────── BIOS boot sector (16-bit real mode)
    ├── boot.asm                 # 512-byte boot sector (INT 0x10 teletype)
    ├── Makefile                 # make / make run / make clean
    └── README.md                # Bootloader documentation
```

---

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
| <span style="color:#22c55e;">`secure_wipe_stack_rev`</span> | `libmysecure.a` | `void *secure_wipe_stack_rev(void *stack_dest, size_t wipe_count)` | Secure backward wipe — see [DSE section](#-dse-prevention-architecture). |

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

By placing `secure_wipe_stack_rev` in `libmysecure.a` (separate from
`libmymem.a`), the security boundary is enforced at the **linker level**.

---

## 🧪 Tests

Two harnesses ship with `libmem`:

### `test_link.c` — 8-Test Harness

```
make test      # builds & runs ./test_link
All 8 tests passed (libmymem.a + libmysecure.a)
```

### `test_suite.c` — 10-Test Colour-Coded Harness

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

A minimal **512-byte boot sector** in `boot/` that prints a multi-colour
ASCII-art banner directly to the BIOS console via **INT 0x10 teletype** —
no operating system required.

| Property | Value |
|:--|:--|
| Mode | 16-bit real mode |
| Entry | `CS:IP` = `0x0000:0x7C00` |
| Output | BIOS video teletype (`AH=0x0E`) |
| Colours | gold / cyan / green / magenta (`BL`) |
| Size | exactly 512 bytes (510 + `0xAA55` signature) |

See [`boot/README.md`](boot/README.md) for build & run instructions.

```
cd boot
nasm -f bin boot.asm -o boot.bin
qemu-system-x86_64 -drive format=raw,file=boot.bin
```

---

## 🛠️ Development Scripts

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
| `make test` | Build & run 8-test harness |
| `make test-suite` | Build & run 10-test colour-coded harness |
| `make clean` | Remove all build artifacts |

---

<p align="center" style="color:#94a3b8; font-size:0.9em;">
  Built with <span style="color:#0ea5e9;"> Next.js </span> ·
  <span style="color:#f59e0b;"> NASM </span> ·
  <span style="color:#22c55e;"> GCC </span> ·
  <span style="color:#ef4444;"> Bun </span>.
</p>
