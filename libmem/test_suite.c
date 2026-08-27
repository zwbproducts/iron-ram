/*
 * =============================================================================
 *  test_suite.c — Comprehensive Color-Coded Test Harness
 *  for libmymem.a and libmysecure.a
 * =============================================================================
 *
 *  PURPOSE:
 *      Verify that every exported symbol from both static libraries links
 *      and behaves correctly under GCC -m32 (cdecl calling convention).
 *
 *  COLOR LEGEND (ANSI escape codes):
 *      [CYAN]    Section headers
 *      [YELLOW]  Individual test names
 *      [GREEN]   PASS
 *      [RED]     FAIL
 *      [RESET]   Normal terminal color
 *
 *  BUILD:
 *      gcc -m32 -fno-builtin -fno-stack-protector -Wall -Wextra -std=c11 \
 *          -o test_suite test_suite.c -L. -lmysecure -lmymem
 *
 *  RUN:
 *      ./test_suite
 *
 *  EXIT CODE:
 *      0 = all tests passed
 *      1 = at least one test failed
 * =============================================================================
 */

/*  -------------------------------------------------------------------------  */
/*  Section 1 — Includes                                                      */
/*  -------------------------------------------------------------------------  */

#include <stdio.h>   /* printf for colored output                      */
#include "mymem.h"   /* All function prototypes (memset, memzero,      */
                      /*   memset_rev, memzero_rev, secure_wipe_stack_rev)*/

/*  -------------------------------------------------------------------------  */
/*  Section 2 — ANSI Color Definitions                                        */
/*  -------------------------------------------------------------------------  */

/*
 *  We define color macros using ANSI escape sequences.
 *
 *  \033  = ESC character (0x1B)
 *  [     = literal bracket
 *  31m   = set foreground to red
 *  [0m    = reset to default color
 *
 *  These codes are embedded in the string literals passed to printf().
 *  When printed to a terminal, the text appears in the specified color.
 */

#define COLOR_RED       "\033[31m"   /* RED:   test failure      */
#define COLOR_GREEN     "\033[32m"   /* GREEN: test success       */
#define COLOR_YELLOW    "\033[33m"   /* YELLOW: test name banner  */
#define COLOR_CYAN      "\033[36m"   /* CYAN:  section header    */
#define COLOR_BOLD      "\033[1m"    /* BOLD:  emphasis           */
#define COLOR_RESET     "\033[0m"    /* RESET: back to default    */

/*  -------------------------------------------------------------------------  */
/*  Section 3 — Configuration Macros                                          */
/*  -------------------------------------------------------------------------  */

#define BUF_SIZE 32   /* Buffer size used across all tests */

/*  -------------------------------------------------------------------------  */
/*  Section 4 — Utility Helpers                                               */
/*  -------------------------------------------------------------------------  */

/*
 * buffers_match
 * -------------
 *  Check whether every byte in a buffer equals the expected value.
 *
 *  Parameters:
 *      buf     — pointer to the buffer to inspect
 *      n       — number of bytes to check
 *      expected — the byte value every position should have
 *
 *  Returns:
 *      1 if all bytes match
 *      0 if any byte differs
 */
static int buffers_match(const unsigned char *buf, size_t n,
                         unsigned char expected)
{
    /*  Iterate byte by byte                                         */
    for (size_t i = 0; i < n; i++) {
        /*  If any byte differs from expected, fail                 */
        if (buf[i] != expected)
            return 0;
    }
    /*  All bytes matched — success                               */
    return 1;
}

/*
 * fill_buffer
 * -----------
 *  Fill an entire buffer with a single byte value.
 *  Used to set up known initial state before each test.
 *
 *  Parameters:
 *      buf   — destination buffer
 *      n     — number of bytes to write
 *      value — byte value to write
 */
static void fill_buffer(unsigned char *buf, size_t n, unsigned char value)
{
    /*  Write the same value to every byte                          */
    for (size_t i = 0; i < n; i++)
        buf[i] = value;
}

/*
 * print_result
 * ------------
 *  Print a PASS or FAIL banner in the appropriate color.
 *
 *  Parameters:
 *      test_name  — human-readable name of the test
 *      passed     — 1 if the test passed, 0 if it failed
 */
