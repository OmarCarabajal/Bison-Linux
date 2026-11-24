#!/bin/bash
# Archivo: bison-background.sh
# Autor: Omar Carabajal
# Fecha: 21/11/2026
# Pone el bison_default.jpg en todos los monitores

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.


sleep 1
for MON in monitor0 monitorVirtual-1 monitorDP-1 monitorHDMI-1 monitorVGA-1; do
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/$MON/workspace0/last-image -s /usr/share/backgrounds/bison/bison_default.jpg 2>/dev/null || true
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/$MON/workspace0/image-style -n -t int -s 5 2>/dev/null || true
done
xfce4-desktop --reload 2>/dev/null || true