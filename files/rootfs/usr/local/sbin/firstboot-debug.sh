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
