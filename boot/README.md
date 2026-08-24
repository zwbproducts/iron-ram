# 🥾 `boot/` — BIOS Bootloader

A minimal **512-byte boot sector** written in 16-bit x86 NASM assembly.
When BIOS loads it at `0x7C00` it prints a multi-colour ASCII-art banner
to the console via **INT 0x10 teletype** — no operating system required.

---

## Requirements

| Tool | Purpose |
|------|---------|
| `nasm` | Assemble `boot.asm` → flat binary |
| `qemu-system-x86_64` | Emulate & view output (optional) |

On Debian/Ubuntu:

```bash
sudo apt install nasm qemu-system-x86
```

---

## Build

```bash
make            # → boot.bin (exactly 512 bytes)
make run        # build + launch in QEMU
```

---

## How It Works

1. **BIOS** loads the 510-byte sector + `0xAA55` signature to `0x7C00`
   and transfers control in **16-bit real mode** (`CS:IP` = `0x0000:0x7C00`).
2. The code sets up its own segments (`DS = ES = SS = 0`) and a real-mode
   stack at `0x7C00`.
3. For each string it calls `print_string`, which loops over characters
   and uses BIOS **teletype** (`AH = 0x0E`, `INT 0x10`) to emit them.
   The `BL` register selects the foreground colour:

   | Macro | Colour |
   |-------|--------|
   | `COLOUR_GOLD`    | yellow   |
   | `COLOUR_CYAN`    | cyan     |
   | `COLOUR_GREEN`   | green    |
   | `COLOUR_MAGENTA` | magenta  |

4. After printing, the CPU is halted with `HLT` in an infinite loop.

---

## Strings

| Symbol | Colour | Content |
|--------|--------|---------|
| `banner`   | yellow   | ASCII-art `kilo-dev` heading |
| `subhead`  | cyan     | Tech specs tagline |
| `tagline`  | green    | Friendly boot message |
| `sig`      | magenta  | Attribution |

---

## Layout

```
boot/
├── boot.asm      # bootloader source (510 bytes + 0xAA55 signature)
├── Makefile      # make / make run / make clean
└── README.md     # this file
```
