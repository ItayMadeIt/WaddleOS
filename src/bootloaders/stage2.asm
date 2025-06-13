[BITS 16]	 ;Tells the assembler that its a 16 bit code
%ifndef ELF
[ORG 0x7E00] ;Origin, tell the assembler start point
%endif


%define PARTITION_LBA_OFFSET       (8)
%define LBA_SIZE                   (4)
%define DISK_SECTORS_AMOUNT_OFFSET (8)
%define DISK_LOAD_ADDR_OFFSET      (4)
%define DISK_LOAD_SEG_OFFSET       (6)
%define DISK_SECTOR_LBA_OFFSET     (8)
%define ENABLE_OPTION_COUNT        (2)
%define FIRST_SECTOR_SEG           (0xFE0)
%define SECTOR_SIZE                (512)

%define FAT_TABLE_SEGMENT           (0x1000)
%define FAT_TABLE_MAX_SIZE          (0x20000)
%define FAT_TABLE_SECTORS           (FAT_TABLE_MAX_SIZE / SECTOR_SIZE)
%define FAT_TABLE_END               (FAT_TABLE_SEGMENT + FAT_TABLE_MAX_SIZE/0x10)

%define FILENAME_SIZE              (11)
%define FILENAME_EXT_SIZE          (3)
%define FILE_ENTRY_SIZE            (32)
%define FILES_PER_SECTOR           (SECTOR_SIZE / FILE_ENTRY_SIZE)

%define SECTOR_SEG_FILEDATA        (FAT_TABLE_END)


; The file's purpose is to understand FAT16 (and maybe others, so it's flexible) and read
;  the boot.cfg file, get it's first line, find that file, and copy it
;  with only 32KiB of size, 0x8000 bytes. (So 0x7E00 + 0x8000 = 0xFE00, from 0xFE00 is usable memory)
;Store stage 1.5
global _start2
_start2:
	MOV SI, hello_string                 
	CALL PrintString	          

	POP DX
	MOV [driver], DL
	POP SI
	MOV [partition_addr], SI
	MOV DX, [SI+0x08]    ; Load bytes at offset 0x08 (LBA start)
	MOV [boot_start_sector], DX

	CALL EnableA20

	CALL ParseFATPartitionSector
	CALL ParseFATLinkedTable


	MOV SI, kernel_elf_path
	PUSH WORD SECTOR_SEG_FILEDATA
	POP ES
	CALL FindFileFromPath

	TEST AX, AX
	JNE _start2.file_path_failed
	
	MOV BX, ES
	CALL PrintFile

	JMP $ 		                        ;Infinite loop, hang it here.


_start2.file_path_failed:
	MOV SI, failed_str
	CALL PrintString
	JMP $


PrintDebugAX: ; really dummy debug function
	PUSH AX
	ADD AL, 0x30
	CALL PrintCharacter
	XCHG AH, AL
	ADD AL, 0x30
	CALL PrintCharacter 
	POP AX
	RET

global PrintFile
; Inputs:
;  - ES:DI = pointer to file entry
;  - BX    = usable memory segment (can be equal to ES)

PrintFile:
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES

    ; Load first cluster
    MOV DX, ES:[DI + 0x1A]       ; First cluster
    CALL SetClusterStartSector   ; AX = absolute sector
    MOV CX, AX                   ; CX = sector counter

    ; Load file size (DX:AX)
    MOV AX, ES:[DI + 0x1C]       ; Low word
    MOV DX, ES:[DI + 0x1E]       ; High word

    MOV DI, 0
    MOV ES, BX                   ; Set ES to output buffer

PrintFile.loop:
    ; Check if DX:AX >= SECTOR_SIZE
    ; If DX > 0, we're good
    CMP DX, 0
    JA  PrintFile.readSector     ; If high word > 0, continue

    ; DX == 0, check if AX >= SECTOR_SIZE
    CMP AX, SECTOR_SIZE
    JB  PrintFile.lastChunk      ; Less than a sector left

PrintFile.readSector:
    ; Load sector at CX into ES:0000
    PUSH CX
    PUSH WORD 0
    PUSH ES
    PUSH WORD 0
    PUSH WORD 1
    CALL LoadSector
    ADD SP, 10

    ; Print whole sector
    PUSH CX
    MOV CX, SECTOR_SIZE
    CALL PrintAmountCharacter
    POP CX

    ; Prepare next
    INC CX
    SUB AX, SECTOR_SIZE
    SBB DX, 0
    JMP PrintFile.loop

