#!/bin/bash
# BISON - Particionado experto con cfdisk

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

  while true; do
    PART_ROOT_MANUAL=$(dialog --clear --title " Partición raíz " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "¿Partición raíz (/)?\n\n" 12 60 "$DISCO""2")
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
        --inputbox "Partición EFI?\n\n" 12 60 "$DISCO""1")
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

  PART_HOME_MANUAL=""
  PART_SWAP_MANUAL=""
  MODO_PART="manual"
  return 0
}
