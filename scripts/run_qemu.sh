#!/bin/bash
set -e

IMAGE_PATH="$(pwd)/build/image/waddle.img"

qemu-system-x86_64 \
  -drive format=raw,file="$IMAGE_PATH" \
  -m 512M \
  -boot order=a \
  -serial stdio \
  -no-reboot \
  -no-shutdown
