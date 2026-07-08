#!/bin/bash

#######################
# 2. Debug
#

# Includes
source "$(dirname "$0")/lib/ui.sh"

# Select SD Card
select_device
clear

# Check if the user pressed Cancel or closed the dialog
RET=$?
if [ $RET -ne 0 ]; then
    exit 1
fi

# Select Partition
mapfile -t PARTITIONS < <(
    lsblk -lnpo NAME,SIZE,FSTYPE,MOUNTPOINT "$DEVICE" | tail -n +2
)
if [ ${#PARTITIONS[@]} -eq 0 ]; then
    msg "No Partitions" "No partitions found on $DEVICE"
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
    menu "Select Partition" "Choose the partition containing the debug log" "${PART_MENU[@]}"
)
clear

# Check if the user pressed Cancel or closed the dialog
RET=$?
if [ $RET -ne 0 ]; then
    exit 0
fi

# Mount Selected Partition
mount_partition "$PARTITION"

# Locate Debug File
DEBUG_FILE=$(
    sudo find "$MOUNT_POINT" -type f \
        -name "firstboot-debug.txt" \
        2>/dev/null \
        | head -n1
)

if [ -z "$DEBUG_FILE" ]; then
    msg "Debug File Not Found" "Could not find firstboot-debug.txt on:\n\n$PARTITION"
    clear
    exit 1
fi

# Display Debug Log
display "Debug Log" $DEBUG_FILE
clear
exit 0
