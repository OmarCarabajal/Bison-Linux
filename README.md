# BISON LINUX

Distro basada en Arch Linux con Xfce.

## Qué es

- Base: Arch Linux
- Entorno: XFCE mínimo.
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
bison-live
```
Particionamiento
Tres modos.

Automático

- EFI/BIOS / swap / root / home

Guiado

- EFI/BIOS / swap / root / home

Experto

- Con cfdisk

Qué instala  
base, linux, linux-firmware  
networkmanager, grub, efibootmgr si UEFI  
xorg, xfce4, firefox.

Para instalar el gestor de energía:
- sudo pacman -S xfce4-power-manager

Para instalar un visor de imágenes:
- sudo pacman -S ristretto

Configuración de zona horaria:
- sudo timedatectl set-timezone Contoinente/País/Ciudad
- sudo timedatectl set-ntp true
- sudo hwclock --systohc

## Capturas

### 01 - Boot
![Boot](docs/images/01-boot.png)

### 02 - Login
![Login](docs/images/02-login.png)

### 03 - Escritorio
![Escritorio](docs/images/03-escritorio.png)

### 04 - Menú
![Menú](docs/images/04-menu.png)

### 05 - Thunar
![Thunar](docs/images/05-thunar.png)


Licencia GPL-3.0

---

Omar Carabajal - Sector 0  
Daireaux, Argentina - Buenos Aires  
15 de Noviembre 2026