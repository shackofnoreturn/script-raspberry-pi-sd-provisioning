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

## meta-data
**Least interesting file of the Cloud-Init config files**

| Parameter | Purpose |
|---|---|
| dsmode: local | Run cloud-init before networking starts |
| instance_id | Unique identifier used by cloud-init to determine whether this is a new instance |
| local-hostname | Define hostname, which also can be done in user-data |
