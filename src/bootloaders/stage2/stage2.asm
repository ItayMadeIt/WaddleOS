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

%define FAT_TABLE_SEGMENT          (0x1000)
%define FAT_TABLE_MAX_SIZE         (0x20000)
%define FAT_TABLE_SECTORS          (FAT_TABLE_MAX_SIZE / SECTOR_SIZE)
%define FAT_TABLE_SEG_END          (FAT_TABLE_SEGMENT + FAT_TABLE_MAX_SIZE/0x10)

%define FILENAME_SIZE              (11)
%define FILENAME_EXT_SIZE          (3)
%define FILE_ENTRY_SIZE            (32)
%define FILES_PER_SECTOR           (SECTOR_SIZE / FILE_ENTRY_SIZE)

%define SECTOR_SEG_FILEDATA        (FAT_TABLE_SEG_END)
%define SECTOR_FILEDATA            (FAT_TABLE_SEG_END * 0x10)
%define SECTOR_FILEDATA_COPY       (SECTOR_FILEDATA + SECTOR_SIZE)
%define SECTOR_ELF_HEADER          (SECTOR_FILEDATA_COPY + SECTOR_SIZE)

%define MEMORY_MAP_SEG             (0x6000)
; Up to 128 KiB for paging setup and long mode 
%define PROTECTED_MODE_BIN_ADDR    (0x80000) 


; The file's purpose is to understand FAT16 (and maybe others, so it's flexible) and read
;  the boot.cfg file, get it's first line, find that file, and copy it
;  with only 32KiB of size, 0x8000 bytes. (So 0x7E00 + 0x8000 = 0xFE00, from 0xFE00 is usable memory)
;Store stage 2
global _start2
_start2:
	MOV SI, hello_string                 
	CALL PrintString	          

	MOV AX, 0
	MOV GS, AX

	POP DX
	MOV GS:[driver], DL
	POP SI
	MOV GS:[partition_addr], SI
	MOV DX, DS:[SI+0x08]    ; Load bytes at offset 0x08 (LBA start)
	MOV GS:[boot_start_sector], DX

	CALL EnableA20
	CALL ParseFATPartitionSector
	CALL ParseFATLinkedTable


	; Sets GS and FS limitless (4 GiB access)
	CALL SetupUnrealMode 

	CALL SetupMemoryMap


	PUSH WORD 0
	POP DS
	MOV SI, stage3_bin_path
	PUSH WORD SECTOR_SEG_FILEDATA
	POP ES
	CALL FindFileFromPath
	MOV SI, DI   ; Get DI from FindFileFromPath

	TEST AX, AX
	JNE _start2.file_path_failed

	
	; DS = ES
	PUSH ES
	POP DS
	; SI = DI
	PUSH DI
	POP SI
	; Ensures DS:SI -> ESI	
	CALL DsSi2ESI
	MOV EDI, 0x80000
	MOV BX, SECTOR_SEG_FILEDATA 

	CALL CopyElfFile
	

	PUSH WORD 0
	POP DS
	MOV SI, kernel_elf_path
	PUSH WORD SECTOR_SEG_FILEDATA
	POP ES
	CALL FindFileFromPath

	; DS = ES
	PUSH ES
	POP DS
	; SI = DI
	PUSH DI
	POP SI

	; Ensures DS:SI -> ESI	
	CALL DsSi2ESI
	MOV EDI, 0x100000
	MOV BX, SECTOR_SEG_FILEDATA 
	CALL CopyElfFile


	CALL ContinueWithProtectedMode

	
_start2.loop:
	JMP _start2.loop                        ;Infinite loop, hang it here.

_start2.file_path_failed:
	MOV SI, failed_str
	CALL PrintString
	
	CALL Abort

;
; ESI - Entry offset
; BX  - Sector for filedata
; AX  - 0 succeeded, 1 failure
CopyElfFile:
	PUSH ECX
	PUSH DX
	
	MOV ECX, FS:[ESI + 0x1C]   ; ECX = size
	MOV DX , FS:[ESI + 0x1A]   ; Load first cluster address

CopyElfFile.parse_header:

	; Gets ESI as entry offset, copies 32 byte
	CALL ParseElfHeader

	MOV AX, 0
	MOV WORD GS:[elf_entry_index], AX

