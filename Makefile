.PHONY: all build debug clean 

CWD := $(shell pwd)
BUILD_DIR := $(CWD)/build/output

all: build

	
build: 
	make -C src/bootloaders BUILD_DIR=$(BUILD_DIR)/bootloaders
	make -C src/kernel      BUILD_DIR=$(BUILD_DIR)/kernel
	make -C src/libk        BUILD_DIR=$(BUILD_DIR)/libk

	./scripts/setup_image.sh
	./scripts/run_qemu.sh

debug:
	make -C src/bootloaders debug BUILD_DIR=$(BUILD_DIR)/bootloaders
	make -C src/kernel      debug BUILD_DIR=$(BUILD_DIR)/kernel
	make -C src/libk        debug BUILD_DIR=$(BUILD_DIR)/libk

	./scripts/setup_image.sh
	./scripts/run_debug.sh

clean: 	

	make -C src/bootloaders clean BUILD_DIR=$(BUILD_DIR)/bootloaders
	make -C src/kernel      clean BUILD_DIR=$(BUILD_DIR)/bootloaders
	make -C src/libk        clean BUILD_DIR=$(BUILD_DIR)/bootloaders

	find . -name ".gdb_history" -exec rm -rf {} +
	
	find ./build -type f -name "*.img" -delete


