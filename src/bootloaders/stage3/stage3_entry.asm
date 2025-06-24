[BITS 32]

section .entry
global stage3_entry

extern stage3_main
extern printf

stage3_entry:
    PUSH EBX ; allow main use it
    CALL stage3_main
    ; not `ADD ESP, 4` on purpose, save it for later

jump_64bit_kernel:
    CLI

    ; Set CR4 5th bit (enable PAE)
    MOV EAX, CR4
    OR  EAX, 1 << 5
    MOV CR4, EAX

    ; Enable efer.lme
    MOV ECX, 0xC0000080 ; EFER
    RDMSR
    OR  EAX, 1 << 8     ; LME
    WRMSR

    ; Enable paging
    MOV EAX, CR0
    OR  EAX, 0x80000001   ; Set PG bit in CR0 to enable paging
    MOV CR0, EAX
    
    ; Load mem-map from before
    POP EBX 

    ; Kernel code segment
    JMP 0x08:long_mode_entry

[BITS 64]
long_mode_entry:
    ; Kernel data segments
    MOV AX, 0x10
    MOV DS, AX
    MOV ES, AX
    MOV SS, AX
    MOV FS, AX
    MOV GS, AX

    STI

    ; Ensure it's low memory
    AND RBX, 0x00000000FFFFFFFF

    ; Jump to kernel
    MOV RAX, 0xFFFFFFFF80000000
    CALL RAX 

[BITS 32]
hlt_loop:
    HLT
    JMP hlt_loop

print_str: db "George", 0x0A,0
values:
dw 0, 0 ; GDT | CR3-page

; Access bits
PRESENT        equ 1 << 7
NOT_SYS        equ 1 << 4
EXEC           equ 1 << 3
DC             equ 1 << 2
RW             equ 1 << 1
ACCESSED       equ 1 << 0

; Flags bits
GRAN_4K       equ 1 << 7
SZ_32         equ 1 << 6
LONG_MODE     equ 1 << 5

GDT:
    .Null: equ $ - GDT
        dq 0
    .Code: equ $ - GDT
        .Code.limit_lo: dw 0xffff
        .Code.base_lo: dw 0
        .Code.base_mid: db 0
        .Code.access: db PRESENT | NOT_SYS | EXEC | RW
        .Code.flags: db GRAN_4K | LONG_MODE | 0xF   ; Flags & Limit (high, bits 16-19)
        .Code.base_hi: db 0
    .Data: equ $ - GDT
        .Data.limit_lo: dw 0xffff
        .Data.base_lo: dw 0
        .Data.base_mid: db 0
        .Data.access: db PRESENT | NOT_SYS | RW
        .Data.Flags: db GRAN_4K | SZ_32 | 0xF       ; Flags & Limit (high, bits 16-19)
        .Data.base_hi: db 0
    .Pointer:
        dw $ - GDT - 1
        dq GDT