/*
 * test_link.c - Test harness for libmymem.a and libmysecure.a
 *
 * Verifies that both static libraries link correctly with GCC -m32
 * (cdecl calling convention) and that every exported function behaves
 * as expected.  Compiled with -Wall -Wextra to ensure zero warnings.
 *
 * Build:  make test
 * Run:    ./test_link
 */

#include <stdio.h>
#include "mymem.h"

#define BUF_SIZE 32

/* ------------------------------------------------------------------ */
/* Helpers (inline to keep the translation unit self-contained)       */
/* ------------------------------------------------------------------ */

static int buffers_match(const unsigned char *buf, size_t n,
                         unsigned char value)
{
    for (size_t i = 0; i < n; i++) {
        if (buf[i] != value)
            return 0;
    }
    return 1;
}

static void fill_buffer(unsigned char *buf, size_t n, unsigned char value)
{
    for (size_t i = 0; i < n; i++)
        buf[i] = value;
}

/* ------------------------------------------------------------------ */
/* Test cases                                                         */
/* ------------------------------------------------------------------ */

static int test_memset_forward(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0);
    memset(buf, 0xAB, BUF_SIZE);
    return buffers_match(buf, BUF_SIZE, 0xAB);
}

static int test_memset_partial(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0x00);
    memset(buf, 0x55, 8);
    return buffers_match(buf, 8, 0x55)
        && buffers_match(buf + 8, BUF_SIZE - 8, 0x00);
}

static int test_memzero_forward(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0xFF);
    memzero(buf, BUF_SIZE);
    return buffers_match(buf, BUF_SIZE, 0x00);
}

static int test_memset_rev(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0);
    memset_rev(buf, 0xCD, BUF_SIZE);
    return buffers_match(buf, BUF_SIZE, 0xCD);
}

static int test_memzero_rev(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0xEE);
    memzero_rev(buf, BUF_SIZE);
    return buffers_match(buf, BUF_SIZE, 0x00);
}

static int test_secure_wipe(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0x77);
    secure_wipe_stack_rev(buf, BUF_SIZE);
    return buffers_match(buf, BUF_SIZE, 0x00);
}

static int test_memcpy(void)
{
    unsigned char src[BUF_SIZE];
    unsigned char dst[BUF_SIZE];
    fill_buffer(src, BUF_SIZE, 0xAB);
    fill_buffer(dst, BUF_SIZE, 0x00);
    memcpy(dst, src, 16);
    return buffers_match(dst, 16, 0xAB) && buffers_match(dst + 16, BUF_SIZE - 16, 0x00);
}

static int test_memmove_overlap(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0x00);
    memset(buf + 16, 0x42, 8);
    memmove(buf + 8, buf + 16, 8);
    return buffers_match(buf + 8, 8, 0x42);
}

static int test_memcmp(void)
{
    unsigned char b1[BUF_SIZE], b2[BUF_SIZE];
    fill_buffer(b1, BUF_SIZE, 0xAB);
    fill_buffer(b2, BUF_SIZE, 0xAB);
    if (memcmp(b1, b2, BUF_SIZE) != 0) return 0;
    b2[BUF_SIZE - 1] = 0xAC;
    if (memcmp(b1, b2, BUF_SIZE) == 0) return 0;
    return 1;
}

static int test_memchr(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0xFF);
    buf[10] = 0x42;
    if (memchr(buf, 0x42, BUF_SIZE) != buf + 10) return 0;
    if (memchr(buf, 0x99, BUF_SIZE) != NULL) return 0;
    return 1;
}

static int test_memsetw(void)
{
    unsigned char buf[BUF_SIZE];
    unsigned short *wp = (unsigned short *)buf;
    memset(buf, 0, BUF_SIZE);
    memsetw(buf, 0xBEEF, BUF_SIZE / 2);
    for (size_t i = 0; i < BUF_SIZE / 2; i++)
        if (wp[i] != 0xBEEF) return 0;
    return 1;
}

static int test_secure_wipe_heap(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0x88);
    secure_wipe_heap_rev(buf, BUF_SIZE);
    return buffers_match(buf, BUF_SIZE, 0x00);
}

static int test_memfill(void)
{
    unsigned char buf[BUF_SIZE];
    memset(buf, 0, BUF_SIZE);
    memfill(buf, 0xBEEF, 6);
    return buf[0] == 0xEF && buf[1] == 0xBE && buf[2] == 0xEF && buf[3] == 0xBE;
}

static int test_memswap(void)
{
    unsigned char b1[BUF_SIZE], b2[BUF_SIZE];
    fill_buffer(b1, BUF_SIZE, 0x11);
    fill_buffer(b2, BUF_SIZE, 0x22);
    memswap(b1, b2, BUF_SIZE);
    return buffers_match(b1, BUF_SIZE, 0x22) && buffers_match(b2, BUF_SIZE, 0x11);
}

static int test_memreverse(void)
{
    unsigned char buf[16];
    for (int i = 0; i < 16; i++) buf[i] = (unsigned char)i;
    memreverse(buf, 16);
    for (int i = 0; i < 16; i++)
        if (buf[i] != (unsigned char)(15 - i)) return 0;
    return 1;
}

static int test_memrotate_l(void)
{
    unsigned char buf[8] = {1,2,3,4,5,6,7,8};
    unsigned char exp[8] = {4,5,6,7,8,1,2,3};
    memrotate_l(buf, 3, 8);
    for (int i = 0; i < 8; i++) if (buf[i] != exp[i]) return 0;
    return 1;
}

static int test_memrotate_r(void)
{
    unsigned char buf[8] = {1,2,3,4,5,6,7,8};
    unsigned char exp[8] = {6,7,8,1,2,3,4,5};
    memrotate_r(buf, 3, 8);
    for (int i = 0; i < 8; i++) if (buf[i] != exp[i]) return 0;
    return 1;
}

