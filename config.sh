#!/bin/bash

#######################
# 3. Configuration
#

# Includes
source "$(dirname "$0")/lib/ui.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/config.env"

# Load configuration
source "$CONFIG_FILE"

# Configuration menu loop
while true; do
CHOICE=$(menu "Configuration" "Select setting to edit" \
    1 "Hostname: $HOSTNAME" \
    2 "Target Device: $DEVICE" \
    3 "IP Address: $IP_ADDRESS" \
    4 "Gateway: $GATEWAY" \
    5 "DNS Servers: $DNS_SERVERS" \
    6 "Username: $USERNAME" \
    7 "Password: $PASSWORD" \
    8 "Save and Return")

# Check if the user pressed Cancel or closed the dialog
RET=$?
if [ $RET -ne 0 ]; then
    break
fi

# Handle menu choices
case $CHOICE in
1)
HOSTNAME=$(input "Hostname" "Enter the hostname for the Raspberry Pi" "$HOSTNAME")
;;

2)
select_device
;;

3)
IP_ADDRESS=$(input "IP Address" "Enter the static IP address for the Raspberry Pi" "$IP_ADDRESS")
;;

4)
GATEWAY=$(input "Gateway" "Enter the gateway IP address for the Raspberry Pi" "$GATEWAY")
;;

5)
DNS_SERVERS=$(input "DNS Servers" "Enter comma-separated DNS servers for the Raspberry Pi" "$DNS_SERVERS")
;;

6)
USERNAME=$(input "Username" "Enter the username for the Raspberry Pi" "$USERNAME")
;;

7)
PASSWORD=$(input "Password" "Enter the password for the Raspberry Pi" "$PASSWORD")
;;

8)
cat > "$CONFIG_FILE" <<EOF
HOSTNAME=$HOSTNAME
DEVICE="$DEVICE"
IP_ADDRESS=$IP_ADDRESS
GATEWAY=$GATEWAY
DNS_SERVERS="$DNS_SERVERS"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
EOF
break
;;

esac
done
clear
