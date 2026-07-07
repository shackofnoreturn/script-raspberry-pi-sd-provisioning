#!/bin/bash

#######################
# 1. Provision
#

# Includes
source "$(dirname "$0")/lib/ui.sh"
source ./config.env

# Config
IMG_URL="https://downloads.raspberrypi.com/raspios_lite_armhf_latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="/tmp/pi-image"
CACHE_IMG="$WORKDIR/image"
LOOP_DEVICE=$(sudo losetup -Pf --show "$CACHE_IMG")
BOOT_DEVICE="${LOOP_DEVICE}p1"
ROOT_DEVICE="${LOOP_DEVICE}p2"
BOOT_MOUNT="/mnt/pi-boot"
ROOT_MOUNT="/mnt/pi-root"

# Prechecking
if [[ ! -b "$DEVICE" ]]; then
  error "$DEVICE is not a valid block device."
  exit 1
fi

DEVICE_INFO=$(lsblk -dno NAME,SIZE,MODEL "$DEVICE")
confirm \
  "Confirm Flash" \
  "Device:
$DEVICE_INFO
All data will be permanently erased.
Continue?"
[[ $? -eq 0 ]] || exit 0

# Setup
PROGRESS_PIPE=$(mktemp -u)
mkfifo "$PROGRESS_PIPE"
dialog \
    --backtitle "$BACKTITLE" \
    --title "Provisioning Raspberry Pi" \
    --gauge "Starting..." \
    10 70 0 < "$PROGRESS_PIPE" &
GAUGE_PID=$!

update_progress 1 "Creating working directory..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Downloading
update_progress 5 "Checking image cache..."
if [[ ! -f "$CACHE_IMG" ]]; then
  update_progress 15 "Downloading Raspberry Pi OS..."
  wget -O "$CACHE_IMG" "$IMG_URL"
fi

# Extracting
update_progress 30 "Extracting image..."
TYPE=$(file -b "$CACHE_IMG")
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

# Locating
update_progress 40 "Locating image file..."
if [[ -z "$IMG_FILE" ]]; then
  IMG_FILE=$(find "$WORKDIR" -maxdepth 1 -type f -name "*.img" | head -n1)

  if [[ -z "$IMG_FILE" ]]; then
    IMG_FILE=$(find "$WORKDIR" -maxdepth 1 -type f \
      ! -name "*.xz" \
      ! -name "*.zip" \
      -exec file {} \; | \
      grep -i "boot sector\|filesystem" | \
      head -n1 | cut -d: -f1)
  fi
fi

if [[ -z "$IMG_FILE" ]]; then
  error "ERROR: Could not locate image file"
  exit 1
fi

# Flashing
update_progress 50 "Flashing image to $DEVICE..."
sudo dd if="$IMG_FILE" of="$DEVICE" bs=4M status=progress conv=fsync

sync


# Wait for partitions
# update_progress 55 "Waiting for partitions to be recognized..."
sleep 5

BOOT_PART="${DEVICE}1"
ROOT_PART="${DEVICE}2"


# Mount partitions
# update_progress 58 "Mounting partitions..."
sudo mkdir -p "$BOOT_MOUNT"
sudo mkdir -p "$ROOT_MOUNT"
sudo mount "$BOOT_PART" "$BOOT_MOUNT"
sudo mount "$ROOT_PART" "$ROOT_MOUNT"

trap 'sudo umount "$BOOT_MOUNT" 2>/dev/null || true; sudo umount "$ROOT_MOUNT" 2>/dev/null || true' EXIT


# Enable SSH
# update_progress 60 "Enabling SSH..."
sudo touch "$BOOT_MOUNT/ssh"


# Creating cmdline.txt
# update_progress 65 "Creating cmdline.txt..."
ROOT_DEVICE=/dev/sdb2
ROOT_PARTUUID=$(sudo blkid -s PARTUUID -o value "$ROOT_DEVICE")
# if [ -z "$ROOT_PARTUUID" ]; then
#     echo "ERROR: Could not determine root PARTUUID"
#     exit 1
# fi
sudo sed -i "s/__ROOT_PARTUUID__/${ROOT_PARTUUID}/" "$BOOT_MOUNT/cmdline.txt"


# Creating config.txt
# update_progress 70 "Creating config.txt..."
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  "$SCRIPT_DIR/files/bootfs/config.txt" \
  | sudo tee "$BOOT_MOUNT/config.txt" >/dev/null


# Creating meta-data
# update_progress 75 "Creating meta-data..."
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  "$SCRIPT_DIR/files/bootfs/meta-data" \
  | sudo tee "$BOOT_MOUNT/meta-data" >/dev/null


# Creating network-config
# update_progress 80 "Creating network-config..."
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


# Creating user-data
# update_progress 85 "Creating user-data..."
PASSWORD_HASH=$(openssl passwd -6 "$PASSWORD")
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  -e "s|__USERNAME__|$USERNAME|g" \
  -e "s|__PASSWORD_HASH__|$PASSWORD_HASH|g" \
  "$SCRIPT_DIR/files/bootfs/user-data" \
  | sudo tee "$BOOT_MOUNT/user-data" >/dev/null


# First Boot Debug
# update_progress 90 "Creating first boot debug script..."
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

# Make executable
sudo chmod +x "$ROOT_MOUNT/usr/local/sbin/firstboot-debug.sh"

# Create systemd service
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

# Enable service
sudo mkdir -p \
  "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants"

sudo ln -sf \
  /etc/systemd/system/firstboot-debug.service \
  "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants/firstboot-debug.service"


# Cleanup
# update_progress 95 "Cleaning up..."
sync
sudo umount "$BOOT_MOUNT"
sudo umount "$ROOT_MOUNT"

trap - EXIT

# update_progress 100 "Provisioning complete."
msg \
    "Provisioning Complete" \
    "SD card successfully prepared.

Hostname: $HOSTNAME
IP Address: $IP_ADDRESS
Username: $USERNAME

SSH Command: ssh ${USERNAME}@${IP_ADDRESS}"