CopyElfFile.entry_loop:
	CALL FetchEntryMetadata

	CALL CopyElfEntry

	DEC WORD GS:[elf_entry_amount]
	JZ CopyElfFile.done

	INC WORD GS:[elf_entry_index]

	JMP CopyElfFile.entry_loop
	
CopyElfFile.done:

	POP DX
	POP ECX
	RET

; BX - Usable sector
; DX - File first cluster index
; All other arguments are global vars:
;  - elf_entry_size
;  - elf_entry_index
;  - elf_ph_offset
;  - elf_ph_entry
CopyElfEntry:
	PUSH ESI
	PUSH EAX

	; Check if it's load
	CMP DWORD GS:[elf_ph_entry], 1
	JNZ CopyElfEntry.done ; not load, done

	CMP BYTE GS:[elf_is_32bit], 1
	JNE CopyElfEntry.bit64

CopyElfEntry.bit32:
	MOV ECX, GS:[elf_ph_entry + 0x10] ; filesz

	; PUSH EAX, EAX will be memsz - filesz (amount of zeros) 
	MOV EAX, GS:[elf_ph_entry + 0x14] ; memsz
	SUB EAX, ECX
	PUSH EAX

	MOV EAX, GS:[elf_ph_entry + 0x04] ; offset
	MOV EDI, GS:[elf_ph_entry + 0x08] ; vaddr
	
	JMP CopyElfEntry.copy

CopyElfEntry.bit64:
	MOV ECX, GS:[elf_ph_entry + 0x20] ; filesz
	
	; PUSH EAX, EAX will be memsz - filesz (amount of zeros) 
	MOV EAX, GS:[elf_ph_entry + 0x28] ; memsz
	SUB EAX, ECX
	PUSH EAX

	MOV EAX, GS:[elf_ph_entry + 0x08] ; offset
	MOV EDI, GS:[elf_ph_entry + 0x10] ; vaddr

CopyElfEntry.copy:

	CALL CopyFileSection

	POP EAX

	TEST EAX, EAX
	JZ CopyElfEntry.done

CopyElfEntry.loop0:
	
	MOV BYTE [EDI], 0
	INC EDI

	DEC EAX
	JNZ CopyElfEntry.loop0

CopyElfEntry.done:
	POP EAX
	POP ESI
	RET

; DX - Start sector of elf file
; BX - Usable segment of memory (512 bytes)
ParseElfHeader:
	PUSH ESI
	PUSH EDI
	PUSH EAX
	PUSH ECX
	PUSH ES
	PUSH DS

	PUSH GS
	POP DS

	PUSH GS
	POP ES

	; AX = DATA + DX * 2
	CALL SetClusterStartSector

	; Load sector
	PUSH AX      ; Sector start low 2 byte
	PUSH WORD 0  ; Sector start high 2 byte
	PUSH BX      ; Segment
	PUSH WORD 0  ; Offset
	PUSH WORD 1  ; 1 Sector
	CALL LoadSector
	ADD SP, 10

	; ESI = BX << 4
	MOV SI, BX
	AND ESI, 0x0000FFFF
	SHL ESI, 4

ParseElfHeader.magic:
	; 0x7F ELF
	CMP WORD FS:[ESI + 0x00], 0x457F
	JNE Abort
	CMP WORD FS:[ESI + 0x02], 0x464C
	JNE Abort

ParseElfHeader.parse_bit:
	CMP BYTE FS:[ESI + 0x04], 0x02 ; [SI + 0x04] EI_CLASS
	JE ParseElfHeader.bit64

ParseElfHeader.bit32:
	MOV BYTE GS:[elf_is_32bit], 1

	MOV EAX, FS:[ESI + 0x1C]
	MOV GS:[elf_ph_offset], EAX

	MOV AX, FS:[ESI + 0x2A]
	MOV GS:[elf_entry_size], AX

	MOV AX, FS:[ESI + 0x2C] 
	MOV GS:[elf_entry_amount], AX

	JMP ParseElfHeader.done
ParseElfHeader.bit64:
	MOV BYTE GS:[elf_is_32bit], 0

	MOV EAX, FS:[ESI + 0x20]
	MOV GS:[elf_ph_offset], EAX

	MOV AX, FS:[ESI + 0x36]
	MOV GS:[elf_entry_size], AX

	MOV AX, FS:[ESI + 0x38] 
	MOV GS:[elf_entry_amount], AX

