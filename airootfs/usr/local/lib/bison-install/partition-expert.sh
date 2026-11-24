#!/bin/bash
# BISON - Particionado experto con cfdisk
# Autor: Omar Carabajal
# Fecha: 14/11/2026

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.

particionado_experto() {
  dialog --clear --title " Manual con cfdisk " --ok-label "Ok" --msgbox 11 70

  # Restaurar teclado elegido en paso 1 (KEYMAP = es / la-latin1 / us)
  # Consola usa la-latin1, X usa latam
  restaurar_teclado() {
    loadkeys "$KEYMAP" 2>/dev/null || true
    case "$KEYMAP" in
      la-latin1) setxkbmap latam 2>/dev/null || true ;;
      es) setxkbmap es 2>/dev/null || true ;;
      us) setxkbmap us 2>/dev/null || true ;;
      *) setxkbmap latam 2>/dev/null || true ;;
    esac
  }

  # solo gpt y dos
  chequear_tabla_permitida() {
    local TABLA="$(blkid -o value -s PTTYPE "$DISCO" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    if [ "$TABLA" != "gpt" ] && [ "$TABLA" != "dos" ]; then
      dialog --clear --title " Tabla no soportada " --ok-label "Volvé a cfdisk" --msgbox "\nElegiste tabla: ${TABLA:-ninguna}.\n\nElegí gpt o dos." 12 70
      return 1
    fi
    return 0
  }

  # releer tabla
  releer_tabla() {
    swapoff -a 2>/dev/null || true
    partprobe "$DISCO" 2>/dev/null || true
    udevadm settle 2>/dev/null || true
    sleep 2
    # Verificar que el kernel ya ve al menos 1 particion (sda1, nvme0n1p1, etc)
    # lsblk lista disco + particiones, si solo hay 1 linea es solo el disco, sin particiones
    if [ "$(lsblk -ln -o NAME "$DISCO" 2>/dev/null | wc -l)" -le 1 ]; then
      return 1
    fi
    return 0
  }

  # Antes del primer cfdisk, apagar swap para que partprobe pueda releer
  swapoff -a 2>/dev/null || true
  clear
  cfdisk "$DISCO"
  RC_CFDISK=$?
  clear
  # Restaurar teclado después de cfdisk
  restaurar_teclado
  if [ $RC_CFDISK -ne 0 ]; then
    dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nSaliste de cfdisk sin guardar." 8 60
    return 1
  fi

  # rebota si la tabla no es gpt o dos
  while ! chequear_tabla_permitida; do
    clear
    cfdisk "$DISCO"
    RC_CFDISK=$?
    clear
    restaurar_teclado
    if [ $RC_CFDISK -ne 0 ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nSaliste de cfdisk sin guardar." 8 60
      return 1
    fi
  done

  if ! releer_tabla; then
    dialog --clear --title " Reiniciá el live " --ok-label "Ok" --msgbox "\nSe crearon las particiones pero el kernel no las detectó porque estaban en uso.\n\nReiniciá el live desde el USB y volvé a entrar al instalador." 12 70
    return 1
  fi

  # chequeo UEFI + DISCO
  TIPO_TABLA_CFDISK=$(blkid -o value -s PTTYPE "$DISCO" 2>/dev/null)
  if [ "$MODO_FIRMWARE" = "uefi" ] || [ -d /sys/firmware/efi ]; then
    if echo "$TIPO_TABLA_CFDISK" | grep -qi "dos"; then
      dialog --clear --title " Tabla incompatible " --ok-label "Volver a cfdisk" --msgbox "\nElegiste DOS (MBR) en UEFI." 12 70
      clear
      cfdisk "$DISCO"
      RC_CFDISK=$?
      clear
      restaurar_teclado
      if [ $RC_CFDISK -ne 0 ]; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nSaliste de cfdisk sin guardar." 8 60
        return 1
      fi
      releer_tabla || true
      # Re-chequea tabla permitida después de volver a cfdisk
      while ! chequear_tabla_permitida; do
        clear
        cfdisk "$DISCO"
        RC_CFDISK=$?
        clear
        restaurar_teclado
        if [ $RC_CFDISK -ne 0 ]; then
          dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nSaliste de cfdisk sin guardar." 8 60
          return 1
        fi
      done
    fi
  fi

  # chequeo BIOS + GPT sin bios_grub
  if [ ! -d /sys/firmware/efi ] && [ "$MODO_FIRMWARE" != "uefi" ]; then
    TIPO_TABLA=$(sfdisk -l "$DISCO" 2>/dev/null | grep -i "label:" | awk '{print $2}')
    if echo "$TIPO_TABLA" | grep -qi "gpt"; then
      if ! sfdisk -l "$DISCO" 2>/dev/null | grep -qi "BIOS boot"; then
        dialog --clear --title " Falta bios_grub " --ok-label "Volver a cfdisk" --msgbox "\nElegiste GPT en BIOS.\n\nTe falta la partición de 1M tipo 'BIOS boot' (EF02)." 12 70
        clear
        cfdisk "$DISCO"
        RC_CFDISK=$?
        clear
        restaurar_teclado
        if [ $RC_CFDISK -ne 0 ]; then
          dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nSaliste de cfdisk sin guardar." 8 60
          return 1
        fi
        releer_tabla || true
      fi
    fi
  fi

  # chequeo BIOS / UEFI vs tabla ---
  TIPO_TABLA=$(blkid -o value -s PTTYPE "$DISCO" 2>/dev/null)
  TIENE_BIOS_BOOT=$(sfdisk -l "$DISCO" 2>/dev/null | grep -qi "BIOS boot" && echo "si" || echo "no")
  TIENE_EFI=$(sfdisk -l "$DISCO" 2>/dev/null | grep -qi "EFI System" && echo "si" || echo "no")

  if [ "$MODO_FIRMWARE" = "legacy" ] && echo "$TIPO_TABLA" | grep -qi "gpt" && [ "$TIENE_BIOS_BOOT" = "no" ]; then
    while true; do
      OPCION_BIOS=$(dialog --clear --title " Tabla incompatible " --stdout \
        --ok-label "Ok" --cancel-label "Cancel" --extra-button --extra-label "Ayuda" \
        --no-tags --menu "\nElegiste una tabla incompatible para tu BIOS!\n\nBIOS + GPT, necesita partición boot.\n\npara instalar GRUB." 16 70 3 \
        "cfdisk" "Volver a cfdisk y crearla" \
        "ayuda" "Ver ayuda" \
        "cancel" "Cancelar instalación")
      RC=$?
      check_cancel $RC
      CC=$?
      if [ "$OPCION_BIOS" = "cfdisk" ]; then
        clear
        cfdisk "$DISCO"
        releer_tabla || true
        restaurar_teclado
        TIPO_TABLA=$(sfdisk -l "$DISCO" 2>/dev/null | grep -i "label:" | awk '{print $2}')
        TIENE_BIOS_BOOT=$(sfdisk -l "$DISCO" 2>/dev/null | grep -qi "BIOS boot" && echo "si" || echo "no")
        [ "$TIENE_BIOS_BOOT" = "si" ] && break
        continue
      fi
      if [ "$OPCION_BIOS" = "ayuda" ]; then
        dialog --clear --title " Ayuda BIOS + GPT " --ok-label "Volver" --msgbox "\nEn BIOS + GPT necesitás:\n\n1M - Tipo: BIOS boot - Sin formato\nCódigo: EF02\n\nCreala en cfdisk antes de las otras particiones.\n\nEjemplo:\n- 1M BIOS boot\n- 2G swap\n- 20G /\n- resto /home" 16 70
        continue
      fi
      return 1
    done
  fi

  SUF=""
  if [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]]; then
    SUF="p"
  fi

  while true; do
    PART_ROOT_MANUAL=$(dialog --clear --title " Partición raíz " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "\n¿Partición raíz (/)?\n\n" 12 60 "${DISCO}${SUF}2")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_ROOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nTenés que poner la partición raíz." 8 60
      continue
    fi
    if [ ! -b "$PART_ROOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición no existe: $PART_ROOT_MANUAL" 8 60
      continue
    fi
    # / no puede ser swap ni EFI ni BIOS boot
    if sfdisk -l "$DISCO" 2>/dev/null | grep "$PART_ROOT_MANUAL" | grep -qi "swap"; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa es swap, no puede ser /." 8 60
      continue
    fi
    if sfdisk -l "$DISCO" 2>/dev/null | grep "$PART_ROOT_MANUAL" | grep -qi "EFI System\|BIOS boot"; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa es EFI o BIOS boot, no puede ser /." 8 60
      continue
    fi
    break
  done

  # /boot separado
  while true; do
    PART_BOOT_MANUAL=$(dialog --clear --title " Partición /boot " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "\n¿Partición /boot?\n\nDejá vacío si no tenés /boot separado." 12 60 "")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_BOOT_MANUAL" ]; then
      break
    fi
    if [ ! -b "$PART_BOOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición no existe: $PART_BOOT_MANUAL" 8 60
      continue
    fi
    if [ "$PART_BOOT_MANUAL" = "$PART_ROOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición ya la usaste." 8 60
      continue
    fi
    if sfdisk -l "$DISCO" 2>/dev/null | grep "$PART_BOOT_MANUAL" | grep -qi "swap\|EFI System\|BIOS boot"; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa no puede ser /boot." 8 60
      continue
    fi
    break
  done

  if [ "$MODO_FIRMWARE" = "uefi" ] || [ -d /sys/firmware/efi ]; then
    while true; do
      PART_EFI_MANUAL=$(dialog --clear --title " Partición EFI " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "\nPartición EFI?\n\n" 12 60 "${DISCO}${SUF}1")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      [ $CC -eq 2 ] && continue
      if [ -z "$PART_EFI_MANUAL" ]; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nTenés que poner la partición EFI." 8 60
        continue
      fi
      if [ ! -b "$PART_EFI_MANUAL" ]; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición no existe: $PART_EFI_MANUAL" 8 60
        continue
      fi
      # chequeo EFI system
      if ! sfdisk -l "$DISCO" 2>/dev/null | grep "$PART_EFI_MANUAL" | grep -qi "EFI System"; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición no es EFI System.\n\n$PART_EFI_MANUAL no es tipo EFI System." 10 70
        continue
      fi
      # EFI no puede ser igual a root
      if [ "$PART_EFI_MANUAL" = "$PART_ROOT_MANUAL" ]; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nLa partición EFI y la raíz no pueden ser la misma." 10 70
        continue
      fi
      break
    done
  else
    PART_EFI_MANUAL=""
  fi

  while true; do
    PART_HOME_MANUAL=$(dialog --clear --title " Partición /home " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "\n¿Partición /home?\n\nDejá vacío si no creaste /home separado." 12 60 "")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_HOME_MANUAL" ]; then
      break
    fi
    if [ ! -b "$PART_HOME_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición no existe: $PART_HOME_MANUAL" 8 60
      continue
    fi
    # chequeo duplicado: /home no puede ser root o EFI ---
    if [ "$PART_HOME_MANUAL" = "$PART_ROOT_MANUAL" ] || [ "$PART_HOME_MANUAL" = "$PART_EFI_MANUAL" ] || [ "$PART_HOME_MANUAL" = "$PART_BOOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición ya la usaste.\n\n$PART_HOME_MANUAL ya está como raíz o como EFI." 10 70
      continue
    fi
    break
  done

  while true; do
    PART_SWAP_MANUAL=$(dialog --clear --title " Partición swap " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "\n¿Partición swap?\n\nDejá vacío si no creaste swap." 12 60 "")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_SWAP_MANUAL" ]; then
      break
    fi
    if [ ! -b "$PART_SWAP_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición no existe: $PART_SWAP_MANUAL" 8 60
      continue
    fi
    if ! sfdisk -l "$DISCO" 2>/dev/null | grep "$PART_SWAP_MANUAL" | grep -qi "swap"; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa no es swap." 8 60
      continue
    fi
    # chequeo duplicado: swap no puede ser root, EFI o home ---
    if [ "$PART_SWAP_MANUAL" = "$PART_ROOT_MANUAL" ] || [ "$PART_SWAP_MANUAL" = "$PART_EFI_MANUAL" ] || [ "$PART_SWAP_MANUAL" = "$PART_HOME_MANUAL" ] || [ "$PART_SWAP_MANUAL" = "$PART_BOOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "\nEsa partición ya la usaste.\n\n$PART_SWAP_MANUAL ya está como raíz, EFI o /home." 12 70
      continue
    fi
    break
  done

  MODO_PART="manual"
  construir_resumen_particiones
  dialog --clear --title " Resumen " \
    --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
    --yesno "\n${RESUMEN_PART}\n¿Crear particiones con este esquema?" 16 70
  RC=$?
  check_cancel $RC
  CC=$?
  [ $CC -eq 1 ] && return 1
  [ $CC -eq 2 ] && return 1

  return 0
}