[BITS 32]

%define ARG1_OFFSET 0x08
%define ARG2_OFFSET 0x0C
%define ARG3_OFFSET 0x10

section .entry

global set_cr3_func

set_cr3_func:
    PUSH EBP
    MOV EBP, ESP

    MOV EAX, [EBP + ARG1_OFFSET]
    MOV CR3, EAX

    MOV ESP, EBP
    POP EBP
    RET

global isr
isr:   
    CLI
    PUSHA

    MOV ESI, 0x0B8000
    MOV BYTE [ESI + 0x00], 'E' 
    MOV BYTE [ESI + 0x02], 'R' 
    MOV BYTE [ESI + 0x04], 'R' 
    MOV BYTE [ESI + 0x06], 'O' 
    MOV BYTE [ESI + 0x08], 'R' 
    MOV BYTE [ESI + 0x0A], ' ' 

loopa:
    HLT
    jmp loopa

    POPA
    IRET

global sti_func
sti_func:
    PUSH EBP
    MOV EBP, ESP

    STI

sti_func.done:
    MOV ESP, EBP
    POP EBP
    RET

global lidt_func
lidt_func:
    PUSH EBP
    MOV EBP, ESP

    MOV  EBX, [EBP + ARG1_OFFSET]
    LIDT [EBX]

lidt_func.done:
    MOV ESP, EBP
    POP EBP
    RET


global lgdt_func
lgdt_func:
    PUSH EBP
    MOV EBP, ESP

    MOV  EBX, [EBP + ARG1_OFFSET]
    LGDT [EBX]

lgdt_func.done:
    MOV ESP, EBP
    POP EBP
    RET

global div0 
div0:
    PUSH EBP
    MOV EBP, ESP

    MOV ECX, 0
    DIV ECX

    MOV ESP, EBP
    POP EBP
    RET
