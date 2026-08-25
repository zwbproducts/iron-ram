/* link.ld — link the 32-bit kernel as a flat binary at 0x100000 */

ENTRY(_start)

SECTIONS
{
    . = 0x100000;                  /* loaded by stage1 at 1 MiB */

    .text : {
        *(.text._start)            /* _start MUST come first */
        *(.text .text.*)
    }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }

    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }

    /DISCARD/ : { *(.comment*) *(.note*) *(.eh_frame*) }
}
