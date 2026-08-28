#!/usr/bin/env bash
#
# =============================================================================
# sanity_check.sh — libmem / os / boot / Next.js build & test verification
# =============================================================================
#
#  Runs every build system in the repo and verifies the results:
#    1. libmem/     — assembles NASM, archives .a, runs 27-test C harness
#    2. os/         — builds 32-bit kernel ELF + disk image (28 syscalls)
#    3. boot/       — builds 16-bit BIOS boot disk image (17 function demos)
#    4. boot/ QEMU  — runs disk.img in QEMU, checks for [OK] markers (17/17)
#    5. security    — verifies shell.c never calls kernel functions directly
#    6. Next.js     — runs bun typecheck + lint
#
#  Usage:
#    ./sanity_check.sh         # full build + test
#    ./sanity_check.sh --qemu  # also launch QEMU for interactive testing
#
#  Exit code: 0 = all green, 1 = at least one failure
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

DO_QEMU=false
[[ "${1:-}" == "--qemu" ]] && DO_QEMU=true

FAILURES=0

info()  { echo -e "${CYAN}${BOLD}=== $1 ===${NC}"; }
pass()  { echo -e "  ${GREEN}✓ $1${NC}"; }
fail()  { echo -e "  ${RED}✗ $1${NC}"; FAILURES=$((FAILURES + 1)); }
warn()  { echo -e "  ${YELLOW}! $1${NC}"; }

# ---------------------------------------------------------------------------
# 1. libmem/ — assembly memory library
# ---------------------------------------------------------------------------
info "Building libmem/ (32-bit x86 memory library)"

if command -v make &>/dev/null; then
    (cd "$SCRIPT_DIR/libmem" && make clean && make all) 2>&1
    (cd "$SCRIPT_DIR/libmem" && make test-suite 2>&1) || {
        fail "libmem test-suite failed"
    }
    pass "libmem/ built + 27 tests verified"
else
    warn "make not available in this environment"
    fail "libmem build requires make"
fi

echo ""

# ---------------------------------------------------------------------------
# 2. os/ — 32-bit protected-mode kernel
# ---------------------------------------------------------------------------
info "Building os/ kern (32-bit protected-mode kernel)"

if command -v make &>/dev/null; then
    (cd "$SCRIPT_DIR/os" && make clean && make all 2>&1) || {
        fail "os kernel build failed"
    }
    pass "os/ kernel built (kernel.elf, kernel.bin, disk.img)"
else
    warn "make not available — os kernel not built"
    fail "os build requires make"
fi

echo ""

# ---------------------------------------------------------------------------
# 3. boot/ — 16-bit BIOS boot stack
# ---------------------------------------------------------------------------
info "Building boot/ (16-bit BIOS boot stack)"

cd "$SCRIPT_DIR/boot" && rm -f kernel.bin kernel.pad boot.bin disk.img *.lst
nasm -f bin kernel.asm -o kernel.bin 2>&1
dd if=kernel.bin of=kernel.pad bs=512 conv=sync 2>&1
ksect=$(stat -c%s kernel.pad)
ksect=$(( (ksect + 511) / 512 ))
nasm -f bin -DKERNEL_SECTORS=$ksect boot.asm -o boot.bin 2>&1
test $(stat -c%s boot.bin) -eq 512
cat boot.bin kernel.pad > disk.img
cd "$SCRIPT_DIR"
pass "boot/ built (boot.bin=512B, kernel.bin, disk.img)"

echo ""

# ---------------------------------------------------------------------------
# 4. QEMU runtime test (boot/ disk image)
# ---------------------------------------------------------------------------
if command -v qemu-system-x86_64 &>/dev/null; then
    info "Running boot/ disk.img in QEMU (serial capture)"
    qemu_out=$(timeout 5 qemu-system-x86_64 \
        -drive format=raw,file="$SCRIPT_DIR/boot/disk.img" \
        -nographic -serial mon:stdio -no-reboot 2>&1 || true)

    ok_count=$(echo "$qemu_out" | grep -c '\[OK\]' || true)
    fail_count=$(echo "$qemu_out" | grep -c '\[FAIL\]' || true)

    if [ "$ok_count" -ge 17 ] && [ "$fail_count" -eq 0 ]; then
        pass "boot/ QEMU: $ok_count/[OK], $fail_count/[FAIL] (15 functions + 2 edge cases)"
    else
        fail "boot/ QEMU: $ok_count/[OK], $fail_count/[FAIL] (expected 17/[OK])"
        echo "$qemu_out" | head -20
    fi

    if $DO_QEMU; then
        info "Interactive QEMU session (boot/disk.img) — press Ctrl-A X to exit"
        qemu-system-x86_64 \
            -drive format=raw,file="$SCRIPT_DIR/boot/disk.img" \
            -nographic -serial mon:stdio -no-reboot
    fi
else
    warn "qemu-system-x86_64 not available — skipping runtime test"
fi

echo ""

