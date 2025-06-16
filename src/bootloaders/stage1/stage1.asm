[BITS 16]	 ;Tells the assembler that its a 16 bit code
%ifndef ELF 
[ORG 0x7C00] ;Origin, tell the assembler start point
%endif


%define PARTITION_START           (0x01BE+0x7C00)
%define PARTITION_SIZE            (16)
%define PARTITION_END             (PARTITION_START + PARTITION_SIZE * 4)
%define PARTITION_LBA_OFFSET      (8)
%define LBA_SIZE                  (4)
%define DISK_ADDR_LBA_OFFSET      (8)
%define BOOT_VALUE                (0x80)

; This file's purpose it so copy ~ 32 KiB worth of sectors between the
; MBR and the first partition so the stage 1.5 can run 


global _start
_start:
	; Far jump to force CS:IP
	JMP 0x0000:0x7C05	

	; Setup segments
	XOR AX, AX
	MOV DS, AX
	MOV ES, AX
	MOV FS, AX
	MOV GS, AX
	MOV SS, AX

	; Save driver
	MOV BYTE [driver], DL

	; Set up stack ss:sp --> 0x7FFFFE
	MOV AX, 0x7000  ; Choose a safe stack segment in RAM 
	MOV SS, AX
	MOV SP, 0xFFFE  ; Pick a high even offset
	
; Scan partitions
	; Go over 16 byte entries to find a bootable one
	MOV SI, PARTITION_START
_start.partition_loop:
	; Get cur partition attributes 
	MOV AL, [SI]

	; Is bootable
	AND AL, BOOT_VALUE
	JNZ _start.boot_partition

	ADD SI, PARTITION_SIZE
	CMP SI, PARTITION_END
	JNZ _start.partition_loop
	CALL Abort

_start.boot_partition:
	MOV WORD [partition_addr], SI

	; Enable extended mode
	MOV AH, 0x41
	MOV BX, 0x55AA
	MOV DL, [driver]
	INT 0x13

	CMP BX, 0xAA55
	JNZ Abort 

	; Read disk
	MOV SI, disk_addr_packet
	MOV AH, 0x42 ; read request
	MOV DL, [driver]
	INT 0x13

	; DX = driver
	MOV DL, [driver]
	XOR DH, DH

	; Pass important values to stage 1.5
	PUSH WORD [partition_addr]
	PUSH DX

	; Jump to stage 1.5
	JMP 0x0000:0x7E00



; Prints binary value in CH, destroys: AX, BX, CX
global PrintBinary
PrintBinary:
    MOV CL, 8           ; Bit counter
PrintBinary.loop:
    SHL CH, 1              ; Shift CH left, MSB goes into CF
    JC PrintBinary.set1    ; If MSB jump to print 1      

    MOV AL, '0'            ; Otherwise set to print 0
    JMP PrintBinary.print  ; Jmp to print
PrintBinary.set1:          
    MOV AL, '1'            ; Set to 1
PrintBinary.print:
    CALL PrintCharacter    ; Print the character
    DEC CL                 ; Decrease iterator var 
    JNZ PrintBinary.loop   ; Jmp to loop it
    RET                    ; Return


global PrintCharacter
PrintCharacter:	                    ;Assume that ASCII value is in register AL
	MOV AH, 0x0E	                ; One char   
	MOV BH, 0x00	                ; Page no
	MOV BL, 0x07	                ; Color 0x07 

	INT 0x10	                    ;Call video interrupt
	RET		                        ;Return to calling procedure


global PrintString
PrintString:	                    ;Procedure to print string on screen
	                                ;Assume that string starting pointer is in register SI

PrintString.next_character:	        ;Label 
	MOV AL, [SI]	                    ;Get a byte from string into AL register
	INC SI		                        ;Increment pointer
	OR AL, AL	                        ;Check if AL is zero (null terminator)
	JZ PrintString.exit_function        ;Stop if null terminator
	CALL PrintCharacter                 ;Else print the character which is in AL register
	JMP PrintString.next_character	    ;Get next character from string
PrintString.exit_function:	        ;End label
	RET		                            ;Return

global Abort
Abort:
	MOV SI, abort_str
	CALL PrintString

;Data
driver: DB 0
disk_addr_packet: 
	DB 16, 0          ; size of the packet 16 bytes, plus 0 reservd
	DW 63             ; 63 sectors will loaded
	DW 0x7E00, 0x0000 ; segment:offset (opposite because little endian system)
	DW 0x01,0,0,0     ; First sector (LBA address)

partition_addr: DW 0x0000
abort_str: DB "Abort", 0

TIMES 446 - ($ - $$) db 0	;fill the rest of sector with 0 (only 446 is real code)