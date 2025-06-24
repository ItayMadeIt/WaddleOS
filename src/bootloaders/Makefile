.PHONY: all build clean

all: build


STAGE3_C_FILES   := stage3_paging.c stage3_idt.c stage3_debug.c stage3_gdt.c stage3_main.c
STAGE3_C_SOURCES := $(addprefix stage3/, $(STAGE3_C_FILES))
STAGE3_C_INCLUDE := include

STAGE3_AS_FILES  := stage3_entry.asm stage3_asm_utils.asm
STAGE3_AS_SOURCES := $(addprefix stage3/, $(STAGE3_AS_FILES))

STAGE3_OBJ_FILES := $(addprefix $(BUILD_DIR)/, $(STAGE3_C_FILES:.c=.o) $(STAGE3_AS_FILES:.asm=.o))

CFLAGS_STAGE3 := -m32 -ffreestanding -nostdlib -fno-pic -fno-pie -fno-stack-protector -Wall -Wextra -O2 -g -I$(STAGE3_C_INCLUDE)
LDFLAGS_STAGE3 := -m elf_i386 -nostdlib

HATCH_DIR := $(BOOT_DIR)/boot/Hatch

build:
	@echo "Build bootloader"
	
	@mkdir -p $(BUILD_DIR)

	$(AS) stage1/stage1.asm -f bin -o $(BUILD_DIR)/stage1.bin
	$(AS) stage2/stage2.asm -f bin -o $(BUILD_DIR)/stage2.bin

	@echo " Build stage3"

	# Compile 32-bit C files
	@for f in $(STAGE3_C_SOURCES); do \
		fname=$$(basename $$f .c); \
		$(CC32) $(CFLAGS_STAGE3) -g -c $$f -o $(BUILD_DIR)/$$fname.o; \
	done

	# Assemble 32-bit ASM files
	@for f in $(STAGE3_AS_SOURCES); do \
		fname=$$(basename $$f .asm); \
		$(AS) -f elf32 -g -F dwarf $$f -o $(BUILD_DIR)/$$fname.o; \
	done
	
	# Link to an elf
	$(LD32) $(LDFLAGS_STAGE3) -T stage3/stage3.ld -o $(HATCH_DIR)/stage3.elf \
		$(STAGE3_OBJ_FILES)

	# Remove left over files
	rm -f $(STAGE3_OBJ_FILES)

debug: build
	@echo "Debug bootloader"

	$(AS) -f elf -g -F dwarf -DELF stage1/stage1.asm -o $(BUILD_DIR)/stage1.o
	$(LD32) -m elf_i386 -Ttext=0x7C00 -o $(BUILD_DIR)/stage1.elf $(BUILD_DIR)/stage1.o

	$(AS) -f elf -g -F dwarf -DELF stage2/stage2.asm -o $(BUILD_DIR)/stage2.o
	$(LD32) -m elf_i386 -Ttext=0x7E00 -o $(BUILD_DIR)/stage2.elf $(BUILD_DIR)/stage2.o

	rm -f $(BUILD_DIR)/stage1.o
	rm -f $(BUILD_DIR)/stage2.o

clean:
	@echo "Clean bootloader"

	rm -f $(BUILD_DIR)/stage1.elf
	rm -f $(BUILD_DIR)/stage1.bin

	rm -f $(BUILD_DIR)/stage2.elf
	rm -f $(BUILD_DIR)/stage2.bin

	rm -f $(HATCH_DIR)/stage3.elf 