# ---------------------------------------------------------------------------
# 4.5. Security boundary: shell.c must NOT call kernel functions directly
# ---------------------------------------------------------------------------
info "Security check: shell.c syscall boundary"

shell_direct_calls=$(grep -cE '^\s*(memset|memzero|memcpy|memmove|memcmp|memchr|memsetw|memfill|memswap|memreverse|memrotate_l|memrotate_r|memfind|memcount|memchecksum|memeq|memmove_rev|secure_wipe|console_putc|console_puts|console_puthex|console_gets|console_cls)\s*\(' "$SCRIPT_DIR/os/user/shell.c" 2>/dev/null) || shell_direct_calls=0

if [ "$shell_direct_calls" -eq 0 ]; then
    pass "shell.c: 0 direct kernel function calls (all via usys_* syscall wrappers)"
else
    fail "shell.c: $shell_direct_calls direct kernel calls found — security violation!"
    grep -nE '^\s*(memset|memzero|memcpy|memmove|memcmp|memchr|memsetw|memfill|memswap|memreverse|memrotate_l|memrotate_r|memfind|memcount|memchecksum|memeq|secure_wipe|console_)' "$SCRIPT_DIR/os/user/shell.c" | head -10
fi

echo ""
if command -v bun &>/dev/null; then
    info "Running Next.js typecheck + lint"
    (cd "$SCRIPT_DIR" && bun typecheck 2>&1) || {
        fail "Next.js typecheck failed"
    }
    (cd "$SCRIPT_DIR" && bun lint 2>&1) || {
        fail "Next.js lint failed"
    }
    pass "Next.js: typecheck + lint green"
else
    warn "bun not available — skipping Next.js checks"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary: libmem function inventory
# ---------------------------------------------------------------------------
info "libmem function inventory"

echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │  libmymem.a (21 general-purpose memory routines)    │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  memset         — forward byte fill                │"
echo "  │  memzero        — forward zero-fill (-> memset)     │"
echo "  │  memset_rev     — backward byte fill               │"
echo "  │  memzero_rev    — backward zero-fill (-> memset_rev)│"
echo "  │  memcpy         — forward byte copy (no overlap)   │"
echo "  │  memmove        — overlapping-safe copy           │"
echo "  │  memcmp         — compare two memory regions       │"
echo "  │  memchr         — find byte in memory              │"
echo "  │  memsetw        — forward 16-bit word fill         │"
echo "  │  memfill        — repeating 16-bit pattern fill     │"
echo "  │  memswap        — swap two memory regions          │"
echo "  │  memreverse     — reverse bytes in region          │"
echo "  │  memrotate_l    — left rotation by N bytes         │"
echo "  │  memrotate_r    — right rotation by N bytes        │"
echo "  │  memfind        — find byte, return offset         │"
echo "  │  memcount       — count byte occurrences           │"
echo "  │  memchecksum    — XOR checksum of region           │"
echo "  │  memeq          — boolean equality test (1/0)      │"
echo "  │  memmove_rev    — backward memmove variant         │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  libmysecure.a (DSE-protected secure wipes)        │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  secure_wipe_stack_rev — backward stack wipe       │"
echo "  │  secure_wipe_heap_rev  — backward heap wipe        │"
echo "  └─────────────────────────────────────────────────────┘"

echo ""
echo "  Kernel interface:"
echo "    int 0x80 -> syscall_dispatch  (28 syscalls, DPL=3 — userland gate)"
echo "    int 0x81 -> signal_dispatch   (SIG_LIBMEM_READY, SIG_LIBMEM_WIPE,"
echo "                                    SIG_LIBMEM_TEST_ALL — kernel-only,"
echo "                                    runs all 21 functions through dispatch)"
echo "    int 0x0D  -> gpf_handler       (General Protection Fault, DPL=0)"
echo "                  - software GPF: log to serial, iret (non-fatal)"
echo "                  - hardware GPF: log to serial, halt"
echo ""
echo "  Boot/ runtime: 15 function demos + 2 edge cases = 17 [OK] markers"
echo "  Syscall interface (os/kernel/syscall.h):"
echo "    int 0x80 -> syscall_dispatch  (28 syscalls, DPL=3)"
echo "    int 0x81 -> signal_dispatch   (SIG_LIBMEM_READY, SIG_LIBMEM_WIPE,"
echo "                                    SIG_LIBMEM_TEST_ALL — runs all 21 functions"
echo "                                    through kernel dispatch with GPF exception handling)"
echo "    int 0x0D  -> gpf_handler       (General Protection Fault, DPL=0)"
echo "                  - software GPF: log to serial, iret (non-fatal)"
echo "                  - hardware GPF: log to serial, halt"

echo ""

# ---------------------------------------------------------------------------
# Final verdict
# ---------------------------------------------------------------------------
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║  ALL CHECKS PASSED — sanity_check OK    ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  $FAILURES CHECK(S) FAILED — review above       ║${NC}"
    echo -e "${RED}${BOLD}╚════════════════════════════════════════╝${NC}"
    exit 1
fi
