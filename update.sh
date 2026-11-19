#!/bin/bash
# Archivo: update.sh
# Autor: Omar Carabajal
# Fecha: 8/11/2026
# Actuializa el host para el build

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.

# Dependencias de build en el host
set -euo pipefail
sudo pacman -Syu --noconfirm --overwrite '*' reflector archiso gnupg grub dosfstools mtools
sudo reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
sudo pacman -Syu --noconfirm --overwrite '*'

# Key que necesaria para firmar / validar
sudo pacman-key --init
sudo pacman-key --recv-keys E35979B896E997256457C632F57D4F59BD3DF454
sudo pacman-key --lsign-key E35979B896E997256457C632F57D4F59BD3DF454