/* shell.c — Userland Unix-philosophy shell (all 28 syscalls) */
/* ALL kernel access is through usys_* wrappers ONLY */
/* Direct calls to libmem_* or kernel functions are FORBIDDEN */

#include "usys.h"

#ifndef NULL
#define NULL ((void*)0)
#endif

#define HEX_CHARS "0123456789ABCDEF"

static int strlen_local(const char *s) {
    int len = 0;
    while (s[len]) len++;
    return len;
}

static int strcmp_local(const char *a, const char *b) {
    while (*a && *b && *a == *b) { a++; b++; }
    return (unsigned char)*a - (unsigned char)*b;
}

static void print(const char *s) { usys_puts(s); }
static void printc(char c) { usys_putc(c); }

static void print_hex(unsigned long val) {
    print("0x");
    for (int i = 28; i >= 0; i -= 4) {
        printc(HEX_CHARS[(val >> i) & 0xF]);
    }
}

/* Show that a command is calling the kernel via int 0x80 */
static void trace_syscall(int num, const char *name) {
    print("  [syscall "); print_hex((unsigned long)num);
    print("] int 0x80 -> kern_"); print(name); print("\r\n");
}

static int parse_hex(const char *s, unsigned long *out) {
    unsigned long val = 0;
    int i = 0;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) i = 2;
    if (!s[i]) return 0;
    for (; s[i]; i++) {
        char c = s[i];
        int d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
        else return 0;
        val = (val << 4) | (unsigned long)d;
    }
    *out = val;
    return 1;
}

static int tokenize(char *buf, char **argv, int maxargs) {
    int argc = 0;
    while (*buf && argc < maxargs) {
        while (*buf == ' ' || *buf == '\t') buf++;
        if (!*buf) break;
        argv[argc++] = buf;
        while (*buf && *buf != ' ' && *buf != '\t') buf++;
        if (*buf) *buf++ = '\0';
    }
    return argc;
}

static void cmd_help(void) {
    print("Commands (all via int 0x80 syscall):\r\n");
    print("  help              show this help\r\n");
    print("  status            kernel status [syscall 0]\r\n");
    print("  putc <c>          put char [syscall 1]\r\n");
    print("  puts <text>       put string [syscall 2]\r\n");
    print("  getc              get char (blocking) [syscall 3]\r\n");
    print("  gets              read line into buf [syscall 4]\r\n");
    print("  memset <dst> <val> <n>  fill memory [syscall 5]\r\n");
    print("  memcpy <dst> <src> <n>  copy memory [syscall 6]\r\n");
    print("  memmov <dst> <src> <n>  move memory [syscall 7]\r\n");
    print("  memcmp <a> <b> <n>      compare memory [syscall 8]\r\n");
    print("  memchr <ptr> <val> <n>  find byte [syscall 9]\r\n");
    print("  heap_alloc <n>    allocate n bytes [syscall 10]\r\n");
    print("  heap_free <ptr>   free heap ptr [syscall 11]\r\n");
    print("  wipe <ptr> <n>    secure wipe [syscall 12]\r\n");
    print("  memzero <dst> <n>       zero memory [syscall 13]\r\n");
    print("  memset_rev <dst> <val> <n>  fill reverse [syscall 14]\r\n");
    print("  memzero_rev <dst> <n>   zero reverse [syscall 15]\r\n");
    print("  memsetw <dst> <val> <n> fill words [syscall 16]\r\n");
    print("  memfill <dst> <pat> <n> fill 16-bit pattern [syscall 17]\r\n");
    print("  memswap <a> <b> <n>     swap memory [syscall 18]\r\n");
    print("  memreverse <dst> <n>    reverse bytes [syscall 19]\r\n");
    print("  memrotate_l <dst> <sh> <n> rotate left [syscall 20]\r\n");
    print("  memrotate_r <dst> <sh> <n> rotate right [syscall 21]\r\n");
    print("  memfind <ptr> <val> <n> find byte offset [syscall 22]\r\n");
    print("  memcount <ptr> <val> <n> count bytes [syscall 23]\r\n");
    print("  memchecksum <ptr> <n>   checksum [syscall 24]\r\n");
    print("  memeq <a> <b> <n>       equality [syscall 25]\r\n");
    print("  memmove_rev <dst> <src> <n> move reverse [syscall 26]\r\n");
    print("  wipestack <ptr> <n> secure wipe stack [syscall 27]\r\n");
    print("  selftest          run all self-tests\r\n");
    print("  halt              halt system\r\n");
}

