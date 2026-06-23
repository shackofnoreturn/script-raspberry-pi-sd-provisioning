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
sleep 5

BOOT_PART="${DEVICE}1"
ROOT_PART="${DEVICE}2"


# Mount partitions
sudo mkdir -p "$BOOT_MOUNT"
sudo mkdir -p "$ROOT_MOUNT"
info \
    "Provisioning" \
    "Mounting partitions..."
sudo mount "$BOOT_PART" "$BOOT_MOUNT"
sudo mount "$ROOT_PART" "$ROOT_MOUNT"

trap 'sudo umount "$BOOT_MOUNT" 2>/dev/null || true; sudo umount "$ROOT_MOUNT" 2>/dev/null || true' EXIT


# Enable SSH
info \
    "Provisioning" \
    "Enabling SSH..."
sudo touch "$BOOT_MOUNT/ssh"


# Creating cmdline.txt
# sed \
#   -e "s|__HOSTNAME__|$HOSTNAME|g" \
#   "$SCRIPT_DIR/files/bootfs/cmdline.txt" \
#   | sudo tee "$BOOT_MOUNT/cmdline.txt" >/dev/null


# Creating config.txt
# sed \
#   -e "s|__HOSTNAME__|$HOSTNAME|g" \
#   "$SCRIPT_DIR/files/bootfs/config.txt" \
#   | sudo tee "$BOOT_MOUNT/config.txt" >/dev/null

# Creating meta-data
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  "$SCRIPT_DIR/files/bootfs/meta-data" \
  | sudo tee "$BOOT_MOUNT/meta-data" >/dev/null


# Creating user-data
# info \
#     "Provisioning" \
#     "Creating user..."
PASSWORD_HASH=$(openssl passwd -6 "$PASSWORD")
sed \
  -e "s|__HOSTNAME__|$HOSTNAME|g" \
  -e "s|__USERNAME__|$USERNAME|g" \
  -e "s|__PASSWORD_HASH__|$PASSWORD_HASH|g" \
  "$SCRIPT_DIR/files/bootfs/user-data" \
  | sudo tee "$BOOT_MOUNT/user-data" >/dev/null



# ### ===== STATIC IP =====
# echo "[+] Configuring static IP..."

# sudo mkdir -p "$ROOT_MOUNT/etc/NetworkManager/system-connections"

# sudo tee "$ROOT_MOUNT/etc/NetworkManager/system-connections/eth0-static.nmconnection" >/dev/null <<EOF
# [connection]
# id=eth0-static
# type=ethernet
# interface-name=eth0
# autoconnect=true

# [ipv4]
# method=manual
# address1=${IP_ADDRESS}/24,${GATEWAY}
# dns=${DNS_SERVERS// /;};

# [ipv6]
# method=ignore
# EOF

# sudo chmod 600 \
#   "$ROOT_MOUNT/etc/NetworkManager/system-connections/eth0-static.nmconnection"


# First Boot Debug
info \
    "Provisioning" \
    "Installing first-boot diagnostics..."

sudo mkdir -p "$ROOT_MOUNT/usr/local/sbin"

sudo tee "$ROOT_MOUNT/usr/local/sbin/firstboot-debug.sh" >/dev/null <<'EOF'
#!/bin/bash

touch firstboot-debug.log.ok

LOG=/boot/firstboot-debug.txt

{
echo "===== FIRST BOOT DEBUG ====="
date
echo

echo "=== HOSTNAME ==="
hostname

echo
echo "=== KERNEL CMDLINE ==="
cat /proc/cmdline

echo
echo "=== IP ADDRESSES ==="
ip addr

echo
echo "=== ROUTES ==="
ip route

echo
echo "=== NETWORK DEVICES ==="
nmcli device status 2>/dev/null || echo "nmcli not available"

echo
echo "=== NETWORK CONNECTIONS ==="
nmcli connection show 2>/dev/null || true

echo
echo "=== DNS CONFIG ==="
cat /etc/resolv.conf

echo
echo "=== DMESG NETWORK ==="
dmesg -T | grep -i -E 'eth|network|link|dhcp'

echo
echo "=== NETWORKMANAGER LOGS ==="
journalctl -u NetworkManager --no-pager -n 200 2>/dev/null || true

echo
echo "===== END DEBUG ====="

} > "$LOG" 2>&1

# Self-remove after first successful run
# systemctl disable firstboot-debug.service 2>/dev/null || true
# rm -f /etc/systemd/system/firstboot-debug.service
# rm -f /etc/systemd/system/multi-user.target.wants/firstboot-debug.service
# rm -f /usr/local/sbin/firstboot-debug.sh
EOF

# Make executable
sudo chmod +x "$ROOT_MOUNT/usr/local/sbin/firstboot-debug.sh"

# Create systemd service
sudo tee "$ROOT_MOUNT/etc/systemd/system/firstboot-debug.service" >/dev/null <<'EOF'
[Unit]
Description=First boot debug dump
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/firstboot-debug.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Enable service
sudo mkdir -p \
  "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants"

sudo ln -sf \
  /etc/systemd/system/firstboot-debug.service \
  "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants/firstboot-debug.service"


# Cleanup
info \
    "Provisioning" \
    "Syncing and unmounting..."
sync
sudo umount "$BOOT_MOUNT"
sudo umount "$ROOT_MOUNT"

trap - EXIT
msg \
    "Provisioning Complete" \
    "SD card successfully prepared.

Hostname:
$HOSTNAME

IP Address:
$IP_ADDRESS

Username:
$USERNAME

SSH Command:
ssh ${USERNAME}@${IP_ADDRESS}"
