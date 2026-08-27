#!/usr/bin/env bash
# regression_test.sh — Root-level regression testing
#
# Complementary to git commit history. For each commit that touched libmem/,
# this script:
#   1. Extracts the libmem/ tree as it existed at that commit
#   2. Builds libmymem.a + libmysecure.a using that commit's Makefile
#   3. Compiles + runs the test suite present at that commit
#   4. Records pass/fail results
#
# This lets us back-test from what historic versions were doing — i.e.,
# we trace the evolution of the test suite and function coverage across
# commits, confirming each stage of development passed at the time.
#
# Usage:  ./regression_test.sh [--quiet] [--commits=N]

set -uo pipefail   # not -e, we handle errors per-stage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBMEM="$SCRIPT_DIR/libmem"
TMPLOG_BASE="/tmp/agent_$(date +%s)/regression"
mkdir -p "$TMPLOG_BASE"

QUIET=0
MAX_COMMITS=0
for arg in "$@"; do
    case $arg in
        --quiet|-q) QUIET=1 ;;
        --commits=*) MAX_COMMITS="${arg#*=}" ;;
        *) echo "Unknown option: $arg; use --quiet or --commits=N"; exit 1 ;;
    esac
done

log() { [ $QUIET -eq 0 ] && echo -e "$*" || true; }

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN}  libmem Regression Test — Git History Backtest${NC}"
echo -e "${CYAN}========================================================${NC}"

