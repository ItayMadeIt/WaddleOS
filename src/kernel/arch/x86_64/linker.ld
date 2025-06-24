ENTRY(entry64)

KERNEL_VIRT = 0xFFFFFFFF80000000;
KERNEL_PHYS = 0x00100000;


SECTIONS {
    /* It must be loaded at KERNEL_PHYS*/
    . = KERNEL_PHYS;

    .entry : ALIGN(16) {
        KEEP(*(.entry))
    }

    /* symbol for C start (Used for GDB)*/
    text_entry_phys = .;
    text_entry_virt = text_entry_phys + (KERNEL_VIRT - KERNEL_PHYS);

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
