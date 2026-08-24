# 🥾 `boot/` — BIOS Bootloader

A minimal **512-byte boot sector** written in 16-bit x86 NASM assembly that
prints a colourful ASCII-art banner **and** exercises five 16-bit ports of
the `libmem/` memory routines on the **BIOS console** via `INT 0x10` teletype —
no operating system required.

---

## Requirements

| Tool | Purpose |
|------|---------|
| `nasm` | Assemble `boot.asm` → flat binary |
| `qemu-system-x86_64` | Emulate & view output |

On Debian/Ubuntu:

```bash
sudo apt install nasm qemu-system-x86
```

---

## Build & Run

```bash
make            # → boot.bin (exactly 512 bytes)
make run        # build + launch in QEMU
```

Manual commands:

```bash
nasm -f bin boot.asm -o boot.bin
qemu-system-x86_64 -drive format=raw,file=boot.bin -nographic -serial mon:stdio
```

---

## What It Does

1. **Real-mode setup** — normalises `DS = ES = SS = 0`, stacks at `0x7C00`.
2. **Prints a golden banner** — ASCII-art `=== BIOS BOOT TEST ===`.
3. **Tests five memory routines** (16-bit ports of `libmem/`):

   | Test | Algorithm | Verify |
   |------|-----------|--------|
   | `memset` | forward fill (`inc di`) | buffer all `0xAB` |
   | `memzero` | delegates to `memset` (`c=0`) | buffer all `0x00` |
   | `memset_rev` | backward fill (`dec di`) | buffer all `0xCD` |
   | `memzero_rev` | delegates to `memset_rev` (`c=0`) | buffer all `0x00` |
   | `secure_wipe` | black-box → `memset_rev` | buffer all `0x00` |

4. **Prints `[PASS]` (green) or `[FAIL]` (red)** for each test.
5. **Halts** in a `HLT` loop.

### Live Test Output

```
  === BIOS BOOT TEST ===
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

  boot halted.
```

### Colours

Foreground colour is set via the `BL` register in BIOS teletype (`INT 0x10, AH=0x0E`).
In QEMU's GUI mode colours render on screen; `-nographic` mode shows plain text.

| Colour | Usage |
|:------:|-------|
| <span style="color:#0ea5e9;">cyan</span> | header banner |
| <span style="color:#f59e0b;">yellow</span> | test names & "boot halted" |
| <span style="color:#22c55e;">green</span> | `[PASS]` |
| <span style="color:#ef4444;">red</span> | `[FAIL]` |

---

## Calling Convention

All memory routines share a compact register-based convention
(no stack-args overhead, ideal for a 512-byte sector):

```
  DI = dest    AL = fill byte    CX = count
```

### Safety guards (mirrors `libmem/`)

Every fill routine checks:
- `DI == 0` (NULL dest) → early return
- `CX == 0` (count zero) → early return (critical for backward routines
  to prevent `dest + count - 1` underflow)

### DSE-prevention mirror

`secure_wipe16` delegates to `memsetw_rev` as a separate function —
mirroring `libmem/`'s `secure_wipe_stack_rev.asm` → `memset_rev` pattern
where the wipe is an opaque call that cannot be eliminated.

---

## Layout

```
boot/
├── boot.asm      # bootloader source (510 bytes + 0xAA55 signature)
├── Makefile      # make / make run / make clean
└── README.md     # this file
```

## Verified

- ✅ Assembles with `nasm -f bin` → exactly **512 bytes**
- ✅ Boot signature `55 AA` at offset 510
- ✅ Runs in QEMU — all 5 tests **PASS**
- ✅ Zero compiler (assembler) warnings
