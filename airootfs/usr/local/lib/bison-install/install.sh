
#!/bin/bash
# Archivo: install.sh
# Autor: Omar Carabajal
# Fecha: 8/11/2026
# BISON - Instalación del sistema

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.


instalar_sistema() {
  rm -f /tmp/bison-grub-failed /tmp/bison-install-grub.log /tmp/bison-pacstrap-failed /tmp/bison-verify-failed /tmp/bison-verify.log

  # Detección de red
  if ! ping -c 1 -W 7 8.8.8.8 &>/dev/null || ! getent hosts archlinux.org >/dev/null 2>&1; then
    dialog --clear --title " Sin red " --yesno "\nNo hay conexión a internet.\n\n¿Querés conectarte ahora?\n\n" 10 70
    if [ $? -eq 0 ]; then
      systemctl start NetworkManager 2>/dev/null || true
      sleep 2
      # Si hay escritorio, mandar al applet de la barra
      if [ -n "$DISPLAY" ]; then
        dialog --clear --title " Sin red " --msgbox "\nConectate desde el applet de la barra izquierda\n\n" 6 70
      else
        # Sin escritorio nmcli + dialog
        nmcli device wifi rescan 2>/dev/null || true
        sleep 3
        WIFI_LIST=$(nmcli -t -f SSID device wifi list 2>/dev/null | grep -v "^--" | grep -v "^$" | sort -u | head -n 15)
        if [ -z "$WIFI_LIST" ]; then
          dialog --clear --title " Sin red " --msgbox "\nNo se encontraron redes WiFi.\n\nConectá el cable o revisá el WiFi." 8 60
        else
          MENU_ARGS=()
          i=1
          # Leer SSID con espacios
          echo "$WIFI_LIST" | while IFS= read -r ssid; do
            [ -z "$ssid" ] && continue
            echo "$ssid"
          done > /tmp/bison-wifi-list.txt
          # Armar menú
          MENU_ARGS=()
          idx=1
          while IFS= read -r ssid; do
            [ -z "$ssid" ] && continue
            MENU_ARGS+=("$idx" "$ssid")
            idx=$((idx+1))
          done < /tmp/bison-wifi-list.txt
          CHOICE=$(dialog --clear --title " Elegí WiFi " --stdout --menu "Elegí tu red WiFi:" 18 60 12 "${MENU_ARGS[@]}")
          if [ -n "$CHOICE" ]; then
            SSID_ELEGIDA=$(sed -n "${CHOICE}p" /tmp/bison-wifi-list.txt)
            CLAVE=$(dialog --clear --title " Clave WiFi " --stdout --insecure --passwordbox " Clave para $SSID_ELEGIDA:" 10 60)
            if [ -n "$CLAVE" ]; then
              nmcli device wifi connect "$SSID_ELEGIDA" password "$CLAVE" 2>/dev/null || true
              sleep 3
            fi
          fi
          rm -f /tmp/bison-wifi-list.txt
        fi
      fi
      if ! ping -c 1 -W 7 8.8.8.8 &>/dev/null || ! getent hosts archlinux.org >/dev/null 2>&1; then
        dialog --clear --title " Sin red " --msgbox "\nSigue sin conexión a internet." 8 60
        return 1
      fi
    else
      return 1
    fi
  fi

  (
    echo "XXX"; echo 5; echo "\nDetectando UEFI / BIOS..."; echo "XXX"
    sleep 1

    # Si booteo en UEFI Partición 2, ES_UEFI=1 aunque MODO_FIRMWARE sea legacy
    if [ -d /sys/firmware/efi ]; then
      ES_UEFI=1
    elif [ "$MODO_FIRMWARE" = "uefi" ]; then
      ES_UEFI=1
    else
      ES_UEFI=0
    fi
    echo "XXX"; echo 15; echo "\nParticionando $DISCO..."; echo "XXX"
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
  PART_BOOT="$PART_BOOT_MANUAL"
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
    echo "XXX"; echo 30; echo "\n Formateando..."; echo "XXX"
    mkfs.ext4 -F "$PART_ROOT" >/dev/null 2>&1
    mount -t ext4 "$PART_ROOT" /mnt
    # /boot separado en experto, si lo elegiste
    if [ "$MODO_PART" = "manual" ] && [ -n "$PART_BOOT" ]; then
      mkfs.ext4 -F "$PART_BOOT" >/dev/null 2>&1
      mkdir -p /mnt/boot
      mount -t ext4 "$PART_BOOT" /mnt/boot
    fi
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
    echo "XXX"; echo 38; echo "\nVerificando particiones y montaje..."; echo "XXX"
    : > /tmp/bison-verify.log
    echo "DISCO=$DISCO PART_ROOT=$PART_ROOT PART_BOOT=$PART_BOOT PART_HOME=$PART_HOME_MANUAL PART_SWAP=$PART_SWAP_MANUAL ES_UEFI=$ES_UEFI" >> /tmp/bison-verify.log
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
    echo "XXX"; echo 45; echo "\n Instalando sistema base con pacstrap..."; echo "XXX"
    mapfile -t PKGS < <(grep -v "^#" /usr/share/bison/packages.x86_64 | grep -v "^$" | tr -d '\r')
    pacstrap -K /mnt "${PKGS[@]}" > /tmp/bison-pacstrap.log 2>&1 &
    PACSTRAP_PID=$!
    while kill -0 $PACSTRAP_PID 2>/dev/null; do
      ULTIMA=$(tail -n 1 /tmp/bison-pacstrap.log 2>/dev/null)
      # Buscar ( X/Y ) en el log, como ( 12/150 )
      PROG=$(grep -o "([0-9]*/[0-9]*)" /tmp/bison-pacstrap.log 2>/dev/null | tail -n 1 | tr -d '()')
      ACTUAL=$(echo "$PROG" | cut -d/ -f1 | tr -d ' ')
      TOTAL_PAC=$(echo "$PROG" | cut -d/ -f2 | tr -d ' ')
      if [ -n "$ACTUAL" ] && [ -n "$TOTAL_PAC" ] && [ "$TOTAL_PAC" -gt 0 ] 2>/dev/null; then
        PORC=$((45 + ACTUAL * 35 / TOTAL_PAC))
      else
        PORC=45
      fi
      echo "XXX"; echo $PORC; echo "\n Instalando sistema base con pacstrap...\n\n $ULTIMA"; echo "XXX"
      sleep 1
    done
    wait $PACSTRAP_PID
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

    # copiar tema, iconos, fondo y defaults del live al instalado
    mkdir -p /mnt/usr/share/themes /mnt/usr/share/icons /mnt/usr/share/backgrounds /mnt/usr/share/bison-defaults
    mkdir -p /mnt/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/ /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
    mkdir -p /mnt/etc/lightdm/ /mnt/usr/share/backgrounds/xfce/ /mnt/boot/grub/themes/bison/

    cp -a /usr/share/themes/Space-dark /mnt/usr/share/themes/ 2>/dev/null
    cp -a /usr/share/icons/besgnulinux-labile-dark-blue /mnt/usr/share/icons/ 2>/dev/null
    cp -a /usr/share/icons/SC_Cursors_Terran_Blue /mnt/usr/share/icons/ 2>/dev/null
    cp -a /usr/share/backgrounds/bison /mnt/usr/share/backgrounds/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/usr/share/bison-defaults/ 2>/dev/null
    cp -a /usr/share/themes/Bison /mnt/usr/share/themes/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null
    cp -a /usr/share/bison-defaults/*.xml /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null

    # evitar launchers vacíos en el panel
    find /mnt/etc/skel/.config/xfce4/panel/ -type f -size 0 -delete 2>/dev/null
    rm -rf /mnt/etc/skel/.config/xfce4/panel/launcher-4 2>/dev/null
    find /mnt/etc/xdg/xfce4/panel/ -type f -size 0 -delete 2>/dev/null
    rm -rf /mnt/etc/xdg/xfce4/panel/launcher-4 2>/dev/null
    cp -a /etc/lightdm/lightdm-gtk-greeter.conf /mnt/etc/lightdm/lightdm-gtk-greeter.conf 2>/dev/null

    # borrar cualquier GRUB_THEME previo para que no tape el menu en BIOS
    mkdir -p /mnt/boot/grub/themes/bison
    cp /usr/share/bison-defaults/splash-1024x768.png /mnt/boot/grub/splash.png 2>/dev/null || \
    cp /boot/grub/themes/bison/splash.png /mnt/boot/grub/splash.png 2>/dev/null || \
    cp /usr/share/bison-defaults/splash.png /mnt/boot/grub/splash.png 2>/dev/null || \
    cp /boot/grub/themes/bison/splash.png /mnt/boot/grub/themes/bison/splash.png 2>/dev/null || \
    cp /usr/share/bison-defaults/splash.png /mnt/boot/grub/themes/bison/splash.png 2>/dev/null || true

    # Borrar / comentar GRUB_THEME si existia
    sed -i 's|^GRUB_THEME=.*|#GRUB_THEME=""|' /mnt/etc/default/grub
    sed -i 's|^#GRUB_THEME=.*|#GRUB_THEME=""|' /mnt/etc/default/grub
    
    sed -i 's|^#\?GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/splash.png"|' /mnt/etc/default/grub
    grep -q "^GRUB_BACKGROUND=" /mnt/etc/default/grub || echo 'GRUB_BACKGROUND="/boot/grub/splash.png"' >> /mnt/etc/default/grub
    
    sed -i 's|^#\?GRUB_GFXMODE=.*|GRUB_GFXMODE=1024x768|' /mnt/etc/default/grub
    grep -q "^GRUB_GFXMODE=" /mnt/etc/default/grub || echo 'GRUB_GFXMODE=1024x768' >> /mnt/etc/default/grub

    # Fondo Bison de entrada, en carpeta xfce y en carpeta bison (las 2, para que el xml lo encuentre)
    mkdir -p /mnt/usr/share/backgrounds/xfce /mnt/usr/share/backgrounds/bison
    cp /usr/share/backgrounds/bison/bison_default.jpg /mnt/usr/share/backgrounds/xfce/bison_default.jpg 2>/dev/null
    chmod 644 /mnt/usr/share/backgrounds/xfce/bison_default.jpg 2>/dev/null
    cp /usr/share/backgrounds/bison/bison_default.jpg /mnt/usr/share/backgrounds/bison/bison_default.jpg 2>/dev/null
    chmod 644 /mnt/usr/share/backgrounds/bison/bison_default.jpg 2>/dev/null
    
    mkdir -p /mnt/usr/share/backgrounds/bison
    cp /usr/share/backgrounds/bison/bison_default.jpg /mnt/usr/share/backgrounds/bison/bison_default.jpg 2>/dev/null
    chmod 644 /mnt/usr/share/backgrounds/bison/bison_default.jpg 2>/dev/null

    echo "XXX"; echo 70; echo "Generando fstab..."; echo "XXX"
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "XXX"; echo 80; echo "\n Configurando el sistema..."; echo "XXX"
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
    echo "XXX"; echo 90; echo "\n Instalando bootloader..."; echo "XXX"
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

      # Fondo Bison + barra en GRUB
      sed -i 's|^#GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/splash.png"|' /mnt/etc/default/grub
      grep -q "^GRUB_BACKGROUND=" /mnt/etc/default/grub || echo 'GRUB_BACKGROUND="/boot/grub/splash.png"' >> /mnt/etc/default/grub
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
    # Segundo bloque: no pisar el splash 1024x768 ya puesto, usar ese primero
    if [ -f /usr/share/bison-defaults/splash-1024x768.png ]; then
      mkdir -p /mnt/boot/grub
      cp /usr/share/bison-defaults/splash-1024x768.png /mnt/boot/grub/splash.png
    elif [ -f /usr/share/bison/splash.png ]; then
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
    echo "XXX"; echo 100; echo "\n Listo!"; echo "XXX"
    sleep 1
  ) | dialog --clear --title " Instalando Bison Linux... " --gauge "\n Preparando..." 10 70 0

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
      --no-tags --menu "\n¡Bison Linux instalado en $DISCO!\n\nAsegurate de extraer el medio antes de reiniciar." 12 70 2 \
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