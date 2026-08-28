/* shell.c — C userspace shell (restricted userland)
 *
 * ═══════════════════════════════════════════════════════════════
 *  UNIX PHILOSOPHY: userland/kernel separation
 * ═══════════════════════════════════════════════════════════════
 *
 *  The shell is the ONLY userland component. It is linked in isolation
 *  against usys.o ONLY. It cannot resolve any kernel function symbols
 *  (memset, console_puts, etc.) — the linker will reject any direct
 *  reference. Every kernel service is reached via `usys_*` wrappers
 *  that issue `int 0x80` → `syscall_dispatch()`.
 *
 *  Architecture:
 *    shell.o → usys.o (separate link unit, no kernel symbols available)
 *    kernel.elf ← kmain.o + syscalls.o + console.o + libmem + isr*
 *
 *  The shell NEVER:
 *    - calls libmem functions directly (memset, memcpy, etc.)
 *    - calls console_* functions directly (console_puts, console_putc...)
 *    - issues raw `int 0x80` or `int 0x81` instructions
 *    - references syscall_dispatch, signal_dispatch, gpf_handler
 *
 *  If you search this file for `memset` or `console_` you will find
 *  ZERO direct references — only `usys_*` wrappers that gate through
 *  the syscall interrupt. This is the fundamental security model.
 *
 *  Signal path (int 0x81): kernel-only, used during boot (kmain.c)
 *  to verify libmem staging. The shell cannot trigger it.
 * ═══════════════════════════════════════════════════════════════
 */

#include "usys.h"
#include <stddef.h>

/* ─── Internal helpers (pure C, no kernel deps) ─── */

static unsigned long xtoi(const char *s) {
    unsigned long v = 0;
    int i = 0;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) i = 2;
    for (; s[i]; i++) {
        char c = s[i];
        int d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        else break;
        v = (v << 4) | (unsigned long)d;
    }
    return v;
}

static int streq(const char *a, const char *b) {
    while (*a && *b) {
        if (*a != *b) return 0;
        a++; b++;
    }
    return *a == *b;
}

static size_t strlen(const char *s) {
    size_t n = 0;
    while (s[n]) n++;
    return n;
}

/* ─── Simple buffer allocator (uses syscalls ONLY) ───
 * The shell maintains a small scratch region in its .bss.
 * No malloc needed — we use a fixed pool. */

#define POOL_SIZE 2048
static char shell_pool[POOL_SIZE];
static size_t pool_off = 0;

static char *shell_alloc(size_t n) {
    if (pool_off + n > POOL_SIZE) return (void*)0;
    char *p = &shell_pool[pool_off];
    pool_off += n;
    return p;
}

static void shell_reset(void) {
    pool_off = 0;
}

/* ─── Command dispatch ─── */

static void cmd_help(void);
static void cmd_secinfo(void);
static void cmd_cls(void);
static void cmd_peek(char **args, int nargs);
static void cmd_memset(char **args, int nargs);
static void cmd_memzero(char **args, int nargs);
static void cmd_memset_rev(char **args, int nargs);
static void cmd_memzero_rev(char **args, int nargs);
static void cmd_memcpy(char **args, int nargs);
static void cmd_memmove(char **args, int nargs);
static void cmd_memcmp(char **args, int nargs);
static void cmd_memchr(char **args, int nargs);
static void cmd_memsetw(char **args, int nargs);
static void cmd_memfill(char **args, int nargs);
static void cmd_memswap(char **args, int nargs);
static void cmd_memreverse(char **args, int nargs);
static void cmd_memrotate_l(char **args, int nargs);
static void cmd_memrotate_r(char **args, int nargs);
static void cmd_memfind(char **args, int nargs);
static void cmd_memcount(char **args, int nargs);
static void cmd_memchecksum(char **args, int nargs);
static void cmd_memeq(char **args, int nargs);
static void cmd_memmove_rev(char **args, int nargs);
static void cmd_secure_wipe(char **args, int nargs);
static void cmd_secure_wipe_heap(char **args, int nargs);

static void cmd_halt(void) {
    usys_halt();
}

/* Split input line into argv-style array (modifies buffer in place) */
static int tokenize(char *line, char **argv, int max) {
    int n = 0;
    char *p = line;
    while (*p == ' ') p++;
    while (*p && n < max) {
        if (*p == ' ') {
            *p = 0;
            p++;
            while (*p == ' ') p++;
        } else {
            argv[n++] = p;
            while (*p && *p != ' ') p++;
        }
    }
    return n;
}

