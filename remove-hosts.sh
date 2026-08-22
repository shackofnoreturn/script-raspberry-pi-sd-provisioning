#!/bin/bash

#######################
# 5. Remove Known Hosts
#

# Includes
source "$(dirname "$0")/lib/ui.sh"

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
