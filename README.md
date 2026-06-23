# Raspberry Pi SD Card Provisioning
An interactive script to provision raspberry pi SD Cards

## What
Raspberry PI OS image flasher in TUI fashion.
Flashes raspberry pi headless OS to an SD card with predetermined configurations.

Configuration is done with several files being injected into the boot partition.

- cmdline.txt
- config.txt
- meta-data
- network-config
- user-data

Touching these files is not required as they have been templated out to be pushed to the sd card in the tool itself.

There is also a single use firstboot service being injected into the root partition by the use of the following files:

- firstboot-debug.sh

## How
**Make all .sh files executable if not already**
```
chmod +x *.sh
```

**Run script after inserting your sd card**
*Be careful which device you pick when provisioning* 

```
./menu.sh
```

# Todo
- inject cmdline.txt
- inject config.txt
- inject meta-data
- inject network-config
- vscode task to run TUI
- static ip configuration