#!/bin/bash

#######################
# 7. Debug Log
#

# Includes
source "$(dirname "$0")/lib/ui.sh"

DEBUG_LOG=$(sudo find "/tmp/" -type f \
-name "debug-script-raspberry-pi-sd-provisioning.log" \
2>/dev/null | head -n1)
echo "$DEBUG_LOG"
display "Debug Log" "$DEBUG_LOG"
