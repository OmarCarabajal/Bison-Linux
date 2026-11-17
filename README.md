# BISON LINUX

Sistema base Arch. XFCE mínimo.

## Qué es

- Base: Arch Linux
- Entorno: XFCE mínimo
- Instalador: `bison-install` - TUI con `dialog`
- Objetivo: sistema limpio, rápido.
- Enfoque: programación

## Requisitos

- CPU 64-bit
- UEFI o Legacy
- 2 GB RAM mínimo
- 30 GB disco mínimo
- Conexión a red durante la instalación

## Instalación

Booteá el ISO. Ejecutá:

```bash
bison-install

```
Particionamiento
Tres modos.

1. Automático
Crea:

EFI - 512M - solo si elegís UEFI
swap - opcional, tamaño a elección
root - resto del disco
home - opcional, tamaño a elección

2. Guiado
Elegís el disco. Elegís tamaños.

EFI / swap / root / home

3. Experto
cfdisk directo. Particiona el usuario.

Qué instala
base, linux, linux-firmware
networkmanager, grub, efibootmgr si UEFI
xorg, xfce4 mínimo.
firefox

Licencia
GPL-3.0

---

Omar Carabajal - Sector 0
Daireaux, Argentina - Buenos Aires
15 de Noviembre 2026