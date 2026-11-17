#!/bin/bash
set -e -u

# Bison: config default - panel izquierda dark, Space-dark, fondo final
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/bison-defaults/*.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/bison-defaults/*.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/bison-defaults/*.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/
