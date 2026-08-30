#!/usr/bin/env bash
#
# build.sh — Unified build script for iron-ram
#
# Builds and tests every component in dependency order with flag-controlled
# testing. Kills QEMU cleanly on exit (Unixy behavior).
#
# Build order:
#   1. libmem/   — 32-bit x86 assembly memory library (pure C library)
#   2. os/       — 32-bit protected-mode kernel (28 syscalls + GPF)
#   3. boot/     — 16-bit BIOS boot stack (17 function demos)
#
# Usage:
#   ./build.sh            # build + test everything (default)
#   ./build.sh --clean    # remove all build artifacts
#   ./build.sh --libmem   # build + test libmem only (pure library)
#   ./build.sh --os       # build + test os in QEMU
#   ./build.sh --boot     # build + test boot in QEMU
#   ./build.sh --all      # same as default
#   ./build.sh --qemu     # interactive QEMU after automated tests
#   ./build.sh --no-qemu  # skip QEMU tests (build only)
#   ./build.sh --help     # show this help
#
# Exit codes:
#   0 = all builds + tests passed
#   1 = at least one failure
#
# QEMU cleanup:
#   Any QEMU process started by this script is killed on exit (normal,
#   Ctrl-C, or error) via EXIT trap.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Defaults ───
TARGET="all"
DO_INTERACTIVE_QEMU=false
SKIP_QEMU=false

# ─── Parse args ───
for arg in "$@"; do
    case $arg in
        --clean)   TARGET="clean" ;;
        --libmem)  TARGET="libmem" ;;
        --os)      TARGET="os" ;;
        --boot)    TARGET="boot" ;;
        --all)     TARGET="all" ;;
        --qemu)    DO_INTERACTIVE_QEMU=true ;;
        --no-qemu) SKIP_QEMU=true ;;
        --help|-h)
            echo "Usage: $0 [--clean|--libmem|--os|--boot|--all] [--qemu|--no-qemu]"
            echo ""
            echo "Targets:"
            echo "  --all      Build + test everything (default)"
            echo "  --clean    Remove all build artifacts"
            echo "  --libmem   Build + test libmem only (pure library)"
            echo "  --os       Build + test os in QEMU"
            echo "  --boot     Build + test boot in QEMU"
            echo ""
            echo "QEMU flags:"
            echo "  --qemu     Launch interactive QEMU after automated tests"
            echo "  --no-qemu  Skip all QEMU tests (build only)"
            exit 0
            ;;
        *) echo "Unknown option: $arg. Use --help for usage."; exit 1 ;;
    esac
done

# ─── Helpers ───
info()  { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}"; }
pass()  { echo -e "  ${GREEN}✓ $1${NC}"; }
fail()  { echo -e "  ${RED}✗ $1${NC}"; FAILURES=$((FAILURES + 1)); }
warn()  { echo -e "  ${YELLOW}! $1${NC}"; }

# ─── QEMU cleanup (Unixy exit) ───
# Kills any QEMU process started by this script on normal exit, Ctrl-C, or error.
QEMU_PIDS=()
cleanup_qemu() {
    for pid in "${QEMU_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    pkill -f "qemu-system-x86_64" 2>/dev/null || true
}
trap cleanup_qemu EXIT

# ─── Toolchain check ───
check_toolchain() {
    local missing=()
    for tool in make nasm gcc qemu-system-x86_64; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}  Missing tools: ${missing[*]}${NC}"
        if command -v apt-get &>/dev/null; then
            echo -e "${CYAN}  Installing toolchain...${NC}"
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq make nasm gcc gcc-multilib qemu-system-x86 2>/dev/null || {
                echo -e "${RED}  Failed to install toolchain. Install manually:${NC}"
                echo -e "${RED}    apt-get install make nasm gcc gcc-multilib qemu-system-x86${NC}"
                exit 1
            }
        else
            echo -e "${RED}  Required tools not found: ${missing[*]}${NC}"
            echo -e "${RED}  Install them before running this script.${NC}"
            exit 1
        fi
    fi
    # Verify gcc-multilib works (32-bit support)
    if ! echo 'int main(){}' | gcc -m32 -x c - -o /dev/null 2>/dev/null; then
        echo -e "${YELLOW}  gcc -m32 not available, installing gcc-multilib...${NC}"
        apt-get install -y -qq gcc-multilib 2>/dev/null || {
            echo -e "${RED}  Failed to install gcc-multilib.${NC}"
            exit 1
        }
    fi
}
check_toolchain

