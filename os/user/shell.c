/* shell.c — Userland Unix-philosophy shell */
/* ALL kernel access is through usys_* wrappers ONLY */
/* Direct calls to libmem_* or kernel functions are FORBIDDEN */

#include "usys.h"

/* ─── Helper functions (userland-only) ─── */

static int strlen_local(const char *s) {
    int len = 0;
    while (s[len]) len++;
    return len;
}

static int strcmp_local(const char *a, const char *b) {
    while (*a && *b && *a == *b) { a++; b++; }
    return *a - *b;
}

static void print(const char *s) {
    usys_puts(s);
}

static void printc(char c) {
    usys_putc(c);
}

/* ─── Command implementations ─── */

static void cmd_help(void) {
    print("Commands: help, status, echo <text>, memset, memcpy, wipe, halt\r\n");
}

static void cmd_status(void) {
    unsigned long status = usys_mem_status();
    /* Print hex value */
    print("Kernel status: 0x");
    /* Simple hex print */
    for (int i = 28; i >= 0; i -= 4) {
        int nibble = (status >> i) & 0xF;
        char c = nibble < 10 ? '0' + nibble : 'A' + nibble - 10;
        printc(c);
    }
    print("\r\n");
}

static void cmd_echo(char **args, int nargs) {
    for (int i = 0; i < nargs; i++) {
        print(args[i]);
        printc(' ');
    }
    print("\r\n");
}

static void cmd_halt(void) {
    print("Halting...\r\n");
    for (;;) { __asm__ volatile ("cli; hlt"); }
}

/* ─── Tokenizer ─── */

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

/* ─── Main shell loop ─── */

void shell_main(void) {
    char buf[128];
    char *argv[16];

    print("\r\niron-ram shell — Unix philosophy: all kernel access via int 0x80\r\n");
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
        } else if (strcmp_local(argv[0], "halt") == 0) {
            cmd_halt();
        } else {
            print("Unknown command: ");
            print(argv[0]);
            print("\r\n");
        }
    }
}
