/* shell.c — C userspace shell
 *
 * This file is compiled into the same flat kernel binary, but it represents
 * the "userspace" layer: it may ONLY call kernel functions through the
 * syscall wrappers declared in usys.h. To keep this discipline visible it
 * never references libmem or console_* directly.
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
    usys_puts("memshell (help)\r\n> ");
    for (;;) {
        usys_gets(buf, sizeof(buf));
        usys_puts("\r\n");

        char *s = buf;
        char *cmd = next_token(&s);
        if (!cmd || !cmd[0]) { usys_puts("> "); continue; }

        if (streq(cmd, "help")) {
            usys_puts("memset <a> <b> <n>    memzero <a> <n>\r\n"
                      "memset_rev <a> <b> <n>  memzero_rev <a> <n>\r\n"
                      "memcpy <dst> <src> <n>  memmove <dst> <src> <n>\r\n"
                      "memcmp <a> <b> <n>      memchr <a> <byte> <n>\r\n"
                      "memsetw <a> <word> <n>  secure_wipe <a> <n>\r\n"
                      "secure_wipe_heap <a> <n>\r\n"
                      "peek <a>  cls  halt\r\n");
        } else if (streq(cmd, "cls")) {
            usys_cls();
        } else if (streq(cmd, "halt")) {
            usys_halt();
        } else if (streq(cmd, "peek")) {
            char *a = next_token(&s);
            if (!a) { usys_puts("peek <addr>\r\n"); goto again; }
            usys_puts("0x"); usys_puthex(usys_peek(xtoi(a))); usys_puts("\r\n");
        } else if (streq(cmd, "memset")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memset <addr> <byte> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memset((void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "memzero")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("memzero <addr> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memzero((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "memset_rev")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memset_rev <addr> <byte> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memset_rev((void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "memzero_rev")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("memzero_rev <addr> <count>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memzero_rev((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "memcpy")) {
            char *d = next_token(&s); char *sr = next_token(&s); char *n = next_token(&s);
            if (!d||!sr||!n) { usys_puts("memcpy <dst> <src> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memcpy((void*)xtoi(d), (const void*)xtoi(sr), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "memmove")) {
            char *d = next_token(&s); char *sr = next_token(&s); char *n = next_token(&s);
            if (!d||!sr||!n) { usys_puts("memmove <dst> <src> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memmove((void*)xtoi(d), (const void*)xtoi(sr), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "memcmp")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memcmp <a> <b> <n>\r\n"); goto again; }
            int r = usys_memcmp((const void*)xtoi(a), (const void*)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("cmp="); usys_puthex((unsigned long)r); usys_puts("\r\n"); goto again;
        } else if (streq(cmd, "memchr")) {
            char *a = next_token(&s); char *b = next_token(&s); char *n = next_token(&s);
            if (!a||!b||!n) { usys_puts("memchr <addr> <byte> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memchr((const void*)xtoi(a), (int)xtoi(b), (unsigned int)xtoi(n));
            usys_puts("found at 0x"); usys_puthex(r); usys_puts("\r\n"); goto again;
        } else if (streq(cmd, "memsetw")) {
            char *a = next_token(&s); char *w = next_token(&s); char *n = next_token(&s);
            if (!a||!w||!n) { usys_puts("memsetw <addr> <word> <n>\r\n"); goto again; }
            unsigned long r = (unsigned long)usys_memsetw((void*)xtoi(a), (unsigned short)xtoi(w), (unsigned int)xtoi(n));
            usys_puthex(r); goto again;
        } else if (streq(cmd, "secure_wipe")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("secure_wipe <addr> <count>\r\n"); goto again; }
            usys_secure_wipe((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puts("ok\r\n");
        } else if (streq(cmd, "secure_wipe_heap")) {
            char *a = next_token(&s); char *n = next_token(&s);
            if (!a||!n) { usys_puts("secure_wipe_heap <addr> <count>\r\n"); goto again; }
            usys_secure_wipe_heap((void*)xtoi(a), (unsigned int)xtoi(n));
            usys_puts("ok\r\n");
        } else {
            usys_puts("err: "); usys_puts(cmd); usys_puts("\r\n");
        }
again:
        usys_puts("> ");
    }
}
