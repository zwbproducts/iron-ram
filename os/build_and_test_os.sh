#!/usr/bin/env bash
#
# build_and_test_os.sh — Build and test the 32-bit kernel + userland
#
# This script builds the kernel, userland, and disk image, then runs
# QEMU tests to verify the syscall path works.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  iron-ram OS Build & Test"
echo "=========================================="

# ─── Step 1: Build kernel ───
echo ""
echo "=== Step 1: Build kernel ==="
make clean 2>/dev/null || true
make kernel.elf
make kernel.bin
echo "  kernel.bin: $(stat -c %s kernel.bin) bytes"

# ─── Step 2: Build userland ───
echo ""
echo "=== Step 2: Build userland ==="
make userland.elf
make userland.bin
echo "  userland.bin: $(stat -c %s userland.bin) bytes"

# ─── Step 3: Build boot sector ───
echo ""
echo "=== Step 3: Build boot sector ==="
make stage1.bin
echo "  stage1.bin: $(stat -c %s stage1.bin) bytes"

# ─── Step 4: Create disk image ───
echo ""
echo "=== Step 4: Create disk image ==="
make disk.img
echo "  disk.img: $(stat -c %s disk.img) bytes"

# ─── Step 5: Verify security boundary ───
echo ""
echo "=== Step 5: Verify security boundary ==="
make verify-shell

# ─── Step 6: Run QEMU boot test ───
echo ""
echo "=== Step 6: QEMU boot test ==="
SERIAL_LOG="/tmp/serial_boot.log"
timeout 10s qemu-system-x86_64 -drive format=raw,file=disk.img \
    -nographic -serial file:"$SERIAL_LOG" -no-reboot 2>/dev/null || true

echo "  Serial output:"
cat "$SERIAL_LOG" | od -A x -t x1z | head -5

# ─── Step 7: Verify boot sequence ───
echo ""
echo "=== Step 7: Verify boot sequence ==="
SERIAL_CHARS=$(strings "$SERIAL_LOG" | tr -d '\n')
echo "  Raw chars: $SERIAL_CHARS"

# Check for expected heartbeat sequence
EXPECTED="SBIE"  ; # S=entry, B=BSS, I=IDT, E=enter userland; then shell starts
FOUND=0
for i in $(seq 1 ${#EXPECTED}); do
    CHAR="${EXPECTED:i-1:1}"
    if echo "$SERIAL_CHARS" | grep -q "$CHAR"; then
        FOUND=$((FOUND + 1))
        echo "  Found '$CHAR' ✓"
    else
        echo "  Missing '$CHAR' ✗"
    fi
done

# Check for shell banner
if echo "$SERIAL_CHARS" | grep -q "iron-ram shell"; then
    echo "  Shell banner found ✓"
    FOUND=$((FOUND + 1))
else
    echo "  Shell banner NOT found ✗"
fi

# Check for shell ready message
if echo "$SERIAL_CHARS" | grep -q "Type 'help'"; then
    echo "  Shell ready message found ✓"
    FOUND=$((FOUND + 1))
else
    echo "  Shell ready message NOT found ✗"
fi

if [ "$FOUND" -ge 6 ]; then
    echo ""
    echo "=== BOOT TEST PASSED ==="
    echo "  All heartbeat characters and self-test found in serial output"
else
    echo ""
    echo "=== BOOT TEST FAILED ==="
    echo "  Only $FOUND/6 checks passed"
    echo "  Check $SERIAL_LOG for details"
    exit 1
fi

echo ""
echo "=========================================="
echo "  Build & Test Complete"
echo "=========================================="
