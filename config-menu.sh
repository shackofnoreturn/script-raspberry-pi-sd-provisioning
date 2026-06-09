#!/bin/bash

#######################
# 3. Configuration
#

# Target Device Helper Function
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

    DEVICE_NAME=$(dialog \
        --title "Select SD Card" \
        --menu "Choose target device" \
        20 100 10 \
        "${MENU_ITEMS[@]}" \
        3>&1 1>&2 2>&3)
}

# Configuration file path
CONFIG_FILE="$(dirname "$0")/config.env"

# Load configuration
source "$CONFIG_FILE"

# Configuration menu loop
while true; do
CHOICE=$(dialog \
    --title "Configuration" \
    --menu "Select setting" \
    20 70 10 \
    1 "Hostname: $HOSTNAME" \
    2 "Target Device: $DEVICE_NAME" \
    3 "IP Address: $IP_ADDRESS" \
    4 "Gateway: $GATEWAY" \
    5 "DNS Servers: $DNS_SERVERS" \
    6 "Save and Return" \
    3>&1 1>&2 2>&3)
RET=$?

# Check if the user pressed Cancel or closed the dialog
if [ $RET -ne 0 ]; then
    break
fi

# Handle menu choices
case $CHOICE in
1)
HOSTNAME=$(dialog \
    --inputbox "Hostname" \
    8 60 "$HOSTNAME" \
    3>&1 1>&2 2>&3)
;;

2)
select_device
;;

3)
IP_ADDRESS=$(dialog \
    --inputbox "IP Address" \
    8 60 "$IP_ADDRESS" \
    3>&1 1>&2 2>&3)
;;

4)
GATEWAY=$(dialog \
    --inputbox "Gateway" \
    8 60 "$GATEWAY" \
    3>&1 1>&2 2>&3)
;;

5)
DNS_SERVERS=$(dialog \
    --inputbox "DNS Servers" \
    8 60 "$DNS_SERVERS" \
    3>&1 1>&2 2>&3)
;;

6)
cat > "$CONFIG_FILE" <<EOF
HOSTNAME=$HOSTNAME
DEVICE_NAME="$DEVICE_NAME"
IP_ADDRESS=$IP_ADDRESS
GATEWAY=$GATEWAY
DNS_SERVERS="$DNS_SERVERS"
EOF
break
;;

esac
done
clear
