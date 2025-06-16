[BITS 64]

global entry64
extern boot_main
extern kernel_main

section .text
entry64:
    MOV ESI, 0xB8000
    MOV BYTE [ESI + 00], 'F'
    MOV BYTE [ESI + 01], 0x07
    MOV BYTE [ESI + 02], 'I'
    MOV BYTE [ESI + 03], 0x07
    MOV BYTE [ESI + 04], 'N'
    MOV BYTE [ESI + 05], 0x07
    MOV BYTE [ESI + 06], 'I'
    MOV BYTE [ESI + 07], 0x07
    MOV BYTE [ESI + 08], 'S'
    MOV BYTE [ESI + 09], 0x07
    MOV BYTE [ESI + 10], 'H'
    MOV BYTE [ESI + 11], 0x07
    MOV BYTE [ESI + 12], '!'
    MOV BYTE [ESI + 13], 0x07
    MOV BYTE [ESI + 14], ' '
    MOV BYTE [ESI + 15], 0x07
    MOV BYTE [ESI + 16], ' '
    MOV BYTE [ESI + 17], 0x07
    MOV BYTE [ESI + 18], ' '
    MOV BYTE [ESI + 19], 0x07
    JMP $