CURRENT_HASH=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Get unique commits that touched libmem/, oldest-first, plus "working tree"
mapfile -t COMMITS < <(cd "$SCRIPT_DIR" && git log --oneline --format='%H %h %s' -- libmem/ 2>/dev/null | tac | head -n "${MAX_COMMITS:-999}")
if [ ${#COMMITS[@]} -eq 0 ]; then
    COMMITS=("local local working-tree")
fi
TOTAL=${#COMMITS[@]}

log "${YELLOW}Found $TOTAL libmem-related commits to test.${NC}\n"

PASSED=0
FAILED=0
SKIPPED=0
RESULTS=""

test_commit() {
    local full_hash="$1"
    local short_hash="$2"
    local subject="$3"
    local label="$4"
    local idx="$5"

    log "${YELLOW}[$idx/$TOTAL] $short_hash ${subject:0:40}...${NC}"

    # Extract the full libmem/ tree at this commit into a temp dir
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    if [ "$full_hash" = "HEAD" ] && [ "$short_hash" = "$CURRENT_HASH" ] && [ "$subject" = "working-tree" ]; then
        # Working tree: copy actual files (includes uncommitted changes)
        cp -r "$LIBMEM" "$TMP_DIR/libmem"
        cd "$TMP_DIR/libmem" && make clean > /dev/null 2>&1; cd - > /dev/null
    elif ! git archive "$full_hash" -- libmem/ 2>/dev/null | tar -x -C "$TMP_DIR" 2>/dev/null; then
        log "  ${RED}FAILED to extract libmem/ at this commit${NC}"
        RESULTS+="$(printf '  %-50s %s\n' "$label" "${RED}EXTRACT FAIL${NC}")"
        SKIPPED=$((SKIPPED + 1))
        rm -rf "$TMP_DIR"
        return
    fi

    if [ ! -d "$TMP_DIR/libmem" ]; then
        log "  ${YELLOW}libmem/ not present at this commit${NC}"
        RESULTS+="$(printf '  %-50s %s\n' "$label" "${YELLOW}N/A (no libmem)${NC}")"
        SKIPPED=$((SKIPPED + 1))
        rm -rf "$TMP_DIR"
        return
    fi

    # Check if required build files exist at this commit
    if [ ! -f "$TMP_DIR/libmem/Makefile" ] || [ ! -f "$TMP_DIR/libmem/mymem.h" ]; then
        log "  ${YELLOW}Missing Makefile or mymem.h — checking .asm compilation only${NC}"
        # Try to at least compile each .asm
        local asm_ok=1
        for asmfile in "$TMP_DIR/libmem"/*.asm; do
            [ -e "$asmfile" ] || continue
            if ! nasm -f elf32 "$asmfile" -o /dev/null 2>/dev/null; then
                log "  ${RED}ASM COMPILE FAIL: $(basename $asmfile)${NC}"
                asm_ok=0
            fi
        done
        if [ $asm_ok -eq 1 ]; then
            log "  ${GREEN}All .asm files compile${NC}"
            RESULTS+="$(printf '  %-50s %s\n' "$label" "${GREEN}ASM OK${NC}")"
            PASSED=$((PASSED + 1))
        else
            log "  ${RED}Some .asm files failed to compile${NC}"
            RESULTS+="$(printf '  %-50s %s\n' "$label" "${RED}ASM FAIL${NC}")"
            FAILED=$((FAILED + 1))
        fi
        rm -rf "$TMP_DIR"
        return
    fi

    # Build
    if ! (cd "$TMP_DIR/libmem" && make all > "$TMPLOG_BASE/build_${idx}.log" 2>&1); then
        log "  ${RED}BUILD FAILED${NC} (see $TMPLOG_BASE/build_${idx}.log)"
        RESULTS+="$(printf '  %-50s %s\n' "$label" "${RED}BUILD FAIL${NC}")"
        FAILED=$((FAILED + 1))
        rm -rf "$TMP_DIR"
        return
    fi

    log "  ${GREEN}BUILD OK${NC}"

    # Run test_link if it exists (fast binary compatibility test)
    if [ -f "$TMP_DIR/libmem/test_link.c" ]; then
        if (cd "$TMP_DIR/libmem" && gcc -m32 -fno-builtin -fno-stack-protector -Wall -std=c11 \
            -o test_link test_link.c -L. -lmysecure -lmymem 2>> "$TMPLOG_BASE/build_${idx}.log" \
            && ./test_link > "$TMPLOG_BASE/run_${idx}.log" 2>&1); then
            local count
            count=$(grep -oP '[0-9]+(?= tests passed)' "$TMPLOG_BASE/run_${idx}.log" 2>/dev/null || echo "?")
            log "  ${GREEN}test_link: PASS ($count tests)${NC}"
            RESULTS+="$(printf '  %-50s %s\n' "$label" "${GREEN}PASS ($count)${NC}")"
            PASSED=$((PASSED + 1))
        else
            log "  ${RED}test_link: FAIL${NC} (see $TMPLOG_BASE/run_${idx}.log)"
            RESULTS+="$(printf '  %-50s %s\n' "$label" "${RED}test_link FAIL${NC}")"
            FAILED=$((FAILED + 1))
        fi
    # Run test_suite if it exists (comprehensive test suite)
    elif [ -f "$TMP_DIR/libmem/test_suite.c" ]; then
        if (cd "$TMP_DIR/libmem" && gcc -m32 -fno-builtin -fno-stack-protector -Wall -std=c11 \
            -o test_suite test_suite.c -L. -lmysecure -lmymem 2>> "$TMPLOG_BASE/build_${idx}.log" \
            && ./test_suite > "$TMPLOG_BASE/run_${idx}.log" 2>&1); then
            local count
            count=$(grep -oP 'ALL \K[0-9]+(?= TESTS PASSED)' "$TMPLOG_BASE/run_${idx}.log" 2>/dev/null || echo "?")
            log "  ${GREEN}test_suite: PASS ($count tests)${NC}"
            RESULTS+="$(printf '  %-50s %s\n' "$label" "${GREEN}PASS ($count)${NC}")"
            PASSED=$((PASSED + 1))
        else
            local fails
            fails=$(grep -oiP '\d+ TEST\(S\) FAILED' "$TMPLOG_BASE/run_${idx}.log" 2>/dev/null || echo "?")
            log "  ${RED}test_suite: FAIL ($fails)${NC}"
            RESULTS+="$(printf '  %-50s %s\n' "$label" "${RED}test_suite FAIL${NC}")"
            FAILED=$((FAILED + 1))
        fi
    else
        log "  ${YELLOW}No test files at this commit${NC}"
        RESULTS+="$(printf '  %-50s %s\n' "$label" "${YELLOW}BUILD ONLY${NC}")"
        PASSED=$((PASSED + 1))
    fi

    rm -rf "$TMP_DIR"
}

# Test current working tree first
test_commit "HEAD" "$CURRENT_HASH" "working-tree" "Current working tree" "0"

# Iterate historical commits
i=0
for entry in "${COMMITS[@]}"; do
    i=$((i + 1))
    read -r full_hash short_hash subject <<< "$entry"
    label="$i/${TOTAL} ${short_hash} ${subject:0:40}..."
    test_commit "$full_hash" "$short_hash" "$subject" "$label" "$i"
done

# Print summary
echo -e "\n${CYAN}========================================================${NC}"
echo -e "${CYAN}  Regression Summary${NC}"
echo -e "${CYAN}========================================================${NC}"
echo -e "$RESULTS"
echo -e "\n${CYAN}--------------------------------------------------------${NC}"
echo -e "${GREEN}PASSED: $PASSED${NC}  ${RED}FAILED: $FAILED${NC}  ${YELLOW}SKIPPED: $SKIPPED${NC}"
echo -e "${YELLOW}Detailed logs: $TMPLOG_BASE/${NC}"
echo -e "${CYAN}========================================================${NC}"

exit $FAILED
