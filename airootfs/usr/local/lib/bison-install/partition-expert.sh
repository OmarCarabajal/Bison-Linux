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
  local resumen_manual="Disco: $DISCO\n\n"
  [ -n "$PART_EFI_MANUAL" ] && resumen_manual="${resumen_manual}efi  $PART_EFI_MANUAL\n"
  resumen_manual="${resumen_manual}/  $PART_ROOT_MANUAL\n"
  if [ -n "$PART_HOME_MANUAL" ]; then
    resumen_manual="${resumen_manual}/home  $PART_HOME_MANUAL\n"
  else
    resumen_manual="${resumen_manual}home adentro de /\n"
  fi
  if [ -n "$PART_SWAP_MANUAL" ]; then
    resumen_manual="${resumen_manual}swap  $PART_SWAP_MANUAL\n"
  else
    resumen_manual="${resumen_manual}sin swap\n"
  fi

  dialog --clear --title " Resumen " \
    --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
    --yesno "${resumen_manual}\n¿Crear particiones con este esquema?" 14 60
  RC=$?
  check_cancel $RC
  CC=$?
  [ $CC -eq 1 ] && return 1
  [ $CC -eq 2 ] && return 1

  MODO_PART="manual"
  return 0
}