PrintFile.lastChunk:
    ; Read last partial sector
    PUSH CX
    PUSH WORD 0
    PUSH ES
    PUSH WORD 0
    PUSH WORD 1
    CALL LoadSector
    ADD SP, 10

    ; Print only remaining bytes in AX
    PUSH CX
    MOV CX, AX
    CALL PrintAmountCharacter
    POP CX

PrintFile.end:
    POP ES
    POP DI
    POP DX
    POP CX
    POP AX
    RET



; Inputs:
;  - ES:DI characters array
;  - CX amount (will be trashed)
PrintAmountCharacter:
	PUSH CX
	PUSH AX
	PUSH DI
PrintAmountCharacter.loop:
	MOV AL, ES:[DI]
	INC DI
	Call PrintCharacter
	
	LOOP PrintAmountCharacter.loop

	POP DI
	POP AX
	POP CX
	RET

global FindFileFromPath
; ES - Usable memory segment (1 sector)
; SI - String start of the full path
FindFileFromPath:
	
	; Gets root dir "a/b/c" -> "a            " in dummy_filename
	CALL ConsumeSubdirSegment

	PUSH SI   ; Save SI
	MOV SI, dummy_filename	
	CALL FindFileInRoot
	POP SI    ; Restore SI

	CMP AX, 0
	JNZ FindFileFromPath.failed

FindFileFromPath.subdir_loop:
	; Gets root dir "a/b/c" -> "a            " in dummy_filename
	CALL ConsumeSubdirSegment

	PUSH SI   ; Save SI
	MOV SI, dummy_filename	
	MOV BX, ES
	CALL FindFileFromDirSector
	POP SI    ; Restore SI
	
	CMP AX, 0
	JNZ FindFileFromPath.failed

	CMP BYTE DS:[SI], 0
	JZ FindFileFromPath.done


	JMP FindFileFromPath.subdir_loop

FindFileFromPath.failed:
	MOV AX, 1

	MOV SI, failed_str
	CALL PrintString

	RET

FindFileFromPath.done:
	XOR AX, AX

	RET


global FindFileInRoot
; Input:
; ES - Usable memory segment (1 sector) - (the segment only, for example 0xFE will be at 0xFE0)
;		ES will contain the result sector, where the file stored, with DI as an offset
; SI - String start of the filename
;
; Output:
; DI - End offset (ES:DI (ES = segment) will give you the 32 bit entry)
; AX - 0 success, 1 or 2 fail (different reasons) 
FindFileInRoot:
	PUSH CX

	MOV AX, [root_dir_start]

	MOV CX, [max_root_entries]
	
	CALL IterateDirectorySectors

	POP CX
	RET



global FindFileFromDirSector
; BX - Usable memory (1 sector), at BX:00
; ES:DI holds the 32 byte entry of the directory ()
; DS:SI holds the filename (11 chars)
; AX - optional output 
FindFileFromDirSector:
	PUSH CX
	PUSH DX

	MOV DX, ES:[DI + 0x1A] ; Load first cluster address

	MOV ES, BX
FindFileFromDirSector.loop:
	; Get from DX (Cluster index) the start sector
	CALL SetClusterStartSector

	MOV CX, [max_dir_entries_per_cluster]
	CALL IterateDirectorySectors

	TEST AX, AX
    JE FindFileFromDirSector.found

	MOV AX, DX
	CALL NextClusterIndex
	MOV DX, AX

	; Invalid file
	CMP AX, 0xFFF8
	JAE FindFileFromDirSector.not_found
	
	JMP FindFileFromDirSector.loop

FindFileFromDirSector.not_found:
	MOV AX, 1
	JMP FindFileFromDirSector.done


FindFileFromDirSector.found:
	XOR AX, AX

FindFileFromDirSector.done:
	POP DX
	POP CX
	RET


global SetClusterStartSector
; Input: DX = cluster index
; Output: AX = start sector of that cluster (LBA)
SetClusterStartSector:
    PUSH BX
    PUSH DX
    SUB DX, 2
    MOV AX, DX
    MOV BX, [sectors_per_cluster]
    MUL BX
    ADD AX, [data_region_start]
	POP DX
    POP BX
    RET