ParseElfHeader.done:
	POP DS
	POP ES
	POP ECX
	POP EAX
	POP EDI
	POP ESI
	RET


; DX - First cluster address (SAVED)
; BX - Segment for sector
FetchEntryMetadata:
	PUSH DX
	PUSH BX
	PUSH EDI

	PUSH DX
	PUSH BX

	MOV BX, GS:[elf_entry_index] ; Index into the program header table
	MOV AX, GS:[elf_entry_size]  ; Size of each entry
	MUL BX ; entry_index * entry_size -> DX:AX 

	; Reconstruct EAX = DX:AX
	SHL EAX, 16
	MOV AX, DX
	ROR EAX, 16
	
	ADD EAX, GS:[elf_ph_offset]

	POP BX
	POP DX


	; EAX = Offset in file (calc above)

	; EDI = destination	
	MOV EDI, elf_ph_entry
	
	PUSH ECX	
	; ECX = size (elf_entry_size)
	MOV CX, GS:[elf_entry_size]
	AND ECX, 0x0000FFFF

	; DX = Cluster index (at offset 0)
	PUSH DX
	CALL CopyFileSection
	POP DX

	POP ECX

	XOR AX, AX
FetchEntryMetadata.done:
	POP EDI
	POP BX
	POP DX
	RET


; DX - First cluster index of file (SAVED)
; BX - Segment for sector
; EAX - Offset bytes in file
; ECX - Amount of bytes
; EDI - Destination location
CopyFileSection:
	PUSH BP
CopyFileSection.offset_loop:
	CMP EAX, GS:[bytes_per_cluster]
	JB CopyFileSection.loop

	SUB EAX, GS:[bytes_per_cluster]

	; DX = FAT_TABLE[DX * 2] next cluster
	XCHG AX, DX
	CALL NextClusterIndex 
	XCHG AX, DX

	JMP CopyFileSection.offset_loop

CopyFileSection.loop:
	PUSH EAX

	; Save cluster index
	MOV BP, DX

	; DX (cluster index) = (cluster first sector)
	; AX (low offset) = (cluster index)
	CALL SetClusterStartSector
	XCHG DX, AX

	POP EAX

	CALL CopyFileSectionCluster

	; Restore cluster index
	MOV DX, BP

	TEST ECX, ECX
	JZ CopyFileSection.done

	; Go to next cluster
	; DX = FAT_TABLE[DX * 2] next cluster
	XCHG AX, DX
	CALL NextClusterIndex 
	XCHG AX, DX

	JMP CopyFileSection.loop

CopyFileSection.done:
	POP BP
	RET


; DX - First sector in cluster of current will-copy cluster
; BX - Segment for sector
; EAX - Offset bytes from cluster start (Less than bytes_per_cluster)
; ECX - Amount of bytes (can be more than bytes_per_cluster, will be modified) 
; EDI - Destination location
CopyFileSectionCluster:
	PUSH ESI
	PUSH BP


CopyFileSectionCluster.fix_offset:
	; If offset >= sector size, fix it
	CMP EAX, SECTOR_SIZE
	JB CopyFileSectionCluster.copies_sector

	; Go to next sector, and eax -= sector_size
	SUB EAX, SECTOR_SIZE
	INC DX
	DEC BP
	JZ CopyFileCluster.done

	JMP CopyFileSectionCluster.fix_offset

CopyFileSectionCluster.copies_sector:

	CALL CopyFileSectionSector

	TEST ECX, ECX
	JZ CopyFileSectionCluster.done

	INC DX
	DEC BP
	JNZ CopyFileSectionCluster.copies_sector

CopyFileSectionCluster.done:
	POP BP
	POP ESI
	RET

; Copies a chunk of a sector starting at a given offset.
; Loads 1 sector at DX into BX:0000
; Input:
;   ECX - Copy as much as possible from one sector (can be larger than SECTOR_SIZE, will be modified)
;   EAX - offset will be modified (CANT be larger than SECTOR_SIZE-1, will be modified)
;   EDI - destination address to be modified (will move forward)
;   BX  - Usable sector (BX = segment)
;   DX  - Sector index
CopyFileSectionSector:
	PUSH ESI
	PUSH EBP

	; ESI = BX << 4 (seg to addr)
	MOV SI, BX
	AND ESI, 0xFFFF
	SHL ESI, 4

	MOV EBP, ESI
	ADD EBP, SECTOR_SIZE

	; Add offset to ESI
	ADD ESI, EAX 
	XOR EAX, EAX ; EAX = 0

	PUSH DX      ; Sector start low 2 byte
	PUSH WORD 0  ; Sector start high 2 byte
	PUSH BX      ; Segment
	PUSH WORD 0  ; Offset
	PUSH WORD 1  ; 1 Sector
	CALL LoadSector
	ADD SP, 10