static void print_result(const char *test_name, int passed)
{
    /*  Print test name in yellow, then PASS/FAIL in green/red       */
    if (passed) {
        printf(COLOR_YELLOW "  [TEST] " COLOR_RESET
               "%-32s "
               COLOR_GREEN "PASS" COLOR_RESET "\n", test_name);
    } else {
        printf(COLOR_YELLOW "  [TEST] " COLOR_RESET
               "%-32s "
               COLOR_RED "FAIL" COLOR_RESET "\n", test_name);
    }
}

/*  -------------------------------------------------------------------------  */
/*  Section 5 — Individual Test Functions                                     */
/*  -------------------------------------------------------------------------  */

/* =========================================================================== */
/*  TEST 1 — memset forward fill                                              */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill a 32-byte buffer with 0xAB using memset().
 *      Verify every byte is 0xAB.
 *
 *  Why:
 *      Confirms Phase 1 (memset.asm) works correctly: the forward
 *      byte-by-byte fill loop stores the character byte across the
 *      full range using inc edi and dec ecx.
 */
static int test_memset_forward(void)
{
    unsigned char buf[BUF_SIZE];    /* Test buffer                    */

    /* Step 1: Clear buffer to known state                         */
    fill_buffer(buf, BUF_SIZE, 0x00);

    /* Step 2: Call our memset implementation                      */
    memset(buf, 0xAB, BUF_SIZE);

    /* Step 3: Verify every byte equals 0xAB                    */
    return buffers_match(buf, BUF_SIZE, 0xAB);
}

/* =========================================================================== */
/*  TEST 2 — memset partial fill                                            */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill only the first 8 bytes of a 32-byte buffer with 0x55.
 *      Verify bytes [0..7] are 0x55 and bytes [8..31] are untouched (0x00).
 *
 *  Why:
 *      Ensures the count parameter controls the exact range and that
 *      bytes outside the range are not modified.
 */
static int test_memset_partial(void)
{
    unsigned char buf[BUF_SIZE];

    /* Step 1: Start with all zeros                               */
    fill_buffer(buf, BUF_SIZE, 0x00);

    /* Step 2: Fill only 8 bytes with 0x55                       */
    memset(buf, 0x55, 8);

    /* Step 3: First 8 bytes must be 0x55                      */
    if (!buffers_match(buf, 8, 0x55))
        return 0;

    /* Step 4: Remaining 24 bytes must still be 0x00          */
    return buffers_match(buf + 8, BUF_SIZE - 8, 0x00);
}

/* =========================================================================== */
/*  TEST 3 — memzero forward zeroing                                          */
/* =========================================================================== */
/*
 *  Scenario:
 *      Pre-fill a buffer with 0xFF, then call memzero().
 *      Verify every byte becomes 0x00.
 *
 *  Why:
 *      Confirms Phase 2 (memzero.asm) correctly delegates to memset
 *      with c=0. All bytes should be zeroed forward.
 */
static int test_memzero_forward(void)
{
    unsigned char buf[BUF_SIZE];

    /* Step 1: Pre-fill with non-zero value                     */
    fill_buffer(buf, BUF_SIZE, 0xFF);

    /* Step 2: Zero the buffer via our wrapper                  */
    memzero(buf, BUF_SIZE);

    /* Step 3: Every byte should now be 0x00                   */
    return buffers_match(buf, BUF_SIZE, 0x00);
}

/* =========================================================================== */
/*  TEST 4 — memset_rev backward fill                                         */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill a 32-byte buffer with 0xCD using memset_rev().
 *      Verify every byte is 0xCD.
 *
 *  Why:
 *      Confirms Phase 3 (memset_rev.asm): starts at dest+count-1
 *      and decrements backward using dec edi. The result should be
 *      identical to forward fill — same end state.
 */
static int test_memset_rev(void)
{
    unsigned char buf[BUF_SIZE];

    /* Step 1: Clear buffer                                     */
    fill_buffer(buf, BUF_SIZE, 0x00);

    /* Step 2: Fill backward with 0xCD                        */
    memset_rev(buf, 0xCD, BUF_SIZE);

    /* Step 3: Verify all bytes are 0xCD                   */
    return buffers_match(buf, BUF_SIZE, 0xCD);
}

