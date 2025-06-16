ENTRY(stage3_main)

SECTIONS {
    /* It must be loaded at 0x80000 and have 64 KiB (0x80000 to 0x8FFFF) of free space.*/
    . = 0x80000;
    
    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(.bss)
        *(COMMON)
    }
}
