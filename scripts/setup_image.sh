#!/bin/bash
set -e

# === Config ===
BUILD_DIR="$(pwd)/build/output"
BUILD_IMG_DIR="$(pwd)/build/image"
OSDIR_DIR="$(pwd)/osdir"
BOOTLOADERS_DIR="$BUILD_DIR/bootloaders"

STAGE1="$BOOTLOADERS_DIR/stage1.bin"
STAGE1_5="$BOOTLOADERS_DIR/stage1_5.bin"

IMAGE="$BUILD_DIR/image/waddle.img"
BOOT_IMAGE="$BUILD_DIR/image/fat.img"

TOTAL_SIZE_MB=64   # Total image size
FAT_SIZE_MB=32     # FAT partition size

# === Clean old image ===
rm -f "$IMAGE" "$BOOT_IMAGE"
mkdir -p "$(dirname "$IMAGE")"

# === Create base image ===
dd if=/dev/zero of="$IMAGE" bs=1M count=$TOTAL_SIZE_MB

# === Create MBR and first partition with parted ===
parted --script "$IMAGE" \
  mklabel msdos \
  mkpart primary fat32 1MiB "$((1 + FAT_SIZE_MB))"MiB \
  set 1 boot on

# === Write Stage 1 to MBR ===
dd if="$STAGE1" of="$IMAGE" bs=446 count=1 conv=notrunc

# === Write Stage 1.5 (64 KiB max) to sectors 1–127 ===
dd if="$STAGE1_5" of="$IMAGE" bs=512 seek=1 conv=notrunc

# === Create FAT image ===
dd if=/dev/zero of="$BOOT_IMAGE" bs=1M count=$FAT_SIZE_MB
mkfs.vfat -F 16 "$BOOT_IMAGE"

# === Mount FAT and copy files ===
MOUNT_DIR="$(mktemp -d)"
sudo mount "$BOOT_IMAGE" "$MOUNT_DIR"

# Copy stage2, kernel, etc.
sudo cp "$OSDIR_DIR/boot_fat/"* "$MOUNT_DIR/"
sync
sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

# === Embed FAT image into main image at sector 2048 ===
# 2048 sectors * 512 = 1 MiB offset
dd if="$BOOT_IMAGE" of="$IMAGE" bs=512 seek=2048 conv=notrunc

echo "Image created at: $IMAGE"

cp $IMAGE $BUILD_IMG_DIR