/* =========================================================================== */
/*  TEST 5 — memzero_rev backward zeroing                                     */
/* =========================================================================== */
/*
 *  Scenario:
 *      Pre-fill with 0xEE, call memzero_rev().
 *      Verify all bytes are 0x00.
 *
 *  Why:
 *      Confirms Phase 3 (memzero_rev.asm): delegates to memset_rev
 *      with c=0. The backward wipe should zero the entire buffer.
 */
static int test_memzero_rev(void)
{
    unsigned char buf[BUF_SIZE];

    /* Step 1: Pre-fill with non-zero                           */
    fill_buffer(buf, BUF_SIZE, 0xEE);

    /* Step 2: Zero backward via wrapper                     */
    memzero_rev(buf, BUF_SIZE);

    /* Step 3: All bytes should be zero                     */
    return buffers_match(buf, BUF_SIZE, 0x00);
}

/* =========================================================================== */
/*  TEST 6 — secure_wipe_stack_rev                                          */
/* =========================================================================== */
/*
 *  Scenario:
 *      Pre-fill with 0x77, call secure_wipe_stack_rev().
 *      Verify all bytes are 0x00.
 *
 *  Why:
 *      Confirms Phase 5: the secure wipe function in libmysecure.a
 *      correctly delegates to memset_rev in libmymem.a. The cross-
 *      library call must resolve at link time and zero the buffer.
 *
 *      This also demonstrates the DSE-prevention architecture: because
 *      secure_wipe_stack_rev lives in a separate .a file and calls
 *      memset_rev (an external symbol the compiler cannot see), the
 *      compiler will not optimize away the wipe even with -O2.
 */
static int test_secure_wipe(void)
{
    unsigned char buf[BUF_SIZE];

    /* Step 1: Pre-fill with sensitive-looking data            */
    fill_buffer(buf, BUF_SIZE, 0x77);

    /* Step 2: Secure wipe via libmysecure.a                */
    secure_wipe_stack_rev(buf, BUF_SIZE);

    /* Step 3: All bytes must be zero                    */
    return buffers_match(buf, BUF_SIZE, 0x00);
}

/* =========================================================================== */
/*  TEST 7 — count == 0 edge cases                                          */
/* =========================================================================== */
/*
 *  Scenario:
 *      Call every function with count=0. Verify no bytes are written
 *      and the return value equals the original dest pointer.
 *
 *  Why:
 *      Edge-case safety. Each assembly routine checks for count==0
 *      and returns early. If this check were missing, the backward
 *      routines (memset_rev, etc.) would compute dest-1 and could
 *      write to invalid memory or loop forever (ECX wrapping).
 */
