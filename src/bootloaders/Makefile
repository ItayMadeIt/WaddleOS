.PHONY: all build clean

all: build

CFLAGS_STAGE3 := -m32 -ffreestanding -nostdlib -fno-pic -fno-pie -fno-stack-protector -Wall -Wextra -O2
LDFLAGS_STAGE3 := -m elf_i386 -nostdlib

HATCH_DIR := $(BOOT_DIR)/boot/Hatch

build:
	@echo "Build bootloader"
	
	@mkdir -p $(BUILD_DIR)

	$(AS) stage1/stage1.asm -f bin -o $(BUILD_DIR)/stage1.bin
	$(AS) stage2/stage2.asm -f bin -o $(BUILD_DIR)/stage2.bin

	@echo " Build stage3"

	# Compile 32-bit C paging setup
	$(CC32) $(CFLAGS_STAGE3) -g -c stage3/stage3_paging.c -o $(BUILD_DIR)/stage3_paging.o

	# Assemble 32-bit ASM long mode entry
	$(AS) -f elf32 -g -F dwarf stage3/stage3_entry.asm -o $(BUILD_DIR)/stage3_entry.o

	# Link to an elf
	$(LD32) $(LDFLAGS_STAGE3) -T stage3/stage3.ld -o $(BUILD_DIR)/stage3.elf \
		$(BUILD_DIR)/stage3_entry.o \
		$(BUILD_DIR)/stage3_paging.o

	# Objcpy elf to bin
	$(OBJCOPY32) -O binary $(BUILD_DIR)/stage3.elf $(HATCH_DIR)/stage3.bin

	# Remove left over files
	rm -f $(BUILD_DIR)/stage3_paging.o
	rm -f $(BUILD_DIR)/stage3_entry.o

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

	rm -f $(BUILD_DIR)/stage3.elf 
	rm -f $(HATCH_DIR)/stage3.bin