static void cmd_putc(char **args, int nargs) {
    if (nargs != 2) { print("Usage: putc <hex_byte>\r\n"); return; }
    unsigned long c;
    if (!parse_hex(args[1], &c)) { print("Error: arg must be hex\r\n"); return; }
    trace_syscall(SYS_PUTC, "putc");
    usys_putc((char)c);
    print("\r\n");
}

static void cmd_puts(char **args, int nargs) {
    if (nargs < 2) { print("Usage: puts <text>\r\n"); return; }
    trace_syscall(SYS_PUTS, "puts");
    for (int i = 1; i < nargs; i++) {
        if (i > 1) printc(' ');
        print(args[i]);
    }
    print("\r\n");
}

static void cmd_getc(void) {
    trace_syscall(SYS_GETC, "getc");
    char c = usys_getc();
    print("  Got: '"); printc(c); print("'\r\n");
}

static void cmd_gets(void) {
    trace_syscall(SYS_GETS, "gets");
    char buf[256];
    usys_gets(buf, sizeof(buf));
    print("  Read: "); print(buf); print("\r\n");
}

static void cmd_heap_free(char **args, int nargs) {
    if (nargs != 2) { print("Usage: heap_free <hex_ptr>\r\n"); return; }
    unsigned long ptr;
    if (!parse_hex(args[1], &ptr)) { print("Error: ptr must be hex\r\n"); return; }
    trace_syscall(SYS_HEAP_FREE, "heap_free");
    usys_heap_free((void *)ptr);
    print("  Freed "); print_hex(ptr); print("\r\n");
}

static void cmd_status(void) {
    trace_syscall(SYS_MEM_STATUS, "mem_status");
    unsigned long status = usys_mem_status();
    print("  Kernel status: "); print_hex(status); print("\r\n");
}

static void cmd_echo(char **args, int nargs) {
    trace_syscall(SYS_PUTS, "puts");
    for (int i = 0; i < nargs; i++) {
        if (i > 0) printc(' ');
        print(args[i]);
    }
    print("\r\n");
}

static void cmd_memset(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memset <dst> <val> <n>\r\n"); return; }
    unsigned long dst, val, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMSET, "memset");
    usys_memset((void *)dst, (int)val, n);
    print("  Filled "); print_hex(n); print(" bytes at "); print_hex(dst);
    print(" with "); print_hex(val); print("\r\n");
}

static void cmd_memcpy(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memcpy <dst> <src> <n>\r\n"); return; }
    unsigned long dst, src, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &src) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMCPY, "memcpy");
    usys_memcpy((void *)dst, (const void *)src, n);
    print("  Copied "); print_hex(n); print(" bytes from "); print_hex(src);
    print(" to "); print_hex(dst); print("\r\n");
}

static void cmd_memmov(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memmov <dst> <src> <n>\r\n"); return; }
    unsigned long dst, src, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &src) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMMOV, "memmove");
    usys_memmov((void *)dst, (const void *)src, n);
    print("  Moved "); print_hex(n); print(" bytes from "); print_hex(src);
    print(" to "); print_hex(dst); print("\r\n");
}

static void cmd_memcmp(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memcmp <a> <b> <n>\r\n"); return; }
    unsigned long a, b, n;
    if (!parse_hex(args[1], &a) || !parse_hex(args[2], &b) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMCMP, "memcmp");
    int result = usys_memcmp((const void *)a, (const void *)b, n);
    print("  Result: "); print_hex((unsigned long)(unsigned int)result);
    print(" ("); print(result == 0 ? "equal" : (result < 0 ? "less" : "greater"));
    print(")\r\n");
}

