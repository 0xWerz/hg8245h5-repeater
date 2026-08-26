# Recovery

## Normal removal

Run `uninstall.sh` from the original installation archive, then reboot. It
stops project processes, removes only `HG5R_` firewall objects, restores the
saved audit hook and feature file, and removes the project directory.

## If the service does not start

The stock LAN remains `192.168.100.1/24`. Connect by Ethernet, obtain or set an
address in that subnet, enter the existing root shell, and inspect:

```sh
/mnt/jffs2/Install_gram/hg8245h5-repeater/doctor.sh
tail -100 /mnt/jffs2/hg8245h5-repeater.log
```

Then run the installed uninstaller:

```sh
/mnt/jffs2/Install_gram/hg8245h5-repeater/uninstall.sh
reboot
```

The installer never changes GPON provisioning, optical credentials, firmware
partitions, or the bootloader.
