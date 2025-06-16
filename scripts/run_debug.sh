#!/bin/bash
set -e

IMG="build/image/waddle.img"
STAGE1=build/output/bootloaders/stage1.elf
STAGE2=build/output/bootloaders/stage2.elf
STAGE3=build/output/bootloaders/stage3.elf
KERNEL=build/output/kernel/kernel.elf

# Start QEMU paused with HDD image
qemu-system-i386 \
  -drive file="$IMG",format=raw,index=0,if=ide \
  -m 32M -boot c -s -S &

sleep 1

sudo -E gdb \
    -ex "set architecture i8086" \
    -ex "target remote localhost:1234" \
    -ex "add-symbol-file $STAGE1 0x7C00" \
    -ex "add-symbol-file $STAGE2 0x7E00" \
    -ex "break *abc" \
    -ex "continue"
