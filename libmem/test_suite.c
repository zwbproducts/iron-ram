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

    /*  ------------------------------------------------------- */
    /*  Final summary in green or red                          */
    /*  ------------------------------------------------------- */

    printf(COLOR_CYAN
           "--------------------------------------------------------\n"
           COLOR_RESET);

    if (failures == 0) {
        printf(COLOR_GREEN COLOR_BOLD
               "  ALL 10 TESTS PASSED  (libmymem.a + libmysecure.a)\n"
               COLOR_RESET);
        return 0;
    }

    printf(COLOR_RED COLOR_BOLD
           "  %d TEST(S) FAILED\n"
           COLOR_RESET, failures);
    return 1;
}
