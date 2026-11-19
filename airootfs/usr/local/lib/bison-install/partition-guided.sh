#!/bin/bash
# BISON - Particionado guiado
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


particionado_guiado() {
  local TAM_EFI="512"
  local TAM_ROOT=""
  local TAM_HOME=""
  local TAM_SWAP=""

  # --- Tamaño del disco en MB ---
  # DISCO viene de disk.sh
  local DISCO_BYTES
  DISCO_BYTES=$(lsblk -b -d -o SIZE -n "$DISCO" 2>/dev/null | tr -d ' ')
  [ -z "$DISCO_BYTES" ] && DISCO_BYTES=0
  local DISCO_MB=$((DISCO_BYTES / 1048576))
  # Para mostrar en GB, redondeo simple
  local DISCO_GB=$((DISCO_MB / 1024))
  [ "$DISCO_GB" -eq 0 ] && DISCO_GB=0

  # --- Helper: calcula libre en MB según lo ya elegido ---
  # variables globales temporales: _EFI_MB _ROOT_MB _HOME_MB _SWAP_MB
  _calc_libre() {
    local usado=0
    if [ "$MODO_FIRMWARE" = "uefi" ]; then
      usado=$((usado + ${TAM_EFI:-0}))
    fi
    usado=$((usado + ${TAM_ROOT:-0} * 1024))
    usado=$((usado + ${TAM_HOME:-0} * 1024))
    usado=$((usado + ${TAM_SWAP:-0} * 1024))
    echo $((DISCO_MB - usado))
  }

  _fmt_gb() {
    # $1 = MB -> "X.YG" aprox, muestra GB enteros + resto
    local mb=$1
    local gb=$((mb / 1024))
    local resto=$(((mb % 1024) * 10 / 1024))
    echo "${gb}.${resto}G"
  }

  # --- Flujo por pasos, con Atrás = paso anterior ---
  # paso 0=EFI (solo UEFI), 1=ROOT, 2=HOME, 3=SWAP, 4=Resumen/Validar
  local paso=0
  if [ "$MODO_FIRMWARE" != "uefi" ]; then
    paso=1
  fi

  while true; do
    # Paso EFI
    if [ "$paso" -eq 0 ]; then
      local libre_mb
      libre_mb=$(_calc_libre)
      local libre_txt
      libre_txt=$(_fmt_gb "$libre_mb")
      TAM_EFI=$(dialog --clear --title " Partición EFI " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "Tamaño de la partición EFI en MB:\n\nRecomendado: 512\n\nDisco: ${DISCO_GB}G | Libre: $libre_txt" 14 60 "$TAM_EFI")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      if [ $CC -eq 2 ]; then
        # Atrás en primer paso = volver al menú anterior (disk/partition)
        return 2
      fi
      if ! echo "$TAM_EFI" | grep -Eq '^[0-9]+$'; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Poné solo un número." 8 60
        continue
      fi
      paso=1
      continue
    fi

    # ---- Paso ROOT ----
    if [ "$paso" -eq 1 ]; then
      # Para mostrar libre, no contar ROOT todavía si es primera vez
      local libre_mb
      # Si TAM_ROOT ya tiene valor (volvimos con Atrás), restarlo para mostrar libre real antes de pedir
      local tmp_root="$TAM_ROOT"
      TAM_ROOT=""
      libre_mb=$(_calc_libre)
      TAM_ROOT="$tmp_root"
      local libre_txt
      libre_txt=$(_fmt_gb "$libre_mb")
      local def_root="${TAM_ROOT:-20}"
      TAM_ROOT=$(dialog --clear --title " Partición / " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "\nTamaño de la partición raíz (/) en GB:\n\nDisco: ${DISCO_GB}G | Libre: $libre_txt\n" 14 60 "$def_root")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      if [ $CC -eq 2 ]; then
        if [ "$MODO_FIRMWARE" = "uefi" ]; then paso=0; else return 2; fi
        continue
      fi
      if ! echo "$TAM_ROOT" | grep -Eq '^[0-9]+$'; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Poné solo un número. Ej: 20" 8 60
        TAM_ROOT=""
        continue
      fi
      paso=2
      continue
    fi

    # ---- Paso HOME ----
    if [ "$paso" -eq 2 ]; then
      local tmp_home="$TAM_HOME"
      TAM_HOME=""
      local libre_mb
      libre_mb=$(_calc_libre)
      TAM_HOME="$tmp_home"
      local libre_txt
      libre_txt=$(_fmt_gb "$libre_mb")
      local def_home="${TAM_HOME:-10}"
      TAM_HOME=$(dialog --clear --title " Partición /home " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "Tamaño de /home en GB:\n\nPoné 0 para no crear /home separado.\n\nDisco: ${DISCO_GB}G | Libre: $libre_txt\n" 14 60 "$def_home")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      if [ $CC -eq 2 ]; then paso=1; continue; fi
      if ! echo "$TAM_HOME" | grep -Eq '^[0-9]+$'; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Poné solo un número. Ej: 10 o 0" 8 60
        TAM_HOME=""
        continue
      fi
      paso=3
      continue
    fi

    # ---- Paso SWAP ----
    if [ "$paso" -eq 3 ]; then
      local tmp_swap="$TAM_SWAP"
      TAM_SWAP=""
      local libre_mb
      libre_mb=$(_calc_libre)
      TAM_SWAP="$tmp_swap"
      local libre_txt
      libre_txt=$(_fmt_gb "$libre_mb")
      local def_swap="${TAM_SWAP:-2}"
      TAM_SWAP=$(dialog --clear --title " Partición swap " --stdout \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --inputbox "Tamaño de SWAP en GB:\n\nPoné 0 para no crear SWAP.\n\n\nDisco: ${DISCO_GB}G | Libre: $libre_txt\n" 14 60 "$def_swap")
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      if [ $CC -eq 2 ]; then paso=2; continue; fi
      if ! echo "$TAM_SWAP" | grep -Eq '^[0-9]+$'; then
        dialog --clear --title " Error " --ok-label "Ok" --msgbox "Poné solo un número. Ej: 2 o 0" 8 60
        TAM_SWAP=""
        continue
      fi
      paso=4
      continue
    fi

    # ---- Paso 4: Resumen + Validación LIBRE >= 1G ----
    if [ "$paso" -eq 4 ]; then
      local libre_mb
      libre_mb=$(_calc_libre)
      local libre_txt
      libre_txt=$(_fmt_gb "$libre_mb")
      local usado_mb=$((DISCO_MB - libre_mb))
      local usado_txt
      usado_txt=$(_fmt_gb "$usado_mb")

      # Construir resumen 
      local resumen="Disco: $DISCO - ${DISCO_GB}G\n\n"
      if [ "$MODO_FIRMWARE" = "uefi" ]; then
        resumen="${resumen}efi  ${TAM_EFI}M\n"
        resumen="${resumen}/ ${TAM_ROOT}G\n"
      else
        resumen="${resumen}/ ${TAM_ROOT}G\n"
      fi

      if [ "$TAM_HOME" != "0" ] && [ -n "$TAM_HOME" ]; then
        resumen="${resumen}/home ${TAM_HOME}G\n"
      else
        resumen="${resumen}home adentro de /\n"
      fi
      if [ "$TAM_SWAP" != "0" ] && [ -n "$TAM_SWAP" ]; then
        resumen="${resumen}swap ${TAM_SWAP}G\n"
      else
        resumen="${resumen}sin swap\n"
      fi
      resumen="${resumen}\nUsado: $usado_txt\nLibre: $libre_txt\n"

      # Validación: hay que dejar al menos 1G libre
      if [ "$libre_mb" -lt 1024 ]; then
        dialog --clear --title " Error: Sin espacio libre " --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
          --msgbox "Te pasaste del disco.\n\n${resumen}\nTenés que dejar al menos 1G libre para tabla y alineación.\n\nBajá HOME o ROOT.\n\n<Atrás> para corregir." 18 62
        RC=$?
        check_cancel $RC
        CC=$?
        [ $CC -eq 1 ] && return 1
        # Tanto Ok como Atrás vuelven a corregir HOME
        paso=2
        continue
      fi

      # Confirmar esquema
      dialog --clear --title " Resumen guided | Libre: $libre_txt " \
        --ok-label "Ok" --cancel-label "Atrás" --extra-button --extra-label "Cancel" \
        --yesno "${resumen}\n¿Crear particiones con este esquema?" 18 62
      RC=$?
      check_cancel $RC
      CC=$?
      [ $CC -eq 1 ] && return 1
      if [ $CC -eq 2 ]; then paso=3; continue; fi
      # Ok -> guardar y salir
      break
    fi
  done

  GUIDED_EFI_MB="$TAM_EFI"
  GUIDED_ROOT_GB="$TAM_ROOT"
  GUIDED_HOME_GB="$TAM_HOME"
  GUIDED_SWAP_GB="$TAM_SWAP"
  MODO_PART="guided"
  return 0
}