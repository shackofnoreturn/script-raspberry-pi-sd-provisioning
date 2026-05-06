# Raspberry Pi SD Card Provisioning


## How
**Make the script file executable**
```
chmod +x provision-pi.sh
```

**Run script after inserting your sd card**
*Make sure the sd card location is the one you want. Use `lsblk` first to check beforehand* 

```
sudo ./provision-pi.sh pi-hostname-001 /dev/sdX 10.0.0.10 myUserName myPassword
```