CopyFileSectionSector.loop:
	; [ESI] = [EDI] (EAX is already 0 so can be used)
	MOV AL, FS:[ESI]
	MOV FS:[EDI], AL

	INC ESI
	INC EDI

	CMP ESI, EBP
	JAE CopyFileSectionSector.done

	DEC ECX
	JNZ CopyFileSectionSector.loop

CopyFileSectionSector.done:

	XOR EAX, EAX ; offset must be 0 after that

	POP EBP
	POP ESI
	RET


; ESI - Entry offset
; EDI - Destination address
; BX  - Sector that filedata  in
UnrealCopyFile:
	PUSH ECX
	
	MOV ECX, FS:[ESI + 0x1C]   ; ECX = size
	MOV DX , FS:[ESI + 0x1A]   ; Load first cluster address

UnrealCopyFile.loop:

	; AX = FAT_DATA + DX * 2
	CALL SetClusterStartSector

	CMP ECX, GS:[bytes_per_cluster]
	JB UnrealCopyFile.final_chunk

	PUSH ECX
	MOV ECX, GS:[bytes_per_cluster]
	CALL UnrealCopyFileCluster
	POP ECX

	SUB ECX, GS:[bytes_per_cluster]

	; DX(index) = FAT_LINKED_LIST[DX*2]
	MOV AX, DX
	CALL NextClusterIndex
	MOV DX, AX

	; Invalid file (shouldn't get here)
	CMP AX, 0xFFF8
	JAE Abort

	JMP UnrealCopyFile.loop


UnrealCopyFile.final_chunk:
	TEST ECX, ECX
	JZ UnrealCopyFile.done

	CALL UnrealCopyFileCluster
UnrealCopyFile.done:
	POP ECX
	RET


;  ECX - Amount of bytes need to be copied
;  AX  - Start sector (will  be modified)
;  BX  - Memory segment sector 
;  EDI - Place to copy into (will advance)
UnrealCopyFileCluster:
	PUSH BX
	PUSH ESI

UnrealCopyFileCluster.loop:
	; ESI = BX << 4 (seg to addr)
	MOV SI, BX
	AND ESI, 0xFFFF
	SHL ESI, 4

	PUSH AX      ; Sector start low 2 byte
	PUSH WORD 0  ; Sector start high 2 byte
	PUSH BX      ; Segment
	PUSH WORD 0  ; Offset
	PUSH WORD 1  ; 1 Sector
	CALL LoadSector
	ADD SP, 10

	; Less than SECTOR_SIZE
	CMP ECX, SECTOR_SIZE
	JB UnrealCopyFileCluster.last_chunk

	; Copy SECTOR_SIZE bytes
	PUSH ECX
	MOV ECX, SECTOR_SIZE
	CALL UnrealCopyFileSector
	POP ECX

	SUB ECX, SECTOR_SIZE
	
	; Next sector
	INC AX

	JMP UnrealCopyFileCluster.loop

UnrealCopyFileCluster.last_chunk:
	TEST ECX, ECX
	JZ UnrealCopyFileCluster.done

	CALL UnrealCopyFileSector

UnrealCopyFileCluster.done:
	POP ESI
	POP BX
	RET


; Inputs:
;  ESI - Place to copy from 
;  EDI - Place to copy into
;  ECX - Amount of bytes need to be copied
UnrealCopyFileSector:
	PUSH AX

UnrealCopyFileSector.loop:
	MOV AL, FS:[ESI]
	MOV FS:[EDI], AL
	
	INC ESI
	INC EDI
	
	DEC ECX	
	JNZ UnrealCopyFileSector.loop

UnrealCopyFileSector.done:
	POP AX
	RET




DsSi2ESI:
	PUSH EAX

	AND ESI, 0xFFFF
	XOR EAX, EAX
	MOV AX, DS
	SHL EAX, 4
	ADD ESI, EAX

	POP  EAX
	RET


SetupMemoryMap:
	PUSH ES
	PUSH DI
	PUSH EAX
	PUSH ECX
	PUSH EDX
	PUSH EBX
	
	XOR EBX, EBX          ; EBX = 0

	PUSH WORD MEMORY_MAP_SEG
	POP ES                ; ES = MEMORY_MAP_SEG
	XOR DI, DI            ; DI = 0

SetupMemoryMap.loop:

	MOV EAX, 0xE820       ; Function (load memory map)
	MOV ECX, 24           ; Size entry
	MOV EDX, 0x534D4150   ; "SMAP" magic constant

	CLC
	INT 0x15	

SetupMemoryMap.loop_after_int:
	; Advance to next 24 byte entry
	MOV CX, 24
	ADD DI, CX

	; If carry, stop
	JC SetupMemoryMap.null_entry

	TEST EBX, EBX
	JNZ SetupMemoryMap.loop

SetupMemoryMap.null_entry:	
	MOV ECX, 24           ; Size entry
	REP STOSB

SetupMemoryMap.done:
	POP EBX
	POP EDX
	POP ECX
	POP EAX
	POP DI
	POP ES
	RET
	

ContinueWithProtectedMode:
	XOR BX, BX
	MOV DS, BX
	MOV ES, BX
	MOV GS, BX
	MOV FS, BX
	
	CLI
	; Load protected mode gdt
	LGDT GS:[protected_gdt_info]

	; Enable protected mode (bit 0 in CR0)
	MOV EAX, CR0
	OR  EAX, 1
	MOV CR0, EAX
	
	; CS = 0x8 (new code segment)
	JMP DWORD 0x8:ContinueWithProtectedMode.protected_mode

ContinueWithProtectedMode.protected_mode:
	
[BITS 32]
	; Select second data segment (2 * 8 = 0x10)
	MOV BX, 0x10     
	MOV DS, BX
	MOV ES, BX
	MOV FS, BX
	MOV GS, BX

	; Setup SS:SP -> ESP
	XOR EAX, EAX
	MOV AX, SS
	SHL EAX, 4
	ADD ESP, EAX

	MOV SS, BX

	STI

	; Now setup argument regs and jump to PROTECTED_MODE_BIN_ADDR
	MOV EBX, MEMORY_MAP_SEG * 0x10
	CALL PROTECTED_MODE_BIN_ADDR

	; Should never return
	JMP $









[BITS 16]




; BX - Usable memory sector
; ES:DI - Destination address
; DS:SI - Entry start
CopyFile:
	PUSH ECX
	PUSH AX
	PUSH DX

	MOV ECX, DS:[SI + 0x1C]   ; ECX = size
	MOV DX , DS:[SI + 0x1A]   ; Load first cluster address

CopyFile.loop:
	; AX = FAT_DATA + DX * 2
	CALL SetClusterStartSector

	CMP ECX, GS:[bytes_per_cluster]
	JB CopyFile.final_chunk

	PUSH ECX
	MOV ECX, GS:[bytes_per_cluster]
	CALL CopyFileCluster
	POP ECX

	SUB ECX, GS:[bytes_per_cluster]

	; DX(index) = FAT_LINKED_LIST[DX*2]
	MOV AX, DX
	CALL NextClusterIndex
	MOV DX, AX

	; Invalid file (shouldn't get here)
	CMP AX, 0xFFF8
	JAE Abort

	JMP CopyFile.loop


CopyFile.final_chunk:
	TEST ECX, ECX
	JZ CopyFile.done

	CALL CopyFileCluster

CopyFile.done:
	POP DX
	POP AX
	POP ECX
	RET


; Inputs:
;  ES:DI - Place to copy into
;  ECX - Amount of bytes need to be copied
;  AX  - Start sector 
;  BX  - Memory segment sector 
; 
; Notes:
;  ES:DI & DS:SI move forward min(ECX, bytes_per_cluster)
;
CopyFileCluster:
	PUSH BX

	MOV DS, BX

CopyFileCluster.loop:
	XOR SI, SI

	PUSH AX      ; Sector start low 2 byte
	PUSH WORD 0  ; Sector start high 2 byte
	PUSH BX      ; Segment
	PUSH WORD 0  ; Offset
	PUSH WORD 1  ; 1 Sector
	CALL LoadSector
	ADD SP, 10

	CMP ECX, SECTOR_SIZE
	JB CopyFileCluster.last_chunk

	PUSH ECX
	PUSH SI
	PUSH DS
	MOV ECX, SECTOR_SIZE
	CALL CopyFileSector
	POP DS
	POP SI
	POP ECX

	SUB ECX, SECTOR_SIZE

	INC AX

	JMP CopyFileCluster.loop

CopyFileCluster.last_chunk:
	TEST ECX, ECX
	JZ CopyFileCluster.done

	CALL CopyFileSector

CopyFileCluster.done:
	POP BX
	RET


;
; Inputs:
;  DS:SI - Place to copy from 
;  ES:DI - Place to copy into
;  ECX - Amount of bytes need to be copied
CopyFileSector:
	PUSH AX

CopyFileSector.loop:
	MOV AL, DS:[SI]
	MOV ES:[DI], AL
	
	INC SI
	INC DI
	JNZ CopyFileSector.skip_seg_bump
	
	MOV AX, ES
	ADD AX, 0x100
	MOV ES, AX
	
CopyFileSector.skip_seg_bump:
	
	DEC ECX	
	JNZ CopyFileSector.loop

CopyFileSector.done:
	POP AX
	RET


SetupUnrealMode:
	PUSH SS
	PUSH DS
	PUSH EAX
	PUSH EBX
	
	XOR BX, BX
	MOV DS, BX
	MOV FS, BX

	CLI         ; No interrupts
	PUSH FS

	LGDT GS:[unreal_gdt_info]     ; Load GDT register

	; Enable protected mode (bit 0 in CR0)
	MOV EAX, CR0
	OR  EAX, 1
	MOV CR0, EAX

	; CS = 0x8 (new code segment)
	JMP 0x8:SetupUnrealMode.protected_mode

SetupUnrealMode.protected_mode:
	
	; Select second data segment (2 * 8 = 0x10)
	MOV BX, 0x10     
	MOV FS, BX

	; Disable protected mode (bit 0 in CR0)
	AND AL, 0xFE
	MOV CR0, EAX
	
	JMP 0x0:SetupUnrealMode.unreal_mode
SetupUnrealMode.unreal_mode:
	POP FS
	STI


SetupUnrealMode.done:
	POP EBX
	POP EAX
	POP DS
	POP SS
	RET




align 8
unreal_gdt_begin:      dd 0,0        ; entry 0 is always unused
; BASE = 0, LIMIT = 0xFFFFF, kernel DPL, executable, page granularity, DB 16 bit protected.
unreal_gdt_flatcode:   db 0xff, 0xff, 0, 0, 0, 10011010b, 10001111b, 0
; BASE = 0, LIMIT = 0xFFFFF, kernel DPL, read-write, page granularity, DB 32 bit protected.
unreal_gdt_flatdata:   db 0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
unreal_gdt_end:


unreal_gdt_info:
   dw unreal_gdt_end - unreal_gdt_begin - 1   ; last byte in table
   dd unreal_gdt_begin                        ; start of table



align 8
protected_gdt_begin: align 8 
	dq 0        ; entry 0 is always unused
; BASE = 0, LIMIT = 0xFFFFF, kernel DPL, executable, page granularity, DB 32 bit protected.
protected_gdt_flatcode: 
	dq 0x00CF9A000000FFFF
; BASE = 0, LIMIT = 0xFFFFF, kernel DPL, read-write, page granularity, DB 32 bit protected.
protected_gdt_flatdata: 
	dq  0x00CF92000000FFFF
protected_gdt_end:


protected_gdt_info:
   dw protected_gdt_end - protected_gdt_begin - 1   ; last byte in table
   dd protected_gdt_begin                        ; start of table



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

PrintFile.done:
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
; DS:SI - String start of the full path
FindFileFromPath:
	
	; Gets root dir "a/b/c" -> "a            " in dummy_filename
	PUSH DS
	PUSH WORD 0
	POP DS
	CALL ConsumeSubdirSegment
	POP DS


	PUSH DS
	PUSH SI   ; Save SI

	PUSH WORD 0
	POP DS

	MOV SI, dummy_filename	
	
	CALL FindFileInRoot
	POP SI    ; Restore SI
	POP DS

	CMP AX, 0
	JNZ FindFileFromPath.failed

FindFileFromPath.subdir_loop:
	; Gets root dir "a/b/c" -> "a            " in dummy_filename
	PUSH DS
	PUSH WORD 0
	POP DS
	CALL ConsumeSubdirSegment
	POP DS

	PUSH DS
	PUSH SI   ; Save SI

	PUSH WORD 0
	POP DS

	MOV SI, dummy_filename	
	MOV BX, ES               ; Segment to be used is the one in use currently for destination
	CALL FindFileFromDirSector
	
	POP SI    ; Restore SI
	POP DS


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

	MOV AX, GS:[root_dir_start]

	MOV CX, GS:[max_root_entries]
	
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

	MOV CX, GS:[max_dir_entries_per_cluster]
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
    MOV BX, GS:[sectors_per_cluster]
    MUL BX
    ADD AX, GS:[data_region_start]
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
	LODSB            ; Load AL from DS:[SI], SI++
	CMP AL, 0        ; null terminator
	JZ ConsumeSubdirSegment.fill_loop
	CMP AL, '/'      ; slash (next part so stop)
	JZ ConsumeSubdirSegment.fill_loop
	CMP AL, '.'      ; dot (start extension)
	JZ ConsumeSubdirSegment.prepare_extension

ConsumeSubdirSegment.copy_loop_iterate:
	STOSB         ; Copy AL into ES:[DI]


	LOOP ConsumeSubdirSegment.copy_loop_start
	JMP ConsumeSubdirSegment.done

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

	JMP ConsumeSubdirSegment.done

ConsumeSubdirSegment.done:
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
	MOV AX, GS:[fat_start_sector]
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
	MOV BX, GS:[boot_start_sector]

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
	MOV GS:[sectors_per_cluster], AX
	MOV BX, SECTOR_SIZE
	MUL BX
	MOV GS:[bytes_per_cluster], AX

	; reserved_sectors
	MOV AX, ES:[0x0E]  
	MOV BX, AX
	ADD AX, GS:[boot_start_sector]
	MOV GS:[fat_start_sector], AX
	
	; num_fats
	MOV AL, ES:[0x10]     
	MOVZX CX, AL

	; root_dir_start
	MOV AX, ES:[0x16]    ; sectors_per_fat 
	MUL CX                 ; AX = num_fats * sectors_per_fat
	ADD AX, BX             ; AX = root_dir_start
	ADD AX, GS:[boot_start_sector]
	MOV GS:[root_dir_start], AX

	; max_root_entries
	MOV CX, ES:[0x11]    ; CX = total root dir amount
	MOV GS:[max_root_entries], CX
	MOV AX, 32
	MUL CX                 ; AX = 32 * CX = size in bytes  
	MOV CX, ES:[0x0B]    ; bytes per sector
	XOR DX, DX
	DIV CX                 ; AX = root_dir_sectors
	ADD AX, GS:[root_dir_start]
	MOV GS:[data_region_start], AX

	; max_dir_entries_per_cluster
	XOR DX, DX
	MOV AX, GS:[sectors_per_cluster]
	MOV BX, FILES_PER_SECTOR
	MUL BX
	MOV GS:[max_dir_entries_per_cluster], AX

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
	MOV CX, SS:[BP + 0x04]
	MOV GS:[disk_addr_packet + DISK_SECTORS_AMOUNT_OFFSET], CL

	; segement:offset 
	MOV AX, SS:[BP + 0x06] ; Offset
	MOV GS:[disk_addr_packet + DISK_LOAD_ADDR_OFFSET], AX
	MOV AX, SS:[BP + 0x08] ; Segment
	MOV GS:[disk_addr_packet + DISK_LOAD_SEG_OFFSET], AX

	; LBA 4 byte sector entry
    MOV DX, SS:[BP + 0x0A] ; LBA high
    MOV AX, SS:[BP + 0x0C] ; LBA low

LoadSector.loop:
	CMP CX, 127
	JB LoadSector.last_chunk

	; Load 127 sectors
	MOV BYTE GS:[disk_addr_packet + DISK_SECTORS_AMOUNT_OFFSET], 127
    MOV GS:[disk_addr_packet + DISK_SECTOR_LBA_OFFSET], AX
    MOV GS:[disk_addr_packet + DISK_SECTOR_LBA_OFFSET + 2], DX
    CALL CallDiskRead

	; Update LBA += 127
	ADD AX, 127
	ADC DX, 0

	; Update CX -= 127
	SUB CX, 127

LoadSector.update_mem_addr:
	; Update memory address: offset += 127 * 512 = 0xFE00
    MOV BX, GS:[disk_addr_packet + DISK_LOAD_ADDR_OFFSET]
	ADD BX, 0xFE00
	JNC LoadSector.no_segment_bump

	MOV BX, GS:[disk_addr_packet + DISK_LOAD_SEG_OFFSET]
	ADD BX, 0xFE0
	MOV GS:[disk_addr_packet + DISK_LOAD_SEG_OFFSET], BX
	JMP LoadSector.after_bump

LoadSector.no_segment_bump:
	MOV GS:[disk_addr_packet + DISK_LOAD_ADDR_OFFSET], BX

LoadSector.after_bump:

	JMP LoadSector.loop

LoadSector.last_chunk:
    CMP CX, 0
    JE LoadSector.done

    MOV GS:[disk_addr_packet + DISK_SECTORS_AMOUNT_OFFSET], CL
    MOV GS:[disk_addr_packet + DISK_SECTOR_LBA_OFFSET], AX
    MOV GS:[disk_addr_packet + DISK_SECTOR_LBA_OFFSET + 2], DX
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
	PUSH DS

	XOR AX, AX
	MOV DS, AX

    MOV AH, 0x42
    MOV SI, disk_addr_packet
    MOV DL, GS:[driver]
    INT 0x13

    POP DS
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
	MOV BX, DS:[SI]

	; Read 0xFFFF:7E0E
	MOV AX, 0xFFFF    ; AX = 0xFFFF
	MOV DS, AX
	MOV SI, 0x7E0E
	CMP BX, DS:[SI]
	
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
	; Wait for input buffer to clear
.wait_input:
	IN AL, 0x64
	TEST AL, 2
	JNZ .wait_input

	; Send command to write output port
	MOV AL, 0xD1
	OUT 0x64, AL

	; Wait again
.wait_input2:
	IN AL, 0x64
	TEST AL, 2
	JNZ .wait_input2

	; Write value with A20 enabled (bit 1 set)
	MOV AL, 0xDF    ; Common: 1101 1111
	OUT 0x60, AL

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

    LODSB              ; AL <- DS:[SI], SI++
    SCASB              ; compare AL to ES:[DI], DI++
    JNZ StrCmpSize.diff

    DEC CX
    JMP StrCmpSize.loop

StrCmpSize.equal:
    XOR AX, AX
    JMP StrCmpSize.done

StrCmpSize.diff:
    ; AL = DS:[SI - 1], BL = ES:[DI - 1]
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

PrintCharacter.done:
	POP BX
	POP AX
	
	RET		                        ;Return to calling procedure



global PrintString
; Prints a string in DS:SI
PrintString:
	PUSH SI
	PUSH AX
PrintString.next_character:	        ;Label 
	MOV AL, DS:[SI]	                    ;Get a byte from string into AL register
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
	JMP $

;Data
hello_string db 'Hello from stage 2', 0x0A, 0xD, 0  ;HelloWorld string ending with 0
driver: DB 0
disk_addr_packet: 
	DB 16, 0           ; size of the packet 16 bytes, plus 0 reservd
	DW 63              ; 63 sectors will loaded
	DW 0x0000, 0x0000  ; segment:offset (opposite because little endian system)
	DW 0,0,0,0         ; Empty 8 bytes for the LBA address 

kernel_elf_path db 'BOOT/HATCH/KERNEL.ELF', 0 
stage3_bin_path db 'BOOT/HATCH/STAGE3.ELF', 0 

dummy_filename db FILENAME_SIZE DUP (0x20), 0
 

; Currently only support FAT:
boot_start_sector: dw 0
sectors_per_cluster: dw 0
bytes_per_cluster: dd 0
fat_start_sector: dw 0
root_dir_start: dw 0
data_region_start: dw 0

max_root_entries dw 0
max_dir_entries_per_cluster dw 0
root_dirs_amount: dw 0
total_sectors: DD 0

elf_entry_size: DW 0
elf_entry_amount: DW 0
elf_entry_index: DW 0 ; max elf program eentry
elf_ph_offset: DD 0
elf_ph_entry: DB 0x38 DUP (0x01) ; max elf program entry
elf_is_32bit: DB 0 ; max elf program eentry

partition_addr: DW 0x0000
abort_str: DB "Abort", 0
failed_str: DB "Failed", 0xD, 0xA, 0
success_str: DB "Succeeded", 0xD, 0xA, 0