void shell_main(void) {
    char buf[128];
    usys_puts("iron-ram shell — Unix philosophy: all kernel access via int 0x80\r\n");
    usys_puts("Type 'help' for commands, 'secinfo' for security model.\r\n");

    for (;;) {
        shell_reset();
        usys_puts("\r\n> ");
        usys_gets(buf, sizeof(buf));

        /* Echo newline for readability */
        usys_puts("\r\n");

        /* Tokenize */
        char *argv[16];
        int argc = tokenize(buf, argv, 16);
        if (argc == 0) continue;

        if (streq(argv[0], "help")) {
            cmd_help();
        } else if (streq(argv[0], "secinfo")) {
            cmd_secinfo();
        } else if (streq(argv[0], "cls")) {
            cmd_cls();
        } else if (streq(argv[0], "halt")) {
            cmd_halt();
        } else if (streq(argv[0], "peek")) {
            cmd_peek(&argv[1], argc - 1);
        } else if (streq(argv[0], "memset")) {
            cmd_memset(&argv[1], argc - 1);
        } else if (streq(argv[0], "memzero")) {
            cmd_memzero(&argv[1], argc - 1);
        } else if (streq(argv[0], "memset_rev")) {
            cmd_memset_rev(&argv[1], argc - 1);
        } else if (streq(argv[0], "memzero_rev")) {
            cmd_memzero_rev(&argv[1], argc - 1);
        } else if (streq(argv[0], "memcpy")) {
            cmd_memcpy(&argv[1], argc - 1);
        } else if (streq(argv[0], "memmove")) {
            cmd_memmove(&argv[1], argc - 1);
        } else if (streq(argv[0], "memcmp")) {
            cmd_memcmp(&argv[1], argc - 1);
        } else if (streq(argv[0], "memchr")) {
            cmd_memchr(&argv[1], argc - 1);
        } else if (streq(argv[0], "memsetw")) {
            cmd_memsetw(&argv[1], argc - 1);
        } else if (streq(argv[0], "memfill")) {
            cmd_memfill(&argv[1], argc - 1);
        } else if (streq(argv[0], "memswap")) {
            cmd_memswap(&argv[1], argc - 1);
        } else if (streq(argv[0], "memreverse")) {
            cmd_memreverse(&argv[1], argc - 1);
        } else if (streq(argv[0], "memrotate_l")) {
            cmd_memrotate_l(&argv[1], argc - 1);
        } else if (streq(argv[0], "memrotate_r")) {
            cmd_memrotate_r(&argv[1], argc - 1);
        } else if (streq(argv[0], "memfind")) {
            cmd_memfind(&argv[1], argc - 1);
        } else if (streq(argv[0], "memcount")) {
            cmd_memcount(&argv[1], argc - 1);
        } else if (streq(argv[0], "memchecksum")) {
            cmd_memchecksum(&argv[1], argc - 1);
        } else if (streq(argv[0], "memeq")) {
            cmd_memeq(&argv[1], argc - 1);
        } else if (streq(argv[0], "memmove_rev")) {
            cmd_memmove_rev(&argv[1], argc - 1);
        } else if (streq(argv[0], "secure_wipe")) {
            cmd_secure_wipe(&argv[1], argc - 1);
        } else if (streq(argv[0], "secure_wipe_heap")) {
            cmd_secure_wipe_heap(&argv[1], argc - 1);
        } else {
            usys_puts("err: unknown command '");
            usys_puts(argv[0]);
            usys_puts("'. Type 'help'.\r\n");
        }
    }
}

/* ─── Command implementations ─── */

static void cmd_help(void) {
    usys_puts(
        "┌─────────────────────────────────────────────────────┐\r\n"
        "│  ORIGINAL 12 (SYS 1-12 via int 0x80)               │\r\n"
        "│  memset memzero memset_rev memzero_rev secure_wipe │\r\n"
        "│  cls putc puts puthex peek gets halt                 │\r\n"
        "├─────────────────────────────────────────────────────┤\r\n"
        "│  PHASE 2: libmem (SYS 13-18 via int 0x80)            │\r\n"
        "│  memcpy memmove memcmp memchr memsetw secure_wipe_h │\r\n"
        "├─────────────────────────────────────────────────────┤\r\n"
        "│  PHASE 3: general (SYS 19-28 via int 0x80)          │\r\n"
        "│  memfill memswap memreverse memrotate_l memrotate_r  │\r\n"
        "│  memfind memcount memchecksum memeq memmove_rev      │\r\n"
        "└─────────────────────────────────────────────────────┘\r\n"
        "  All calls go through syscall wrappers — see secinfo\r\n");
}

static void cmd_secinfo(void) {
    usys_puts(
        "SECURITY MODEL — userland/kernel separation\r\n"
        "  • shell.c is linked against usys.o ONLY\r\n"
        "  • kernel symbols are NOT exported to the shell\r\n"
        "  • EVERY operation uses usys_* wrappers -> int 0x80\r\n"
        "  • int 0x80 -> syscall_dispatch() -> kernel-owned fn\r\n"
        "  • int 0x81 (signals) used by kernel ONLY (kmain.c)\r\n"
        "  • int 0x0D (GPF) caught by kernel, never reaches userland\r\n"
        "  • 28 syscalls exposed, 0 direct kernel access from shell\r\n"
        "  • Runtime audit: every int 0x80 is logged with audit ID\r\n"
        "  • SIG_LIBMEM_TEST_ALL runs 21 functions through dispatch\r\n"
        "  • All shell<->kernel traffic: int 0x80 (syscall gate only)\r\n");
}

static void cmd_cls(void) {
    usys_cls();
}