global IterateDirectorySectors
; Inputs:
;   ES:0000  target memory segment (for loading sectors)
;   CX       total number of directory entries to scan
;   AX       starting LBA (sector index)
;   SI       pointer to filename to compare (11-byte space-padded, DS:SI)
; Outputs:
;   AX = 0 success, 1 or 2 fail (different reasons)
;   DI = offset in ES:0000 where the matching entry starts
IterateDirectorySectors:
    PUSH BX
    PUSH DX

IterateDirectorySectors.loop:

	PUSH CX
	PUSH DX

    ; Load sector AX (LBA) into ES:0000
    PUSH AX            ; LBA low
    PUSH WORD 0        ; LBA high
    PUSH ES
    PUSH WORD 0x0000   ; Offset
    PUSH WORD 1        ; 1 sector
    CALL LoadSector
	ADD SP, 10

	POP DX
	POP CX

    ; BX = how many entries to check this sector (min(16, CX))
    CMP CX, 16
    JA IterateDirectorySectors.more
    MOV BX, CX
    JMP IterateDirectorySectors.scan

IterateDirectorySectors.more:
    MOV BX, 16

IterateDirectorySectors.scan:
	PUSH AX
	PUSH CX
    MOV CX, BX
    CALL IterateDirectoryEntries
	POP CX
    TEST AX, AX
    JE IterateDirectorySectors.found

	CMP AX, 2
	JE IterateDirectorySectors.cant_be_found

    ; Advance to next sector
	POP AX
    INC AX            ; AX = next sector
    SUB CX, BX        ; CX -= entries scanned
    JNZ IterateDirectorySectors.loop

IterateDirectorySectors.not_found:
    MOV AX, 1         ; not found
    JMP IterateDirectorySectors.done

IterateDirectorySectors.cant_be_found:
	POP AX
    MOV AX, 2        ; not found and can't be found
    JMP IterateDirectorySectors.done

IterateDirectorySectors.found:
	POP AX
    XOR AX, AX        ; success (AX = 0)

IterateDirectorySectors.done:
    POP DX
    POP BX
    RET

;LoadSector.done
;IterateDirectorySectors.done



global IterateDirectoryEntries
; Inputs:
;   DS:SI = pointer to filename to match
;   ES:0000 = sector with directory entries
;   CX = number of entries to scan (16 for 1 full sector)
;
;   AX = 0 success, 1 or 2 fail (different reasons)
;   DI = offset of matching entry in ES
IterateDirectoryEntries:
    XOR DI, DI              ; start at offset 0
IterateDirectoryEntries.loop:
	MOV AL, ES:[DI]
	CMP AL, 0x00
	JE IterateDirectoryEntries.cant_be_found

	; Skipped entry
    CMP AL, 0xE5
    JE IterateDirectoryEntries.loop_skip

	; Dot (. or ..)
    CMP AL, 0x2E
    JE IterateDirectoryEntries.loop_skip

	; Long File Name (LFN)
    MOV AL, ES:[DI + 0x0B]
	CMP AL, 0x0F
    JE IterateDirectoryEntries.loop_skip

   	PUSH CX                 ; save loop count for each entry check
    
	MOV CX, FILENAME_SIZE

    CALL StrCmpSize         ; compare DS:SI with ES:DI (11 bytes)

    POP CX                  ; restore loop count

    CMP AX, 0
    JE IterateDirectoryEntries.found

    ADD DI, FILE_ENTRY_SIZE
    LOOP IterateDirectoryEntries.loop

	JMP IterateDirectoryEntries.not_found

IterateDirectoryEntries.loop_skip:
    ADD DI, FILE_ENTRY_SIZE    
	LOOP IterateDirectoryEntries.loop
	
IterateDirectoryEntries.cant_be_found:
    MOV AX, 2              ; cant be found
    RET

IterateDirectoryEntries.not_found:
    MOV AX, 1              ; not found
    RET

IterateDirectoryEntries.found:
    XOR AX, AX             ; found
    RET


global NextClusterIndex
; Returns the next cluster's value
;   AX - Cluster index
;   AX - Return next cluster value
NextClusterIndex:
	PUSH BX
	PUSH ES

	SHL AX, 1 ; Multiply by 2 (each addr is 2 bytes)
	MOV BX, AX 

	PUSH FAT_TABLE_SEGMENT
	POP ES

	MOV AX, ES:[BX]

	POP ES
	POP BX
	RET


