#!/bin/bash
# Archivo: show_bison_menu.zsh
# Autor: Omar Carabajal
# Fecha: 12/11/2026
# Muestra el menú principal

# Este programa es software libre: puedes redistribuirlo y/o modificarlo 
# bajo los términos de la Licencia Pública General GNU (GPL) versión 3, 
# o (a tu elección) cualquier versión posterior publicada por la 
# Free Software Foundation.
#
# Este programa se distribuye SIN NINGUNA GARANTÍA. Para más detalles,
# consulta el archivo LICENSE incluido en la raíz del proyecto o visita
# <https://gnu.org>.

show_bison_menu() {
  print -P "%K{red}  %k%K{green}  %k%K{yellow}  %k%K{blue}  %k%K{magenta}  %k%K{cyan}  %k%K{white}\
           %k  %K{red}  %k%K{green}  %k%K{yellow}  %k%K{blue}  %k%K{magenta}  %k%K{cyan}  %k%K{white}  %k"
           
  echo -e "\nInstalar Bison: \e[1;36mbison-install\e[0m"
  echo -e "Probar live: \e[1;36mbison-live\e[0m\n"
}