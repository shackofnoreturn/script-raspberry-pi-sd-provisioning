#!/bin/bash

#######################
# 1. Provision
#

# Includes
source "$(dirname "$0")/lib/system.sh"
source "$(dirname "$0")/lib/ui.sh"
source ./config.env


# Config
log_debug "Setting up configuration variables..." "DEBUG"
IMG_URL="https://downloads.raspberrypi.com/raspios_lite_armhf_latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="/tmp/pi-image"
CACHE_IMG="$WORKDIR/image"
BOOT_MOUNT="/mnt/pi-boot"
ROOT_MOUNT="/mnt/pi-root"


# Prechecking
log_debug "Checking if $DEVICE is a valid block device..." "DEBUG"
if [[ ! -b "$DEVICE" ]]; then
  error "$DEVICE is not a valid block device."
  exit 1
fi

log_debug "Confirming with user about flashing $DEVICE..." "DEBUG"
DEVICE_INFO=$(lsblk -dno NAME,SIZE,MODEL "$DEVICE")
confirm \
  "Confirm Flash" \
  "Device:
$DEVICE_INFO
All data will be permanently erased.
Continue?"
[[ $? -eq 0 ]] || exit 1
log_debug "User confirmed to proceed with flashing $DEVICE." "DEBUG"


# Setup
log_debug "Setting up progress pipe..." "DEBUG"
PROGRESS_PIPE=$(mktemp -u)
mkfifo "$PROGRESS_PIPE"

# Open the pipe for both reading and writing so it never blocks
exec 3<>"$PROGRESS_PIPE"
log_debug "FIFO Descriptor: $(ls -l /proc/$$/fd/3)" "DEBUG"

# Start dialog reading from the pipe
dialog --gauge "Starting..." 8 70 0 <&3 &
GAUGE_PID=$!
log_debug "Gauge process started with PID: $GAUGE_PID" "DEBUG"

update_progress 5 "Creating working directory..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"
sleep 1


# Downloading
update_progress 10 "Checking image cache..."
if [[ ! -f "$CACHE_IMG" ]]; then
  update_progress 12 "Downloading Raspberry Pi OS..."
  wget -O "$CACHE_IMG" "$IMG_URL"
fi
sleep 1


# Extracting
update_progress 15 "Extracting image..."
TYPE=$(file -b "$CACHE_IMG")
log_debug "Image type: $TYPE" "DEBUG"
IMG_FILE=""

if [[ "$TYPE" == *"boot sector"* ]] || [[ "$TYPE" == *"filesystem"* ]]; then
  IMG_FILE="$CACHE_IMG"
elif [[ "$TYPE" == *"XZ compressed"* ]]; then
  rm -f "$WORKDIR"/image.img
  cp "$CACHE_IMG" image.xz
  unxz -f image.xz
elif [[ "$TYPE" == *"Zip archive"* ]]; then
  cp "$CACHE_IMG" image.zip
  unzip -o image.zip
else
  error "ERROR: Unknown image format: $TYPE"
  exit 1
fi
sleep 1


# Locating
update_progress 20 "Locating image file..."
if [[ -z "$IMG_FILE" ]]; then
  IMG_FILE=$(find "$WORKDIR" -maxdepth 1 -type f -name "image.*" | head -n1)
fi

if [[ -z "$IMG_FILE" ]]; then
  error "ERROR: Could not locate image file"
  exit 1
fi
sleep 1


# Loop device setup
update_progress 25 "Setting up loop device..."
LOOP_DEVICE=$(sudo losetup -Pf --show "$CACHE_IMG")
BOOT_DEVICE="${LOOP_DEVICE}p1"
ROOT_DEVICE="${LOOP_DEVICE}p2"
sleep 1


# Flashing
update_progress 30 "Flashing image to $DEVICE..."
sudo dd if="$IMG_FILE" of="$DEVICE" bs=4M status=progress conv=fsync
sleep 1
update_progress 35 "Flashing complete. Syncing..."
sleep 1
sync
sleep 1


# Wait for partitions
update_progress 40 "Waiting for partitions to be recognized..."
sleep 5
BOOT_PART="${DEVICE}1"
ROOT_PART="${DEVICE}2"
sleep 1


# Mount partitions
update_progress 45 "Mounting partitions..."
sudo mkdir -p "$BOOT_MOUNT"
sudo mkdir -p "$ROOT_MOUNT"
sudo mount "$BOOT_PART" "$BOOT_MOUNT"
sudo mount "$ROOT_PART" "$ROOT_MOUNT"
trap 'sudo umount "$BOOT_MOUNT" 2>/dev/null || true; sudo umount "$ROOT_MOUNT" 2>/dev/null || true' EXIT
sleep 1


# Enable SSH
update_progress 50 "Enabling SSH..."
sudo touch "$BOOT_MOUNT/ssh"
sleep 1


