#!/bin/bash
# BISON - Particionado automático
# Autor: Omar Carabajal
# Fecha: 16/11/2026

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.


particionado_auto() {
  # En UEFI preguntamos tamaño EFI, en BIOS no hay EFI
  if [ "$MODO_FIRMWARE" = "uefi" ]; then
    while true; do
      AUTO_EFI_MB=$(dialog --clear --title " Partición EFI " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "Tamaño de la partición EFI en MB:\n\nRecomendado: 512" 12 60 "512")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      [ $CC -eq 2 ] && continue
      if ! echo "$AUTO_EFI_MB" | grep -Eq '^[0-9]+$'; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Poné solo un número. Ej: 512" 8 60
        continue
      fi
      break
    done
  else
    AUTO_EFI_MB="0"
  fi

  while true; do
    AUTO_QUIERE_SWAP=$(dialog --clear --title " Swap " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "¿Querés partición SWAP?\n\nLa SWAP sirve cuando te quedás sin RAM." 14 70 2 \
      "si" "Sí, crear SWAP" \
      "no" "No, sin SWAP")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done

  if [ "$AUTO_QUIERE_SWAP" = "si" ]; then
    while true; do
      AUTO_SWAP_GB=$(dialog --clear --title " Tamaño SWAP " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "¿Cuántos GB de SWAP?\n\nEj: 2, 4, 8" 12 60 "2")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      [ $CC -eq 2 ] && continue
      if ! echo "$AUTO_SWAP_GB" | grep -Eq '^[0-9]+$'; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Poné solo un número. Ej: 2" 8 60
        continue
      fi
      break
    done
  else
    AUTO_SWAP_GB="0"
  fi

    # Resumen 
  local resumen_auto="Disco: $DISCO\n\n"
  if [ "$MODO_FIRMWARE" = "uefi" ]; then
    resumen_auto="${resumen_auto}efi  ${AUTO_EFI_MB}M\n"
  fi
  if [ "$AUTO_QUIERE_SWAP" = "si" ]; then
    resumen_auto="${resumen_auto}swap ${AUTO_SWAP_GB}G\n"
  else
    resumen_auto="${resumen_auto}sin swap\n"
  fi
  resumen_auto="${resumen_auto}/ resto del disco\n"

  dialog --clear --title " Resumen " \
    --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
    --yesno "${resumen_auto}\n¿Crear particiones con este esquema?" 14 60
  RC=$?
  check_cancel $RC
  CC=$?
  [ $CC -eq 1 ] && return 1
  [ $CC -eq 2 ] && return 1
  
  return 0
}
