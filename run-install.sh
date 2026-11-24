#!/bin/bash
# Archivo: run-install.sh
# Autor: Omar Carabajal
# Fecha: 8/11/2026
# Bootea el disco instalado (args: bios/uefi)

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.

MODO=${1:-bios}
DISK=./bison-test-disk.qcow2

if [ "$MODO" = "uefi" ]; then
  cp /usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
  qemu-system-x86_64 \
    -enable-kvm -m 2048 -machine q35 \
    -enable-kvm \
    -m 2048 \
    -drive file=/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd,if=pflash,format=raw,unit=0,readonly=on \
    -drive file=/tmp/OVMF_VARS.fd,if=pflash,format=raw,unit=1 \
    -drive file=$DISK,if=virtio,format=qcow2 \
    -boot c \
    -audiodev pa,id=snd0 \
    -device intel-hda \
    -device hda-output,audiodev=snd0 \
    -display gtk
else
  qemu-system-x86_64 \
    -enable-kvm \
    -m 2048 \
    -drive file=$DISK,if=virtio,format=qcow2 \
    -boot order=c,menu=on \
    -audiodev pa,id=snd0 \
    -device intel-hda \
    -device hda-output,audiodev=snd0 \
    -display gtk
fi
