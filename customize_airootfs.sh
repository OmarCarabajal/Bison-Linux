#!/bin/bash
# Archivo: customize_airootfs.sh
# Autor: Omar Carabajal
# Fecha: 8/11/2026
# Configura el aspecto del entorno.

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.
set -e -u

# Bison: config default - panel izquierda dark, Space-dark, fondo final
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/bison-defaults/*.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/bison-defaults/*.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/bison-defaults/*.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/