global ConsumeSubdirSegment
; Consumes a subdir segment that is pointed by using SI:
;  Example: SI -> "ABC.D" -> "ABC     D  "    , SI -> ""    (using dummy_filename)
;  Example: SI -> "ABC.D/EFG" -> "ABC     D  ", SI -> "EFG" (using dummy_filename)
;  Example: SI -> "ABC/EFG" -> "ABC        "  , SI -> "EFG" (using dummy_filename)
ConsumeSubdirSegment:
	PUSH DI
	PUSH CX
	PUSH AX
	PUSH DS
	PUSH ES

	XOR AX, AX
	MOV DS, AX
	MOV ES, AX

	MOV CX, FILENAME_SIZE
	MOV DI, dummy_filename
ConsumeSubdirSegment.copy_loop_start:
	LODSB            ; Load AL from [SI], SI++
	CMP AL, 0        ; null terminator
	JZ ConsumeSubdirSegment.fill_loop
	CMP AL, '/'      ; slash (next part so stop)
	JZ ConsumeSubdirSegment.fill_loop
	CMP AL, '.'      ; dot (start extension)
	JZ ConsumeSubdirSegment.prepare_extension

ConsumeSubdirSegment.copy_loop_iterate:
	STOSB         ; Copy AL into [DI]


	LOOP ConsumeSubdirSegment.copy_loop_start
	JMP ConsumeSubdirSegment.end

ConsumeSubdirSegment.prepare_extension:
	MOV AL, ' '

	; Copy spaces CX - FILENAME_EXT_SIZE times (CX amount of characters remaining)
	; Copy for "joker.txt" 3 space after joker into DI
	SUB CX, FILENAME_EXT_SIZE
	REP STOSB          

	MOV CX, FILENAME_EXT_SIZE

	JMP ConsumeSubdirSegment.copy_loop_start


ConsumeSubdirSegment.fill_loop:
	MOV AL, ' '
	REP STOSB     

	JMP ConsumeSubdirSegment.end

ConsumeSubdirSegment.end:
	POP ES
	POP DS
	POP AX
	POP CX
	POP DI

	RET

global ParseFATLinkedTable
ParseFATLinkedTable:
	PUSH AX
	; partition sector index
	MOV AX, [fat_start_sector]
	PUSH AX          ; LBA low 
	PUSH WORD 0x0000 ; LBA high
	; segment:offset
	PUSH WORD FAT_TABLE_SEGMENT
	PUSH WORD 0x0000
	; Size (amount of sectors) 
	PUSH WORD FAT_TABLE_SECTORS
	CALL LoadSector
	ADD SP, 10

	POP AX
	RET

global ParseFATPartitionSector
ParseFATPartitionSector:
	; First load the first sector of the partition
ParseFATPartitionSector.load:

	; Load first sector from the active partition
	MOV BX, [boot_start_sector]

	; partition sector index
	PUSH BX      ; low  2 bytes sector
	PUSH 0x000   ; high 2 bytes sector
	; segment:offset
	PUSH FIRST_SECTOR_SEG
	PUSH 0x0000
	; Size (amount of sectors) (512 bytes)
	PUSH 1
	CALL LoadSector
	ADD SP, 10

ParseFATPartitionSector.parse:

	MOV AX, FIRST_SECTOR_SEG
	MOV ES, AX

	; sectors_per_cluster (1 byte)
	MOV AL, ES:[0x0D]       
	MOVZX AX, AL
	MOV DS:[sectors_per_cluster], AX

	; reserved_sectors
	MOV AX, ES:[0x0E]  
	MOV BX, AX
	ADD AX, DS:[boot_start_sector]
	MOV DS:[fat_start_sector], AX
	
	; num_fats
	MOV AL, ES:[0x10]     
	MOVZX CX, AL

	; root_dir_start
	MOV AX, ES:[0x16]    ; sectors_per_fat 
	MUL CX                 ; AX = num_fats * sectors_per_fat
	ADD AX, BX             ; AX = root_dir_start
	ADD AX, DS:[boot_start_sector]
	MOV DS:[root_dir_start], AX

	; max_root_entries
	MOV CX, ES:[0x11]    ; CX = total root dir amount
	MOV DS:[max_root_entries], CX
	MOV AX, 32
	MUL CX                 ; AX = 32 * CX = size in bytes  
	MOV CX, ES:[0x0B]    ; bytes per sector
	XOR DX, DX
	DIV CX                 ; AX = root_dir_sectors
	ADD AX, DS:[root_dir_start]
	MOV DS:[data_region_start], AX

	; max_dir_entries_per_cluster
	XOR DX, DX
	MOV AX, DS:[sectors_per_cluster]
	MOV BX, FILES_PER_SECTOR
	MUL BX
	MOV DS:[max_dir_entries_per_cluster], AX

	RET

	