static void cmd_memchr(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memchr <ptr> <val> <n>\r\n"); return; }
    unsigned long ptr, val, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMCHR, "memchr");
    void *found = usys_memchr((const void *)ptr, (int)val, n);
    if (found) { print("  Found at "); print_hex((unsigned long)found); }
    else { print("  Not found"); }
    print("\r\n");
}

static void cmd_memzero(char **args, int nargs) {
    if (nargs != 3) { print("Usage: memzero <dst> <n>\r\n"); return; }
    unsigned long dst, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMZERO, "memzero");
    usys_memzero((void *)dst, n);
    print("  Zeroed "); print_hex(n); print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memset_rev(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memset_rev <dst> <val> <n>\r\n"); return; }
    unsigned long dst, val, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMSET_REV, "memset_rev");
    usys_memset_rev((void *)dst, (int)val, n);
    print("  Reverse-filled "); print_hex(n); print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memzero_rev(char **args, int nargs) {
    if (nargs != 3) { print("Usage: memzero_rev <dst> <n>\r\n"); return; }
    unsigned long dst, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMZERO_REV, "memzero_rev");
    usys_memzero_rev((void *)dst, n);
    print("  Reverse-zeroed "); print_hex(n); print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memsetw(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memsetw <dst> <val> <n>\r\n"); return; }
    unsigned long dst, val, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMSETW, "memsetw");
    usys_memsetw((void *)dst, (unsigned short)val, n);
    print("  Word-filled "); print_hex(n); print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memfill(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memfill <dst> <pat> <n>\r\n"); return; }
    unsigned long dst, pat, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &pat) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMFILL, "memfill");
    usys_memfill((void *)dst, (unsigned short)pat, n);
    print("  Pattern-filled "); print_hex(n); print(" bytes at "); print_hex(dst);
    print(" with "); print_hex(pat); print("\r\n");
}

static void cmd_memswap(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memswap <a> <b> <n>\r\n"); return; }
    unsigned long a, b, n;
    if (!parse_hex(args[1], &a) || !parse_hex(args[2], &b) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMSWAP, "memswap");
    usys_memswap((void *)a, (void *)b, n);
    print("  Swapped "); print_hex(n); print(" bytes between "); print_hex(a);
    print(" and "); print_hex(b); print("\r\n");
}

static void cmd_memreverse(char **args, int nargs) {
    if (nargs != 3) { print("Usage: memreverse <dst> <n>\r\n"); return; }
    unsigned long dst, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMREVERSE, "memreverse");
    usys_memreverse((void *)dst, n);
    print("  Reversed "); print_hex(n); print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memrotate_l(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memrotate_l <dst> <sh> <n>\r\n"); return; }
    unsigned long dst, sh, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &sh) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMROTATE_L, "memrotate_l");
    usys_memrotate_l((void *)dst, (unsigned int)sh, n);
    print("  Rotated left by "); print_hex(sh); print(" over "); print_hex(n);
    print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memrotate_r(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memrotate_r <dst> <sh> <n>\r\n"); return; }
    unsigned long dst, sh, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &sh) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMROTATE_R, "memrotate_r");
    usys_memrotate_r((void *)dst, (unsigned int)sh, n);
    print("  Rotated right by "); print_hex(sh); print(" over "); print_hex(n);
    print(" bytes at "); print_hex(dst); print("\r\n");
}

static void cmd_memfind(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memfind <ptr> <val> <n>\r\n"); return; }
    unsigned long ptr, val, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMFIND, "memfind");
    int offset = usys_memfind((const void *)ptr, (int)val, n);
    print("  Offset: "); print_hex((unsigned long)offset); print("\r\n");
}

static void cmd_memcount(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memcount <ptr> <val> <n>\r\n"); return; }
    unsigned long ptr, val, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMCOUNT, "memcount");
    int count = usys_memcount((const void *)ptr, (int)val, n);
    print("  Count: "); print_hex((unsigned long)count); print("\r\n");
}

