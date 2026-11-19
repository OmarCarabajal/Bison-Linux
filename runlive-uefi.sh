#!/bin/bash
# Archivo: runlive-uefi.sh
# Autor: Omar Carabajal
# Fecha: 8/11/2026
# Corre el live modo uefi

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.
# Bootea el live de BISON en UEFI en QEMU

# borrar el test viejo
rm -f ./bison-test-disk.qcow2

ISO=$(ls -t out/*.iso | head -n 1)
qemu-img create -f qcow2 ./bison-test-disk.qcow2 28G 2>/dev/null || true
cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd /tmp/OVMF_VARS.fd
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -drive file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
  -drive file=/tmp/OVMF_VARS.fd,if=pflash,format=raw,unit=1 \
  -cdrom "$ISO" \
  -boot d \
  -drive file=./bison-test-disk.qcow2,if=virtio,format=qcow2 \
  -display gtk