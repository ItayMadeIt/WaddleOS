[BITS 64]

global entry64
extern boot_main
extern kernel_main

section .entry
entry64:
    ; Should setup stack

    CALL boot_main

    JMP $
