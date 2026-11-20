#!/bin/bash
# BISON - Pantallas del instalador
# Autor: Omar Carabajal
# Fecha: 12/11/2026

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.

bienvenida() {
  dialog --clear --title " Bison Linux - Instalador " --ok-label "Ok" --msgbox "Bienvenido a Bison Linux\n\nPara instalar a mano, salí con ESC y seguí la guía de Arch." 14 70
}

preguntar_teclado() {
  while true; do
    KEYMAP=$(dialog --clear --title " Teclado " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "Elegí tu distribución de teclado:\n\nUsá ↑ ↓ para moverte, Enter para elegir." 15 60 5 \
      "es" "Español (España)" \
      "la-latin1" "Latinoamericano" \
      "us" "Inglés (USA)")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done
  loadkeys "$KEYMAP" 2>/dev/null || true
  echo "KEYMAP=$KEYMAP"
  return 0
}

preguntar_hostname() {
  while true; do
    HOSTNAME=$(dialog --clear --title " Hostname " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "\nNombre del equipo:\n\nSolo letras minúsculas, números y guión. Ej: bison-pc" 12 60 "bison-pc")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$HOSTNAME" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "El hostname no puede estar vacío." 8 60
      continue
    fi
    if ! echo "$HOSTNAME" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Hostname inválido. Solo minúsculas, números y guión." 8 60
      continue
    fi
    return 0
  done
}

preguntar_usuario() {
  while true; do
    USUARIO=$(dialog --clear --title " Usuario " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --inputbox "\nNombre de usuario:\n\nSolo minúsculas sin espacios." 12 60 "bison")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$USUARIO" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "El usuario no puede estar vacío." 8 60
      continue
    fi
    if ! echo "$USUARIO" | grep -Eq '^[a-z][a-z0-9_-]*$'; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Usuario inválido. Empieza con minúscula, sin espacios." 8 60
      continue
    fi
    if [ "$USUARIO" = "root" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "No podés usar root como usuario." 8 60
      continue
    fi
    return 0
  done
}

preguntar_passwords() {
  while true; do
    PASS_ROOT=$(dialog --clear --title " Contraseña de root " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --passwordbox "\nContraseña de root:" 10 60)
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PASS_ROOT" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "La contraseña de root no puede estar vacía." 8 60
      continue
    fi
    PASS_ROOT2=$(dialog --clear --title " Confirmar root " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --passwordbox "\nRepetí la contraseña de root:" 10 60)
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ "$PASS_ROOT" != "$PASS_ROOT2" ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "Las contraseñas de root no coinciden." 8 60
      continue
    fi
    break
  done
  while true; do
    PASS_USER=$(dialog --clear --title " Contraseña de $USUARIO " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --passwordbox "\nContraseña para $USUARIO:" 10 60)
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ -z "$PASS_USER" ]; then
      dialog --clear --title "Error" --ok-label "Ok" --msgbox "La contraseña no puede estar vacía." 8 60
      continue
    fi
    PASS_USER2=$(dialog --clear --title " Confirmar $USUARIO " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --passwordbox "\nRepetí la contraseña para $USUARIO:" 10 60)
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 1 ] && return 1
    [ $CC -eq 2 ] && continue
    if [ "$PASS_USER" != "$PASS_USER2" ]; then
      dialog --clear --title "Error" --ok-label "Ok" --msgbox "Las contraseñas no coinciden." 8 60
      continue
    fi
    break
  done
  return 0
}


# Deja el resumen en $RESUMEN_PART
construir_resumen_particiones() {
  RESUMEN_PART=""
  if [ "$MODO_PART" = "guided" ]; then
    RESUMEN_PART="Disco: $DISCO\n"
    [ -n "$GUIDED_EFI_MB" ] && [ "$GUIDED_EFI_MB" != "0" ] && RESUMEN_PART+="  EFI: ${GUIDED_EFI_MB}M - vfat\n"
    RESUMEN_PART+="  ROOT: ${GUIDED_ROOT_GB}G - ext4 - /\n"
    [ "$GUIDED_HOME_GB" != "0" ] && [ -n "$GUIDED_HOME_GB" ] && RESUMEN_PART+="  HOME: ${GUIDED_HOME_GB}G - ext4 - /home\n"
    [ "$GUIDED_SWAP_GB" != "0" ] && [ -n "$GUIDED_SWAP_GB" ] && RESUMEN_PART+="  SWAP: ${GUIDED_SWAP_GB}G - swap\n"
  elif [ "$MODO_PART" = "auto" ]; then
    RESUMEN_PART="Disco: $DISCO\n"
    [ -n "$AUTO_EFI_MB" ] && [ "$AUTO_EFI_MB" != "0" ] && RESUMEN_PART+="  EFI: ${AUTO_EFI_MB}M - vfat\n"
    if [ "$AUTO_QUIERE_SWAP" = "si" ]; then
      RESUMEN_PART+="  SWAP: ${AUTO_SWAP_GB}G - swap\n"
    else
      RESUMEN_PART+="  SWAP: sin swap\n"
    fi
    RESUMEN_PART+="  ROOT: resto del disco - ext4 - /\n"
  elif [ "$MODO_PART" = "manual" ]; then
    # En manual los valores están en el disco, los sacamos con lsblk, más fácil
    RESUMEN_PART="Disco: $DISCO\n"
    RESUMEN_PART+=$(lsblk -n -o NAME,SIZE,TYPE -l "$DISCO" 2>/dev/null | grep "part" | while read -r name size type; do
      echo "  /dev/$name - $size"
    done)
    RESUMEN_PART+="\n"
    [ -n "$PART_EFI_MANUAL" ] && RESUMEN_PART+="  EFI: $PART_EFI_MANUAL\n"
    [ -n "$PART_ROOT_MANUAL" ] && RESUMEN_PART+="  ROOT: $PART_ROOT_MANUAL - /\n"
    [ -n "$PART_HOME_MANUAL" ] && RESUMEN_PART+="  HOME: $PART_HOME_MANUAL - /home\n"
    [ -n "$PART_SWAP_MANUAL" ] && RESUMEN_PART+="  SWAP: $PART_SWAP_MANUAL - swap\n"
  fi
}

resumen_final() {
  local RESUMEN
  RESUMEN="Resumen de la instalación:\n\n"
  RESUMEN+="Disco: $DISCO ($DISCO_SIZE)\n"
  RESUMEN+="Modo: $MODO_PART\n"
  construir_resumen_particiones
  RESUMEN+="Particiones:\n$RESUMEN_PART\n"
  RESUMEN+="Teclado: $KEYMAP\n"
  RESUMEN+="Hostname: $HOSTNAME\n"
  RESUMEN+="Usuario: $USUARIO\n\n"
  RESUMEN+="Se va a borrar todo $DISCO.\n\n"
  RESUMEN+="¿Instalar?"
  # ... el resto del dialog que ya tenés
}