#!/bin/bash
# BISON - Selección de disco
# Autor: Omar Carabajal
# Fecha: 6/11/2026

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.


elegir_disco() {
  while true; do
    local LISTA=""
    local DISCOS=()
    while read -r NOMBRE TAM MODELO; do
      [ -z "$NOMBRE" ] && continue
      local DEV="/dev/$NOMBRE"
      local DESC="$TAM"
      [ -n "$MODELO" ] && DESC="$TAM $MODELO"
      DISCOS+=("$DEV" "$DESC")
    done < <(lsblk -d -n -o NAME,SIZE,MODEL 2>/dev/null | grep -v "^loop" | grep -v "^sr" | grep -v "^ram")

    if [ ${#DISCOS[@]} -eq 0 ]; then
      dialog --clear --title " Error " --ok-label "Ok" --msgbox "No se encontró ningún disco.\n\nConectá un disco y reintentá." 10 60
      return 1
    fi

    DISCO=$(dialog --clear --title " Disco " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "Elegí el disco donde instalar Bison:\n\nSe va a borrar TODO el disco.\n\nUsá ↑ ↓ para moverte, Enter para elegir." 18 70 6 \
      "${DISCOS[@]}")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done
  # guardar el tamaño total para mostrarlo en confirmar y resumen
  DISCO_SIZE=$(lsblk -d -n -o SIZE "$DISCO" 2>/dev/null | tr -d ' ')
  return 0
}

confirmar_borrado() {
  while true; do
    OPCION=$(dialog --clear --title " Confirmar borrado " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "¡ATENCIÓN!\n\nSe va a borrar TODO $DISCO ($DISCO_SIZE).\n\nTotal disponible: $DISCO_SIZE\n\n¿Estás seguro?" 16 70 2 \
      "si" "Sí, borrar todo $DISCO ($DISCO_SIZE)" \
      "no" "No, elegir otro disco")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done
  if [ "$OPCION" = "no" ]; then
    return 1
  fi
  return 0
}
