.PHONY: all build debug clean 

CWD := $(shell pwd)
BUILD_DIR := $(CWD)/build/output
BOOT_DIR := $(CWD)/osdir/boot_fat
ROOT_DIR := $(CWD)/osdir/root_undefined

CC64 := x86_64-elf-gcc
CC32 := i686-elf-gcc
LD64 := x86_64-elf-ld
LD32 := i686-elf-ld
OBJCOPY32 := i686-elf-objcopy
OBJCOPY64 := x86_64-elf-objcopy
AS := nasm

all: build


	
build: 
	make -C src/bootloaders \
		BUILD_DIR=$(BUILD_DIR)/bootloaders \
		LD=$(LD32) LD32=$(LD32) LD64=$(LD64) AS=$(AS) CC32=$(CC32) CC64=$(CC64) \
		ROOT_DIR=$(ROOT_DIR), BOOT_DIR=$(BOOT_DIR) OBJCOPY32=$(OBJCOPY32) OBJCOPY64=$(OBJCOPY64)
		
	make -C src/kernel \
		BUILD_DIR=$(BUILD_DIR)/kernel \
		LD32=$(LD32) LD64=$(LD64) AS=$(AS) CC32=$(CC32) CC64=$(CC64) \
		ROOT_DIR=$(ROOT_DIR), BOOT_DIR=$(BOOT_DIR) OBJCOPY32=$(OBJCOPY32) OBJCOPY64=$(OBJCOPY64)

	make -C src/libk \
		BUILD_DIR=$(BUILD_DIR)/libk \
		LD32=$(LD32) LD64=$(LD64) AS=$(AS) CC32=$(CC32) CC64=$(CC64) \
		ROOT_DIR=$(ROOT_DIR), BOOT_DIR=$(BOOT_DIR) OBJCOPY32=$(OBJCOPY32) OBJCOPY64=$(OBJCOPY64)


	./scripts/setup_image.sh
	./scripts/run_qemu.sh

debug:
	make -C src/bootloaders debug \
		BUILD_DIR=$(BUILD_DIR)/bootloaders \
		LD32=$(LD32) LD64=$(LD64) AS=$(AS) CC32=$(CC32) CC64=$(CC64) \
		ROOT_DIR=$(ROOT_DIR), BOOT_DIR=$(BOOT_DIR) OBJCOPY32=$(OBJCOPY32) OBJCOPY64=$(OBJCOPY64)

	make -C src/kernel      debug \
		BUILD_DIR=$(BUILD_DIR)/kernel \
		LD32=$(LD32) LD64=$(LD64) AS=$(AS) CC32=$(CC32) CC64=$(CC64) \
		ROOT_DIR=$(ROOT_DIR), BOOT_DIR=$(BOOT_DIR) OBJCOPY32=$(OBJCOPY32) OBJCOPY64=$(OBJCOPY64)

	make -C src/libk        debug \
		BUILD_DIR=$(BUILD_DIR)/libk \
		LD32=$(LD32) LD64=$(LD64) AS=$(AS) CC32=$(CC32) CC64=$(CC64)\
		ROOT_DIR=$(ROOT_DIR), BOOT_DIR=$(BOOT_DIR) OBJCOPY32=$(OBJCOPY32) OBJCOPY64=$(OBJCOPY64)


	./scripts/setup_image.sh
	./scripts/run_debug.sh

clean: 	

	make -C src/bootloaders clean BUILD_DIR=$(BUILD_DIR)/bootloaders
	make -C src/kernel      clean BUILD_DIR=$(BUILD_DIR)/kernel
	make -C src/libk        clean BUILD_DIR=$(BUILD_DIR)/libk

	find . -name ".gdb_history" -exec rm -rf {} +
	
	find ./build -type f -name "*.img" -delete


