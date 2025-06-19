#!/bin/bash
set -e

IMG="build/image/waddle.img"
STAGE1=build/output/bootloaders/stage1.elf
STAGE2=build/output/bootloaders/stage2.elf
STAGE3=osdir/boot_fat/boot/Hatch/stage3.elf
KERNEL=osdir/boot_fat/boot/Hatch/kernel.elf

# Start QEMU paused with HDD image
qemu-system-i386 \
  -drive file="$IMG",format=raw,index=0,if=ide \
  -m 32M -boot c -s -S &

sleep 1

sudo -E gdb \
    -ex "set architecture i386:intel" \
    -ex "target remote localhost:1234" \
    -ex "file $STAGE3" \
    -ex "add-symbol-file $STAGE3 &text_entry" \
    -ex "break *stage3_main" \
    -ex "continue"
