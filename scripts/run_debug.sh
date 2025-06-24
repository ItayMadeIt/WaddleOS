#!/bin/bash
set -e

IMG="build/image/waddle.img"
STAGE1=build/output/bootloaders/stage1.elf
STAGE2=build/output/bootloaders/stage2.elf
STAGE3=osdir/boot_fat/boot/Hatch/stage3.elf
KERNEL=osdir/boot_fat/boot/Hatch/kernel.elf

# Start QEMU paused with HDD image
qemu-system-x86_64 \
  -drive file="$IMG",format=raw,index=0,if=ide \
  -m 32M -boot c -s -S &

sleep 1

TEXT_VADDR=$(nm $KERNEL | grep ' text_entry_virt' | awk '{print $1}')

sudo -E gdb \
    -ex "set architecture i386:x86-64:intel" \
    -ex "target remote localhost:1234" \
    -ex "file $KERNEL" \
    -ex "add-symbol-file $KERNEL 0x$TEXT_VADDR" \
    -ex "break *boot_main" \
    -ex "continue"
