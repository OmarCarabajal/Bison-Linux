#!/bin/bash
# Archivo: runlive-bios.sh
# Autor: Omar Carabajal
# Fecha: 8/11/2026
# Corre el live modo bios

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.
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
