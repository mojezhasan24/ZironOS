/* Define the entry point */
ENTRY(_start)

SECTIONS
{
    /* Start at 1 MiB (0x100000) - standard kernel load address */
    . = 1M;

    /* Multiboot header must be in the first 8 KiB and at the very beginning */
    .multiboot : ALIGN(4) {
        KEEP(*(.multiboot))
    }

    /* Code section */
    .text : ALIGN(4K) {
        *(.text)
        *(.text.*)
    }

    /* Read-only data */
    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Initialized data */
    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    }

    /* Uninitialized data (BSS) */
    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }

    /* Discard debug and unwanted sections */
    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
        *(.note.gnu.build-id)
        *(.comment)
    }
}