# 🥾 `boot/` — BIOS Bootloader

A **512-byte boot sector** that implements its **own 16-bit memory routines**
(no BIOS memory libraries) and tests them on-boot via BIOS console output.

The five functions are **modular ports** of the 32-bit `libmem/` assembly —
each lives in its own `.asm` file with `global`/`extern` directives mirroring
the original library structure, and `boot.asm` pulls them in via `%include`.

---

## Files

| File | Mirrors | Function |
|------|---------|----------|
| `memset.asm` | `libmem/memset.asm` | Forward byte fill (`inc di`) |
| `memzero.asm` | `libmem/memzero.asm` | Delegates to `memset` (`extern`) |
| `memset_rev.asm` | `libmem/memset_rev.asm` | Backward fill (`dec di`) |
| `memzero_rev.asm` | `libmem/memzero_rev.asm` | Delegates to `memset_rev` (`extern`) |
| `secure_wipe.asm` | `libmem/secure_wipe_stack_rev.asm` | Black-box wipe (`extern memset_rev`) |
| `boot.asm` | — | Entry point + table-driven test runner + edge cases |

### DSE-Prevention Mirror

```
┌─────────────────────┐    extern memset_rev16    ┌─────────────────────┐
│  secure_wipe.asm    │ ─────────────────────────→ │  memset_rev.asm     │
│  (opaque wipe)      │  (black-box call)           │  (backward fill)    │
└─────────────────────┘                            └─────────────────────┘
```

---

## Requirements

| Tool | Purpose |
|------|---------|
| `nasm` | Assemble the boot sector |
| `qemu-system-x86_64` | Emulate & view output |

```bash
sudo apt install nasm qemu-system-x86
```

---

## Build & Run

```bash
make            # → boot.bin (exactly 512 bytes)
make run        # build + launch in QEMU
```

Manual:

```bash
nasm -f bin boot.asm -o boot.bin
qemu-system-x86_64 -drive format=raw,file=boot.bin -nographic -serial mon:stdio
```

---

## Calling Convention

All memory routines share a compact register-based convention
(no stack-arg overhead, ideal for a 512-byte sector):

```
  DI = dest    AL = fill byte    CX = count
```

**Safety guards** (mirrors `libmem/`):
- `DI == 0` (NULL dest) → early return
- `CX == 0` (count zero) → early return (critical for backward routines to prevent `dest+count-1` underflow)

---

## Test Results

**6 tests, all PASS** (5 function tests + 1 edge-case test):

| # | Test | Algorithm | Result |
|---|------|:---------:|:------:|
| 1 | `memset` forward fill | `memsetw` | ✅ PASS |
| 2 | `memzero` (delegates) | `memzero16` | ✅ PASS |
| 3 | `memset_rev` backward fill | `memset_rev16` | ✅ PASS |
| 4 | `memzero_rev` (delegates) | `memzero_rev16` | ✅ PASS |
| 5 | `secure_wipe` (black-box) | `secure_wipe16` | ✅ PASS |
| 6 | `edge: NULL + count==0` | all functions | ✅ PASS |

The test runner is **table-driven** — a 5-entry dispatch table with name/function/
prefill/op-value/expected fields. Each entry is 8 bytes, iterated via `add bp, 8`
with an indirect `call word [bp+2]`.

---

## Live Output (QEMU)

```
  BIOS BOOT TEST
  memset
  [PASS]
  memzero
  [PASS]
  memset_rev
  [PASS]
  memzero_rev
  [PASS]
  secure_wipe
  [PASS]
  edge: NULL+0
  [PASS]

  halt
```

### Colours

| Colour macro | BIOS BL value | Usage |
|:------------:|:-------------:|-------|
| `COL_CYAN` | 0x0B | header banner |
| `COL_YELLOW` | 0x0E | test names, "halt" |
| `COL_GREEN` | 0x0A | `[PASS]` |
| `COL_RED` | 0x0C | `[FAIL]` |

---

## Layout

```
boot/
├── boot.asm           # entry point + test runner (510 bytes + 0xAA55)
├── memset.asm         # 16-bit memset (port of libmem/memset.asm)
├── memzero.asm        # delegates to memset (extern memsetw)
├── memset_rev.asm     # 16-bit backward fill
├── memzero_rev.asm    # delegates to memset_rev
├── secure_wipe.asm    # black-box secure wipe (extern memset_rev16)
├── Makefile           # make / make run / make clean
├── README.md          # this file
└── .gitignore         # boot.bin, *.lst
```

## Verified

- ✅ Assembles with `nasm -f bin` → exactly **512 bytes**
- ✅ Boot signature `55 AA` at offset 510
- ✅ Runs in QEMU — **6/6 tests PASS** (5 functions + NULL/count==0 edge cases)
- ✅ Zero assembler warnings
