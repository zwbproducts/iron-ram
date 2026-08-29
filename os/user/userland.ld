/* userland.ld — userland linker script */
/* Userland loaded at 0x200000 (2 MB) */

ENTRY(_start)

SECTIONS
{
    . = 0x200000;

    .text : {
        *(.text .text.*)
    }

    .rodata : {
        *(.rodata .rodata.*)
    }

    .data : {
        *(.data .data.*)
    }

    .bss : {
        *(.bss .bss.*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.comment*)
        *(.note*)
        *(.eh_frame*)
    }
}
