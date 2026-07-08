#!/bin/bash

####################################################################################
# Raspberry Pi Provisioner - Main Menu
# This script provides a menu-driven interface for provisioning Raspberry Pi SD cards,
# retrieving debug data, and managing configuration settings.
#

# Configuration file path
CONFIG_FILE="$(dirname "$0")/config.env"

# Create default configuration file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
HOSTNAME=shack-pi-001
DEVICE=/dev/sdb
IP_ADDRESS=10.0.0.50
GATEWAY=10.0.0.1
DNS_SERVERS="10.0.0.1 1.1.1.1"
USERNAME=shackadmin
PASSWORD="your_secure_password_here"
EOF
fi

# Includes
source "$(dirname "$0")/lib/ui.sh"
source "$CONFIG_FILE"

# Main menu loop
while true; do
CHOICE=$(menu "Main Menu" "Select an action" \
    1 "Provision SD Card" \
    2 "Retrieve Debug Data" \
    3 "Configuration" \
    4 "Show Current Config" \
    5 "Remove Known Hosts" \
    6 "Exit")
clear

# Check if the user pressed Cancel or closed the dialog
RET=$?
if [ $RET -ne 0 ]; then
    clear
    break
fi

# Handle menu choices
case $CHOICE in
1)
    ./provision.sh || true
    ;;

2)
    ./debug.sh || true
    ;;

3)
    ./config.sh || true
    source "$CONFIG_FILE"
    ;;

4)
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" <<EOF
Hostname      : $HOSTNAME
Device        : $DEVICE
IP Address    : $IP_ADDRESS
Gateway       : $GATEWAY
DNS Servers   : $DNS_SERVERS
Username      : $USERNAME
Password      : $PASSWORD
EOF

    text "Current Configuration" "$TMPFILE"
    rm -f "$TMPFILE"
    ;;

5)
    remove_host() {
        local host="$1"
        local output

        output=$(ssh-keygen -R "$host" 2>&1)
        local rc=$?

        if [ $rc -ne 0 ]; then
            error "Failed to remove known_hosts entry for $host."
            return 1
        fi

        if grep -q "not found" <<<"$output"; then
            error "No known_hosts entry for $host."
        else
            msg "Removed known_hosts entry for $host"
        fi
    }
    remove_host "$HOSTNAME"
    remove_host "$IP_ADDRESS"
    remove_host "[$IP_ADDRESS]:22"
    ;;
6)
    exit 0
    ;;

esac
done
