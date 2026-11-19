#!/bin/bash
# BISON - Modo de particionado
# Autor: Omar Carabajal
# Fecha: 13/11/2026

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.


elegir_modo_particionado() {
  while true; do
    MODO_PART=$(dialog --clear --title " Particionado " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "¿Cómo querés particionar $DISCO?\n\nUsá ↑ ↓ para moverte, Enter para elegir." 16 70 3 \
      "auto" "Automático - Borra todo y particiona solo" \
      "guided" "Guiado - Elegís particiones, sin cfdisk" \
      "manual" "Manual - Con cfdisk, para expertos")
    RC=$?
    check_cancel $RC
    CC=$?
    [ $CC -eq 0 ] && break
    [ $CC -eq 1 ] && return 1
  done

  if [ "$MODO_PART" = "auto" ]; then
    particionado_auto
    RC=$?
    [ $RC -eq 1 ] && return 1
    return 0
  fi
  if [ "$MODO_PART" = "guided" ]; then
    particionado_guiado
    RC=$?
    [ $RC -eq 1 ] && return 1
    return 0
  fi
  if [ "$MODO_PART" = "manual" ]; then
    particionado_experto
    RC=$?
    [ $RC -eq 1 ] && return 1
    return 0
  fi
  return 0
}
