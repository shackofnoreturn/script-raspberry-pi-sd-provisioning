# Raspberry Pi SD Card Provisioning
*An interactive menu script to provision raspberry pi SD Cards with some extra TUI flair!*

## What
Raspberry PI OS image flasher in TUI fashion.
Flashes raspberry pi headless OS to an SD card with predetermined configurations.

Configuration is done with several files being injected into the boot partition:
- cmdline.txt
- config.txt
- meta-data
- network-config
- user-data

*Modifying these files is not needed as they have been templated out to be pushed to the sd card in the tool itself.*

**All variables are stored in the ``config.env`` file and can be altered in the menu itself.**

There is also a single use firstboot service being injected into the root partition by the use of the following files:

- firstboot-debug.sh

You can alter this file however you like to for example to collect data on first boot and have it deleted automatically.
This is why you notice there is a menu option ``Retrieve Debug Data``.


## How
### Prerequisites
Make all .sh files executable if not already:
```
chmod +x *.sh
```

### Execution
Run this command to launch the **interactive menu**: ``./menu.sh``

To run the provisioning menu **inside VSCode**:
`CTRL` + `SHIFT` + `P` -> Run Task


## Todo
- FIXME: Scrambled text when downloading image
- TODO: Flashing image: progress display improvement
- FIXME: Error (post 55%)
    - Can't open input file Syncing...
    - Can't open input file Unmounting partitions...
    - Can't open input file Detaching loop device...
    - Can't open input file Executing losetup detach...
    - Can't open input file Killing gauge process...
    - Can't open input file Waiting for gauge process to exit...
    - ./provision.sh: line 283: 269508 Killed
    - dialog --gauge "Starting..." 8 70 0 0<&3 (wd: Documents/Github/Operations/script-raspberry-pi-sd-provisioning)
    - Can't open input file Removing progress pipe...
- TODO: Full code review & cleanup
- FIXME: VSCode producing permission errors

