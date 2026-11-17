#!/bin/bash
# Bootea el disco instalado.

MODO=${1:-bios}
DISK=./bison-test-disk.qcow2

if [ "$MODO" = "uefi" ]; then
  cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd /tmp/OVMF_VARS.fd
  qemu-system-x86_64 \
    -enable-kvm \
    -m 2048 \
    -drive file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
    -drive file=/tmp/OVMF_VARS.fd,if=pflash,format=raw,unit=1 \
    -drive file=$DISK,if=virtio,format=qcow2 \
    -boot c \
    -display gtk
else
  qemu-system-x86_64 \
    -enable-kvm \
    -m 2048 \
    -drive file=$DISK,if=virtio,format=qcow2 \
    -boot c \
    -display gtk
fi
