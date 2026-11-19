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

resumen_final() {
  local RESUMEN
  RESUMEN="Resumen de la instalación:\n\n"
  RESUMEN+="Disco: $DISCO ($DISCO_SIZE)\n"
  RESUMEN+="Modo: $MODO_PART\n"
  RESUMEN+="Teclado: $KEYMAP\n"
  RESUMEN+="Hostname: $HOSTNAME\n"
  RESUMEN+="Usuario: $USUARIO\n\n"
  RESUMEN+="Se va a borrar todo $DISCO.\n\n"
  RESUMEN+="¿Instalar?"
  while true; do
    OPCION=$(dialog --clear --title " Resumen " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "$RESUMEN" 18 70 2 \
      "instalar" "Instalar ahora" \
      "menu" "Volver al menú principal")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done
  if [ "$OPCION" = "menu" ]; then
    volver_al_menu
  fi
  return 0
}
