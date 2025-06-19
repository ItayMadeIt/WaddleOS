[BITS 32]

section .entry
global stage3_entry

extern stage3_main

stage3_entry:
    PUSH EBX
    CALL stage3_main
    ADD ESP, 0x4
    
hlt_loop:
    HLT
    JMP hlt_loop

section .data