ENTRY(entry64)

SECTIONS {
    . = 1M;

    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data :
    {
        *(.data)
        *(.bss)
        *(COMMON)
    }
}