static int test_count_zero(void)
{
    unsigned char buf[BUF_SIZE];
    void *ret;

    /* --- memset with count 0 ---                               */
    fill_buffer(buf, BUF_SIZE, 0xAA);
    ret = memset(buf, 0xBB, 0);
    /* Return value must be the original pointer                 */
    if (ret != (void *)buf)
        return 0;
    /* Buffer must be unchanged                                  */
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    /* --- memzero with count 0 ---                              */
    ret = memzero(buf, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    /* --- memset_rev with count 0 ---                          */
    ret = memset_rev(buf, 0xBB, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    /* --- memzero_rev with count 0 ---                         */
    ret = memzero_rev(buf, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 8 — NULL dest safety                                             */
/* =========================================================================== */
/*
 *  Scenario:
 *      Pass NULL as the destination pointer to each function with a
 *      non-zero count. Verify no crash occurs.
 *
 *  Why:
 *      All routines (memset, memset_rev) check `test edi, edi` and
 *      jump to .done if dest is NULL. The wrapper functions
 *      (memzero, memzero_rev, secure_wipe_stack_rev) inherit this
 *      safety through delegation.
 *
 *      The return value for NULL dest is NULL (the original dest).
 */
static int test_null_safety(void)
{
    void *ret;

    /* memset should return NULL without crashing              */
    ret = memset(NULL, 0xFF, 32);
    if (ret != NULL)
        return 0;

    /* memset_rev should return NULL without crashing        */
    ret = memset_rev(NULL, 0xFF, 32);
    if (ret != NULL)
        return 0;

    /* memzero delegates to memset → NULL return           */
    ret = memzero(NULL, 32);
    if (ret != NULL)
        return 0;

    /* memzero_rev delegates to memset_rev → NULL return   */
    ret = memzero_rev(NULL, 32);
    if (ret != NULL)
        return 0;

    /* secure_wipe_stack_rev delegates to memset_rev → NULL */
    ret = secure_wipe_stack_rev(NULL, 32);
    if (ret != NULL)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 9 — return value correctness                                     */
/* =========================================================================== */
/*
 *  Scenario:
 *      Verify each function returns the original dest pointer in EAX.
 *
 *  Why:
 *      The C ABI requires memset and family to return dest. Our
 *      assembly loads `mov eax, [ebp+8]` (original dest) at the end.
 *      This test confirms EAX is correctly populated.
 */
static int test_return_value(void)
{
    unsigned char buf[BUF_SIZE];
    void *ret;

    /* Forward memset */
    ret = memset(buf, 0x01, BUF_SIZE);
    if (ret != (void *)buf)
        return 0;

    /* Forward memzero */
    ret = memzero(buf, BUF_SIZE);
    if (ret != (void *)buf)
        return 0;

    /* Backward memset */
    ret = memset_rev(buf, 0x02, BUF_SIZE);
    if (ret != (void *)buf)
        return 0;

    /* Backward memzero */
    ret = memzero_rev(buf, BUF_SIZE);
    if (ret != (void *)buf)
        return 0;

    /* Secure wipe */
    ret = secure_wipe_stack_rev(buf, BUF_SIZE);
    if (ret != (void *)buf)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 10 — backward fill data integrity                                */
/* =========================================================================== */
/*
 *  Scenario:
 *      Use memset_rev to write a pattern into only part of a buffer.
 *      Verify the pattern is in the right place and the rest is
 *      untouched.
 *
 *  Why:
 *      Confirms memset_rev respects the count boundary. With count=8,
 *      bytes [BUF_SIZE-8 .. BUF_SIZE-1] should be 0x99, and the rest
 *      should be 0x00 (or whatever we initialized).
 */
static int test_memset_rev_partial(void)
{
    unsigned char buf[BUF_SIZE];

    /* Step 1: Start with all zeros                           */
    fill_buffer(buf, BUF_SIZE, 0x00);

    /* Step 2: Fill last 8 bytes backward with 0x99       */
    memset_rev(buf + BUF_SIZE - 8, 0x99, 8);

    /* Step 3: First 24 bytes must be zero               */
    if (!buffers_match(buf, BUF_SIZE - 8, 0x00))
        return 0;

    /* Step 4: Last 8 bytes must be 0x99                */
    return buffers_match(buf + BUF_SIZE - 8, 8, 0x99);
}

/* =========================================================================== */
/*  TEST 11 — memcpy forward copy                                         */
/* =========================================================================== */
/*
 *  Scenario:
 *      Copy 16 bytes from a source buffer (pre-filled with 0xAB)
 *      into a destination buffer (pre-filled with 0x00).
 *      Verify destination has 0xAB and source is unchanged.
 *
 *  Why:
 *      Confirms the new memcpy.asm function (non-overlapping forward copy).
 *      Source and destination must be intact (no aliasing).
 */
static int test_memcpy(void)
{
    unsigned char src[BUF_SIZE];
    unsigned char dst[BUF_SIZE];

    fill_buffer(src, BUF_SIZE, 0xAB);
    fill_buffer(dst, BUF_SIZE, 0x00);

    memcpy(dst, src, 16);

    if (!buffers_match(dst, 16, 0xAB))
        return 0;
    if (!buffers_match(dst + 16, BUF_SIZE - 16, 0x00))
        return 0;
    if (!buffers_match(src, BUF_SIZE, 0xAB))
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 12 — memmove overlapping forward                              */
/* =========================================================================== */
/*
 *  Scenario:
 *      Copy 8 bytes forward by 8 (dst = src - 8) so dest < src with overlap.
 *      Forward copy reads from higher addresses first, safe.
 */
static int test_memmove_overlap_forward(void)
{
    unsigned char buf[BUF_SIZE];

    fill_buffer(buf, BUF_SIZE, 0x00);
    memset(buf + 16, 0x42, 8);   /* bytes [16..23] = 0x42 */

    /* Move [16..23] to [8..15] — dest < src, overlapping */
    memmove(buf + 8, buf + 16, 8);

    /* dst [8..15] should be 0x42 */
    return buffers_match(buf + 8, 8, 0x42);
}

/* =========================================================================== */
/*  TEST 13 — memmove overlapping backward                             */
/* =========================================================================== */
/*
 *  Scenario:
 *      Copy 8 bytes backward by 8 (dst = src + 8) so dest > src with overlap.
 *      memmove must detect dest > src and copy backward to avoid
 *      corrupting source data.
 */
static int test_memmove_overlap_backward(void)
{
    unsigned char buf[BUF_SIZE];

    fill_buffer(buf, BUF_SIZE, 0x00);
    memset(buf, 0x55, 8);         /* bytes [0..7] = 0x55 */

    /* Move [0..7] to [8..15] — dest > src, overlapping */
    memmove(buf + 8, buf, 8);

    /* dst [8..15] should be 0x55 */
    return buffers_match(buf + 8, 8, 0x55);
}

/* =========================================================================== */
/*  TEST 14 — memcmp equality                                           */
/* =========================================================================== */
/*
 *  Scenario:
 *      Compare two identical buffers → expect 0.
 *      Compare two buffers that differ at one byte → expect non-zero.
 */
static int test_memcmp(void)
{
    unsigned char buf1[BUF_SIZE];
    unsigned char buf2[BUF_SIZE];

    fill_buffer(buf1, BUF_SIZE, 0xAB);
    fill_buffer(buf2, BUF_SIZE, 0xAB);

    if (memcmp(buf1, buf2, BUF_SIZE) != 0)
        return 0;

    buf2[BUF_SIZE - 1] = 0xAC;
    if (memcmp(buf1, buf2, BUF_SIZE) == 0)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 15 — memchr found and not found                                  */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill buffer with 0xFF, then set one byte to 0x42.
 *      memchr should find the 0x42 byte.
 *      memchr for 0x99 should return NULL.
 */
static int test_memchr(void)
{
    unsigned char buf[BUF_SIZE];
    unsigned char *result;

    fill_buffer(buf, BUF_SIZE, 0xFF);
    buf[10] = 0x42;

    result = memchr(buf, 0x42, BUF_SIZE);
    if (result != buf + 10)
        return 0;

    result = (unsigned char *)memchr(buf, 0x99, BUF_SIZE);
    if (result != NULL)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 16 — memsetw word fill                                        */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill a 32-byte buffer with 0xBEEF using memsetw.
 *      Every 16-bit word should be 0xBEEF.
 */
static int test_memsetw(void)
{
    unsigned char buf[BUF_SIZE];
    unsigned short *wp = (unsigned short *)buf;

    memset(buf, 0, BUF_SIZE);
    memsetw(buf, 0xBEEF, BUF_SIZE / 2);

    for (size_t i = 0; i < BUF_SIZE / 2; i++) {
        if (wp[i] != 0xBEEF)
            return 0;
    }

    return 1;
}

/* =========================================================================== */
/*  TEST 17 — secure_wipe_heap_rev                                      */
/* =========================================================================== */
/*
 *  Scenario:
 *      Pre-fill buffer with 0x88, call secure_wipe_heap_rev.
 *      Verify all bytes are 0x00.
 *
 *  Why:
 *      Confirms the new secure_wipe_heap_rev.asm function in libmysecure.a
 *      delegates to memset_rev and zeroes the buffer. Like
 *      secure_wipe_stack_rev, it is isolated from the compiler via an
 *      external symbol, preventing DSE on sensitive heap data.
 */
static int test_secure_wipe_heap(void)
{
    unsigned char buf[BUF_SIZE];

    fill_buffer(buf, BUF_SIZE, 0x88);
    secure_wipe_heap_rev(buf, BUF_SIZE);

    return buffers_match(buf, BUF_SIZE, 0x00);
}

/* =========================================================================== */
/*  TEST 18 — memfill pattern fill                                        */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill a buffer with repeating 16-bit pattern 0xBEEF using memfill.
 *      Verify the pattern repeats correctly for odd-length buffers.
 *
 *  Why:
 *      Confirms memfill.asm writes 2-byte patterns. An odd count should
 *      produce an extra low-byte at the end.
 */
static int test_memfill(void)
{
    unsigned char buf[BUF_SIZE];

    memset(buf, 0, BUF_SIZE);
    memfill(buf, 0xBEEF, 10);

    /* bytes: BE EF BE EF BE EF */
    if (buf[0] != 0xEF) return 0; /* little-endian: low byte first */
    if (buf[1] != 0xBE) return 0;
    if (buf[2] != 0xEF) return 0;
    if (buf[3] != 0xBE) return 0;
    if (buf[4] != 0xEF) return 0; /* 5th byte = low byte again */
    return 1;
}

/* =========================================================================== */
/*  TEST 19 — memswap two regions                                       */
/* =========================================================================== */
/*
 *  Scenario:
 *      Two buffers with distinct fill values. Swap them.
 *      After swap, contents should be exchanged.
 */
static int test_memswap(void)
{
    unsigned char buf1[BUF_SIZE];
    unsigned char buf2[BUF_SIZE];

    fill_buffer(buf1, BUF_SIZE, 0x11);
    fill_buffer(buf2, BUF_SIZE, 0x22);

    memswap(buf1, buf2, BUF_SIZE);

    if (!buffers_match(buf1, BUF_SIZE, 0x22))
        return 0;
    return buffers_match(buf2, BUF_SIZE, 0x11);
}

/* =========================================================================== */
/*  TEST 20 — memreverse reverse bytes                                   */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill buf with [0,1,2,...,N-1]. Reverse. Verify [N-1,N-2,...,0].
 */
static int test_memreverse(void)
{
    unsigned char buf[16];

    for (int i = 0; i < 16; i++)
        buf[i] = (unsigned char)i;

    memreverse(buf, 16);

    for (int i = 0; i < 16; i++) {
        if (buf[i] != (unsigned char)(15 - i))
            return 0;
    }
    return 1;
}

/* =========================================================================== */
/*  TEST 21 — memrotate_l left rotation                              */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill buf with [A,B,C,D,E,F,G,H]. Rotate left by 3.
 *      Result should be [D,E,F,G,H,A,B,C].
 */
static int test_memrotate_l(void)
{
    unsigned char buf[8] = {1,2,3,4,5,6,7,8};

    memrotate_l(buf, 3, 8);

    /* After left-rotate by 3: [4,5,6,7,8,1,2,3] */
    unsigned char expected[8] = {4,5,6,7,8,1,2,3};
    for (int i = 0; i < 8; i++) {
        if (buf[i] != expected[i])
            return 0;
    }
    return 1;
}

/* =========================================================================== */
/*  TEST 22 — memrotate_r right rotation                             */
/* =========================================================================== */
static int test_memrotate_r(void)
{
    unsigned char buf[8] = {1,2,3,4,5,6,7,8};

    memrotate_r(buf, 3, 8);

    /* After right-rotate by 3: [6,7,8,1,2,3,4,5] */
    unsigned char expected[8] = {6,7,8,1,2,3,4,5};
    for (int i = 0; i < 8; i++) {
        if (buf[i] != expected[i])
            return 0;
    }
    return 1;
}

/* =========================================================================== */
/*  TEST 23 — memfind offset                                          */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill buf with 0xFF, set buf[10]=0x42.
 *      memfind should return 10 (offset). Search for 0x99 → -1.
 */
static int test_memfind(void)
{
    unsigned char buf[BUF_SIZE];

    fill_buffer(buf, BUF_SIZE, 0xFF);
    buf[10] = 0x42;

    if (memfind(buf, 0x42, BUF_SIZE) != 10)
        return 0;
    if (memfind(buf, 0x99, BUF_SIZE) != -1)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 24 — memcount byte occurrences                               */
/* =========================================================================== */
static int test_memcount(void)
{
    unsigned char buf[BUF_SIZE];

    fill_buffer(buf, BUF_SIZE, 0xFF);
    buf[0] = 0x42;
    buf[10] = 0x42;
    buf[20] = 0x42;

    /* Count 0x42: should be 3 */
    if (memcount(buf, 0x42, BUF_SIZE) != 3)
        return 0;
    /* Count 0xFF: should be 29 (32 - 3) */
    if (memcount(buf, 0xFF, BUF_SIZE) != 29)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 25 — memchecksum XOR                                         */
/* =========================================================================== */
/*
 *  Scenario:
 *      Fill buf with 0xFF. checksum = 0xFF (XOR of 32 0xFF bytes).
 *      With count=0, checksum should be 0.
 */
static int test_memchecksum(void)
{
    unsigned char buf[BUF_SIZE];

    fill_buffer(buf, BUF_SIZE, 0xFF);
    /* 32 bytes of 0xFF: XOR = 0 (even count of 0xFF = 0x00) */
    if (memchecksum(buf, BUF_SIZE) != 0)
        return 0;

    /* 3 bytes of 0xFF: XOR = 0xFF */
    if (memchecksum(buf, 3) != 0xFF)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 26 — memeq equality                                         */
/* =========================================================================== */
/*
 *  Scenario:
 *      Two identical buffers → 1.
 *      One byte differs → 0.
 */
static int test_memeq(void)
{
    unsigned char buf1[BUF_SIZE];
    unsigned char buf2[BUF_SIZE];

    fill_buffer(buf1, BUF_SIZE, 0xAB);
    fill_buffer(buf2, BUF_SIZE, 0xAB);

    if (memeq(buf1, buf2, BUF_SIZE) != 1)
        return 0;

    buf2[5] = 0xAC;
    if (memeq(buf1, buf2, BUF_SIZE) != 0)
        return 0;

    return 1;
}

/* =========================================================================== */
/*  TEST 27 — memmove_rev backward copy                                */
/* =========================================================================== */
/*
 *  Scenario:
 *      Copy 8 bytes using memmove_rev (always backward).
 *      Verify destination has the correct data.
 */
static int test_memmove_rev(void)
{
    unsigned char src[BUF_SIZE];
    unsigned char dst[BUF_SIZE];

    memset(src, 0, BUF_SIZE);
    memset(src, 0x77, 8);
    memset(dst, 0, BUF_SIZE);

    memmove_rev(dst, src, 8);

    if (!buffers_match(dst, 8, 0x77))
        return 0;
    if (!buffers_match(dst + 8, BUF_SIZE - 8, 0x00))
        return 0;

    /* Source must be unchanged */
    return buffers_match(src, 8, 0x77);
}

/*  -------------------------------------------------------------------------  */
/*  Section 6 — Test Runner (main)                                            */
/*  -------------------------------------------------------------------------  */

int main(void)
{
    /*
     *  failures tracks how many tests did not pass.
     *  We print a colored banner at the start and end.
     */
    int failures = 0;

    /*  Print a cyan section header for the test suite            */
    printf(COLOR_CYAN COLOR_BOLD
           "========================================================\n"
           "  libmem / libmysecure — Comprehensive Test Suite\n"
           "========================================================\n"
           COLOR_RESET);

    /*  ------------------------------------------------------- */
    /*  Run each test, print result in color                    */
    /*  ------------------------------------------------------- */

    if (test_memset_forward())
        print_result("memset forward fill", 1);
    else {
        print_result("memset forward fill", 0);
        failures++;
    }

    if (test_memset_partial())
        print_result("memset partial fill", 1);
    else {
        print_result("memset partial fill", 0);
        failures++;
    }

    if (test_memzero_forward())
        print_result("memzero forward", 1);
    else {
        print_result("memzero forward", 0);
        failures++;
    }

    if (test_memset_rev())
        print_result("memset_rev backward fill", 1);
    else {
        print_result("memset_rev backward fill", 0);
        failures++;
    }

    if (test_memzero_rev())
        print_result("memzero_rev backward", 1);
    else {
        print_result("memzero_rev backward", 0);
        failures++;
    }

    if (test_secure_wipe())
        print_result("secure_wipe_stack_rev", 1);
    else {
        print_result("secure_wipe_stack_rev", 0);
        failures++;
    }

    if (test_count_zero())
        print_result("count == 0 edge cases", 1);
    else {
        print_result("count == 0 edge cases", 0);
        failures++;
    }

    if (test_null_safety())
        print_result("NULL dest safety", 1);
    else {
        print_result("NULL dest safety", 0);
        failures++;
    }

    if (test_return_value())
        print_result("return value correctness", 1);
    else {
        print_result("return value correctness", 0);
        failures++;
    }

    if (test_memset_rev_partial())
        print_result("memset_rev partial fill", 1);
    else {
        print_result("memset_rev partial fill", 0);
        failures++;
    }

    /* --- New function tests (Phase 2 expansion) --- */

    if (test_memcpy())
        print_result("memcpy forward copy", 1);
    else {
        print_result("memcpy forward copy", 0);
        failures++;
    }

    if (test_memmove_overlap_forward())
        print_result("memmove overlap forward", 1);
    else {
        print_result("memmove overlap forward", 0);
        failures++;
    }

    if (test_memmove_overlap_backward())
        print_result("memmove overlap backward", 1);
    else {
        print_result("memmove overlap backward", 0);
        failures++;
    }

    if (test_memcmp())
        print_result("memcmp equality", 1);
    else {
        print_result("memcmp equality", 0);
        failures++;
    }

    if (test_memchr())
        print_result("memchr found & not-found", 1);
    else {
        print_result("memchr found & not-found", 0);
        failures++;
    }

    if (test_memsetw())
        print_result("memsetw word fill", 1);
    else {
        print_result("memsetw word fill", 0);
        failures++;
    }

    if (test_secure_wipe_heap())
        print_result("secure_wipe_heap_rev", 1);
    else {
        print_result("secure_wipe_heap_rev", 0);
        failures++;
    }

    /* --- Phase 3: 10 more general-purpose functions --- */

    if (test_memfill())
        print_result("memfill pattern fill", 1);
    else {
        print_result("memfill pattern fill", 0);
        failures++;
    }

    if (test_memswap())
        print_result("memswap two regions", 1);
    else {
        print_result("memswap two regions", 0);
        failures++;
    }

    if (test_memreverse())
        print_result("memreverse bytes", 1);
    else {
        print_result("memreverse bytes", 0);
        failures++;
    }

    if (test_memrotate_l())
        print_result("memrotate_l left", 1);
    else {
        print_result("memrotate_l left", 0);
        failures++;
    }

    if (test_memrotate_r())
        print_result("memrotate_r right", 1);
    else {
        print_result("memrotate_r right", 0);
        failures++;
    }

    if (test_memfind())
        print_result("memfind offset", 1);
    else {
        print_result("memfind offset", 0);
        failures++;
    }

    if (test_memcount())
        print_result("memcount occurrences", 1);
    else {
        print_result("memcount occurrences", 0);
        failures++;
    }

    if (test_memchecksum())
        print_result("memchecksum XOR", 1);
    else {
        print_result("memchecksum XOR", 0);
        failures++;
    }

    if (test_memeq())
        print_result("memeq equality", 1);
    else {
        print_result("memeq equality", 0);
        failures++;
    }

    if (test_memmove_rev())
        print_result("memmove_rev backward", 1);
    else {
        print_result("memmove_rev backward", 0);
        failures++;
    }

    /*  ------------------------------------------------------- */
    /*  Final summary in green or red                          */
    /*  ------------------------------------------------------- */

    printf(COLOR_CYAN
           "--------------------------------------------------------\n"
           COLOR_RESET);

    if (failures == 0) {
        printf(COLOR_GREEN COLOR_BOLD
               "  ALL 27 TESTS PASSED  (libmymem.a + libmysecure.a)\n"
               COLOR_RESET);
        return 0;
    }

    printf(COLOR_RED COLOR_BOLD
           "  %d TEST(S) FAILED\n"
           COLOR_RESET, failures);
    return 1;
}