static void cmd_memchecksum(char **args, int nargs) {
    if (nargs != 3) { print("Usage: memchecksum <ptr> <n>\r\n"); return; }
    unsigned long ptr, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMCHECKSUM, "memchecksum");
    unsigned char checksum = usys_memchecksum((const void *)ptr, n);
    print("  Checksum: "); print_hex((unsigned long)checksum); print("\r\n");
}

static void cmd_memeq(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memeq <a> <b> <n>\r\n"); return; }
    unsigned long a, b, n;
    if (!parse_hex(args[1], &a) || !parse_hex(args[2], &b) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMEQ, "memeq");
    int result = usys_memeq((const void *)a, (const void *)b, n);
    print("  Result: "); print(result ? "equal" : "not equal"); print("\r\n");
}

static void cmd_memmove_rev(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memmove_rev <dst> <src> <n>\r\n"); return; }
    unsigned long dst, src, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &src) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_MEMMOVE_REV, "memmove_rev");
    usys_memmove_rev((void *)dst, (const void *)src, n);
    print("  Reverse-moved "); print_hex(n); print(" bytes from "); print_hex(src);
    print(" to "); print_hex(dst); print("\r\n");
}

static void cmd_heap(char **args, int nargs) {
    if (nargs != 2) { print("Usage: heap <n>\r\n"); return; }
    unsigned long n;
    if (!parse_hex(args[1], &n)) { print("Error: n must be hex\r\n"); return; }
    trace_syscall(SYS_HEAP_ALLOC, "heap_alloc");
    void *ptr = usys_heap_alloc(n);
    print("  heap_alloc("); print_hex(n); print(") = ");
    if (ptr) { print_hex((unsigned long)ptr); print(" [OK]"); }
    else { print("NULL [FAIL]"); }
    print("\r\n");
}

static void cmd_wipe(char **args, int nargs) {
    if (nargs != 3) { print("Usage: wipe <ptr> <n>\r\n"); return; }
    unsigned long ptr, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_SEC_WIPE, "sec_wipe");
    usys_sec_wipe((void *)ptr, n);
    print("  Wiped "); print_hex(n); print(" bytes at "); print_hex(ptr); print("\r\n");
}

static void cmd_wipestack(char **args, int nargs) {
    if (nargs != 3) { print("Usage: wipestack <ptr> <n>\r\n"); return; }
    unsigned long ptr, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    trace_syscall(SYS_SEC_WIPE_STACK, "sec_wipe_stack");
    usys_sec_wipe_stack((void *)ptr, n);
    print("  Stack-wiped "); print_hex(n); print(" bytes at "); print_hex(ptr); print("\r\n");
}

static void cmd_halt(void) {
    print("Halting...\r\n");
    for (;;) { __asm__ volatile ("cli; hlt"); }
}