# Creating cmdline.txt
update_progress 55 "Creating cmdline.txt..."
ROOT_DEVICE="${DEVICE}2"
ROOT_PARTUUID=$(sudo blkid -s PARTUUID -o value "$ROOT_DEVICE")
# if [ -z "$ROOT_PARTUUID" ]; then
#     echo "ERROR: Could not determine root PARTUUID"
#     exit 1
# fi
sudo sed -i "s/__ROOT_PARTUUID__/${ROOT_PARTUUID}/" "$BOOT_MOUNT/cmdline.txt"
sleep 1


# Creating config.txt
update_progress 60 "Creating config.txt..."
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  "$SCRIPT_DIR/files/bootfs/config.txt" \
  | sudo tee "$BOOT_MOUNT/config.txt" >/dev/null
sleep 1


# Creating meta-data
update_progress 65 "Creating meta-data..."
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  "$SCRIPT_DIR/files/bootfs/meta-data" \
  | sudo tee "$BOOT_MOUNT/meta-data" >/dev/null
sleep 1


# Creating network-config
update_progress 70 "Creating network-config..."
IFS=',' read -ra DNS <<< "$DNS_SERVERS"
DNS1=$(echo "${DNS[0]}" | xargs)
DNS2=$(echo "${DNS[1]}" | xargs)
sed \
  -e "s|__IP_ADDRESS__|$IP_ADDRESS|g" \
  -e "s|__GATEWAY__|$GATEWAY|g" \
  -e "s|__DNS1__|$DNS1|g" \
  -e "s|__DNS2__|$DNS2|g" \
  "$SCRIPT_DIR/files/bootfs/network-config" \
  | sudo tee "$BOOT_MOUNT/network-config" >/dev/null
sleep 1


# Creating user-data
update_progress 75 "Creating user-data..."
PASSWORD_HASH=$(openssl passwd -6 "$PASSWORD")
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  -e "s|__USERNAME__|$USERNAME|g" \
  -e "s|__PASSWORD_HASH__|$PASSWORD_HASH|g" \
  "$SCRIPT_DIR/files/bootfs/user-data" \
  | sudo tee "$BOOT_MOUNT/user-data" >/dev/null
sleep 1


# First Boot Debug
update_progress 80 "Creating first boot debug script..."
sudo mkdir -p "$ROOT_MOUNT/usr/local/sbin"
IFS=',' read -ra DNS <<< "$DNS_SERVERS"
DNS1=$(echo "${DNS[0]}" | xargs)
DNS2=$(echo "${DNS[1]}" | xargs)
sed \
  -e "s|__IP_ADDRESS__|$IP_ADDRESS|g" \
  -e "s|__GATEWAY__|$GATEWAY|g" \
  -e "s|__DNS1__|$DNS1|g" \
  -e "s|__DNS2__|$DNS2|g" \
  "$SCRIPT_DIR/files/rootfs/usr/local/sbin/firstboot-debug.sh" \
  | sudo tee "$ROOT_MOUNT/usr/local/sbin/firstboot-debug.sh" >/dev/null
sleep 1


# Make executable
update_progress 85 "Making firstboot-debug.sh executable..."
sudo chmod +x "$ROOT_MOUNT/usr/local/sbin/firstboot-debug.sh"
sleep 1


# Create systemd service
update_progress 90 "Creating firstboot-debug.service..."
IFS=',' read -ra DNS <<< "$DNS_SERVERS"
DNS1=$(echo "${DNS[0]}" | xargs)
DNS2=$(echo "${DNS[1]}" | xargs)
sed \
  -e "s|__IP_ADDRESS__|$IP_ADDRESS|g" \
  -e "s|__GATEWAY__|$GATEWAY|g" \
  -e "s|__DNS1__|$DNS1|g" \
  -e "s|__DNS2__|$DNS2|g" \
  "$SCRIPT_DIR/files/rootfs/etc/systemd/system/firstboot-debug.service" \
  | sudo tee "$ROOT_MOUNT/etc/systemd/system/firstboot-debug.service" >/dev/null
sleep 1


# Enable service
update_progress 95 "Enabling firstboot-debug.service..."
sudo mkdir -p \
  "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants"

sudo ln -sf \
  /etc/systemd/system/firstboot-debug.service \
  "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants/firstboot-debug.service"
sleep 1


# Completion
update_progress 100 "Provisioning complete."
sleep 1


# Cleanup
text "Cleanup" "Syncing..."
sync
sleep 1

text "Cleanup" "Unmounting partitions..."
sudo umount "$BOOT_MOUNT"
sudo umount "$ROOT_MOUNT"

text "Cleanup" "Detaching loop device..."
trap - EXIT
text "Cleanup" "Executing losetup detach..."
exec 3>&-

text "Cleanup" "Killing gauge process..."
kill -9 "$GAUGE_PID" 2>/dev/null
text "Cleanup" "Waiting for gauge process to exit..."
wait "$GAUGE_PID" 2>/dev/null || true
text "Cleanup" "Removing progress pipe..."
rm -f "$PROGRESS_PIPE"
sleep 1


# Final Message
msg "Provisioning Complete" \
    "SD card successfully prepared.

Hostname: $HOSTNAME
IP Address: $IP_ADDRESS
Username: $USERNAME

SSH Command: ssh ${USERNAME}@${IP_ADDRESS}"