static int test_memfind(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0xFF);
    buf[10] = 0x42;
    return memfind(buf, 0x42, BUF_SIZE) == 10 && memfind(buf, 0x99, BUF_SIZE) == -1;
}

static int test_memcount(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0xFF);
    buf[0] = 0x42; buf[10] = 0x42; buf[20] = 0x42;
    return memcount(buf, 0x42, BUF_SIZE) == 3;
}

static int test_memchecksum(void)
{
    unsigned char buf[BUF_SIZE];
    fill_buffer(buf, BUF_SIZE, 0xFF);
    return memchecksum(buf, BUF_SIZE) == 0;
}

static int test_memeq(void)
{
    unsigned char b1[BUF_SIZE], b2[BUF_SIZE];
    fill_buffer(b1, BUF_SIZE, 0xAB);
    fill_buffer(b2, BUF_SIZE, 0xAB);
    if (memeq(b1, b2, BUF_SIZE) != 1) return 0;
    b2[5] = 0xAC;
    return memeq(b1, b2, BUF_SIZE) == 0;
}

static int test_memmove_rev(void)
{
    unsigned char src[BUF_SIZE], dst[BUF_SIZE];
    memset(src, 0, BUF_SIZE);
    memset(src, 0x77, 8);
    memset(dst, 0, BUF_SIZE);
    memmove_rev(dst, src, 8);
    return buffers_match(dst, 8, 0x77) && buffers_match(src, 8, 0x77);
}

static int test_count_zero(void)
{
    unsigned char buf[BUF_SIZE];
    unsigned char *ret;

    fill_buffer(buf, BUF_SIZE, 0xAA);
    ret = memset(buf, 0xBB, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    ret = memzero(buf, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    ret = memset_rev(buf, 0xBB, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    ret = memzero_rev(buf, 0);
    if (ret != (void *)buf)
        return 0;
    if (!buffers_match(buf, BUF_SIZE, 0xAA))
        return 0;

    return 1;
}

static int test_null_safety(void)
{
    /* Should return NULL without crashing */
    void *ret;

    ret = memset(NULL, 0xFF, 32);
    if (ret != NULL)
        return 0;

    ret = memset_rev(NULL, 0xFF, 32);
    if (ret != NULL)
        return 0;

    /* memzero / memzero_rev delegate to memset / memset_rev, so they
       silently return when dest is NULL (return value is the NULL
       pointer passed through from memset / memset_rev). */
    ret = memzero(NULL, 32);
    if (ret != NULL)
        return 0;

    ret = memzero_rev(NULL, 32);
    if (ret != NULL)
        return 0;

    ret = secure_wipe_stack_rev(NULL, 32);
    if (ret != NULL)
        return 0;

    return 1;
}

/* ------------------------------------------------------------------ */
/* Runner                                                             */
/* ------------------------------------------------------------------ */

int main(void)
{
    int failures = 0;

    if (!test_memset_forward()) {
        printf("FAIL: memset forward fill\n");
        failures++;
    }
    if (!test_memset_partial()) {
        printf("FAIL: memset partial fill\n");
        failures++;
    }
    if (!test_memzero_forward()) {
        printf("FAIL: memzero forward\n");
        failures++;
    }
    if (!test_memset_rev()) {
        printf("FAIL: memset_rev backward fill\n");
        failures++;
    }
    if (!test_memzero_rev()) {
        printf("FAIL: memzero_rev backward\n");
        failures++;
    }
    if (!test_secure_wipe()) {
        printf("FAIL: secure_wipe_stack_rev\n");
        failures++;
    }
    if (!test_count_zero()) {
        printf("FAIL: count == 0 edge cases\n");
        failures++;
    }
    if (!test_null_safety()) {
        printf("FAIL: NULL dest safety\n");
        failures++;
    }
    if (!test_memcpy()) {
        printf("FAIL: memcpy forward copy\n");
        failures++;
    }
    if (!test_memmove_overlap()) {
        printf("FAIL: memmove overlap\n");
        failures++;
    }
    if (!test_memcmp()) {
        printf("FAIL: memcmp equality\n");
        failures++;
    }
    if (!test_memchr()) {
        printf("FAIL: memchr found & not-found\n");
        failures++;
    }
    if (!test_memsetw()) {
        printf("FAIL: memsetw word fill\n");
        failures++;
    }
    if (!test_secure_wipe_heap()) {
        printf("FAIL: secure_wipe_heap_rev\n");
        failures++;
    }
    if (!test_memfill()) {
        printf("FAIL: memfill\n");
        failures++;
    }
    if (!test_memswap()) {
        printf("FAIL: memswap\n");
        failures++;
    }
    if (!test_memreverse()) {
        printf("FAIL: memreverse\n");
        failures++;
    }
    if (!test_memrotate_l()) {
        printf("FAIL: memrotate_l\n");
        failures++;
    }
    if (!test_memrotate_r()) {
        printf("FAIL: memrotate_r\n");
        failures++;
    }
    if (!test_memfind()) {
        printf("FAIL: memfind\n");
        failures++;
    }
    if (!test_memcount()) {
        printf("FAIL: memcount\n");
        failures++;
    }
    if (!test_memchecksum()) {
        printf("FAIL: memchecksum\n");
        failures++;
    }
    if (!test_memeq()) {
        printf("FAIL: memeq\n");
        failures++;
    }
    if (!test_memmove_rev()) {
        printf("FAIL: memmove_rev\n");
        failures++;
    }

    if (failures == 0) {
        printf("All 24 tests passed (libmymem.a + libmysecure.a)\n");
        return 0;
    }

    printf("%d test(s) failed\n", failures);
    return 1;
}
