# Dependencias de build en el host
set -euo pipefail
sudo pacman -Syu --noconfirm --overwrite '*' reflector archiso gnupg grub dosfstools mtools
sudo reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
sudo pacman -Syu --noconfirm --overwrite '*'

# Key que necesitás para firmar / validar
sudo pacman-key --init
sudo pacman-key --recv-keys E35979B896E997256457C632F57D4F59BD3DF454
sudo pacman-key --lsign-key E35979B896E997256457C632F57D4F59BD3DF454