global LoadSector
; Loads a sector into the segment:offset provided
; AX, CX, DX will be wiped out, args are as follows:
; 	SectorFirst2Bytes (Low)
; 	SectorLast2Bytes  (High)
; 	Segment
; 	Offset
; 	Sectors Amount
LoadSector:
	PUSH BP
	MOV BP, SP
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	
	; Sectors amount
	MOV CX, [BP + 0x04]
	MOV [disk_addr_packet + DISK_SECTORS_AMOUNT_OFFSET], CL

	; segement:offset 
	MOV AX, [BP + 0x06] ; Offset
	MOV [disk_addr_packet + DISK_LOAD_ADDR_OFFSET], AX
	MOV AX, [BP + 0x08] ; Segment
	MOV [disk_addr_packet + DISK_LOAD_SEG_OFFSET], AX

	; LBA 4 byte sector entry
    MOV DX, [BP + 0x0A] ; LBA high
    MOV AX, [BP + 0x0C] ; LBA low

LoadSector.loop:
	CMP CX, 127
	JB LoadSector.last_chunk

	; Load 127 sectors
	MOV BYTE [disk_addr_packet + DISK_SECTORS_AMOUNT_OFFSET], 127
    MOV [disk_addr_packet + DISK_SECTOR_LBA_OFFSET], AX
    MOV [disk_addr_packet + DISK_SECTOR_LBA_OFFSET + 2], DX
    CALL CallDiskRead

	; Update LBA += 127
	ADD AX, 127
	ADC DX, 0

	; Update CX -= 127
	SUB CX, 127

LoadSector.update_mem_addr:
	; Update memory address: offset += 127 * 512 = 0xFE00
    MOV BX, [disk_addr_packet + DISK_LOAD_ADDR_OFFSET]
	ADD BX, 0xFE00
	JNC LoadSector.no_segment_bump

	MOV BX, [disk_addr_packet + DISK_LOAD_SEG_OFFSET]
	ADD BX, 0xFE0
	MOV [disk_addr_packet + DISK_LOAD_SEG_OFFSET], BX
	JMP LoadSector.after_bump

LoadSector.no_segment_bump:
	MOV [disk_addr_packet + DISK_LOAD_ADDR_OFFSET], BX

LoadSector.after_bump:

	JMP LoadSector.loop

LoadSector.last_chunk:
    CMP CX, 0
    JE LoadSector.done

    MOV [disk_addr_packet + DISK_SECTORS_AMOUNT_OFFSET], CL
    MOV [disk_addr_packet + DISK_SECTOR_LBA_OFFSET], AX
    MOV [disk_addr_packet + DISK_SECTOR_LBA_OFFSET + 2], DX
    CALL CallDiskRead

LoadSector.done:
	POP DX
	POP CX
	POP BX
	POP AX
	MOV SP, BP
	POP BP
    RET


global CallDiskRead
CallDiskRead:
    PUSH AX
    PUSH DX
    PUSH SI

    MOV AH, 0x42
    MOV SI, disk_addr_packet
    MOV DL, [driver]
    INT 0x13

    POP SI
    POP DX
    POP AX
    RET

global EnableA20
EnableA20:
	XOR CX, CX
EnableA20.test:
	; Read 0x0000:7DFE
	XOR AX, AX
	MOV DS, AX
	MOV SI, 0x7DFE
	MOV BX, [SI]

	; Read 0xFFFF:7E0E
	MOV AX, 0xFFFF    ; AX = 0xFFFF
	MOV DS, AX
	MOV SI, 0x7E0E
	CMP BX, [SI]
	
	PUSH WORD 0
	POP DS
	
	; If equal, A20 likely disabled

	JE EnableA20.enable_loop
	RET

