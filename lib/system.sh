#!/bin/bash

# Debug Logging
log_debug() {
    local message="$1"
    local type="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] $message" >> /tmp/debug-script-raspberry-pi-sd-provisioning.log
}
