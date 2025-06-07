[BITS 16]	 ;Tells the assembler that its a 16 bit code
[ORG 0x7E00] ;Origin, tell the assembler start point

; The file's purpose is to understand FAT32 (and maybe others, so it's flexible) and read
;  the boot.cfg file, get it's first line, find that file, and copy it
;  with only 32KiB of size, 0x8000 bytes. (So 0x7E00 + 0x8000 = 0xFE00, from 0xFE00 is usable memory)
;Store stage 1.5
Start:
	MOV SI, HelloString                 
	CALL PrintString	          

	POP DX
	POP WORD [partition_addr]    	

	JMP $ 		                        ;Infinite loop, hang it here.


; Prints binary value in CH, destroys: AX, BX, CX
PrintBinary:
    MOV CL, 8           ; Bit counter
PrintBinary.loop:
    shl CH, 1              ; Shift CH left, MSB goes into CF
    jc PrintBinary.set1    ; If MSB jump to print 1      

    MOV AL, '0'            ; Otherwise set to print 0
    JMP PrintBinary.print  ; Jmp to print
PrintBinary.set1:          
    MOV AL, '1'            ; Set to 1
PrintBinary.print:
    CALL PrintCharacter    ; Print the character
    DEC CL                 ; Decrease iterator var 
    JNZ PrintBinary.loop   ; Jmp to loop it
    RET                    ; Return


PrintCharacter:	                    ;Assume that ASCII value is in register AL
	MOV AH, 0x0E	                ; One char   
	MOV BH, 0x00	                ; Page no
	MOV BL, 0x07	                ; Color 0x07 

	INT 0x10	                    ;Call video interrupt
	RET		                        ;Return to calling procedure



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


Abort:
	MOV SI, abort_str
	CALL PrintString
;Data
HelloString db 'Hello from stage1_5', 0x0A, 0xD, 0  ;HelloWorld string ending with 0
driver: DB 0
disk_addr_packet: 
	DB 16, 0           ; size of the packet 16 bytes, plus 0 reservd
	DW 63              ; 63 sectors will loaded
	DW 0x0000, 0x1000  ; 0x10000 - segment:offset (opposite because little endian system)
	DW 0,0,0,0         ; Empty 8 bytes for the LBA address (Will change at runtime)

partition_addr: DW 0x0000
abort_str: DB "Abort", 0