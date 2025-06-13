.PHONY: all build clean

all: build

NASM = nasm
LD = ld

build:
	@echo "Build bootloader"
	@mkdir -p $(BUILD_DIR)
	nasm ./stage1.asm -f bin -o $(BUILD_DIR)/stage1.bin
	nasm ./stage2.asm -f bin -o $(BUILD_DIR)/stage2.bin

debug: build
	@echo "Debug bootloader"

	nasm -f elf -g -F dwarf -DELF stage1.asm -o $(BUILD_DIR)/stage1.o
	ld -m elf_i386 -Ttext=0x7C00 -o $(BUILD_DIR)/stage1.elf $(BUILD_DIR)/stage1.o

	nasm -f elf -g -F dwarf -DELF stage2.asm -o $(BUILD_DIR)/stage2.o
	ld -m elf_i386 -Ttext=0x7E00 -o $(BUILD_DIR)/stage2.elf $(BUILD_DIR)/stage2.o

clean:
	@echo "Clean bootloader"

	rm -f $(BUILD_DIR)/stage1.o
	rm -f $(BUILD_DIR)/stage1.elf

	rm -f $(BUILD_DIR)/stage2.o
	rm -f $(BUILD_DIR)/stage2.elf

	rm -f $(BUILD_DIR)/stage1.bin
	rm -f $(BUILD_DIR)/stage2.bin