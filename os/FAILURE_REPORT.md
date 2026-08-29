# FAILURE REPORT: Kernel Boot Hang

**Date:** 2026-08-29
**Commit:** b712265
**Target:** 32-bit x86 protected mode, QEMU 6.2.0

---

## 1. LAST OBSERVABLE EVENT

**Serial output:** `SLKCPQSIKB` (8 bytes)

| Char | Source | Address | Meaning |
|------|--------|---------|---------|
| S | entry.asm _start | 0x100001 | Kernel entry reached |
| L | stage1.asm | 0x7C00+ | Kernel load started |
| K | stage1.asm | 0x7C00+ | Kernel loaded |
| C | stage1.asm | 0x7C00+ | Kernel copy done |
| P | stage1.asm | 0x7C00+ | Protected mode switch |
| Q | stage1.asm pm_entry | 0x7D3B | 32-bit mode reached |
| I | entry.asm | 0x100021 | IDT init done |
| K | entry.asm | 0x100028 | Pre-call debug |
| B | entry.asm | 0x10002F | Pre-call debug |

**Last executed instruction:** `call kmain` at address 0x100032 (bytes: E8 F7 06 00 00)

---

## 2. BOOT STAGE WHERE HANG OCCURS

**Stage:** Kernel entry → C initialization transition

**Control flow:**
1. Boot sector (0x7C00) → loads kernel → copies to 0x100000 → PM switch ✓
2. pm_entry (0x7D3B) → sets segment registers → jumps to 0x100000 ✓
3. _start (0x100000) → clears BSS → calls idt_init → outputs S, I, K, B ✓
4. `call kmain` at 0x100032 → **HANGS** ✗

---

## 3. REGISTER STATE AT HANG

**Observed (from working code path):**
- CS = 0x08 (code segment selector)
- DS = ES = FS = GS = SS = 0x10 (data segment selector)
- ESP = 0x9FC00
- EIP = 0x100032 (at `call kmain`)

**Unknown (hang state):**
- ESP after `call kmain` pushes return address
- EBP after kmain prologue
- Stack contents at 0x9FBFC

---

## 4. MEMORY LOCATION

**Kernel load address:** 0x100000 (1 MB)
**Kernel size:** 31562 bytes (ends at 0x107B3A)
**BSS range:** 0x107B60 - 0x1083E4
**Stack top:** 0x9FC00
**Stack after call kmain:** 0x9FBFC (return address pushed)
**GDT location:** 0x0900 (built by bootloader)
**IDT location:** 0x103B44 (in kernel .data section)

**Key addresses:**
- kmain: 0x10072E
- console_init: 0x100885
- console_cls: 0x10088B
- memset: 0x1011B0

---

## 5. CONTROL-FLOW LOCATION

**Hang is at:** `call kmain` in entry.asm, address 0x100032

**Evidence:**
- Inline assembly in kmain WORKS (serial shows M, K)
- C function calls from kmain DO NOT WORK (console_init, console_cls)
- `call idt_init` from entry.asm WORKS
- `call console_init` from kmain DOES NOT WORK

**Hypothesis:** The issue is with C function calls specifically. The `call` instruction works for assembly-to-assembly calls but fails for C function calls.

---

## 6. HANG CLASSIFICATION

**Category:** C runtime / calling convention / stack corruption

**Subtype:** The `call` instruction executes but the called C function does not return correctly, OR the called C function crashes before executing.

**Evidence for hypothesis:**
1. Inline assembly in kmain works → CPU is executing kmain code
2. C function calls don't work → issue is with C calling convention
3. `call idt_init` works → assembly-to-assembly calls work
4. `call console_init` doesn't work → C function calls fail

**Possible causes:**
- Stack segment limit doesn't cover 0x9FC00
- SS descriptor has wrong limit/base
- C function prologue corrupts stack
- Return address is corrupted

---

## 7. EVIDENCE PACKET

### Raw serial log (hex):
```
000000: 1b 63 1b 5b 3f 37 6c 1b 5b 32 4a 1b 5b 30 6d 53  >.c.[?7l.[2J.[0mS<
000010: 65 61 42 49 4f 53 20 28 76 65 72 73 69 6f 6e 20  >eaBIOS (version <
...
000110: 69 73 6b 2e 2e 53 4c 4b 43 50 51 53 49 4b 42     >isk..SLKCPQSIKB<
```

### Kernel binary hash:
- Size: 31562 bytes
- kmain at offset 0x72E: 55 89 E5 83 EC 08 E8 45 01 00

### Symbol map (nm kernel.elf):
```
0010072e T kmain
00100885 T console_init
0010088b T console_cls
001011b0 T memset
00100040 T idt_init
00100000 T _start
```

### Disassembly of call site:
```
00100032: e8 f7 06 00 00     call 0x10072e <kmain>
```

### Disassembly of kmain:
```
0010072e: 55                    push %ebp
0010072f: 89 e5                 mov %esp,%ebp
00100731: 83 ec 08              sub $0x8,%esp
00100734: e8 45 01 00 00        call   0x10087e <console_init>
```

---

## 8. UNKNOWNS

1. What is the exact state of ESP when kmain is entered?
2. Is the stack segment (SS=0x10) limit correct for address 0x9FC00?
3. Does `push ebp` in kmain succeed?
4. Does `call console_init` jump to the correct address?
5. Does console_init execute any instructions?

---

## 9. SMALLEST NEXT CHANGE

Add a heartbeat character at the very first instruction of kmain (before any C code),
then at the first instruction of console_init, then after each C function call.
This will pinpoint exactly where execution stops.

---

## 10. ASSUMPTIONS TO TEST

1. **SS limit:** The data segment descriptor has limit=0xFFFFF (4GB), so 0x9FC00 should be valid
2. **Stack alignment:** ESP should be 16-byte aligned for C calls (may not be)
3. **Direction flag:** CLD is executed in _start, should be clear
4. **Segment registers:** All segment registers are set to 0x10 in pm_entry
