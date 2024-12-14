# castpi2go

## Ansible playbook to deploy/manage multiple raspberry pis + hifiberry DAC HATs with upmpdcli, mpd and snapcast as UPnP targets with multi-room functionality.

I wrote this because the number of pis in my family has reached a point point where deploying them and keeping them up to date has become a chore.<br>
The pis are used as UPnP casting targets for Symfonium on android.<br>
upmpdcli and mpd allow for bit perfect casting while snapcast allows for multi-room casting (letting multiple pis play the same music in sync).<br>
This playbook can turn a pi (or many) with a fresh raspbian install into a finished UPnP target within a couple of minutes with no user interaction.<br>
I tested it on Raspberry Pi Zero 1W, Zero 2W, 2 and 3B. Tested DACs: Hifiberry Dac+ Pro and Dac+ Zero.

**What can this playbook do?**
  * update all packages
  * create a user with passwordless sudo privileges and add the appropriate ssh key (optional)
  * configure the audio settings to use the Hifiberry DAC (optional)
  * install mpd and upmpdcli and configure them
  * install and configure snapclient (optional)
  * install and configure snapserver (optional)

