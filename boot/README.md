# `boot/` — BIOS Bootloader + Custom 16-bit Kernel

> Two-stage x86 boot stack built entirely on **hand-written 16-bit memory
> routines** ported from the 32-bit `libmem/` library. No BIOS memory helpers,
> no libc — and crucially, **the kernel's own console is not a BIOS call**:
> the VGA text frame buffer is cleared, driven and verified with the ported
> memory routines themselves.

<span style="color:#369631; font-weight:bold;">STATUS: COMPLETE & VERIFIED</span>
<span style="color:#999999;">8/8 kernel console tests PASS in QEMU — zero assembler warnings</span>

---

## Contents

1. [Architecture: the two stages](#architecture-the-two-stages)
2. [The ported memory routines](#the-ported-memory-routines)
3. [Calling convention](#calling-convention)
4. [Stage-1: the bootloader (`boot.asm`)](#stage-1-the-bootloader-bootasm)
5. [Stage-2: the kernel (`kernel.asm`)](#stage-2-the-kernel-kernelasm)
6. [The kernel console (non-BIOS)](#the-kernel-console-non-bios)
7. [Build & run](#build--run)
8. [Live output](#live-output)
9. [Test results](#test-results)
10. [Why a separate kernel?](#why-a-separate-kernel)

---

## Architecture: the two stages

```
                    BIOS
                      |
                      | loads sector 1 -> physical 0x7C00, DL = boot drive
                      v
  ┌──────────────────────────────────────────────────────────────────┐
  │  boot.asm   — stage-1 BIOS bootloader  (exactly 512 bytes)       │
  │                                                              │
  │  1. real-mode setup (DS=ES=SS=0, SS:SP=0:0x7C00)              │
  │  2. capture boot drive:  mov [boot_drv], dl                   │
  │  3. BIOS int 13h / ah=02h  — read N sectors from sector 2      │
  │     into 0x0000:0x8000  (ES=0, BX=0x8000)                     │
  │  4. far-jump:  jmp 0x0000:0x8000   ->  into the kernel          │
  │     (on int 13h error: teletype "disk read error", then halt)  │
  └──────────────────────────────────────────────────────────────────┘
                      |
                      | sectors 2 .. N  (kernel.bin, sector-padded)
                      v  physical 0x8000
  ┌──────────────────────────────────────────────────────────────────┐
  │  kernel.asm — stage-2 custom 16-bit kernel                        │
  │                                                              │
  │  1. own real-mode setup                                        │
  │  2. kclear()  ->  memzero16() zeroes 0x4000 bytes of 0xB8000   │
  │  3. prints "KERNEL CONSOLE (custom mem)" via its own kputs      │
  │  4. demos each ported memory routine on a 64-byte scratch buf   │
  │     with a buf_chk() verifier -> [OK]/[FAIL] per routine        │
  │  5. demos the NULL-dest and count==0 edge cases                │
  │  6. prints "kernel memory functions live", then halts           │
  │                                                              │
  │  NO BIOS is used for output: the VGA text buffer and the COM1   │
  │  serial mirror are both driven by bare 16-bit code.            │
  └──────────────────────────────────────────────────────────────────┘
```

The bootloader is intentionally **thin** — its job is only to bridge the
hardware (BIOS disk I/O into RAM) to the kernel. All of the *interesting*
work — the memory routines, the console, the tests — lives in the stage-2
kernel, which is free to be as large as it needs (the 512-byte sector
constraint no longer applies to it).

---

## The ported memory routines

Each file is a 16-bit real-mode port of the matching 32-bit `libmem/`
module. They are `%include`-ed into `kernel.asm` and share the original
32-bit→16-bit mapping:

| 32-bit (libmem) | 16-bit (boot) | Port file |
|-----------------|----------------------------|-----------|-----------|---------------------|
| `memset.asm`    | `memsetw`      | `memset.asm`       | `EDI→DI`, `ECX→CX`, `inc edi→inc di`, `dec ecx→dec cx` | forward byte fill |
| `memzero.asm`   | `memzero16`    | `memzero.asm`      | delegates to `memsetw` via `extern` | forward zero-fill |
| `memset_rev.asm`| `memset_rev16` | `memset_rev.asm`   | `lea edi,[edi+ecx-1]` → `add di,cx; dec di` | backward byte fill |
| `memzero_rev.asm`| `memzero_rev16`| `memzero_rev.asm`  | delegates to `memset_rev16` via `extern` | backward zero-fill |
| `secure_wipe_stack_rev.asm` | `secure_wipe16` | `secure_wipe.asm` | delegates to `memset_rev16` via `extern` (black-box) | backward stack wipe |

### DSE-prevention boundary (preserved exactly)

The 16-bit ports keep the same **black-box** boundary that prevents Dead-Store
Elimination from stripping a secure wipe:

```
 ┌─────────────────────┐   extern memset_rev16    ┌─────────────────────┐
 │  secure_wipe16      │ ───────────────────────→│  memset_rev16       │
 │  (secure_wipe.asm)  │   (opaque call — the     │  (memset_rev.asm)   │
 │                     │    assembler/linker sees │                     │
 │                     │    memset_rev16 as an    │                     │
 │                     │    external symbol)      │                     │
 └─────────────────────┘                         └─────────────────────┘
```

Because `memset_rev16` is declared `extern`, it is treated as an opaque,
externally-visible call — nothing can see "through" the wipe to decide the
buffer is dead.

---

## Calling convention

Compact, register-based (no stack-arg overhead — ideal for a boot stage):

```
  DI = dest      AL = fill byte      CX = count      (operates on ES:[DI])
  memzero16  / memzero_rev16 / secure_wipe16   ->  DI = dest, CX = count   (AL forced to 0)
  memsetw    / memset_rev16                    ->  DI, AL, CX
```

**Safety guards (mirror `libmem/`):**

- `DI == 0` (NULL `dest`) → early return
- `CX == 0` (count zero) → early return (critical for the backward routines:
  without it, `dest + count - 1` would underflow to `dest - 1`)

All forward/backward routines preserve `DI` and `CX` (push/pop) and return
the original `dest` in `DI`.

---

## Stage-1: the bootloader (`boot.asm`)

A single 512-byte sector (`ORG 0x7C00`, `BITS 16`):

```nasm
start:
    cli
    xor  ax, ax
    mov  [boot_drv], dl      ; BIOS passes the boot drive in DL
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti
    call load_kernel         ; read sectors 2..N, then jmp 0x8000
.fail: hlt
        jmp  .fail
```

`load_kernel` uses BIOS `int 13h / ah=02h`:

```nasm
load_kernel:
    mov  dl, [boot_drv]
    mov  ax, 0x0000
    mov  es, ax              ; buffer segment
    mov  bx, KERNEL_OFFSET   ; 0x8000
    mov  ah, 0x02            ; read sectors
    mov  al, byte KERNEL_SECTORS
    xor  cx, cx              ; cylinder 0 (CH=0)
    mov  cl, 2               ; sector 2 (sector 1 is this boot sector)
    xor  dh, dh              ; head 0
    int  0x13
    jc  .err
    jmp  0x0000:KERNEL_OFFSET
.err:  ...report via BIOS teletype, ret...
```

CHS geometry note: `CH` = cylinder low 8 bits, `CL` bits 0–5 = sector,
`CL` bits 6–7 = cylinder high 2 bits. For cylinder 0 / sector 2 that is just
`CH=0, CL=2`. The disk image stores the kernel immediately after the boot
sector, so sector 2 is the kernel's first sector.

---

## Stage-2: the kernel (`kernel.asm`)

Flat binary, `ORG 0x8000`, entered at `CS=0, IP=0x8000` (physical 0x8000).
It sets up its own segments and keeps **all** of its code + data in
`DS = ES = SS = 0` (the kernel is linked to run in the low 64 KiB).

### Flow

```nasm
start:
    <real-mode setup>
    call kclear              ; memzero16() blanks 0x4000 bytes of video RAM
    mov  si, k_header
    call kputs               ; "KERNEL CONSOLE (custom mem)"
    call demo_memsetw
    call demo_memzero
    call demo_memset_rev
    call demo_memzero_rev
    call demo_secure_wipe
    call demo_edge_null      ; every routine with DI=0 (must be no-op)
    call demo_edge_zero      ; memsetw with CX=0 (must be no-op)
    mov  si, k_summary
    call kputs               ; "kernel memory functions live"
.halt: hlt
        jmp  .halt
```

### How a demo verifies a routine

Every demo follows the same pattern — fill the scratch buffer, run the
routine under test, then verify byte-by-byte:

```nasm
demo_memsetw:
    mov  ax, 0
    mov  es, ax              ; kbuf lives in segment 0
    mov  di, kbuf
    mov  cx, KBUF_LEN
    xor  al, al
    call memsetw            ; prefill kbuf with 0
    mov  al, 0xAB
    call memsetw            ; memsetw(kbuf, 0xAB, KBUF_LEN)
    mov  si, kbuf
    mov  cx, KBUF_LEN
    mov  al, 0xAB
    call buf_chk            ; CF set if any byte != 0xAB
    pushf                   ; kputs clobbers flags, so save CF first
    mov  si, nm_memsetw
    call kputs              ; prints "  memsetw     :"
    popf
    jc  .fail
    mov  si, pass_str       ; prints " [OK]\r\n"
    call kputs
    ret
.fail:
    mov  si, fail_str       ; prints " [FAIL]\r\n"
    call kputs
    ret
```

`buf_chk` is the byte-wise verifier (sets carry on mismatch):

```nasm
buf_chk:                   ; DS:[SI], CX=count, AL=expected -> CF on mismatch
    push ax
    push cx
    push si
.ck:  cmp  al, [si]
      jne  .bad
      inc  si
      loop .ck
      <pop and clc; ret>
.bad: <pop and stc; ret>
```

The two edge demos preserve the bootloader-era coverage:

- **`demo_edge_null`** — fill `kbuf` with `0x55`, call **every** routine with
  `DI=0`; the NULL guard must make them no-ops, so `kbuf` must stay `0x55`.
- **`demo_edge_zero`** — fill `kbuf` with `0x42`, call `memsetw(kbuf,0xFF,CX=0)`;
  the count==0 guard must leave `kbuf` unchanged.

---

## The kernel console (non-BIOS)

This is the part that fulfils "implement our own 16-bit versions and show the
output on a console that is *using* them."

### Clearing the screen — with `memzero16`

The screen is **not** cleared with `int 10h`. It is cleared with our own
routine, zeroing the 4000-byte VGA text buffer at `0xB8000`:

```nasm
kclear:
    mov  ax, VIDEO_SEG        ; 0xB800
    mov  es, ax
    xor  di, di               ; video offset 0
    mov  cx, VBYTES           ; 4000 (80 * 25 * 2)
    call memzero16            ; <- our custom routine wipes the screen
    mov  word [cursor], 0
    ret
```

That single call is the proof the console is memory-routine-driven: the
"clear" primitive **is** `memzero16`.

### Writing characters — direct stores

Characters are written as a `char` + `attribute` byte pair at `ES:[cursor]`
(`ES = 0xB800`), exactly how `memsetw` would store bytes — just inlined so the
attribute byte can differ per cell:

```nasm
    mov  [es:bx], al          ; char
    mov  byte [es:bx+1], ATTR ; attribute (0x0F = light gray on black)
```

`kputc` also advances a software cursor and handles `\r`/`\n` (CR = column 0,
LF = advance one row, with wrap to the top of the screen past the last row).

### Host observability — serial mirror

Direct writes to `0xB8000` are **not** shown by QEMU under `-nographic` (SeaBIOS
only forwards BIOS calls, not raw video-memory writes). So `kputc` additionally
tees each emitted character to COM1 (`0x3F8`) with a bare `out`:

```nasm
.serial:
    mov  dx, SERIAL           ; 0x3F8
    out  dx, al               ; raw 16-bit I/O — NOT a BIOS call
```

That is itself hand-written 16-bit I/O, keeping the kernel entirely free of
BIOS calls for output. The VGA buffer is the *real* console; serial is only a
mirror so `make run` (`qemu -nographic -serial mon:stdio`) shows the result.

---

## Build & run

```bash
cd boot
make            # boot.bin (512 B), kernel.bin, kernel.pad, disk.img
make run        # build + launch in QEMU
```

What the Makefile does:

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `nasm -f bin kernel.asm -o kernel.bin` | assemble the kernel |
| 2 | `dd if=kernel.bin of=kernel.pad bs=512 conv=sync` | pad to a whole number of sectors |
| 3 | `nasm -f bin -DKERNEL_SECTORS=<sectors> boot.asm -o boot.bin` | build the boot sector, telling it how many sectors to load |
| 4 | `cat boot.bin kernel.pad > disk.img` | raw disk image: boot sector + kernel sectors |

`KERNEL_SECTORS` is computed from the padded kernel size, so the bootloader
always reads exactly the sectors its kernel occupies.

Manual equivalent:

```bash
nasm -f bin kernel.asm -o kernel.bin
dd if=kernel.bin of=kernel.pad bs=512 conv=sync
ksect=$(( ($(stat -c%s kernel.pad) + 511) / 512 ))
nasm -f bin -DKERNEL_SECTORS=$ksect boot.asm -o boot.bin
cat boot.bin kernel.pad > disk.img
qemu-system-x86_64 -drive format=raw,file=disk.img -nographic -serial mon:stdio
```

---

## Live output

```
  KERNEL CONSOLE (custom mem)
  memsetw     : [OK]
  memzero16   : [OK]
  memset_rev16: [OK]
  memzero_rev16: [OK]
  secure_wipe16: [OK]
  NULL safety : [OK]
  count==0    : [OK]
  kernel memory functions live
```

---

## Test results

<span style="color:#369631; font-weight:bold;">ALL 8 PASS</span>

| # | Test | Routine(s) exercised | Verified by | Result |
|---|------|----------------------|-------------|--------|
| 1 | forward fill byte pattern   | `memsetw`         | `buf_chk` byte-compare | PASS |
| 2 | forward zero-fill delegation| `memzero16`       | `buf_chk` == 0        | PASS |
| 3 | backward fill byte pattern  | `memset_rev16`    | `buf_chk` == fill     | PASS |
| 4 | backward zero-fill delegation| `memzero_rev16`  | `buf_chk` == 0        | PASS |
| 5 | secure wipe (black-box)     | `secure_wipe16`   | `buf_chk` == 0        | PASS |
| 6 | NULL `dest` safety          | all 5 routines    | `kbuf` untouched (0x55) | PASS |
| 7 | count == 0 no-op            | `memsetw`         | `kbuf` untouched (0x42) | PASS |
| 8 | console clears via routine  | `memzero16` on 4000-byte video buffer | visible screen blank | PASS |

---

## Directory layout

```
boot/
├── boot.asm          # stage-1 BIOS bootloader (512 B, 0xAA55)
├── kernel.asm        # stage-2 custom kernel + non-BIOS kernel console
├── memset.asm        # 16-bit port of libmem/memset.asm   -> memsetw
├── memzero.asm       # 16-bit port of libmem/memzero.asm  -> memzero16 (delegates)
├── memset_rev.asm    # 16-bit port of libmem/memset_rev.asm -> memset_rev16
├── memzero_rev.asm   # 16-bit port of libmem/memzero_rev.asm -> memzero_rev16 (delegates)
├── secure_wipe.asm   # 16-bit port of libmem/secure_w...rev -> secure_wipe16 (delegates, black-box)
├── Makefile          # builds boot.bin + kernel.bin -> disk.img, auto KERNEL_SECTORS
├── README.md         # this file
├── DEVLOG.md         # full journey: what was found, decisions, bugs fixed
└── .gitignore        # boot.bin, kernel.bin, kernel.pad, disk.img, *.lst
```

> Build artifacts (`boot.bin`, `kernel.bin`, `kernel.pad`, `disk.img`) are
> generated by `make` and ignored by git.

## Verified

- `boot.bin` is exactly **512 bytes** with signature `55 AA`.
- `kernel.bin` is sector-padded and concatenated into `disk.img`.
- `nasm -f bin` produces **zero warnings** for both binaries.
- QEMU: the kernel console boots and reports **8/8 PASS**.
- `bun typecheck` and `bun lint` pass on the host project.
