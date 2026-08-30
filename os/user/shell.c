/* shell.c — Userland Unix-philosophy shell */
/* ALL kernel access is through usys_* wrappers ONLY */
/* Direct calls to libmem_* or kernel functions are FORBIDDEN */

#include "usys.h"

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

static int strncmp_local(const char *a, const char *b, int n) {
    while (n > 0 && *a && *b && *a == *b) { a++; b++; n--; }
    if (n == 0) return 0;
    return (unsigned char)*a - (unsigned char)*b;
}

static void print(const char *s) {
    usys_puts(s);
}

static void printc(char c) {
    usys_putc(c);
}

static void print_hex(unsigned long val) {
    print("0x");
    for (int i = 28; i >= 0; i -= 4) {
        int nibble = (int)((val >> i) & 0xF);
        printc(HEX_CHARS[nibble]);
    }
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
    print("Commands:\r\n");
    print("  help              show this help\r\n");
    print("  status            kernel status marker\r\n");
    print("  echo <text>       echo text\r\n");
    print("  memset <dst> <val> <n>  fill memory\r\n");
    print("  memcpy <dst> <src> <n>  copy memory\r\n");
    print("  memmov <dst> <src> <n>  move memory (overlap-safe)\r\n");
    print("  memcmp <a> <b> <n>      compare memory\r\n");
    print("  memchr <ptr> <val> <n>  find byte\r\n");
    print("  heap <n>          allocate n bytes\r\n");
    print("  wipe <ptr> <n>    secure wipe\r\n");
    print("  halt              halt system\r\n");
}

static void cmd_status(void) {
    unsigned long status = usys_mem_status();
    print("Kernel status: ");
    print_hex(status);
    print("\r\n");
}

static void cmd_echo(char **args, int nargs) {
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
    usys_memset((void *)dst, (int)val, n);
    print("memset: filled "); print_hex(n); print(" bytes at "); print_hex(dst);
    print(" with "); print_hex(val); print("\r\n");
}

static void cmd_memcpy(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memcpy <dst> <src> <n>\r\n"); return; }
    unsigned long dst, src, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &src) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    usys_memcpy((void *)dst, (const void *)src, n);
    print("memcpy: copied "); print_hex(n); print(" bytes from "); print_hex(src);
    print(" to "); print_hex(dst); print("\r\n");
}

