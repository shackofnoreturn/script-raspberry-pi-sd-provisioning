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

## Display Box
display() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Info}" \
         --textbox "$2" 30 120
}

## Info Box
info() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$1" \
        --infobox "$2" \
        8 60
}

## Error Box
error() {
  dialog \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Error" \
      --msgbox "$1" \
      12 70
}

## Input Box
input() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Input}" \
         --inputbox "$2" 10 60 "${3:-}" \
         3>&1 1>&2 2>&3
}

## Password Box
## Input Box
secure() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Input}" \
         --insecure \
         --passwordbox "$2" 10 60 "${3:-}" \
         3>&1 1>&2 2>&3
}

## Yes/No Prompt
confirm() {
  dialog --backtitle "$BACKTITLE" \
         --title "${1:-Confirm}" \
         --yesno "$2" 10 60
}

# Progress Bar
progress() {
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
# update_progress() {

#     local pct="$1"
#     local msg="$2"

#     {
#         echo "XXX"
#         echo "$pct"
#         echo "$msg"
#         echo "XXX"
#     } > "$PROGRESS_PIPE"

# }

update_progress() {
    local percent="$1"
    local text="$2"

    printf '%s\nXXX\n%s\nXXX\n' \
        "$percent" \
        "$text" >&3
}

# update_progress() {
#     echo "Writing progress..."
#     printf "%s\nXXX\n%s\nXXX\n" "$1" "$2" >&3
#     echo "Progress written"
# }

## Debug Logging
log_debug() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $message" >> /tmp/debug.log
}
