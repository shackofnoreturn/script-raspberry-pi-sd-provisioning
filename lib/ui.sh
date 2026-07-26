#!/bin/bash

# Includes
source "system.sh"

# Global UI Variables
BACKTITLE="Pi Provisioner"

# Shared UI Functions
## Message Box
msg() {
  log_debug "$1 - $2 (msg)" "INFO"
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Info}" \
         --msgbox "$2" 10 60
}

## Text Box
text() {
  log_debug "$1 - $2 (text)" "INFO"
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Info}" \
         --textbox "$2" 15 60
}

## Display Box
display() {
  log_debug "$1 - $2 (display)" "INFO"
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Info}" \
         --textbox "$2" 30 120
}

## Info Box
info() {
  log_debug "$1 - $2 (info)" "INFO"
  dialog \
      --backtitle "$BACKTITLE" \
      --title "$1" \
      --infobox "$2" \
      8 60
}

## Error Box
error() {
  log_debug "$1 (error)" "ERROR"
  dialog \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Error" \
      --msgbox "$1" \
      12 70
}

## Input Box
input() {
  log_debug "$1 - $2 - $3 (input)" "INFO"
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Input}" \
         --inputbox "$2" 10 60 "${3:-}" \
         3>&1 1>&2 2>&3
}

## Password Box
## Input Box
secure() {
  log_debug "$1 - $2 - $3 (secure)" "INFO"
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Input}" \
         --insecure \
         --passwordbox "$2" 10 60 "${3:-}" \
         3>&1 1>&2 2>&3
}

## Yes/No Prompt
confirm() {
  log_debug "$1 - $2 (confirm)" "INFO"
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Confirm}" \
         --yesno "$2" 10 60
}

# Progress Bar
progress() {
  log_debug "$1 - $2 (progress)" "INFO"
  local percent="$1"
  local message="$2"

  {
      echo "XXX"
      echo "$percent"
      echo "$message"
      echo "XXX"
  } > "$PROGRESS_PIPE"
}

## Menu Wrapper
menu() {
  log_debug "$1 - $2 - $3 (menu)" "INFO"
  dialog --clear \
         --backtitle "$BACKTITLE" \
         --title "$1" \
         --menu "$2" 20 70 10 "${@:3}" 3>&1 1>&2 2>&3
}

## Device Selection
select_device() {
  log_debug "Selecting device" "INFO"

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
  log_debug "Mounting partition $1" "INFO"
  local part="$1"

  MOUNT_POINT=$(mktemp -d)

  cleanup() {
    if mountpoint -q "$MOUNT_POINT"; then
        sudo umount "$MOUNT_POINT" >/dev/null 2>&1 || true
    fi

    rmdir "$MOUNT_POINT" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  if ! sudo mount "$PARTITION" "$MOUNT_POINT"; then
    dialog \
        --backtitle "$BACKTITLE" \
        --title "Mount Failed" \
        --msgbox "Failed to mount:\n\n$PARTITION" \
        10 60
    clear
    exit 1
  fi
  echo "$MOUNT_POINT"
}

## Update Progress Bar
update_progress() {
  log_debug "Updating progress: $1% - $2" "INFO"
  local percent="$1"
  local text="$2"

  printf '%s\nXXX\n%s\nXXX\n' \
      "$percent" \
      "$text" >&3
}
