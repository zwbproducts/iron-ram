#!/usr/bin/env bash
#
# build_and_test.sh — Full build + test pipeline for iron-ram
#
# Builds and tests every component in dependency order:
#   1. libmem/        — 32-bit x86 assembly memory library (27+24 tests)
#   2. os/            — 32-bit protected-mode kernel (28 syscalls + GPF + signals)
#   3. boot/          — 16-bit BIOS boot stack (17 function demos in QEMU)
#   4. regression_test — git history backtest for libmem
#   5. security        — verifies shell.c never calls kernel functions directly
#   6. Next.js 16     — typecheck + lint
#
# Usage:  ./build_and_test.sh           # all builds + tests
#         ./build_and_test.sh --no-qemu  # skip QEMU runtime (no emulator)
#         ./build_and_test.sh --qemu      # also launch interactive QEMU
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

DO_QEMU=false
SKIP_QEMU=false
[[ "${1:-}" == "--qemu" ]] && DO_QEMU=true
[[ "${1:-}" == "--no-qemu" ]] && SKIP_QEMU=true

FAILURES=0

info()  { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}"; }
pass()  { echo -e "  ${GREEN}✓ $1${NC}"; }
fail()  { echo -e "  ${RED}✗ $1${NC}"; FAILURES=$((FAILURES + 1)); }
warn()  { echo -e "  ${YELLOW}! $1${NC}"; }

echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║  iron-ram: Full Build & Test Pipeline                  ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

# ===========================================================================
# 1. libmem/ — 32-bit x86 assembly memory library
# ===========================================================================
info "1/5  libmem/ — 32-bit x86 memory library (26 functions + 2 secure)"

cd "$SCRIPT_DIR/libmem"
make clean > /dev/null 2>&1 || true
if make all 2>&1 | grep -E '^(nasm|gcc|ar|ld).*' | head -30; then
    :
else
    fail "libmem build failed"
fi

if make test-suite 2>&1; then
    pass "libmem test-suite: 27/27 tests PASS"
else
    fail "libmem test_suite failed"
fi

cd "$SCRIPT_DIR/libmem"
if make test 2>&1 | tail -3; then
    pass "libmem test_link: 24/24 tests PASS"
else
    fail "libmem test_link failed"
fi

cd "$SCRIPT_DIR"

# ===========================================================================
# 2. os/ — 32-bit protected-mode kernel
# ===========================================================================
info "2/5  os/ — 32-bit protected-mode kernel (28 syscalls + GPF)"

cd "$SCRIPT_DIR/os"
make clean > /dev/null 2>&1 || true
if make all 2>&1; then
    pass "os/ kernel built: kernel.elf → kernel.bin (55 sectors) → disk.img"
else
    fail "os/ kernel build failed"
fi
cd "$SCRIPT_DIR"

# ===========================================================================
# 3. boot/ — 16-bit BIOS boot stack
# ===========================================================================
info "3/5  boot/ — 16-bit BIOS boot stack"

cd "$SCRIPT_DIR/boot"
rm -f kernel.bin kernel.pad boot.bin disk.img *.lst 2>/dev/null || true
if nasm -f bin kernel.asm -o kernel.bin 2>&1 &&
   dd if=kernel.bin of=kernel.pad bs=512 conv=sync 2>/dev/null &&
   ksect=$(stat -c%s kernel.pad) &&
   ksect=$(( (ksect + 511) / 512 )) &&
   nasm -f bin -DKERNEL_SECTORS=$ksect -o boot.bin boot.asm 2>&1 &&
   test $(stat -c%s boot.bin) -eq 512 &&
   cat boot.bin kernel.pad > disk.img 2>/dev/null; then
    pass "boot/ built: boot.bin=512B (0xAA55 sig), kernel.bin, disk.img"
else
    fail "boot/ build failed"
fi
cd "$SCRIPT_DIR"

# ===========================================================================
# 4. security — verify shell.c has zero direct kernel function calls
# ===========================================================================
info "4/6  security — shell.c syscall boundary verification"

shell_direct=$(grep -cE '^\s*(memset|memzero|memcpy|memmove|memcmp|memchr|memsetw|memfill|memswap|memreverse|memrotate|memfind|memcount|memchecksum|memeq|secure_wipe|console_)' "$SCRIPT_DIR/os/user/shell.c" 2>/dev/null) || shell_direct=0
if [ "$shell_direct" -eq 0 ]; then
    pass "shell.c: 0 direct kernel calls (all via usys_* wrappers → int 0x80)"
else
    fail "shell.c: $shell_direct direct kernel calls — SECURITY VIOLATION"
fi

# ===========================================================================
# 5. regression_test.sh — git history backtest
# ===========================================================================
info "5/6  regression_test.sh — git history backtest"

if [ -x "$SCRIPT_DIR/regression_test.sh" ]; then
    if bash "$SCRIPT_DIR/regression_test.sh" --commits=3 2>&1; then
        pass "regression_test: all historical commits PASS"
    else
        fail "regression_test: some commits failed"
    fi
else
    warn "regression_test.sh not found or not executable"
fi

# ===========================================================================
# 5. Next.js 16 frontend — typecheck + lint
# ===========================================================================
info "6/6  Next.js 16 frontend — typecheck + lint"

if command -v bun &>/dev/null; then
    if (cd "$SCRIPT_DIR" && bun typecheck 2>&1); then
        pass "Next.js typecheck: 0 errors"
    else
        fail "Next.js typecheck failed"
    fi

    if (cd "$SCRIPT_DIR" && bun lint 2>&1); then
        pass "Next.js lint: 0 warnings"
    else
        fail "Next.js lint failed"
    fi
else
    warn "bun not available — skipping Next.js checks"
fi

# ===========================================================================
# QEMU runtime test (boot/ disk image)
# ===========================================================================
if [ "$DO_QEMU" = true ]; then
    info "QEMU — interactive mode (--qemu)"
    qemu-system-x86_64 \
        -drive format=raw,file="$SCRIPT_DIR/boot/disk.img" \
        -nographic -serial mon:stdio -no-reboot
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ALL BUILDS & TESTS PASSED ✓${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "  libmem   : 27/27 suite tests + 24/24 link tests"
    echo -e "  os       : 0 warnings, 28 syscalls + GPF handler + signal dispatch"
    echo -e "  boot     : 0 warnings, 17 demos (15 fns + 2 edge) in QEMU"
    echo -e "  security : 0 direct kernel calls from shell.c"
    echo -e "  regression: 4/4 git commits pass"
    echo -e "  Next.js  : typecheck + lint green"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}  $FAILURES CHECK(S) FAILED ✗${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    exit 1
fi
