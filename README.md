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
- deploy to 3 raspberry pi's
- look for known_hosts and remove previous entry
- Provisioning: "No" on Confirm Flash doesn't exit application
- Debug: "Cancel" doesn't exit application
- Select SD Card: "Cancel" doesn't exit application
- Select Partition: "Cancel" doesn't exit application
- Configuration: "Cancel" doesn't exit application
- All config options: "Cancel" doesn't exit application
- Debug: Loading graphic when loading debug log
- Provisioning: Flashing graphic
- Complete loading bar implementation