EnableA20.enable_loop:
	INC CX

    ; Check how many methods tried
	CMP CX, ENABLE_OPTION_COUNT
	JAE Abort

	CMP CX, 1
	JE EnableA20.enable0
	CMP CX, 2
	JE EnableA20.enable1

	; None of the options existed
	JMP Abort


EnableA20.enable0: ; FAST A20 Method
	IN AL, 0x92
	TEST AL, 2
	JNZ EnableA20.after0
	OR AL, 2
	AND AL, 0xFE
	OUT 0x92, AL
EnableA20.after0:
	JMP EnableA20.test

EnableA20.enable1:
	IN AL,0xee
	JMP EnableA20.test

global PrintBinary
; Prints binary value in CH
PrintBinary:
	PUSH AX
	PUSH BX
	PUSH CX

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

	POP CX
	POP BX
	POP AX
	
    RET                    ; Return

global StrCmpSize
; StrCmpSize - String compare, compares the strings that are in SI and DI with length CX
;				Returns the difference between the last mismatched characters in AX.
;				Assumes:
;					- SI is in DS segment
;					- DI is in ES segment
;				Returns:
;					- AX = 0 if equal
;					- AX = signed difference (SI[i] - DI[i]) on first mismatch
StrCmpSize:
    PUSH SI
    PUSH DI
	PUSH BX
	PUSH CX

StrCmpSize.loop:
    CMP CX, 0
    JE StrCmpSize.equal

    LODSB              ; AL ← [DS:SI], SI++
    SCASB              ; compare AL to [ES:DI], DI++
    JNZ StrCmpSize.diff

    DEC CX
    JMP StrCmpSize.loop

StrCmpSize.equal:
    XOR AX, AX
    JMP StrCmpSize.done

StrCmpSize.diff:
    ; AL = [SI - 1], BL = [DI - 1]
    MOV AL, DS:[SI - 1]
    MOV BL, ES:[DI - 1]
    SUB AL, BL
    CBW                ; sign-extend into AX

StrCmpSize.done:
	POP CX
	POP BX
    POP DI
    POP SI
    RET


global PrintCharacter
PrintCharacter:	                    ;Assume that ASCII value is in register AL
	PUSH AX
	PUSH BX

	MOV AH, 0x0E	                ; One char   
	MOV BH, 0x00	                ; Page no
	MOV BL, 0x07	                ; Color 0x07 

	INT 0x10	                    ;Call video interrupt

PrintCharacter.end
	POP BX
	POP AX
	
	RET		                        ;Return to calling procedure



global PrintString
; Prints a string in DS:SI
PrintString:
	PUSH SI
	PUSH AX
PrintString.next_character:	        ;Label 
	MOV AL, [SI]	                    ;Get a byte from string into AL register
	INC SI		                        ;Increment pointer
	OR AL, AL	                        ;Check if AL is zero (null terminator)
	JZ PrintString.exit_function        ;Stop if null terminator
	CALL PrintCharacter                 ;Else print the character which is in AL register
	JMP PrintString.next_character	    ;Get next character from string
PrintString.exit_function:	        ;End label
	POP AX
	POP SI
	RET		                            ;Return


global Abort
Abort:
	MOV SI, abort_str
	CALL PrintString
;Data
hello_string db 'Hello from stage 2', 0x0A, 0xD, 0  ;HelloWorld string ending with 0
driver: DB 0
disk_addr_packet: 
	DB 16, 0           ; size of the packet 16 bytes, plus 0 reservd
	DW 63              ; 63 sectors will loaded
	DW 0x0000, 0x0000  ; segment:offset (opposite because little endian system)
	DW 0,0,0,0         ; Empty 8 bytes for the LBA address 

kernel_elf_path db 'BOOT/HATCH/KERNEL.ELF', 0 

dummy_filename db FILENAME_SIZE DUP (0x20), 0
 

; Currently only support FAT:
boot_start_sector: dw 0
sectors_per_cluster: dw 0
fat_start_sector: dw 0
root_dir_start: dw 0
data_region_start: dw 0

max_root_entries dw 0
max_dir_entries_per_cluster dw 0
root_dirs_amount: dw 0
total_sectors: DD 0

partition_addr: DW 0x0000
abort_str: DB "Abort", 0
failed_str: DB "Failed", 0xD, 0xA, 0
success_str: DB "Succeeded", 0xD, 0xA, 0