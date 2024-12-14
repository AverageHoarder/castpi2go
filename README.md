# castpi2go

## Ansible playbook to deploy/manage multiple raspberry pis + hifiberry DAC HATs with upmpdcli, mpd and snapcast as UPnP targets with multi-room functionality.

I wrote this because the number of pis in my family has increased to the point where setting them up/keeping them up to date and configuring them has become a chore.
The pis are used as UPnP casting targets for Symfonium on my android phone. upmpdcli and mpd allow for bit perfect casting while snapcast allows for multi-room casting (letting multiple pis play the same music in sync).
This playbook can turn a pi (or many) with a fresh raspbian install into a finished UPnP target within a couple of minutes with no user interaction.
I tested it on Raspberry Pi Zero 1W, Raspberry Zero 2W, Raspberry Pi 2 and Raspberry Pi 3B. Hifiberry Tested DAC are Hifiberry Dac+ Pro and Hifiberry Dac+ Zero.

**What can this playbook do?**
  * update all packages
  * create a user with passwordless sudo privileges and add the appropriate ssh key (optional)
  * configure the audio settings to use the Hifiberry DAC (optional)
  * install mpd and upmpdcli and configure them
  * install and configure snapclient (optional)
  * install and configure snapserver (optional)

