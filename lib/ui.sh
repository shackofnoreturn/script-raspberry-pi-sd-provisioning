#!/bin/bash
set -euo pipefail

# Global UI Variables
BACKTITLE="Pi Provisioner"

# Shared UI Functions
## Message Box
msg() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Info}" \
         --msgbox "$2" 10 60
}

## Text Box
text() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Info}" \
         --textbox "$2" 15 60
}

## Input Box
input() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Input}" \
         --inputbox "$2" 10 60 "${3:-}" \
         3>&1 1>&2 2>&3
}

## YES/NO Prompt
confirm() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Confirm}" \
         --yesno "$2" 10 60
}

## Menu Wrapper
menu() {
  dialog --clear \
         --backtitle "$BACKTITLE" \
         --title "$1" \
         --menu "$2" 20 70 10 "${@:3}" 3>&1 1>&2 2>&3
}

## Device Selection
select_device() {
  mapfile -t DEVICES < <(
      lsblk -dpno NAME,SIZE,MODEL,TRAN |
      grep -E 'usb|mmc'
  )

  MENU_ITEMS=()
  for DEV in "${DEVICES[@]}"; do
      NAME=$(echo "$DEV" | awk '{print $1}')
      DESC=$(echo "$DEV" | cut -d' ' -f2-)

      MENU_ITEMS+=("$NAME" "$DESC")
  done

  DEVICE=$(menu "Select SD Card" "Choose target device" "${MENU_ITEMS[@]}")
}

# Helpers
## Mounting
mount_partition() {
  local part="$1"

  MNT=$(mktemp -d)

  sudo mount "$part" "$MNT" || return 1

  echo "$MNT"
}

## Debug file resolver
find_debug_file() {
  local root="$1"

  for p in \
    "$root/boot/firstboot-debug.txt" \
    "$root/firstboot-debug.txt" \
    "$root/boot/firmware/firstboot-debug.txt"
  do
    [ -f "$p" ] && echo "$p" && return 0
  done

  return 1
}
