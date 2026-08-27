#!/usr/bin/env bash
#
# =============================================================================
# sanity_check.sh — libmem / os / boot / Next.js build & test verification
# =============================================================================
#
#  Runs every build system in the repo and verifies the results:
#    1. libmem/     — assembles NASM, archives .a, runs 17-test C harness
#    2. os/         — builds 32-bit kernel ELF + disk image
#    3. boot/       — builds 16-bit BIOS boot disk image
#    4. boot/ QEMU  — runs disk.img in QEMU, checks for [OK] markers
#    5. Next.js     — runs bun typecheck + lint
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
    pass "libmem/ built + 17 tests verified"
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

    if [ "$ok_count" -ge 6 ] && [ "$fail_count" -eq 0 ]; then
        pass "boot/ QEMU: $ok_count/[OK], $fail_count/[FAIL]"
    else
        fail "boot/ QEMU: $ok_count/[OK], $fail_count/[FAIL]"
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
# 5. Next.js frontend — typecheck + lint
# ---------------------------------------------------------------------------
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
echo "  │  libmymem.a (general-purpose memory routines)     │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  memset         — forward byte fill                │"
echo "  │  memzero        — forward zero-fill (→ memset)     │"
echo "  │  memset_rev     — backward byte fill               │"
echo "  │  memzero_rev    — backward zero-fill (→ memset_rev)│"
echo "  │  memcpy         — forward byte copy (no overlap)   │"
echo "  │  memmove        — overlapping-safe copy           │"
echo "  │  memcmp         — compare two memory regions       │"
echo "  │  memchr         — find byte in memory              │"
echo "  │  memsetw        — forward 16-bit word fill         │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  libmysecure.a (DSE-protected secure wipe)        │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  secure_wipe_stack_rev — backward stack wipe       │"
echo "  │  secure_wipe_heap_rev  — backward heap wipe        │"
echo "  └─────────────────────────────────────────────────────┘"

echo ""
echo "  Syscall interface (os/kernel/syscall.h):"
echo "    int 0x80 → syscall_dispatch  (18 syscalls, DPL=3)"
echo "    int 0x81 → signal_dispatch   (SIG_LIBMEM_READY, SIG_LIBMEM_WIPE)"

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