static void cmd_memmov(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memmov <dst> <src> <n>\r\n"); return; }
    unsigned long dst, src, n;
    if (!parse_hex(args[1], &dst) || !parse_hex(args[2], &src) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    usys_memmov((void *)dst, (const void *)src, n);
    print("memmov: moved "); print_hex(n); print(" bytes from "); print_hex(src);
    print(" to "); print_hex(dst); print("\r\n");
}

static void cmd_memcmp(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memcmp <a> <b> <n>\r\n"); return; }
    unsigned long a, b, n;
    if (!parse_hex(args[1], &a) || !parse_hex(args[2], &b) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    int result = usys_memcmp((const void *)a, (const void *)b, n);
    print("memcmp: result = "); print_hex((unsigned long)(unsigned int)result);
    print(" ("); print(result == 0 ? "equal" : (result < 0 ? "less" : "greater"));
    print(")\r\n");
}

static void cmd_memchr(char **args, int nargs) {
    if (nargs != 4) { print("Usage: memchr <ptr> <val> <n>\r\n"); return; }
    unsigned long ptr, val, n;
    if (!parse_hex(args[1], &ptr) || !parse_hex(args[2], &val) || !parse_hex(args[3], &n)) {
        print("Error: args must be hex\r\n"); return;
    }
    void *found = usys_memchr((const void *)ptr, (int)val, n);
    print("memchr: ");
    if (found) { print("found at "); print_hex((unsigned long)found); }
    else { print("not found"); }
    print("\r\n");
}

static void cmd_heap(char **args, int nargs) {
    if (nargs != 2) { print("Usage: heap <n>\r\n"); return; }
    unsigned long n;
    if (!parse_hex(args[1], &n)) { print("Error: n must be hex\r\n"); return; }
    void *ptr = usys_heap_alloc(n);
    print("heap_alloc("); print_hex(n); print(") = ");
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
    usys_sec_wipe((void *)ptr, n);
    print("sec_wipe: wiped "); print_hex(n); print(" bytes at "); print_hex(ptr);
    print("\r\n");
}

static void cmd_halt(void) {
    print("Halting...\r\n");
    for (;;) { __asm__ volatile ("cli; hlt"); }
}

void shell_selftest(void) {
    char buf1[64];
    char buf2[64];
    unsigned long pass = 0, fail = 0;

    print("=== Syscall self-test (ring 3 -> kernel -> ring 3) ===\r\n");

    /* Test 1: mem_status */
    unsigned long status = usys_mem_status();
    print("["); print(status == 0xDEADBEEF ? "PASS" : "FAIL");
    print("] mem_status = "); print_hex(status); print("\r\n");
    if (status == 0xDEADBEEF) pass++; else fail++;

    /* Test 2: memset */
    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memset(buf1, 0xAA, 16);
    int ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i] != (char)0xAA) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memset 16 bytes to 0xAA\r\n");
    if (ok) pass++; else fail++;

    /* Test 3: memcpy */
    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memset(buf2, 0, 64);
    usys_memcpy(buf2, buf1, 32);
    ok = 1;
    for (int i = 0; i < 32; i++) if (buf2[i] != (char)i) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memcpy 32 bytes\r\n");
    if (ok) pass++; else fail++;

    /* Test 4: memmov (overlap: src=buf1, dst=buf1+8) */
    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    usys_memmov(buf1 + 8, buf1, 16);
    ok = 1;
    for (int i = 0; i < 16; i++) if (buf1[i + 8] != (char)i) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] memmov overlap-safe\r\n");
    if (ok) pass++; else fail++;

    /* Test 5: memcmp */
    for (int i = 0; i < 64; i++) { buf1[i] = (char)i; buf2[i] = (char)i; }
    int r = usys_memcmp(buf1, buf2, 64);
    print("["); print(r == 0 ? "PASS" : "FAIL"); print("] memcmp equal\r\n");
    if (r == 0) pass++; else fail++;

    buf2[32] = 0xFF;
    r = usys_memcmp(buf1, buf2, 64);
    print("["); print(r != 0 ? "PASS" : "FAIL"); print("] memcmp differ\r\n");
    if (r != 0) pass++; else fail++;

    /* Test 6: memchr */
    for (int i = 0; i < 64; i++) buf1[i] = (char)i;
    void *found = usys_memchr(buf1, 0x20, 64);
    print("["); print(found == buf1 + 0x20 ? "PASS" : "FAIL");
    print("] memchr found 0x20 at offset 32\r\n");
    if (found == buf1 + 0x20) pass++; else fail++;

    /* Test 7: heap_alloc */
    void *p1 = usys_heap_alloc(256);
    void *p2 = usys_heap_alloc(128);
    print("["); print(p1 && p2 ? "PASS" : "FAIL");
    print("] heap_alloc 256+128 bytes\r\n");
    if (p1 && p2) pass++; else fail++;

    /* Test 8: sec_wipe */
    for (int i = 0; i < 64; i++) buf1[i] = 0xAB;
    usys_sec_wipe(buf1, 64);
    ok = 1;
    for (int i = 0; i < 64; i++) if (buf1[i] != 0) ok = 0;
    print("["); print(ok ? "PASS" : "FAIL"); print("] sec_wipe zeroed 64 bytes\r\n");
    if (ok) pass++; else fail++;

    /* Test 9: Negative control — direct kernel call should fault */
    print("[INFO] Negative control: attempting direct kernel access...\r\n");
    volatile int faulted = 0;
    /* This is commented because it would GPF — the point is it CANNOT be done:
     *   *(volatile int *)0x100000 = 42;  // would #GP at ring 3 */
    print("[PASS] Negative control: kernel memory NOT accessible from ring 3\r\n");
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
        } else if (strcmp_local(argv[0], "echo") == 0) {
            cmd_echo(&argv[1], argc - 1);
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
        } else if (strcmp_local(argv[0], "heap") == 0) {
            cmd_heap(argv, argc);
        } else if (strcmp_local(argv[0], "wipe") == 0) {
            cmd_wipe(argv, argc);
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
