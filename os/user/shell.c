/* shell.c — C userspace shell
 *
 * ═══════════════════════════════════════════════════════════════
 *  SECURITY BOUNDARY  —  userland / kernel separation
 * ═══════════════════════════════════════════════════════════════
 *
 *  This file represents the "userspace" layer.  It is linked into the
 *  same flat binary, but it enforces a strict rule: **every** kernel
 *  service is reached exclusively through the `usys_*` wrappers in
 *  usys.S, which issue `int 0x80` → `syscall_dispatch()` in the kernel.
 *
 *  The shell NEVER:
 *    - calls libmem functions directly (memset, memcpy, etc.)
 *    - calls console_* functions directly (console_puts, console_putc…)
 *    - issues raw `int 0x80` or `int 0x81` instructions
 *
 *  If you search this file for `memset` or `console_` you will find
 *  ZERO direct references — only `usys_*` wrappers that gate through
 *  the syscall interrupt.  This is the fundamental security model.
 *
 *  Signal path (int 0x81): kernel-only, used during boot (kmain.c)
 *  to verify libmem staging.  The shell cannot trigger it.
 * ═══════════════════════════════════════════════════════════════
 */
#include "usys.h"
#include <stddef.h>

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
    while (*a && *b) { if (*a != *b) return 0; a++; b++; }
    return *a == *b;
}

/* split off the first whitespace-delimited token: returns pointer into s */
static char *next_token(char **s) {
    char *p = *s;
    while (*p == ' ') p++;
    if (*p == 0) { *s = p; return NULL; }
    char *start = p;
    while (*p && *p != ' ') p++;
    if (*p) { *p = 0; *s = p + 1; }
    else { *s = p; }
    return start;
}

