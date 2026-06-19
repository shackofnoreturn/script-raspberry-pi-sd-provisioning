# Further explanation of configurable files

## cmdline.txt

| Parameter | Purpose |
|---|---|
| console=serial0,115200 | Send boot messages to the serial port at 115200 baud |
| console=tty1 | Also display boot messages on the local HDMI console |
| root=PARTUUID=... | Root filesystem location (PARTUUID identifies the partition) |
| rootfstype=ext4 | Root filesystem type |
| fsck.repair=yes | Automatically repair filesystem errors |
| rootwait | Wait indefinitely for the root device to appear |
| quiet splash | Disable splash screen |
