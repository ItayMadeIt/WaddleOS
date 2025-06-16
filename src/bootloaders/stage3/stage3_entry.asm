[BITS 32]

global stage3_main
extern setup_paging

stage3_main:
    MOV ESI, 0xB8000
    MOV BYTE [ESI + 00], 'S'
    MOV BYTE [ESI + 01], 0x07
    MOV BYTE [ESI + 02], 'T'
    MOV BYTE [ESI + 03], 0x07
    MOV BYTE [ESI + 04], 'A'
    MOV BYTE [ESI + 05], 0x07
    MOV BYTE [ESI + 06], 'G'
    MOV BYTE [ESI + 07], 0x07
    MOV BYTE [ESI + 08], 'E'
    MOV BYTE [ESI + 09], 0x07
    MOV BYTE [ESI + 10], ' '
    MOV BYTE [ESI + 11], 0x07
    MOV BYTE [ESI + 12], '3'
    MOV BYTE [ESI + 13], 0x07
    MOV BYTE [ESI + 14], '!'
    MOV BYTE [ESI + 15], 0x07
    MOV BYTE [ESI + 16], '?'
    MOV BYTE [ESI + 17], 0x07
    MOV BYTE [ESI + 18], ' '
    MOV BYTE [ESI + 19], 0x07
    
    CALL setup_paging

    JMP $