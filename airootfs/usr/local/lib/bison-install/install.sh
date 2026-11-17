#!/bin/bash
# BISON - Instalación del sistema

instalar_sistema() {
  rm -f /tmp/bison-grub-failed /tmp/bison-install-grub.log /tmp/bison-pacstrap-failed /tmp/bison-verify-failed /tmp/bison-verify.log

  # Detección de red
  if ! ping -c 1 -W 7 8.8.8.8 &>/dev/null || ! getent hosts archlinux.org >/dev/null 2>&1; then
    dialog --clear --title " Sin red " --yesno "No hay conexión a internet.\n\n" 10 70
    if [ $? -eq 0 ]; then
      systemctl start NetworkManager 2>/dev/null || true
      sleep 2
      nmtui
      sleep 5
      if ! ping -c 1 -W 7 8.8.8.8 &>/dev/null || ! getent hosts archlinux.org >/dev/null 2>&1; then
        dialog --clear --title " Sin red " --msgbox "Sigue sin conexuón a internet." 8 60
        return 1
      fi
    else
      return 1
    fi
  fi

  (
    echo "XXX"; echo 5; echo "Detectando UEFI / BIOS..."; echo "XXX"
    sleep 1

    # Si booteo en UEFI Partición 2, ES_UEFI=1 aunque MODO_FIRMWARE sea legacy
    if [ -d /sys/firmware/efi ]; then
      ES_UEFI=1
    elif [ "$MODO_FIRMWARE" = "uefi" ]; then
      ES_UEFI=1
    else
      ES_UEFI=0
    fi
    echo "XXX"; echo 15; echo "Particionando $DISCO..."; echo "XXX"
    if [ "$MODO_PART" = "guided" ]; then
  # Guided: crear las particiones con los tamaños que eligió el usuario
  wipefs -a "$DISCO" 2>/dev/null
  if [ "$ES_UEFI" -eq 1 ]; then
    # GPT + EFI + ROOT + HOME + SWAP según lo que eligió
    if [ "$GUIDED_SWAP_GB" != "0" ] && [ "$GUIDED_HOME_GB" != "0" ]; then
      printf "label: gpt\n,${GUIDED_EFI_MB}M,U\n,${GUIDED_ROOT_GB}G,L\n,${GUIDED_HOME_GB}G,L\n,${GUIDED_SWAP_GB}G,S\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_EFI="${DISCO}1"
      PART_ROOT="${DISCO}2"
      PART_HOME_MANUAL="${DISCO}3"
      PART_SWAP_MANUAL="${DISCO}4"
      [[ "$DISCO" == *"nvme"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2" && PART_HOME_MANUAL="${DISCO}p3" && PART_SWAP_MANUAL="${DISCO}p4"
      [[ "$DISCO" == *"mmcblk"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2" && PART_HOME_MANUAL="${DISCO}p3" && PART_SWAP_MANUAL="${DISCO}p4"
    elif [ "$GUIDED_SWAP_GB" != "0" ]; then
      printf "label: gpt\n,${GUIDED_EFI_MB}M,U\n,${GUIDED_ROOT_GB}G,L\n,${GUIDED_SWAP_GB}G,S\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_EFI="${DISCO}1"
      PART_ROOT="${DISCO}2"
      PART_SWAP_MANUAL="${DISCO}3"
      [[ "$DISCO" == *"nvme"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2" && PART_SWAP_MANUAL="${DISCO}p3"
      [[ "$DISCO" == *"mmcblk"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2" && PART_SWAP_MANUAL="${DISCO}p3"
    elif [ "$GUIDED_HOME_GB" != "0" ]; then
      printf "label: gpt\n,${GUIDED_EFI_MB}M,U\n,${GUIDED_ROOT_GB}G,L\n,${GUIDED_HOME_GB}G,L\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_EFI="${DISCO}1"
      PART_ROOT="${DISCO}2"
      PART_HOME_MANUAL="${DISCO}3"
      [[ "$DISCO" == *"nvme"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2" && PART_HOME_MANUAL="${DISCO}p3"
      [[ "$DISCO" == *"mmcblk"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2" && PART_HOME_MANUAL="${DISCO}p3"
    else
      printf "label: gpt\n,${GUIDED_EFI_MB}M,U\n,,L\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_EFI="${DISCO}1"
      PART_ROOT="${DISCO}2"
      [[ "$DISCO" == *"nvme"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2"
      [[ "$DISCO" == *"mmcblk"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2"
    fi
    [ -n "$PART_EFI" ] && mkfs.fat -F32 "$PART_EFI" >/dev/null 2>&1
  else
    # Legacy MBR - BIOS: /boot adentro de ROOT, sin EFI
    if [ "$GUIDED_SWAP_GB" != "0" ] && [ "$GUIDED_HOME_GB" != "0" ]; then
      printf "label: dos\n,${GUIDED_ROOT_GB}G,L,*\n,${GUIDED_HOME_GB}G,L\n,${GUIDED_SWAP_GB}G,S\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_ROOT="${DISCO}1"
      PART_HOME_MANUAL="${DISCO}2"
      PART_SWAP_MANUAL="${DISCO}3"
    elif [ "$GUIDED_SWAP_GB" != "0" ]; then
      printf "label: dos\n,${GUIDED_ROOT_GB}G,L,*\n,${GUIDED_SWAP_GB}G,S\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_ROOT="${DISCO}1"
      PART_SWAP_MANUAL="${DISCO}2"
    elif [ "$GUIDED_HOME_GB" != "0" ]; then
      printf "label: dos\n,${GUIDED_ROOT_GB}G,L,*\n,${GUIDED_HOME_GB}G,L\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_ROOT="${DISCO}1"
      PART_HOME_MANUAL="${DISCO}2"
    else
      printf "label: dos\n,,L,*\n" | sfdisk "$DISCO" >/dev/null 2>&1
      PART_ROOT="${DISCO}1"
    fi
    # nvme/mmcblk también en BIOS
    [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]] && PART_ROOT="${DISCO}p1"
    if [ -n "$PART_HOME_MANUAL" ]; then
      [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]] && PART_HOME_MANUAL="${DISCO}p2"
    fi
    if [ -n "$PART_SWAP_MANUAL" ]; then
      # Si hay HOME, SWAP es p3, si no, p2
      if [ -n "$PART_HOME_MANUAL" ]; then
        [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]] && PART_SWAP_MANUAL="${DISCO}p3"
      else
        [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]] && PART_SWAP_MANUAL="${DISCO}p2"
      fi
    fi
  fi
  elif [ "$MODO_PART" = "manual" ]; then
  PART_ROOT="$PART_ROOT_MANUAL"
  PART_EFI="$PART_EFI_MANUAL"
  [ -n "$PART_EFI" ] && mkfs.fat -F32 "$PART_EFI" >/dev/null 2>&1
    else
      wipefs -a "$DISCO" 2>/dev/null
      if [ "$ES_UEFI" -eq 1 ]; then
        if [ "$AUTO_QUIERE_SWAP" = "si" ]; then
          printf "label: gpt\n,512M,U\n,${AUTO_SWAP_GB}G,S\n,,L\n" | sfdisk "$DISCO" >/dev/null 2>&1
          PART_EFI="${DISCO}1"
          PART_ROOT="${DISCO}3"
          PART_SWAP_MANUAL="${DISCO}2"
          [[ "$DISCO" == *"nvme"* ]] && PART_EFI="${DISCO}p1" && PART_SWAP_MANUAL="${DISCO}p2" && PART_ROOT="${DISCO}p3"
          [[ "$DISCO" == *"mmcblk"* ]] && PART_EFI="${DISCO}p1" && PART_SWAP_MANUAL="${DISCO}p2" && PART_ROOT="${DISCO}p3"
          mkfs.fat -F32 "$PART_EFI" >/dev/null 2>&1
        else
          printf "label: gpt\n,512M,U\n,,L\n" | sfdisk "$DISCO" >/dev/null 2>&1
          PART_EFI="${DISCO}1"
          PART_ROOT="${DISCO}2"
          [[ "$DISCO" == *"nvme"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2"
          [[ "$DISCO" == *"mmcblk"* ]] && PART_EFI="${DISCO}p1" && PART_ROOT="${DISCO}p2"
          mkfs.fat -F32 "$PART_EFI" >/dev/null 2>&1
        fi
      else
        if [ "$AUTO_QUIERE_SWAP" = "si" ]; then
          printf "label: dos\n,${AUTO_SWAP_GB}G,S\n,,L,*\n" | sfdisk "$DISCO" >/dev/null 2>&1
          PART_ROOT="${DISCO}2"
          PART_SWAP_MANUAL="${DISCO}1"
          [[ "$DISCO" == *"nvme"* ]] && PART_ROOT="${DISCO}p2" && PART_SWAP_MANUAL="${DISCO}p1"
          [[ "$DISCO" == *"mmcblk"* ]] && PART_ROOT="${DISCO}p2" && PART_SWAP_MANUAL="${DISCO}p1"
        else
          printf "label: dos\n,,L,*\n" | sfdisk "$DISCO" >/dev/null 2>&1
          PART_ROOT="${DISCO}1"
          [[ "$DISCO" == *"nvme"* ]] && PART_ROOT="${DISCO}p1"
          [[ "$DISCO" == *"mmcblk"* ]] && PART_ROOT="${DISCO}p1"
        fi
      fi
    fi
    echo "XXX"; echo 30; echo "Formateando..."; echo "XXX"
    mkfs.ext4 -F "$PART_ROOT" >/dev/null 2>&1
    mount -t ext4 "$PART_ROOT" /mnt
    if [ "$ES_UEFI" -eq 1 ] && [ -n "$PART_EFI" ]; then
      mkdir -p /mnt/boot/efi
      mkdir -p /mnt/boot/grub
      mount -t vfat "$PART_EFI" /mnt/boot/efi
    fi
    if [ -n "$PART_HOME_MANUAL" ]; then
      mkfs.ext4 -F "$PART_HOME_MANUAL" >/dev/null 2>&1
      mkdir -p /mnt/home
      mount -t ext4 "$PART_HOME_MANUAL" /mnt/home
    fi
    if [ -n "$PART_SWAP_MANUAL" ]; then
      mkswap "$PART_SWAP_MANUAL" >/dev/null 2>&1
      swapon "$PART_SWAP_MANUAL" 2>/dev/null || true
    fi
    # verificación antes de pacstrap
    echo "XXX"; echo 38; echo "Verificando particiones y montaje..."; echo "XXX"
    : > /tmp/bison-verify.log
    echo "DISCO=$DISCO PART_ROOT=$PART_ROOT PART_HOME=$PART_HOME_MANUAL PART_SWAP=$PART_SWAP_MANUAL ES_UEFI=$ES_UEFI" >> /tmp/bison-verify.log
    echo "--- lsblk ---" >> /tmp/bison-verify.log
    lsblk -f "$DISCO" >> /tmp/bison-verify.log 2>&1
    echo "--- sfdisk --verify ---" >> /tmp/bison-verify.log
    sfdisk --verify "$DISCO" >> /tmp/bison-verify.log 2>&1
    VERIFY_RC=$?
    echo "sfdisk --verify rc=$VERIFY_RC" >> /tmp/bison-verify.log
    echo "--- mount / df ---" >> /tmp/bison-verify.log
    mount | grep -E " /mnt|/mnt/" >> /tmp/bison-verify.log 2>&1
    df -h /mnt >> /tmp/bison-verify.log 2>&1
    # 1. PART_ROOT existe?
    if [ -z "$PART_ROOT" ] || [ ! -b "$PART_ROOT" ]; then
      echo "ERROR: PART_ROOT no existe o no es blockdev: $PART_ROOT" >> /tmp/bison-verify.log
      touch /tmp/bison-verify-failed
    fi
    # 2. sfdisk verify falló?
    if [ "$VERIFY_RC" -ne 0 ]; then
      echo "ERROR: sfdisk --verify falló" >> /tmp/bison-verify.log
      touch /tmp/bison-verify-failed
    fi
    # 3. /mnt montado?
    if ! mountpoint -q /mnt; then
      echo "ERROR: /mnt no está montado" >> /tmp/bison-verify.log
      touch /tmp/bison-verify-failed
    fi
    # 4. ¿Se puede escribir en /mnt?
    if mountpoint -q /mnt; then
      if ! touch /mnt/.bison-test 2>>/tmp/bison-verify.log; then
        echo "ERROR: no se puede escribir en /mnt" >> /tmp/bison-verify.log
        touch /tmp/bison-verify-failed
      else
        rm -f /mnt/.bison-test
      fi
      # 5. ¿Hay al menos 2G libres en /mnt para pacstrap?
      LIBRE_KB=$(df -k /mnt 2>/dev/null | tail -n 1 | awk '{print $4}')
      echo "Libre en /mnt: ${LIBRE_KB}K" >> /tmp/bison-verify.log
      if [ -n "$LIBRE_KB" ] && [ "$LIBRE_KB" -lt 2097152 ]; then
        echo "ERROR: menos de 2G libres en /mnt" >> /tmp/bison-verify.log
        touch /tmp/bison-verify-failed
      fi
    fi
    if [ -f /tmp/bison-verify-failed ]; then
      echo "XXX"; echo 100; echo "Verificación falló, abortando antes de pacstrap..."; echo "XXX"
      sleep 1
      exit 2
    fi

    # DNS real para pacstrap 
    mkdir -p /mnt/etc
    rm -f /mnt/etc/resolv.conf
    echo "nameserver 8.8.8.8" > /mnt/etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /mnt/etc/resolv.conf

    # instalar con pacstrap
    echo "XXX"; echo 45; echo "\nInstalando sistema base con pacstrap..."; echo "XXX"
    mapfile -t PKGS < <(grep -v "^#" /usr/share/bison/packages.x86_64 | grep -v "^$" | tr -d '\r')
    pacstrap -K /mnt "${PKGS[@]}" >/tmp/bison-pacstrap.log 2>&1
    PACSTRAP_RC=$?
    if [ $PACSTRAP_RC -ne 0 ] || [ ! -x /mnt/usr/bin/pacman ]; then
      echo "ERROR: pacstrap falló rc=$PACSTRAP_RC o falta /mnt/usr/bin/pacman" >> /tmp/bison-pacstrap.log
      touch /tmp/bison-pacstrap-failed
      touch /tmp/bison-grub-failed
      echo "XXX"; echo 100; echo "Falló pacstrap, abortando..."; echo "XXX"
      sleep 1
      exit 1
    fi
    arch-chroot /mnt systemctl enable lightdm.service >/dev/null 2>&1

    # Bison: copiar tema, iconos, fondo y defaults del live al instalado
    mkdir -p /mnt/usr/share/themes /mnt/usr/share/icons /mnt/usr/share/backgrounds /mnt/usr/share/bison-defaults
    cp -a /usr/share/themes/Space-dark /mnt/usr/share/themes/ 2>/dev/null
    cp -a /usr/share/icons/besgnulinux-labile-dark-blue /mnt/usr/share/icons/ 2>/dev/null
    cp -a /usr/share/icons/SC_Cursors_Terran_Blue /mnt/usr/share/icons/ 2>/dev/null
    cp -a /usr/share/backgrounds/bison /mnt/usr/share/backgrounds/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/usr/share/bison-defaults/ 2>/dev/null
    mkdir -p /mnt/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/ /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
    cp -a /usr/share/bison-defaults/*.xml /mnt/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null
    cp -a /etc/lightdm/lightdm-gtk-greeter.conf /mnt/etc/lightdm/lightdm-gtk-greeter.conf 2>/dev/null

    echo "XXX"; echo 70; echo "Generando fstab..."; echo "XXX"
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "XXX"; echo 80; echo "Configurando sistema..."; echo "XXX"
    echo "$HOSTNAME" > /mnt/etc/hostname
    echo "127.0.0.1 localhost" > /mnt/etc/hosts
    echo "::1 localhost" >> /mnt/etc/hosts
    echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /mnt/etc/hosts
    echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
    echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
    echo "es_AR.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    echo "LANG=es_AR.UTF-8" > /mnt/etc/locale.conf
    echo "root:$PASS_ROOT" | arch-chroot /mnt chpasswd 2>/dev/null
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USUARIO" 2>/dev/null
    
    # Copiar config de escritorio Bison del live al instalado
    cp -a /etc/skel/.config /mnt/etc/skel/ 2>/dev/null
    cp -a /etc/skel/.themes /mnt/etc/skel/ 2>/dev/null
    cp -a /etc/skel/.icons /mnt/etc/skel/ 2>/dev/null
    cp -a /etc/skel/.config /mnt/home/$USUARIO/ 2>/dev/null
    cp -a /etc/skel/.themes /mnt/home/$USUARIO/ 2>/dev/null
    cp -a /etc/skel/.icons /mnt/home/$USUARIO/ 2>/dev/null
    arch-chroot /mnt chown -R "$USUARIO:$USUARIO" "/home/$USUARIO/.config"\
     "/home/$USUARIO/.themes" "/home/$USUARIO/.icons" 2>/dev/null

    echo "$USUARIO:$PASS_USER" | arch-chroot /mnt chpasswd 2>/dev/null
    echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers
    echo "exec startxfce4" > /mnt/etc/skel/.xinitrc
    if [ -d "/mnt/home/$USUARIO" ]; then
      echo "exec startxfce4" > "/mnt/home/$USUARIO/.xinitrc"
      arch-chroot /mnt chown "$USUARIO:$USUARIO" "/home/$USUARIO/.xinitrc" 2>/dev/null
    fi
    cat > /mnt/etc/os-release <<'OSRELEASE'
NAME="BISON Linux"
PRETTY_NAME="BISON Linux 0.1"
ID=bison
ID_LIKE=arch
BUILD_ID=0.1
VERSION="0.1"
VERSION_ID="0.1"
HOME_URL="https://bisonlinux.org"
ANSI_COLOR="1;37"
LOGO="bison"
OSRELEASE
    arch-chroot /mnt locale-gen >/dev/null 2>&1
    arch-chroot /mnt mkinitcpio -P >/dev/null 2>&1
    echo "XXX"; echo 90; echo "Instalando bootloader..."; echo "XXX"
    GRUB_LOG="/tmp/bison-install-grub.log"
    : > "$GRUB_LOG"
    if [ -f /mnt/etc/default/grub ]; then
      sed -i 's/^GRUB_TERMINAL_INPUT=console/#GRUB_TERMINAL_INPUT=console/' /mnt/etc/default/grub
      sed -i 's/^GRUB_TERMINAL_OUTPUT=console/#GRUB_TERMINAL_OUTPUT=console/' /mnt/etc/default/grub
      sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=1024x768/' /mnt/etc/default/grub
      sed -i 's/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' /mnt/etc/default/grub
      grep -q "^GRUB_GFXMODE=" /mnt/etc/default/grub || echo "GRUB_GFXMODE=1024x768" >> /mnt/etc/default/grub
      grep -q "^GRUB_GFXPAYLOAD_LINUX=" /mnt/etc/default/grub || echo "GRUB_GFXPAYLOAD_LINUX=keep" >> /mnt/etc/default/grub
      
      # Meter Bison en grub
      sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Bison Linux"/' /mnt/etc/default/grub
      grep -q "^GRUB_DISTRIBUTOR=" /mnt/etc/default/grub || echo 'GRUB_DISTRIBUTOR="Bison Linux"' >> /mnt/etc/default/grub
    else
      echo "WARN: /mnt/etc/default/grub no existe, grub-mkconfig usará default" >> "$GRUB_LOG"
    fi

    # asegurar /boot/grub en BIOS y UEFI antes de grub-install
    echo "--- /mnt/boot antes de grub-install ---" >> "$GRUB_LOG"
    ls -ld /mnt/boot >> "$GRUB_LOG" 2>&1
    ls -la /mnt/boot/ >> "$GRUB_LOG" 2>&1
    df -h /mnt >> "$GRUB_LOG" 2>&1
    if [ ! -d /mnt/boot ]; then
      echo "WARN: /mnt/boot no es directorio, recreando" >> "$GRUB_LOG"
      rm -f /mnt/boot
      mkdir -p /mnt/boot/grub
    fi
    mount -o remount,rw /mnt 2>>"$GRUB_LOG"
    mkdir -p /mnt/boot/grub 2>>"$GRUB_LOG"
    ls -ld /mnt/boot/grub >> "$GRUB_LOG" 2>&1
    if [ ! -d /mnt/boot/grub ]; then
      echo "ERROR: no se pudo crear /mnt/boot/grub" >> "$GRUB_LOG"
      touch /tmp/bison-grub-failed
    fi
    if [ -f /usr/share/bison/splash.png ]; then
      mkdir -p /mnt/boot/grub
      cp /usr/share/bison/splash.png /mnt/boot/grub/splash.png
      if [ -f /mnt/etc/default/grub ]; then
        if grep -q "^GRUB_BACKGROUND=" /mnt/etc/default/grub; then
          sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/splash.png"|' /mnt/etc/default/grub
        elif grep -q "^#GRUB_BACKGROUND=" /mnt/etc/default/grub; then
          sed -i 's|^#GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/splash.png"|' /mnt/etc/default/grub
        else
          echo 'GRUB_BACKGROUND="/boot/grub/splash.png"' >> /mnt/etc/default/grub
        fi
      fi
    else
      echo "WARN: /usr/share/bison/splash.png no existe, GRUB sin fondo" >> "$GRUB_LOG"
    fi
    if [ "$ES_UEFI" -eq 1 ]; then
      mkdir -p /mnt/boot/efi /mnt/boot/grub
      if ! mountpoint -q /mnt/boot/efi; then
        echo "ERROR: /boot/efi no está montado" >> "$GRUB_LOG"
        touch /tmp/bison-grub-failed
      fi
      if [ ! -f /tmp/bison-grub-failed ]; then
        if ! arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=BISON --removable --recheck >> "$GRUB_LOG" 2>&1; then
          echo "ERROR: grub-install UEFI falló" >> "$GRUB_LOG"
          touch /tmp/bison-grub-failed
        fi
      fi
    else
      # BIOS: /boot adentro de ROOT, sin EFI
      if [ ! -f /tmp/bison-grub-failed ]; then
        if ! arch-chroot /mnt grub-install --target=i386-pc --boot-directory=/boot --recheck "$DISCO" >> "$GRUB_LOG" 2>&1; then
          echo "ERROR: grub-install Legacy falló" >> "$GRUB_LOG"
          touch /tmp/bison-grub-failed
        fi
      fi
    fi
    if [ ! -f /tmp/bison-grub-failed ]; then
      if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> "$GRUB_LOG" 2>&1; then
        echo "ERROR: grub-mkconfig falló" >> "$GRUB_LOG"
        touch /tmp/bison-grub-failed
      fi
    fi
    arch-chroot /mnt systemctl enable NetworkManager >/dev/null 2>&1
    if [ -f /mnt/usr/bin/lightdm ]; then
      arch-chroot /mnt systemctl enable lightdm >/dev/null 2>&1
    fi
    echo "XXX"; echo 100; echo "Listo!"; echo "XXX"
    sleep 1
  ) | dialog --clear --title " Instalando Bison Linux... " --gauge "Preparando..." 10 70 0

  if [ -f /tmp/bison-verify-failed ]; then
    if mountpoint -q /mnt; then
      umount -R /mnt 2>/dev/null
    fi
    dialog --clear --title " ERROR: Verificación antes de pacstrap " --ok-label "Ok" --msgbox "Falló la verificación de particiones/montaje.\n\nNo se ejecutó pacstrap.\n\nDisco: $DISCO\nLog: /tmp/bison-verify.log\n\nÚltimas líneas:\n$(tail -n 25 /tmp/bison-verify.log 2>/dev/null)" 20 75
    volver_al_menu
    return
  fi

  if [ -f /tmp/bison-pacstrap-failed ]; then
    if mountpoint -q /mnt; then
      umount -R /mnt 2>/dev/null
    fi
    dialog --clear --title " ERROR: pacstrap " --ok-label "Ok" --msgbox "Falló pacstrap. No se instaló nada en $DISCO.\n\nLog: /tmp/bison-pacstrap.log\n\nÚltimas líneas:\n$(tail -n 20 /tmp/bison-pacstrap.log 2>/dev/null)" 20 75
    volver_al_menu
    return
  fi

  if [ -f /tmp/bison-grub-failed ]; then
    if mountpoint -q /mnt; then
      umount -R /mnt 2>/dev/null
    fi
    dialog --clear --title " ERROR: Bootloader " --ok-label "Ok" --msgbox "Falló la instalación de GRUB.\n\nEl sistema se copió, pero no va a bootear.\n\nLog: /tmp/bison-install-grub.log\n\nÚltimas líneas:\n$(tail -n 20 /tmp/bison-install-grub.log 2>/dev/null)" 20 75
    volver_al_menu
    return
  fi

  if mountpoint -q /mnt; then
    umount -R /mnt 2>/dev/null
  fi

  local CONF_REBOOT=""
  local RC=0
  local CC=0
  while true; do
    CONF_REBOOT=$(dialog --clear --title " ¡Listo! " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "¡Bison Linux instalado en $DISCO!\n\nAsegurate de extraer el medio antes de reiniciar." 14 70 2 \
      "reboot" "Reiniciar ahora" \
      "menu" "Volver al menú principal")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done

  if [ "$CONF_REBOOT" = "reboot" ]; then
    reboot
  else
    volver_al_menu
  fi
}