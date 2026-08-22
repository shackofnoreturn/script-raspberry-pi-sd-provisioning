#!/bin/bash

#######################
# 4. Show Current Config
#

# Includes
source "$(dirname "$0")/lib/ui.sh"

# Configuration file path
CONFIG_FILE="$(dirname "$0")/config.env"

# Load configuration
source "$CONFIG_FILE"

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
