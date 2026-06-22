# Further explanation of configurable files and alterations

## cmdline.txt
**Linux kernel boot parameters**

| Parameter | Purpose |
|---|---|
| quiet splash | Disable splash screen |


## config.txt
**Firmware and hardware configuration before linux starts**

| Parameter | Purpose |
|---|---|
| dtparam=audio=off | Disables onboard audio |
| camera_auto_detect=0 | Disables camera drivers |
| display_auto_detect=0 | Disables attached displays |
| #dtoverlay=vc4-kms-v3d | Disable full KMS Graphics stack |
| #max_framebuffers=2 |  |
| gpu_mem=16 | Lower GPU memory |
| dtoverlay=disable-bt | Disable Bluetooth |
| dtoverlay=disable-wifi | Disable Wifi |
