.PHONY: all build clean

all: build

build:
	@echo "Build bootloader"
	@mkdir -p $(BUILD_DIR)
	nasm stage1.asm   -f bin -o $(BUILD_DIR)/stage1.bin
	nasm stage1_5.asm -f bin -o $(BUILD_DIR)/stage1_5.bin
	nasm stage2.asm   -f bin -o $(BUILD_DIR)/stage2.bin

clean:
	@echo "Clean bootloader"
	rm -f BUILD_DIR=$(BUILD_DIR)/stage1.bin
	rm -f BUILD_DIR=$(BUILD_DIR)/stage1_5.bin
	rm -f BUILD_DIR=$(BUILD_DIR)/stage2.bin