static void cmd_peek(char **args, int nargs) {
    if (nargs < 1) { usys_puts("peek <addr>\r\n"); return; }
    usys_puts("0x");
    usys_puthex(usys_peek(xtoi(args[0])));
    usys_puts("\r\n");
}

/* Phase 1 commands (SYS 1-12) */

static void cmd_memset(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memset <addr> <byte> <count>\r\n"); return; }
    usys_puthex((unsigned long)usys_memset((void*)xtoi(args[0]), (int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memzero(char **args, int nargs) {
    if (nargs < 2) { usys_puts("memzero <addr> <count>\r\n"); return; }
    usys_puthex((unsigned long)usys_memzero((void*)xtoi(args[0]), (unsigned int)xtoi(args[1])));
    usys_puts("\r\n");
}

static void cmd_memset_rev(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memset_rev <addr> <byte> <count>\r\n"); return; }
    usys_puthex((unsigned long)usys_memset_rev((void*)xtoi(args[0]), (int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memzero_rev(char **args, int nargs) {
    if (nargs < 2) { usys_puts("memzero_rev <addr> <count>\r\n"); return; }
    usys_puthex((unsigned long)usys_memzero_rev((void*)xtoi(args[0]), (unsigned int)xtoi(args[1])));
    usys_puts("\r\n");
}

static void cmd_secure_wipe(char **args, int nargs) {
    if (nargs < 2) { usys_puts("secure_wipe <addr> <count>\r\n"); return; }
    usys_secure_wipe((void*)xtoi(args[0]), (unsigned int)xtoi(args[1]));
    usys_puts("ok\r\n");
}

/* Phase 2 commands (SYS 13-18) */

static void cmd_memcpy(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memcpy <dst> <src> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memcpy((void*)xtoi(args[0]), (const void*)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memmove(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memmove <dst> <src> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memmove((void*)xtoi(args[0]), (const void*)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memcmp(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memcmp <a> <b> <n>\r\n"); return; }
    int r = usys_memcmp((const void*)xtoi(args[0]), (const void*)xtoi(args[1]), (unsigned int)xtoi(args[2]));
    usys_puts("cmp=");
    usys_puthex((unsigned long)r);
    usys_puts("\r\n");
}

static void cmd_memchr(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memchr <addr> <byte> <n>\r\n"); return; }
    usys_puts("at 0x");
    usys_puthex((unsigned long)usys_memchr((const void*)xtoi(args[0]), (int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memsetw(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memsetw <addr> <word> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memsetw((void*)xtoi(args[0]), (unsigned short)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_secure_wipe_heap(char **args, int nargs) {
    if (nargs < 2) { usys_puts("secure_wipe_heap <addr> <count>\r\n"); return; }
    usys_secure_wipe_heap((void*)xtoi(args[0]), (unsigned int)xtoi(args[1]));
    usys_puts("ok\r\n");
}

/* Phase 3 commands (SYS 19-28) */

static void cmd_memfill(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memfill <addr> <pattern> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memfill((void*)xtoi(args[0]), (unsigned short)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memswap(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memswap <a> <b> <n>\r\n"); return; }
    usys_memswap((void*)xtoi(args[0]), (void*)xtoi(args[1]), (unsigned int)xtoi(args[2]));
    usys_puts("ok\r\n");
}

static void cmd_memreverse(char **args, int nargs) {
    if (nargs < 2) { usys_puts("memreverse <addr> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memreverse((void*)xtoi(args[0]), (unsigned int)xtoi(args[1])));
    usys_puts("\r\n");
}

static void cmd_memrotate_l(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memrotate_l <addr> <shift> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memrotate_l((void*)xtoi(args[0]), (unsigned int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memrotate_r(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memrotate_r <addr> <shift> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memrotate_r((void*)xtoi(args[0]), (unsigned int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memfind(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memfind <addr> <byte> <n>\r\n"); return; }
    usys_puts("at ");
    usys_puthex((unsigned long)usys_memfind((const void*)xtoi(args[0]), (int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memcount(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memcount <addr> <byte> <n>\r\n"); return; }
    usys_puts("count=");
    usys_puthex((unsigned long)usys_memcount((const void*)xtoi(args[0]), (int)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}

static void cmd_memchecksum(char **args, int nargs) {
    if (nargs < 2) { usys_puts("memchecksum <addr> <n>\r\n"); return; }
    usys_puts("chk=0x");
    usys_puthex((unsigned long)usys_memchecksum((const void*)xtoi(args[0]), (unsigned int)xtoi(args[1])));
    usys_puts("\r\n");
}

static void cmd_memeq(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memeq <a> <b> <n>\r\n"); return; }
    int r = usys_memeq((const void*)xtoi(args[0]), (const void*)xtoi(args[1]), (unsigned int)xtoi(args[2]));
    usys_puts(r ? "equal\r\n" : "not_equal\r\n");
}

static void cmd_memmove_rev(char **args, int nargs) {
    if (nargs < 3) { usys_puts("memmove_rev <dst> <src> <n>\r\n"); return; }
    usys_puthex((unsigned long)usys_memmove_rev((void*)xtoi(args[0]), (const void*)xtoi(args[1]), (unsigned int)xtoi(args[2])));
    usys_puts("\r\n");
}
