#!/bin/bash

####################################################################################
# Raspberry Pi Provisioner - Main Menu
# This script provides a menu-driven interface for provisioning Raspberry Pi SD cards,
# retrieving debug data, and managing configuration settings.
#

# Configuration
set -euo pipefail
CONFIG_FILE="$(dirname "$0")/config.env"

# Default configuration
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
HOSTNAME=shack-dns-p001
DEVICE=/dev/sdb
IP_ADDRESS=10.0.0.6
GATEWAY=10.0.0.1
DNS_SERVERS="10.0.0.1 10.0.0.6"
USERNAME=shackadmin
PASSWORD="your_secure_password_here"
EOF
fi

# Includes
source "$CONFIG_FILE"
source "$(dirname "$0")/lib/ui.sh"


# Main menu
while true; do
    if MAINMENU=$(menu "Main Menu" "Select an action" \
        1 "Provision SD Card" \
        2 "Retrieve Debug Data" \
        3 "Configuration" \
        4 "Show Current Config" \
        5 "Remove Known Hosts" \
        6 "Launch SSH Session" \
        7 "Debug Log" \
        8 "Exit"); then
    
        # Menu completed successfully
        :

    else
        # User cancelled or closed the dialog
        clear
        break
    fi

    clear

    # Handle choices
    case $MAINMENU in
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
            ./config-display.sh || true
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
                    msg "Remove Known Host" "Removed known_hosts entry for $host"
                fi
            }
            remove_host "$HOSTNAME"
            remove_host "$IP_ADDRESS"
            remove_host "[$IP_ADDRESS]:22"
            ;;
        6)
            ssh ${USERNAME}@${IP_ADDRESS}
            ;;
        7)
            DEBUG_LOG=$(sudo find "/tmp/" -type f \
            -name "debug-script-raspberry-pi-sd-provisioning.log" \
            2>/dev/null | head -n1)
            echo "$DEBUG_LOG"
            display "Debug Log" "$DEBUG_LOG"
            ;;
        8)
            clear
            exit 0
            ;;
    esac
done
