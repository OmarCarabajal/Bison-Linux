#!/bin/bash
# BISON - Funciones comunes

cat > /tmp/bison-dialogrc <<'DIALOGRC'
screen_color = (WHITE,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,ON)
title_color = (WHITE,RED,ON)
border_color = (WHITE,BLACK,ON)
button_active_color = (BLACK,WHITE,ON)
button_inactive_color = (WHITE,BLACK,ON)
button_key_active_color = (BLACK,WHITE,ON)
button_key_inactive_color = (WHITE,BLACK,ON)
button_label_active_color = (BLACK,WHITE,ON)
button_label_inactive_color = (WHITE,BLACK,ON)
inputbox_color = (WHITE,BLACK,ON)
inputbox_border_color = (WHITE,BLACK,ON)
searchbox_color = (WHITE,BLACK,ON)
searchbox_title_color = (WHITE,BLACK,ON)
searchbox_border_color = (WHITE,BLACK,ON)
position_indicator_color = (WHITE,BLACK,ON)
menubox_color = (WHITE,BLACK,ON)
menubox_border_color = (WHITE,BLACK,ON)
item_color = (WHITE,BLACK,ON)
item_selected_color = (BLACK,WHITE,ON)
tag_color = (WHITE,BLACK,ON)
tag_selected_color = (BLACK,WHITE,ON)
tag_key_color = (WHITE,BLACK,ON)
tag_key_selected_color = (BLACK,WHITE,ON)
check_color = (WHITE,BLACK,ON)
check_selected_color = (BLACK,WHITE,ON)
uarrow_color = (WHITE,BLACK,ON)
darrow_color = (WHITE,BLACK,ON)
itemhelp_color = (WHITE,BLACK,ON)
form_active_text_color = (WHITE,BLACK,ON)
form_text_color = (WHITE,BLACK,ON)
form_item_readonly_color = (WHITE,BLACK,ON)
gauge_color = (WHITE,BLACK,ON)
border2_color = (WHITE,BLACK,ON)
inputbox_border2_color = (WHITE,BLACK,ON)
searchbox_border2_color = (WHITE,BLACK,ON)
menubox_border2_color = (WHITE,BLACK,ON)
DIALOGRC
export DIALOGRC=/tmp/bison-dialogrc

MODO_PART="auto"
PART_EFI_MANUAL=""
PART_ROOT_MANUAL=""
MODO_FIRMWARE=""
DISCO=""
KEYMAP=""
HOSTNAME=""
USUARIO=""
PASS_ROOT=""
PASS_USER=""

# Detectar UEFI / Legacy
if [ -d /sys/firmware/efi ]; then
  MODO_FIRMWARE="uefi"
else
  MODO_FIRMWARE="legacy"
fi

MENU_CMD="/bin/zsh"

verificar_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Tenés que ser root para instalar Bison."
    exit 1
  fi
}

verificar_dialog() {
  if ! command -v dialog &>/dev/null; then
    echo "Falta dialog. Instalalo con: pacman -S dialog"
    exit 1
  fi
}

msg() {
  dialog --clear --title " Bison Linux " --ok-label "Ok" --msgbox "$1" 12 70
}

volver_al_menu() {
  if mountpoint -q /mnt 2>/dev/null; then
    umount -R /mnt 2>/dev/null || true
  fi
  swapoff -a 2>/dev/null || true
  clear
  exec "$MENU_CMD"
}

# RC: 0=Ok, 1=Atras, 3=Cancel
# Devuelve: 0=seguir, 1=atras, 2=quedarse (eligio seguir instalando)
check_cancel() {
  local ret=$1
  if [ "$ret" -eq 0 ]; then
    return 0
  fi
  if [ "$ret" -eq 1 ]; then
    return 1
  fi
  if [ "$ret" -eq 3 ]; then
    local OPCION
    OPCION=$(dialog --clear --title " ¿Cancelar instalación? " --stdout \
      --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
      --no-tags --menu "¿Seguro querés cancelar la instalación?\n\nUsá ↑ ↓ para elegir, Enter para confirmar." 16 70 2 \
      "si" "Cancelar e ir al menú" \
      "no" "Seguir instalando")
    local rc2=$?
    if [ "$rc2" -eq 3 ] || [ "$OPCION" = "si" ]; then
      dialog --clear --title " Bison Linux " --ok-label "Ok" --infobox "Cancelando... volviendo al menú principal." 8 70
      sleep 1
      volver_al_menu
    fi
    return 2
  fi
  return 2
}
