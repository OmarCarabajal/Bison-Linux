#!/bin/bash
# Bootea el live de BISON en BIOS en QEMU

# borrar el test viejo
rm -f ./bison-test-disk.qcow2

ISO=$(ls -t out/*.iso | head -n 1)
qemu-img create -f qcow2 ./bison-test-disk.qcow2 28G 2>/dev/null || true
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -cdrom "$ISO" \
  -boot d \
  -drive file=./bison-test-disk.qcow2,if=virtio,format=qcow2 \
  -display gtk
