#!/usr/bin/env bash
#
# =============================================================================
# timeline_regression.sh -- Full git history timeline + regression backtest
# =============================================================================
#
# Colour-coded comprehensive view of EVERY commit in the repo's history, with
# per-commit build + test status for libmem/, os/, and boot/.
#
#   Timeline view  -- all commits oldest->newest, with file-change stats
#   Per-commit test -- extract tree, build, run tests, report pass/fail
#   Colour coding  -- green=pass  red=fail  yellow=skip  blue=info  magenta=warn
#   Summary stats  -- totals, coverage evolution, build health over time
#
# Usage:
#   ./timeline_regression.sh              full timeline + regression
#   ./timeline_regression.sh --timeline   timeline view only (no builds)
#   ./timeline_regression.sh --commits=N  limit to N most recent commits
#   ./timeline_regression.sh --quiet      minimal output
#   ./timeline_regression.sh --help       usage info
#
# Exit code: number of failed commits (0 = all green)
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# colours
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; DIM='\033[2m'
NC='\033[0m'

# symbols
SYM_PASS="PASS"; SYM_FAIL="FAIL"; SYM_SKIP="SKIP"; SYM_WARN="WARN"

# options
QUIET=0; MAX_COMMITS=0; TIMELINE_ONLY=0
for arg in "$@"; do
    case $arg in
        --quiet|-q) QUIET=1 ;;
        --timeline|-t) TIMELINE_ONLY=1 ;;
        --commits=*) MAX_COMMITS="${arg#*=}" ;;
        --help|-h)
            sed -n '2,20p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() { [ "$QUIET" -eq 0 ] && echo -e "$*" || true; }

# helpers
count_files_at_commit() {
    local hash="$1"; shift
    git ls-tree -r --name-only "$hash" -- "$@" 2>/dev/null | wc -l
}

# banner
echo ""
log "${CYAN}${BOLD}======================================================================${NC}"
log "${CYAN}${BOLD}  TIMELINE REGRESSION -- Full Git History Backtest${NC}"
log "${CYAN}${BOLD}======================================================================${NC}"
echo ""

log "${BOLD}Colour Legend:${NC}"
log "  ${GREEN}PASS${NC} = pass   ${RED}FAIL${NC} = fail   ${YELLOW}SKIP${NC} = skip   ${MAGENTA}WARN${NC} = warn   ${CYAN}*${NC} = commit"
echo ""

# gather commits (oldest first)
mapfile -t RAW_COMMITS < <(git log --format='%H|%h|%an|%ad|%s' --date=short 2>/dev/null | tac)

if [ "$MAX_COMMITS" -gt 0 ]; then
    RAW_COMMITS=("${RAW_COMMITS[@]: -$MAX_COMMITS}")
fi