# ─── Summary counter ───
FAILURES=0

# =============================================================================
# CLEAN
# =============================================================================
do_clean() {
    info "Cleaning all build artifacts"

    # libmem/
    if [ -d "$SCRIPT_DIR/libmem" ]; then
        (cd "$SCRIPT_DIR/libmem" && make clean 2>/dev/null) || true
        rm -f "$SCRIPT_DIR/libmem"/*.o "$SCRIPT_DIR/libmem"/*.a \
              "$SCRIPT_DIR/libmem"/test_link "$SCRIPT_DIR/libmem"/test_suite
    fi

    # os/
    if [ -d "$SCRIPT_DIR/os" ]; then
        (cd "$SCRIPT_DIR/os" && make clean 2>/dev/null) || true
        rm -f "$SCRIPT_DIR/os"/*.elf "$SCRIPT_DIR/os"/*.bin "$SCRIPT_DIR/os"/*.img
        rm -f "$SCRIPT_DIR/os"/kernel/*.o "$SCRIPT_DIR/os"/user/*.o
    fi

    # boot/
    if [ -d "$SCRIPT_DIR/boot" ]; then
        (cd "$SCRIPT_DIR/boot" && make clean 2>/dev/null) || true
        rm -f "$SCRIPT_DIR/boot"/*.bin "$SCRIPT_DIR/boot"/*.img \
              "$SCRIPT_DIR/boot"/*.pad "$SCRIPT_DIR/boot"/*.lst
    fi

    pass "All artifacts cleaned"
}

# =============================================================================
# LIBMEM — pure library build + test
# =============================================================================
do_libmem() {
    info "Building libmem/ (32-bit x86 memory library)"

    if [ ! -d "$SCRIPT_DIR/libmem" ]; then
        fail "libmem/ directory not found"
        return
    fi

    (cd "$SCRIPT_DIR/libmem" && make clean && make all 2>&1) || {
        fail "libmem build failed"
        return
    }
    pass "libmem built: libmymem.a + libmysecure.a"

    info "Testing libmem/"

    # test-suite: comprehensive C harness (27 tests)
    if (cd "$SCRIPT_DIR/libmem" && make test-suite 2>&1); then
        pass "libmem test-suite: PASS"
    else
        fail "libmem test-suite failed"
    fi

    # test_link: binary compatibility test (24 tests)
    if (cd "$SCRIPT_DIR/libmem" && make test 2>&1); then
        pass "libmem test_link: PASS"
    else
        fail "libmem test_link failed"
    fi
}

# =============================================================================
# OS — 32-bit kernel build + QEMU test
# =============================================================================
do_os() {
    info "Building os/ (32-bit protected-mode kernel)"

    if [ ! -d "$SCRIPT_DIR/os" ]; then
        fail "os/ directory not found"
        return
    fi

    (cd "$SCRIPT_DIR/os" && make clean && make all 2>&1) || {
        fail "os build failed"
        return
    }
    pass "os built: kernel.elf + kernel.bin + disk.img"

    # Skip QEMU if requested
    if [ "$SKIP_QEMU" = true ]; then
        warn "Skipping os/ QEMU test (--no-qemu)"
        return
    fi

    info "Testing os/ in QEMU"

    if ! command -v qemu-system-x86_64 &>/dev/null; then
        warn "qemu-system-x86_64 not found — skipping os QEMU test"
        return
    fi

    local serial_log
    serial_log=$(mktemp "$SCRIPT_DIR"/.serial_log_XXXXXX)

    # Run QEMU with timeout so it exits automatically
    timeout 10s qemu-system-x86_64 \
        -drive format=raw,file="$SCRIPT_DIR/os/disk.img" \
        -nographic -serial file:"$serial_log" -no-reboot 2>/dev/null || true

    # Analyze serial output
    local chars
    chars=$(strings "$serial_log" 2>/dev/null | tr -d '\n' || echo "")
    rm -f "$serial_log"

    # Verify boot sequence markers: S B I E
    local found=0
    for c in S B I E; do
        if echo "$chars" | grep -q "$c"; then
            pass "Boot marker '$c' found"
            found=$((found + 1))
        else
            fail "Boot marker '$c' missing"
        fi
    done

    # Verify shell banner
    if echo "$chars" | grep -q "iron-ram shell"; then
        pass "Shell banner found"
        found=$((found + 1))
    else
        fail "Shell banner NOT found"
    fi

    # Verify shell ready message
    if echo "$chars" | grep -q "Type 'help'"; then
        pass "Shell ready message found"
        found=$((found + 1))
    else
        fail "Shell ready message NOT found"
    fi

    if [ "$found" -ge 6 ]; then
        pass "os/ QEMU boot test PASSED ($found/6 checks)"
    else
        fail "os/ QEMU boot test FAILED ($found/6 checks)"
    fi
}

# =============================================================================
# BOOT — 16-bit BIOS boot stack build + QEMU test
# =============================================================================
do_boot() {
    info "Building boot/ (16-bit BIOS boot stack)"

    if [ ! -d "$SCRIPT_DIR/boot" ]; then
        fail "boot/ directory not found"
        return
    fi

    (cd "$SCRIPT_DIR/boot" && make clean && make all 2>&1) || {
        fail "boot build failed"
        return
    }
    pass "boot built: boot.bin + kernel.bin + disk.img"

    # Skip QEMU if requested
    if [ "$SKIP_QEMU" = true ]; then
        warn "Skipping boot/ QEMU test (--no-qemu)"
        return
    fi

    info "Testing boot/ in QEMU"

    if ! command -v qemu-system-x86_64 &>/dev/null; then
        warn "qemu-system-x86_64 not found — skipping boot QEMU test"
        return
    fi

    local serial_log
    serial_log=$(mktemp "$SCRIPT_DIR"/.serial_log_XXXXXX)

    # Run QEMU with timeout so it exits automatically
    timeout 10s qemu-system-x86_64 \
        -drive format=raw,file="$SCRIPT_DIR/boot/disk.img" \
        -nographic -serial file:"$serial_log" -no-reboot 2>/dev/null || true

    # Count [OK] and [FAIL] markers
    local ok_count fail_count
    ok_count=$(grep -c '\[OK\]' "$serial_log" 2>/dev/null) || ok_count=0
    fail_count=$(grep -c '\[FAIL\]' "$serial_log" 2>/dev/null) || fail_count=0

    rm -f "$serial_log"

    if [ "$fail_count" -eq 0 ] && [ "$ok_count" -ge 17 ]; then
        pass "boot/ QEMU: $ok_count [OK], $fail_count [FAIL]"
    else
        fail "boot/ QEMU: $ok_count [OK], $fail_count [FAIL] (expected >=17 [OK])"
    fi
}

# =============================================================================
# MAIN
# =============================================================================
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║  iron-ram: Unified Build & Test                      ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

case "$TARGET" in
    clean)
        do_clean
        ;;
    libmem)
        do_libmem
        ;;
    os)
        do_os
        ;;
    boot)
        do_boot
        ;;
    all)
        do_clean
        do_libmem
        do_os
        do_boot
        ;;
esac

# =============================================================================
# INTERACTIVE QEMU
# =============================================================================
if [ "$DO_INTERACTIVE_QEMU" = true ]; then
    info "Interactive QEMU"
    echo -e "  ${YELLOW}Press Ctrl-A X to exit QEMU${NC}"

    # Pick the best available disk image
    disk=""
    if [ -f "$SCRIPT_DIR/os/disk.img" ]; then
        disk="$SCRIPT_DIR/os/disk.img"
    elif [ -f "$SCRIPT_DIR/boot/disk.img" ]; then
        disk="$SCRIPT_DIR/boot/disk.img"
    fi

    if [ -n "$disk" ]; then
        # Run QEMU in foreground; trap will clean up on exit
        qemu-system-x86_64 \
            -drive format=raw,file="$disk" \
            -nographic -serial mon:stdio -no-reboot || true
    else
        warn "No disk image found for interactive QEMU"
    fi
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ALL BUILDS & TESTS PASSED ✓${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}  $FAILURES CHECK(S) FAILED ✗${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    exit 1
fi