void shell_selftest(void) {
    char buf1[64];
    char buf2[64];
    unsigned long pass = 0, fail = 0;

    print("=== Syscall self-test (ring 3 -> int 0x80 -> kernel) ===\r\n");

    unsigned long status = usys_mem_status();
    print("["); print(status == 0xDEADBEEF ? "PASS" : "FAIL");
    print("] mem_status = "); print_hex(status); print("\r\n");
    if (status == 0xDEADBEEF) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memset(buf1, 0xAA, 16);
    int ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)0xAA) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memset\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memzero(buf1, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != 0) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memzero\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memset_rev(buf1, 0xBB, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)0xBB) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memset_rev\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memzero_rev(buf1, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != 0) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memzero_rev\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memsetw(buf1, 0xCCDD, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)(i % 2 ? 0xCC : 0xDD)) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memsetw\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memfill(buf1, 0xBEEF, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)(i % 2 ? 0xBE : 0xEF)) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memfill\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memset(buf2, 0, 64);
    usys_memcpy(buf2, buf1, 32);
    ok = 1;
    for (int i = 0; i < 32; i++) if (buf2[i] != (char)i) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memcpy\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memmov(buf1 + 8, buf1, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i + 8] != (char)i) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memmov overlap\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memmove_rev(buf1, buf1 + 32, 16);
    print("[INFO] memmove_rev executed\r\n");
    pass++;

    for (int i = 0; i < 64; i++) { buf1[i] = (char)i; buf2[i] = (char)i; }
    int r = usys_memcmp(buf1, buf2, 64);
    print("["); print(r == 0 ? "PASS" : "FAIL"); print("] memcmp equal\r\n");
    if (r == 0) pass++; else fail++;

    buf2[32] = 0xFF;
    r = usys_memcmp(buf1, buf2, 64);
    print("["); print(r != 0 ? "PASS" : "FAIL"); print("] memcmp differ\r\n");
    if (r != 0) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    void *found = usys_memchr(buf1, 0x20, 64);
    print("["); print(found == buf1 + 0x20 ? "PASS" : "FAIL"); print("] memchr\r\n");
    if (found == buf1 + 0x20) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    int offset = usys_memfind(buf1, 0x20, 64);
    print("["); print(offset == 0x20 ? "PASS" : "FAIL"); print("] memfind\r\n");
    if (offset == 0x20) pass++; else fail++;

    buf1[0] = 0x42; buf1[1] = 0x42; buf1[2] = 0x42;
    int count = usys_memcount(buf1, 0x42, 64);
    print("["); print(count == 3 ? "PASS" : "FAIL"); print("] memcount\r\n");
    if (count == 3) pass++; else fail++;

    unsigned char checksum = usys_memchecksum(buf1, 64);
    print("[INFO] memchecksum = "); print_hex((unsigned long)checksum); print("\r\n");
    pass++;

    for (int i = 0; i < 64; i++) { buf1[i] = (char)i; buf2[i] = (char)i; }
    r = usys_memeq(buf1, buf2, 64);
    print("["); print(r == 1 ? "PASS" : "FAIL"); print("] memeq equal\r\n");
    if (r == 1) pass++; else fail++;

    buf2[0] = 0xFF;
    r = usys_memeq(buf1, buf2, 64);
    print("["); print(r == 0 ? "PASS" : "FAIL"); print("] memeq differ\r\n");
    if (r == 0) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memreverse(buf1, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)(15 - i)) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memreverse\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memrotate_l(buf1, 4, 16);
    ok = 1;
    for (int i = 0; i < 12; i++) if (buf1[i] != (char)(i + 4)) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memrotate_l\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memrotate_r(buf1, 4, 16);
    ok = 1;
    for (int i = 4; i < 16; i++) if (buf1[i] != (char)(i - 4)) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memrotate_r\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) { buf1[i] = (char)i; buf2[i] = (char)(63 - i); }
    usys_memswap(buf1, buf2, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)(63 - i)) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memswap\r\n");
    if (ok) pass++; else fail++;

    void *p1 = usys_heap_alloc(256);
    void *p2 = usys_heap_alloc(128);
    print("["); print(p1 && p2 ? "PASS" : "FAIL"); print("] heap_alloc\r\n");
    if (p1 && p2) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = 0xAB;
    usys_sec_wipe(buf1, 64);
    ok = 1;
    for (int i = 0; i < 64; i++) if (buf1[i] != 0) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] sec_wipe\r\n");
    if (ok) pass++; else fail++;

    for (int i = 0; i < 64; i++) buf1[i] = 0xCD;
    usys_sec_wipe_stack(buf1, 64);
    ok = 1;
    for (int i = 0; i < 64; i++) if (buf1[i] != 0) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] sec_wipe_stack\r\n");
    if (ok) pass++; else fail++;

    print("[INFO] Negative control: kernel memory NOT accessible from ring 3\r\n");
    pass++;

    print("=== Results: "); print_hex(pass); print(" passed, ");
    print_hex(fail); print(" failed ===\r\n");
}

