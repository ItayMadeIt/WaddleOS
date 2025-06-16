.PHONY: all build debug clean 

ARCH_DIR := arch/x86_64
CORE_DIR := core

CFLAGS64 := -m64 -ffreestanding -O2 -Wall -Wextra

LDFLAGS := -nostdlib -T $(ARCH_DIR)/linker.ld

HATCH_DIR := $(BOOT_DIR)/boot/Hatch
KERNEL_OUT := $(HATCH_DIR)/kernel.elf

all: build
	
build: 
	@echo "Build kernel"
	@mkdir -p $(BUILD_DIR)

	# Assemble entry points
	$(AS) -f elf64 $(ARCH_DIR)/entry/boot_entry.asm -o $(BUILD_DIR)/boot_entry.o

	# Compile 64-bit setup C code and kernel
	$(CC64) $(CFLAGS64) -c $(ARCH_DIR)/setup/boot_setup.c -o $(BUILD_DIR)/boot_setup.o
	$(CC64) $(CFLAGS64) -c $(CORE_DIR)/kernel.c -o $(BUILD_DIR)/kernel.o

	# Link final kernel ELF
	$(LD) $(LDFLAGS) -o $(KERNEL_OUT) \
		$(BUILD_DIR)/boot_entry.o \
		$(BUILD_DIR)/boot_setup.o \
		$(BUILD_DIR)/kernel.o
	
	rm -r $(BUILD_DIR)/boot_entry.o
	rm -r $(BUILD_DIR)/boot_setup.o
	rm -r $(BUILD_DIR)/kernel.o

debug: 
	@echo "Debug kernel"

clean: 	
	@echo "Clean kernel"
	rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
