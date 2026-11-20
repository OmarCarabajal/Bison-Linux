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
  dialog --clear --title " Manual con cfdisk " --ok-label "Ok" --msgbox "Vas a entrar a cfdisk.\n\nCreá tus particiones a mano.\n\nCuando termines, salí de cfdisk con Write + Quit.\n\nDespués te voy a preguntar cuál es la raíz y cuál la EFI." 14 70

  clear
  cfdisk "$DISCO"
  RC_CFDISK=$?
  clear
  if [ $RC_CFDISK -ne 0 ]; then
    dialog --clear --title " Error " --ok-label "Ok" --msgbox "Saliste de cfdisk sin guardar." 8 60
    return 1
  fi

  partprobe "$DISCO" 2>/dev/null
  sleep 1

  # --- Chequeo BIOS + GPT sin bios_grub ---
  # Si eligió gpt en cfdisk y está en BIOS, tiene que tener BIOS boot
  if [ ! -d /sys/firmware/efi ] && [ "$MODO_FIRMWARE" != "uefi" ]; then
    TIPO_TABLA=$(sfdisk -l "$DISCO" 2>/dev/null | grep -i "label:" | awk '{print $2}')
    if echo "$TIPO_TABLA" | grep -qi "gpt"; then
      if ! sfdisk -l "$DISCO" 2>/dev/null | grep -qi "BIOS boot"; then
        dialog --clear --title " Falta bios_grub " --ok-label "Volver a cfdisk" --msgbox "Elegiste GPT en BIOS.\n\nTe falta la partición de 1M tipo 'BIOS boot' (EF02).\n\nSin eso GRUB no puede instalarse.\n\nVolvé a cfdisk y creá una partición de 1M tipo 'BIOS boot' antes de la swap." 12 70
        clear
        cfdisk "$DISCO"
        RC_CFDISK=$?
        clear
        if [ $RC_CFDISK -ne 0 ]; then
          dialog --clear --title " Error " --ok-label "Ok" --msgbox "Saliste de cfdisk sin guardar." 8 60
          return 1
        fi
        partprobe "$DISCO" 2>/dev/null
        sleep 1
      fi
    fi
  fi

  # --- Chequeo BIOS / UEFI vs tabla ---
  TIPO_TABLA=$(blkid -o value -s PTTYPE "$DISCO" 2>/dev/null)
  TIENE_BIOS_BOOT=$(sfdisk -l "$DISCO" 2>/dev/null | grep -qi "BIOS boot" && echo "si" || echo "no")
  TIENE_EFI=$(sfdisk -l "$DISCO" 2>/dev/null | grep -qi "EFI System" && echo "si" || echo "no")

  if [ "$MODO_FIRMWARE" = "legacy" ] && echo "$TIPO_TABLA" | grep -qi "gpt" && [ "$TIENE_BIOS_BOOT" = "no" ]; then
    while true; do
      OPCION_BIOS=$(dialog --clear --title " Tabla incompatible " --stdout \
        --ok-label "Ok" --cancel-label "Cancel" --extra-button --extra-label "Ayuda" \
        --no-tags --menu "Elegiste una tabla incompatible para tu BIOS!\n\nBIOS (legacy) + GPT, necesita partición boot.\n\npara instalar GRUB." 16 70 3 \
        "cfdisk" "Volver a cfdisk y crearla" \
        "ayuda" "Ver ayuda" \
        "cancel" "Cancelar instalación")
      RC=$?
      check_cancel $RC
      CC=$?
      if [ "$OPCION_BIOS" = "cfdisk" ]; then
        clear
        cfdisk "$DISCO"
        partprobe "$DISCO" 2>/dev/null
        sleep 1
        # Volver a chequear
        TIPO_TABLA=$(sfdisk -l "$DISCO" 2>/dev/null | grep -i "label:" | awk '{print $2}')
        TIENE_BIOS_BOOT=$(sfdisk -l "$DISCO" 2>/dev/null | grep -qi "BIOS boot" && echo "si" || echo "no")
        [ "$TIENE_BIOS_BOOT" = "si" ] && break
        continue
      fi
      if [ "$OPCION_BIOS" = "ayuda" ]; then
        dialog --clear --title " Ayuda BIOS + GPT " --ok-label "Volver" --msgbox "En BIOS + GPT necesitás:\n\n1M - Tipo: BIOS boot - Sin formato\nCódigo: EF02\n\nCreala en cfdisk antes de las otras particiones.\n\nEjemplo:\n- 1M BIOS boot\n- 2G swap\n- 20G /\n- resto /home" 16 70
        continue
      fi
      # Cancel
      return 1
    done
  fi

  # Sufijo para nvme / mmcblk: p1, p2... en SATA: 1, 2...
  SUF=""
  if [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]]; then
    SUF="p"
  fi

  while true; do
    PART_ROOT_MANUAL=$(dialog --clear --title " Partición raíz " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "¿Partición raíz (/)?\n\n" 12 60 "${DISCO}${SUF}2")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_ROOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Tenés que poner la partición raíz." 8 60
      continue
    fi
    if [ ! -b "$PART_ROOT_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Esa partición no existe: $PART_ROOT_MANUAL" 8 60
      continue
    fi
    break
  done

  if [ "$MODO_FIRMWARE" = "uefi" ] || [ -d /sys/firmware/efi ]; then
    while true; do
      PART_EFI_MANUAL=$(dialog --clear --title " Partición EFI " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "Partición EFI?\n\n" 12 60 "${DISCO}${SUF}1")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      [ $CC -eq 2 ] && continue
      if [ -z "$PART_EFI_MANUAL" ]; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Tenés que poner la partición EFI." 8 60
        continue
      fi
      if [ ! -b "$PART_EFI_MANUAL" ]; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Esa partición no existe: $PART_EFI_MANUAL" 8 60
        continue
      fi
      break
    done
  else
    PART_EFI_MANUAL=""
  fi

  # --- /home (opcional, dejá vacío si no creaste) ---
  while true; do
    PART_HOME_MANUAL=$(dialog --clear --title " Partición /home " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "¿Partición /home?\n\nDejá vacío si no creaste /home separado." 12 60 "")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_HOME_MANUAL" ]; then
      break
    fi
    if [ ! -b "$PART_HOME_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Esa partición no existe: $PART_HOME_MANUAL" 8 60
      continue
    fi
    break
  done

  # --- Swap (opcional, dejá vacío si no creaste) ---
  while true; do
    PART_SWAP_MANUAL=$(dialog --clear --title " Partición swap " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "¿Partición swap?\n\nDejá vacío si no creaste swap." 12 60 "")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PART_SWAP_MANUAL" ]; then
      break
    fi
    if [ ! -b "$PART_SWAP_MANUAL" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Esa partición no existe: $PART_SWAP_MANUAL" 8 60
      continue
    fi
    break
  done

  # Resumen
  MODO_PART="manual"
  construir_resumen_particiones
  dialog --clear --title " Resumen " \
    --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
    --yesno "${RESUMEN_PART}\n¿Crear particiones con este esquema?" 16 70
  RC=$?
  check_cancel $RC
  CC=$?
  [ $CC -eq 1 ] && return 1
  [ $CC -eq 2 ] && return 1
  
  return 0
}