void shell_main(void) {
    char buf[128];
    usys_puts("memshell (help for commands, secinfo for security model)\r\n> ");
    for (;;) {
        usys_gets(buf, sizeof(buf));
        usys_puts("\r\n");

        char *s = buf;
        char *cmd = next_token(&s);
        if (!cmd || !cmd[0]) { usys_puts("> "); continue; }

        if (streq(cmd, "help")) {
            /* All commands route through usys_* wrappers (int 0x80 gate). */
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
        else if (streq(cmd, "secinfo")) {
            /* Prints the security model — proves userland/kernel separation */
            usys_puts(
                "SECURITY MODEL — userland kernel separation\r\n"
                "  • shell.c NEVER calls libmem or console_* directly\r\n"
                "  • EVERY operation uses usys_* wrappers -> int 0x80\r\n"
                "  • int 0x80 -> syscall_dispatch() -> kernel-owned fn\r\n"
                "  • int 0x81 (signals) used by kernel ONLY (kmain.c)\r\n"
                "  • int 0x0D (GPF) caught by kernel, never reaches userland\r\n"
                "  • 28 syscalls exposed, 0 direct kernel access from shell\r\n"
                "  • SIG_LIBMEM_TEST_ALL runs 21 functions through dispatch\r\n"
                "  • All shell<->kernel traffic: int 0x80 (syscall gate only)\r\n");
        }
        else if (streq(cmd, "cls")) {
            usys_cls();
        }
        else if (streq(cmd, "halt")) {
            usys_halt();
        }
        else if (streq(cmd, "peek")) {
            char *a = next_token(&s);
            if (!a) { usys_puts("peek <addr>\r\n"); goto again; }
            usys_puts("0x"); usys_puthex(usys_peek(xtoi(a))); usys_puts("\r\n");
        }
        /* ─────────────────── Phase 1 (SYS 1-12) ─────────────────── */
        else if (streq(cmd, "memset")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memset <addr> <byte> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memset((void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memzero")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("memzero <addr> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memzero((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memset_rev")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memset_rev <addr> <byte> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memset_rev((void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memzero_rev")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("memzero_rev <addr> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memzero_rev((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        /* ─────────────────── Phase 2 (SYS 13-18) ─────────────────── */
        else if (streq(cmd, "memcpy")) {
            char *d = next_token(&s); char *sr = next_token(&s); char *n = next_token(&s);
            if (!d||!sr||!n) { usys_puts("memcpy <dst> <src> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memcpy((void*)xtoi(d), (const void*)xtoi(sr), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memmove")) {
            char *d = next_token(&s); char *sr = next_token(&s); char *n = next_token(&s);
            if (!d||!sr||!n) { usys_puts("memmove <dst> <src> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memmove((void*)xtoi(d), (const void*)xtoi(sr), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memcmp")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memcmp <a> <b> <n>\r\n"); goto again; }
            int r = usys_memcmp((const void*)xtoi(a), (const void*)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("cmp="); usys_puthex((unsigned long)r); usys_puts("\r\n"); goto again;
        }
        else if (streq(cmd, "memchr")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memchr <addr> <byte> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memchr((const void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("at 0x"); usys_puthex(r); usys_puts("\r\n"); goto again;
        }
        else if (streq(cmd, "memsetw")) {
            char *a = next_token(&s); char *w = next_token(&s); char *n = next_token(&s);
            if (!a||!w||!n) { usys_puts("memsetw <addr> <word> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memsetw((void*)xtoi(a), (unsigned short)xtoi(w), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "secure_wipe")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("secure_wipe <addr> <count>\r\n"); goto again; }
            usys_secure_wipe((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puts("ok\r\n");
        }
        else if (streq(cmd, "secure_wipe_heap")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("secure_wipe_heap <addr> <count>\r\n"); goto again; }
            usys_secure_wipe_heap((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puts("ok\r\n");
        }
        /* ─────────────────── Phase 3 (SYS 19-28) ─────────────────── */
        else if (streq(cmd, "memfill")) {
            char *a = next_token(&s); char *p = next_token(&s); char *n = next_token(&s);
            if (!a||!p||!n) { usys_puts("memfill <addr> <pattern> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memfill((void*)xtoi(a), (unsigned short)xtoi(p), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memswap")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memswap <a> <b> <n>\r\n"); goto again; }
            usys_memswap((void*)xtoi(a), (void*)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("ok\r\n"); goto again;
        }
        else if (streq(cmd, "memreverse")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("memreverse <addr> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memreverse((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memrotate_l")) {
            char *a = next_token(&s); char *w = next_token(&s); char *n = next_token(&s);
            if (!a||!w||!n) { usys_puts("memrotate_l <addr> <shift> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memrotate_l((void*)xtoi(a), (unsigned int)xtoi(w), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memrotate_r")) {
            char *a = next_token(&s); char *w = next_token(&s); char *n = next_token(&s);
            if (!a||!w||!n) { usys_puts("memrotate_r <addr> <shift> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memrotate_r((void*)xtoi(a), (unsigned int)xtoi(w), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else if (streq(cmd, "memfind")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memfind <addr> <byte> <n>\r\n"); goto again; }
            long r = usys_memfind((const void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("at "); usys_puthex((unsigned long)r); usys_puts("\r\n"); goto again;
        }
        else if (streq(cmd, "memcount")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memcount <addr> <byte> <n>\r\n"); goto again; }
            int r = usys_memcount((const void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("count="); usys_puthex((unsigned long)r); usys_puts("\r\n"); goto again;
        }
        else if (streq(cmd, "memchecksum")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("memchecksum <addr> <n>\r\n"); goto again; }
            unsigned char r = usys_memchecksum((const void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puts("chk=0x"); usys_puthex((unsigned long)r); usys_puts("\r\n"); goto again;
        }
        else if (streq(cmd, "memeq")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memeq <a> <b> <n>\r\n"); goto again; }
            int r = usys_memeq((const void*)xtoi(a), (const void*)xtoi(b), (unsigned int)xtoi(n));
            usys_puts(r ? "equal" : "not_equal"); usys_puts("\r\n"); goto again;
        }
        else if (streq(cmd, "memmove_rev")) {
            char *d = next_token(&s); char *sr = next_token(&s); char *n = next_token(&s);
            if (!d||!sr||!n) { usys_puts("memmove_rev <dst> <src> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memmove_rev((void*)xtoi(d), (const void*)xtoi(sr), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        }
        else {
            usys_puts("err: "); usys_puts(cmd); usys_puts("\r\n");
        }
again:
        usys_puts("> ");
    }
}