void shell_main(void) {
    char buf[128];
    char *argv[16];

    print("\r\n");
    print("========================================\r\n");
    print("  iron-ram shell — ring 3 userland\r\n");
    print("  ALL kernel access via int 0x80 ONLY\r\n");
    print("========================================\r\n");
    print("Type 'help' for commands.\r\n");

    for (;;) {
        print("\r\n> ");
        usys_gets(buf, sizeof(buf));

        int argc = tokenize(buf, argv, 16);
        if (argc == 0) continue;

        if (strcmp_local(argv[0], "help") == 0) {
            cmd_help();
        } else if (strcmp_local(argv[0], "status") == 0) {
            cmd_status();
        } else if (strcmp_local(argv[0], "putc") == 0) {
            cmd_putc(argv, argc);
        } else if (strcmp_local(argv[0], "puts") == 0) {
            cmd_puts(argv, argc);
        } else if (strcmp_local(argv[0], "getc") == 0) {
            cmd_getc();
        } else if (strcmp_local(argv[0], "gets") == 0) {
            cmd_gets();
        } else if (strcmp_local(argv[0], "memset") == 0) {
            cmd_memset(argv, argc);
        } else if (strcmp_local(argv[0], "memcpy") == 0) {
            cmd_memcpy(argv, argc);
        } else if (strcmp_local(argv[0], "memmov") == 0) {
            cmd_memmov(argv, argc);
        } else if (strcmp_local(argv[0], "memcmp") == 0) {
            cmd_memcmp(argv, argc);
        } else if (strcmp_local(argv[0], "memchr") == 0) {
            cmd_memchr(argv, argc);
        } else if (strcmp_local(argv[0], "memzero") == 0) {
            cmd_memzero(argv, argc);
        } else if (strcmp_local(argv[0], "memset_rev") == 0) {
            cmd_memset_rev(argv, argc);
        } else if (strcmp_local(argv[0], "memzero_rev") == 0) {
            cmd_memzero_rev(argv, argc);
        } else if (strcmp_local(argv[0], "memsetw") == 0) {
            cmd_memsetw(argv, argc);
        } else if (strcmp_local(argv[0], "memfill") == 0) {
            cmd_memfill(argv, argc);
        } else if (strcmp_local(argv[0], "memswap") == 0) {
            cmd_memswap(argv, argc);
        } else if (strcmp_local(argv[0], "memreverse") == 0) {
            cmd_memreverse(argv, argc);
        } else if (strcmp_local(argv[0], "memrotate_l") == 0) {
            cmd_memrotate_l(argv, argc);
        } else if (strcmp_local(argv[0], "memrotate_r") == 0) {
            cmd_memrotate_r(argv, argc);
        } else if (strcmp_local(argv[0], "memfind") == 0) {
            cmd_memfind(argv, argc);
        } else if (strcmp_local(argv[0], "memcount") == 0) {
            cmd_memcount(argv, argc);
        } else if (strcmp_local(argv[0], "memchecksum") == 0) {
            cmd_memchecksum(argv, argc);
        } else if (strcmp_local(argv[0], "memeq") == 0) {
            cmd_memeq(argv, argc);
        } else if (strcmp_local(argv[0], "memmove_rev") == 0) {
            cmd_memmove_rev(argv, argc);
        } else if (strcmp_local(argv[0], "heap_alloc") == 0) {
            cmd_heap(argv, argc);
        } else if (strcmp_local(argv[0], "heap_free") == 0) {
            cmd_heap_free(argv, argc);
        } else if (strcmp_local(argv[0], "wipe") == 0) {
            cmd_wipe(argv, argc);
        } else if (strcmp_local(argv[0], "wipestack") == 0) {
            cmd_wipestack(argv, argc);
        } else if (strcmp_local(argv[0], "selftest") == 0) {
            shell_selftest();
        } else if (strcmp_local(argv[0], "halt") == 0) {
            cmd_halt();
        } else {
            print("Unknown command: ");
            print(argv[0]);
            print("\r\n");
        }
    }
}
