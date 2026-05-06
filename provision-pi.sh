#!/usr/bin/env bash
set -euo pipefail

### ===== CONFIG =====
HOSTNAME=${1:-pi-node}
DEVICE=${2:-/dev/sdX}
IP_ADDRESS=${3:-10.0.0.11}

GATEWAY="10.0.0.1"
DNS_SERVERS="1.1.1.1 8.8.8.8"

USERNAME="shackadmin"
PASSWORD="Ackou1736jens"

IMG_URL="https://downloads.raspberrypi.com/raspios_lite_armhf_latest"
WORKDIR="/tmp/pi-image"
CACHE_IMG="$WORKDIR/image"

### ===== PRECHECKS =====
if [[ ! -b "$DEVICE" ]]; then
  echo "ERROR: $DEVICE is not a valid block device"
  exit 1
fi

echo "Target device:"
lsblk "$DEVICE"

echo "WARNING: ALL DATA ON $DEVICE WILL BE DESTROYED"
read -p "Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || exit 1

mkdir -p "$WORKDIR"
cd "$WORKDIR"

### ===== DOWNLOAD (CACHED) =====
if [[ ! -f "$CACHE_IMG" ]]; then
  echo "[+] Downloading Raspberry Pi OS image..."
  wget -O "$CACHE_IMG" "$IMG_URL"
else
  echo "[+] Using cached image"
fi

### ===== DETECT FORMAT =====
echo "[+] Detecting image format..."
TYPE=$(file -b "$CACHE_IMG")

IMG_FILE=""

# --- CASE 1: Already a disk image ---
if [[ "$TYPE" == *"boot sector"* ]] || [[ "$TYPE" == *"filesystem"* ]]; then
  echo "[+] Cached file is already a disk image"
  IMG_FILE="$CACHE_IMG"

# --- CASE 2: XZ compressed ---
elif [[ "$TYPE" == *"XZ compressed"* ]]; then
  echo "[+] Extracting XZ..."
  cp "$CACHE_IMG" image.xz
  unxz -f image.xz

# --- CASE 3: ZIP archive ---
elif [[ "$TYPE" == *"Zip archive"* ]]; then
  echo "[+] Extracting ZIP..."
  cp "$CACHE_IMG" image.zip
  unzip -o image.zip

else
  echo "ERROR: Unknown image format: $TYPE"
  exit 1
fi

### ===== FIND IMAGE (IF EXTRACTED) =====
if [[ -z "$IMG_FILE" ]]; then
  echo "[+] Locating extracted image..."

  IMG_FILE=$(find "$WORKDIR" -maxdepth 1 -type f -name "*.img" | head -n1)

  if [[ -z "$IMG_FILE" ]]; then
    IMG_FILE=$(find "$WORKDIR" -maxdepth 1 -type f ! -name "*.xz" ! -name "*.zip" -exec file {} \; | grep -i "boot sector\|filesystem" | head -n1 | cut -d: -f1)
  fi

  if [[ -z "$IMG_FILE" ]]; then
    echo "ERROR: Could not find disk image after extraction"
    ls -lah "$WORKDIR"
    exit 1
  fi
fi

echo "[+] Image ready: $IMG_FILE"
ls -lh "$IMG_FILE"

### ===== FLASH =====
echo "[+] Flashing to $DEVICE..."
sudo dd if="$IMG_FILE" of="$DEVICE" bs=4M status=progress conv=fsync

sync

### ===== MOUNT BOOT =====
BOOT_PART="${DEVICE}1"
MOUNT_POINT="/mnt/pi-boot"

sudo mkdir -p "$MOUNT_POINT"
sudo mount "$BOOT_PART" "$MOUNT_POINT"

trap 'sudo umount "$MOUNT_POINT" || true' EXIT

### ===== BASIC CONFIG =====
echo "[+] Enabling SSH..."
sudo touch "$MOUNT_POINT/ssh"

echo "[+] Setting hostname..."
echo "$HOSTNAME" | sudo tee "$MOUNT_POINT/hostname" >/dev/null

echo "[+] Creating user..."
HASH=$(openssl passwd -6 "$PASSWORD")
echo "${USERNAME}:${HASH}" | sudo tee "$MOUNT_POINT/userconf.txt" >/dev/null

### ===== STATIC IP CONFIG =====
echo "[+] Configuring static IP..."

sudo tee "$MOUNT_POINT/dhcpcd.conf.append" >/dev/null <<EOF

interface eth0
static ip_address=${IP_ADDRESS}/24
static routers=${GATEWAY}
static domain_name_servers=${DNS_SERVERS}
EOF

sudo tee "$MOUNT_POINT/firstboot.sh" >/dev/null <<'EOF'
#!/bin/bash
set -e
cat /boot/dhcpcd.conf.append >> /etc/dhcpcd.conf
rm /boot/dhcpcd.conf.append
rm /boot/firstboot.sh
EOF

sudo chmod +x "$MOUNT_POINT/firstboot.sh"

sudo tee "$MOUNT_POINT/rc.local" >/dev/null <<'EOF'
#!/bin/bash
bash /boot/firstboot.sh
exit 0
EOF

sudo chmod +x "$MOUNT_POINT/rc.local"

### ===== CGROUPS =====
echo "[+] Enabling cgroups..."
sudo sed -i '1 s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' "$MOUNT_POINT/cmdline.txt"

### ===== CLEANUP =====
echo "[+] Unmounting..."
sudo umount "$MOUNT_POINT"
trap - EXIT

echo "[+] SUCCESS: $HOSTNAME ready at $IP_ADDRESS"