TOTAL=${#RAW_COMMITS[@]}
log "${BOLD}Found ${TOTAL} commits to analyse.${NC}"
echo ""

# timeline header
log "${CYAN}${BOLD}======================================================================${NC}"
log "${CYAN}${BOLD}  TIMELINE${NC}"
log "${CYAN}${BOLD}======================================================================${NC}"
echo ""
log "$(printf '  ${BOLD}%-4s %-8s %-12s %-20s %-8s %s${NC}' '' 'Hash' 'Date' 'Author' 'Files' 'Subject')"
log "$(printf '  %-4s %-8s %-12s %-20s %-8s %s' '----' '--------' '------------' '--------------------' '--------' '--------------------------------------------')"

for entry in "${RAW_COMMITS[@]}"; do
    IFS='|' read -r FULL_HASH SHORT_HASH AUTHOR DATE SUBJECT <<< "$entry"
    FILE_COUNT=$(count_files_at_commit "$FULL_HASH")
    AUTHOR_TRUNC="${AUTHOR:0:18}"
    log "$(printf "  ${CYAN}*${NC} %-8s %-12s %-20s ${DIM}%5d${NC}   %s" \
        "$SHORT_HASH" "$DATE" "$AUTHOR_TRUNC" "$FILE_COUNT" "${SUBJECT:0:45}")"
done

echo ""

# exit early if timeline-only
if [ "$TIMELINE_ONLY" -eq 1 ]; then
    log "${DIM}(--timeline mode: skipping build & test)${NC}"
    exit 0
fi

# regression header
log "${CYAN}${BOLD}======================================================================${NC}"
log "${CYAN}${BOLD}  REGRESSION BACKTEST${NC}"
log "${CYAN}${BOLD}======================================================================${NC}"
echo ""

# temp workspace
WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT

PASSED=0; FAILED=0; SKIPPED=0
RESULTS=""

# per-commit test function
test_commit() {
    local FULL_HASH="$1" SHORT_HASH="$2" SUBJECT="$3" IDX="$4" TOTAL="$5"

    log "${BOLD}[$IDX/$TOTAL]${NC} ${CYAN}$SHORT_HASH${NC} ${SUBJECT:0:50}"

    # extract tree
    local COMMIT_DIR="$WORK/c$IDX"
    mkdir -p "$COMMIT_DIR"

    if ! git archive "$FULL_HASH" 2>/dev/null | tar -x -C "$COMMIT_DIR" 2>/dev/null; then
        log "  ${RED}FAIL Failed to extract tree${NC}"
        RESULTS+="$(printf '  %s %-45s %s\n' "$IDX/$TOTAL" "$SHORT_HASH ${SUBJECT:0:35}" "${RED}EXTRACT FAIL${NC}")"
        FAILED=$((FAILED + 1))
        return
    fi

    local LIBMEM_STATUS="${YELLOW}${SYM_SKIP}${NC}"
    local OS_STATUS="${YELLOW}${SYM_SKIP}${NC}"
    local BOOT_STATUS="${YELLOW}${SYM_SKIP}${NC}"

    # test libmem/
    if [ -d "$COMMIT_DIR/libmem" ]; then
        local LIBMEM_DIR="$COMMIT_DIR/libmem"
        mkdir -p "$WORK/libmem_$IDX"
        cp -r "$LIBMEM_DIR"/* "$WORK/libmem_$IDX/"
        cd "$WORK/libmem_$IDX"

        if make clean > /dev/null 2>&1 && make all > "$WORK/build_libmem_$IDX.log" 2>&1; then
            LIBMEM_STATUS="${GREEN}${SYM_PASS} build${NC}"

            if [ -f "test_link.c" ]; then
                if gcc -m32 -fno-builtin -fno-stack-protector -Wall -std=c11 \
                    -o test_link test_link.c -L. -lmysecure -lmymem 2>/dev/null && \
                    ./test_link > "$WORK/run_libmem_$IDX.log" 2>&1; then
                    local TL_COUNT
                    TL_COUNT=$(grep -oP '[0-9]+(?= tests passed)' "$WORK/run_libmem_$IDX.log" 2>/dev/null || echo "?")
                    LIBMEM_STATUS="${GREEN}${SYM_PASS} build+test_link(${TL_COUNT})${NC}"
                else
                    LIBMEM_STATUS="${RED}${SYM_FAIL} test_link FAIL${NC}"
                fi
            elif [ -f "test_suite.c" ]; then
                if gcc -m32 -fno-builtin -fno-stack-protector -Wall -std=c11 \
                    -o test_suite test_suite.c -L. -lmysecure -lmymem 2>/dev/null && \
                    ./test_suite > "$WORK/run_libmem_$IDX.log" 2>&1; then
                    local TS_COUNT
                    TS_COUNT=$(grep -oP 'ALL \K[0-9]+(?= TESTS PASSED)' "$WORK/run_libmem_$IDX.log" 2>/dev/null || echo "?")
                    LIBMEM_STATUS="${GREEN}${SYM_PASS} build+test_suite(${TS_COUNT})${NC}"
                else
                    LIBMEM_STATUS="${RED}${SYM_FAIL} test_suite FAIL${NC}"
                fi
            else
                LIBMEM_STATUS="${GREEN}${SYM_PASS} build only${NC}"
            fi
        else
            LIBMEM_STATUS="${RED}${SYM_FAIL} build FAIL${NC}"
        fi
        cd "$SCRIPT_DIR"
    fi

    # test os/
    if [ -d "$COMMIT_DIR/os" ]; then
        local OS_DIR="$COMMIT_DIR/os"
        mkdir -p "$WORK/os_$IDX/os"
        cp -r "$OS_DIR"/* "$WORK/os_$IDX/os/"
        # os/Makefile expects ../libmem/ — create symlink if libmem exists
        if [ -d "$COMMIT_DIR/libmem" ]; then
            mkdir -p "$WORK/os_$IDX/libmem"
            cp -r "$COMMIT_DIR/libmem"/* "$WORK/os_$IDX/libmem/"
        fi
        cd "$WORK/os_$IDX/os"

        if make clean > /dev/null 2>&1 && make all > "$WORK/build_os_$IDX.log" 2>&1; then
            local SECTORS
            SECTORS=$(grep -oP 'kernel sectors=\K[0-9]+' "$WORK/build_os_$IDX.log" 2>/dev/null || echo "?")
            OS_STATUS="${GREEN}${SYM_PASS} build(${SECTORS} sectors)${NC}"
        else
            OS_STATUS="${RED}${SYM_FAIL} build FAIL${NC}"
        fi
        cd "$SCRIPT_DIR"
    fi

    # test boot/
    if [ -d "$COMMIT_DIR/boot" ]; then
        local BOOT_DIR="$COMMIT_DIR/boot"
        cp -r "$BOOT_DIR" "$WORK/boot_$IDX"
        cd "$WORK/boot_$IDX"

        local BOOT_BUILT=0
        if make clean > /dev/null 2>&1 && make all > "$WORK/build_boot_$IDX.log" 2>&1; then
            BOOT_STATUS="${GREEN}${SYM_PASS} build${NC}"
            BOOT_BUILT=1
        elif [ -f "kernel.asm" ] && [ -f "boot.asm" ]; then
            if nasm -f bin kernel.asm -o kernel.bin 2>/dev/null && \
               dd if=kernel.bin of=kernel.pad bs=512 conv=sync 2>/dev/null; then
                local KS
                KS=$(( ($(stat -c%s kernel.pad) + 511) / 512 ))
                if nasm -f bin -DKERNEL_SECTORS="$KS" boot.asm -o boot.bin 2>/dev/null && \
                   test "$(stat -c%s boot.bin)" -eq 512; then
                    cat boot.bin kernel.pad > disk.img 2>/dev/null
                    BOOT_STATUS="${GREEN}${SYM_PASS} build (manual)${NC}"
                    BOOT_BUILT=1
                fi
            fi
        fi

        if [ "$BOOT_BUILT" -eq 1 ] && [ -f "disk.img" ] && command -v qemu-system-x86_64 &>/dev/null; then
            local QEMU_OUT
            QEMU_OUT=$(timeout 5 qemu-system-x86_64 -drive format=raw,file=disk.img -nographic -serial mon:stdio -no-reboot 2>&1 || true)
            local OK_COUNT FAIL_COUNT
            OK_COUNT=$(echo "$QEMU_OUT" | grep -c '\[OK\]' || true)
            FAIL_COUNT=$(echo "$QEMU_OUT" | grep -c '\[FAIL\]' || true)
            if [ "$FAIL_COUNT" -eq 0 ] && [ "$OK_COUNT" -gt 0 ]; then
                BOOT_STATUS="${GREEN}${SYM_PASS} build+QEMU(${OK_COUNT} OK)${NC}"
            elif [ "$FAIL_COUNT" -gt 0 ]; then
                BOOT_STATUS="${RED}${SYM_FAIL} QEMU(${FAIL_COUNT} FAIL)${NC}"
            else
                BOOT_STATUS="${MAGENTA}${SYM_WARN} QEMU(no output)${NC}"
            fi
        elif [ "$BOOT_BUILT" -eq 1 ]; then
            BOOT_STATUS="${GREEN}${SYM_PASS} build (no QEMU)${NC}"
        else
            BOOT_STATUS="${RED}${SYM_FAIL} build FAIL${NC}"
        fi
        cd "$SCRIPT_DIR"
    fi

    # record result
    local OVERALL="${GREEN}${SYM_PASS}${NC}"
    if echo "$LIBMEM_STATUS $OS_STATUS $BOOT_STATUS" | grep -q "${SYM_FAIL}"; then
        OVERALL="${RED}${SYM_FAIL}${NC}"
        FAILED=$((FAILED + 1))
    elif echo "$LIBMEM_STATUS $OS_STATUS $BOOT_STATUS" | grep -q "${SYM_SKIP}"; then
        OVERALL="${YELLOW}${SYM_SKIP}${NC}"
        SKIPPED=$((SKIPPED + 1))
    else
        PASSED=$((PASSED + 1))
    fi

    log "    libmem: $LIBMEM_STATUS"
    log "    os:     $OS_STATUS"
    log "    boot:   $BOOT_STATUS"
    log "    ${BOLD}overall: $OVERALL${NC}"

    RESULTS+="$(printf '  %s %-8s %-35s l:%-25s o:%-20s b:%-20s %s\n' \
        "$IDX/$TOTAL" "$SHORT_HASH" "${SUBJECT:0:35}" \
        "$(echo -e "$LIBMEM_STATUS" | sed 's/\x1b\[[0-9;]*m//g')" \
        "$(echo -e "$OS_STATUS" | sed 's/\x1b\[[0-9;]*m//g')" \
        "$(echo -e "$BOOT_STATUS" | sed 's/\x1b\[[0-9;]*m//g')" \
        "$OVERALL")"
}

# run tests
IDX=0
for entry in "${RAW_COMMITS[@]}"; do
    IDX=$((IDX + 1))
    IFS='|' read -r FULL_HASH SHORT_HASH _ _ SUBJECT <<< "$entry"
    test_commit "$FULL_HASH" "$SHORT_HASH" "$SUBJECT" "$IDX" "$TOTAL"
    echo ""
done

# summary
echo ""
log "${CYAN}${BOLD}======================================================================${NC}"
log "${CYAN}${BOLD}  SUMMARY${NC}"
log "${CYAN}${BOLD}======================================================================${NC}"
echo ""

log "${BOLD}Per-Commit Results:${NC}"
log "$(printf '  %-10s %-8s %-35s %-25s %-20s %-20s %s\n' '' 'Hash' 'Subject' 'libmem' 'os' 'boot' 'Overall')"
log "$(printf '  %-10s %-8s %-35s %-25s %-20s %-20s %s\n' '----------' '--------' '-----------------------------------' '-------------------------' '--------------------' '--------------------' '--------')"
log "$RESULTS"

echo ""
log "${CYAN}----------------------------------------------------------------------${NC}"
log "${GREEN}${BOLD}  PASSED:  $PASSED${NC}  ${RED}${BOLD}FAILED:  $FAILED${NC}  ${YELLOW}${BOLD}SKIPPED: $SKIPPED${NC}  ${BOLD}TOTAL: $TOTAL${NC}"
log "${CYAN}----------------------------------------------------------------------${NC}"

# coverage evolution
echo ""
log "${BOLD}Coverage Evolution:${NC}"
PREV_FUNCS=0
IDX=0
for entry in "${RAW_COMMITS[@]}"; do
    IDX=$((IDX + 1))
    IFS='|' read -r FULL_HASH SHORT_HASH _ _ SUBJECT <<< "$entry"
    COMMIT_DIR="$WORK/timeline_$IDX"
    mkdir -p "$COMMIT_DIR"
    git archive "$FULL_HASH" 2>/dev/null | tar -x -C "$COMMIT_DIR" 2>/dev/null

    FUNC_COUNT=0
    if [ -d "$COMMIT_DIR/libmem" ]; then
        FUNC_COUNT=$(find "$COMMIT_DIR/libmem" -name '*.asm' ! -name 'secure_wipe*' 2>/dev/null | wc -l)
    fi
    SECURE_COUNT=0
    if [ -d "$COMMIT_DIR/libmem" ]; then
        SECURE_COUNT=$(find "$COMMIT_DIR/libmem" -name 'secure_wipe*.asm' 2>/dev/null | wc -l)
    fi
    TEST_COUNT=0
    if [ -d "$COMMIT_DIR/libmem" ]; then
        TEST_COUNT=$(find "$COMMIT_DIR/libmem" -name 'test_*.c' 2>/dev/null | wc -l)
    fi
    BOOT_DEMOS=0
    if [ -d "$COMMIT_DIR/boot" ] && [ -f "$COMMIT_DIR/boot/kernel.asm" ]; then
        BOOT_DEMOS=$(grep -c 'demo_' "$COMMIT_DIR/boot/kernel.asm" 2>/dev/null || echo 0)
    fi

    if [ "$FUNC_COUNT" -ne "$PREV_FUNCS" ] || [ "$IDX" -eq "$TOTAL" ]; then
        BAR=""
        for ((b=0; b<FUNC_COUNT; b++)); do BAR+="#"; done
        for ((b=FUNC_COUNT; b<25; b++)); do BAR+="-"; done
        log "$(printf "  %s %-8s  funcs: ${GREEN}%2d${NC}  secure: ${MAGENTA}%2d${NC}  tests: ${CYAN}%2d${NC}  boot_demos: ${YELLOW}%2d${NC}  %s" \
            "$IDX/$TOTAL" "$SHORT_HASH" "$FUNC_COUNT" "$SECURE_COUNT" "$TEST_COUNT" "$BOOT_DEMOS" "$BAR")"
        PREV_FUNCS=$FUNC_COUNT
    fi
    rm -rf "$COMMIT_DIR"
done

echo ""
log "${CYAN}${BOLD}======================================================================${NC}"
if [ "$FAILED" -eq 0 ]; then
    log "${GREEN}${BOLD}  ALL COMMITS PASSED -- timeline is green${NC}"
else
    log "${RED}${BOLD}  $FAILED COMMIT(S) FAILED -- review logs above${NC}"
fi
log "${CYAN}${BOLD}======================================================================${NC}"
echo ""

exit "$FAILED"
