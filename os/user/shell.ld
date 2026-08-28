/* shell.ld — link script for the restricted-userland shell binary
 *
 * The shell is linked ONLY against usys.o. It cannot resolve any
 * kernel function symbols (memset, console_puts, etc.) — if shell.c
 * references them directly, the link fails with "undefined reference".
 * This is the hard enforcement boundary: the shell must call kernel
 * services through int 0x80 wrappers only.
 */
ENTRY(shell_main)

SECTIONS
{
    . = 0x200000;

    .text : {
        *(.text .text.*)
    }
    .rodata : { *(.rodata .rodata.*) }
    .data : { *(.data .data.*) }
    .bss : { *(COMMON) *(.bss .bss.*) }

    /DISCARD/ : {
        *(.comment*)
        *(.note*)
        *(.eh_frame*)
        *(.symtab)
        *(.strtab)
        *(.shstrtab)
    }
}
