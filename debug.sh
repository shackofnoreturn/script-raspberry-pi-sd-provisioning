#!/bin/bash

#######################
# 2. Debug
#

# Includes
source "$(dirname "$0")/lib/ui.sh"

if ! command -v dialog >/dev/null 2>&1; then
    echo "dialog is not installed."
    echo "Install it with:"
    echo "sudo pacman -S dialog"
    exit 1
fi

# Select SD Card
mapfile -t DEVICES < <(
    lsblk -dpno NAME,SIZE,MODEL,TRAN |
    grep -E 'usb|mmc'
)

if [ ${#DEVICES[@]} -eq 0 ]; then
    dialog \
        --backtitle "$BACKTITLE" \
        --title "Debug Viewer" \
        --msgbox "No removable devices detected." \
        8 50
    clear
    exit 1
fi

MENU_ITEMS=()

for DEV in "${DEVICES[@]}"; do
    NAME=$(echo "$DEV" | awk '{print $1}')
    DESC=$(echo "$DEV" | cut -d' ' -f2-)

    MENU_ITEMS+=("$NAME" "$DESC")
done

DEBUG_DEVICE=$(
    dialog \
        --clear \
        --backtitle "$BACKTITLE" \
        --title "Select SD Card" \
        --menu "Choose the Raspberry Pi SD card" \
        20 100 10 \
        "${MENU_ITEMS[@]}" \
        3>&1 1>&2 2>&3
)

RET=$?

clear

if [ $RET -ne 0 ]; then
    exit 0
fi

# Select Partition
mapfile -t PARTITIONS < <(
    lsblk -lnpo NAME,SIZE,FSTYPE,MOUNTPOINT "$DEBUG_DEVICE" | tail -n +2
)

if [ ${#PARTITIONS[@]} -eq 0 ]; then
    dialog \
        --backtitle "$BACKTITLE" \
        --title "Error" \
        --msgbox "No partitions found on $DEBUG_DEVICE" \
        8 60
    clear
    exit 1
fi

PART_MENU=()

for PART in "${PARTITIONS[@]}"; do
    PART_NAME=$(echo "$PART" | awk '{print $1}')
    PART_DESC=$(echo "$PART" | cut -d' ' -f2-)

    PART_MENU+=("$PART_NAME" "$PART_DESC")
done

PARTITION=$(
    dialog \
        --backtitle "$BACKTITLE" \
        --title "Select Partition" \
        --menu "Choose the partition containing the debug log" \
        20 100 10 \
        "${PART_MENU[@]}" \
        3>&1 1>&2 2>&3
)

RET=$?

clear

if [ $RET -ne 0 ]; then
    exit 0
fi

# Mount Selected Partition
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

# Locate Debug File
DEBUG_FILE=$(
    sudo find "$MOUNT_POINT" -type f \
        -name "firstboot-debug.txt" \
        2>/dev/null \
        | head -n1
)

if [ -z "$DEBUG_FILE" ]; then
    dialog \
        --backtitle "$BACKTITLE" \
        --title "Debug File Not Found" \
        --msgbox \
        "Could not find firstboot-debug.txt anywhere on:\n\n$PARTITION" \
        12 70

    clear
    exit 1
fi

# Display Debug Log
dialog \
    --backtitle "$BACKTITLE" \
    --title "First Boot Debug" \
    --textbox "$DEBUG_FILE" \
    30 120

clear
exit 0
