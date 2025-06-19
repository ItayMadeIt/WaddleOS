ENTRY(stage3_entry)

SECTIONS {
    /* It must be loaded at 0x80000 and have 64 KiB (0x80000 to 0x8FFFF) of free space.*/
    . = 0x80000;

    .entry : ALIGN(16) {
        KEEP(*(.entry))
    }

    text_entry = .;     /* symbol for C start (Used for GDB)*/
    
    .text : ALIGN(16) {
        *(.text)
    }

    .rodata : ALIGN(16)  {
        *(.rodata)
    }

    .data : ALIGN(16) {
        *(.data)
    }

    .bss : ALIGN(16) {
        *(.bss)
        *(COMMON)
    }
}
