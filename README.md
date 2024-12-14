# castpi2go

## Ansible playbook to deploy/manage Raspberry Pi(s) + Hifiberry DAC HAT(s) with upmpdcli, mpd and snapcast as multi-room UPnP targets

I wrote this because the number of pis in my family has reached a point where deploying them and keeping them up to date has become a chore.<br>
The pis are mainly used as UPnP casting targets for [Symfonium](https://support.symfonium.app/) on android via wifi.<br>
[upmpdcli](https://www.lesbonscomptes.com/upmpdcli/) and [MPD](https://github.com/MusicPlayerDaemon/MPD) allow for bit perfect casting while [Snapcast](https://github.com/badaix/snapcast) allows for multi-room casting (letting multiple pis play the same music in sync).<br>
This playbook can turn a pi (or many) with a fresh Raspberry Pi OS (Lite) install into a finished headless UPnP target within a couple of minutes with no user interaction (Pi 3B took 12 minutes).<br>
I tested it on Raspberry Pi Zero 1W, Zero 2W, 2 and 3B. Tested DACs: Hifiberry Dac+ Pro and Dac+ Zero.

**What can this playbook do?**
  * update all packages (including those not available on apt)
  * create a user with passwordless sudo privileges and add the appropriate ssh key (optional)
  * configure the audio settings to use the Hifiberry DAC (optional)
  * install mpd and upmpdcli and configure them
  * install and configure snapclient and/or snapserver (optional)
  

## Installed Software
Following the guides and documentation on these sites you can achieve the same as this playbook if you perform a bit over 20 steps (per pi).<br>
[MPD - Music Player Daemon](https://github.com/MusicPlayerDaemon/MPD)<br>
[upmpdcli - UPnP Audio Media Renderer based on MPD](https://www.lesbonscomptes.com/upmpdcli/)<br>
[Snapcast - Synchronous multiroom audio player](https://github.com/badaix/snapcast)

## How to install castpi2go

### Prerequisites

**Required:**
1. [ansible](https://github.com/ansible/ansible) must be installed
2. fresh install of Raspberry Pi OS Lite (it's what I've tested, it might work with other debian/ubuntu variants)

### Downloading the playbook
Download the repository as .zip and unpack it where you want to run the playbook or clone the repository.

## Step by step guide
This guide assumes that you have a Raspberry Pi, a power supply, a Hifiberry DAC HAT (optional) and a microSD card. Linux commands are used, but they work in [WSL on Windows](https://learn.microsoft.com/en-us/windows/wsl/install) as well.

### Preparing SSH keys
If you already have a SSH key for your user as well as an ansible specific SSH key, you can skip these steps.

1. create an SSH key for your normal user by running `ssh-keygen -t ed25519 -C "user default"` (replace "user" with your chosen username). I recommend to use a password for this key.
2. create an ansible specific SSH key by running `ssh-keygen -t ed25519 -C "ansible"` and save it as "ansible" (otherwise it will overwrite the first key). For this key I recommend not to use a password.
You should then have two SSH key pairs (public/private) in `~/.ssh`.

### Preparing/flashing the microSD card
1. download and install [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. connect the microSD card to your PC
3. open Raspberry Pi Imager
4. under "Choose Device" select the model of Pi you are using
5. under "Choose OS" select the OS version you want (I usually choose Raspberry Pi OS Lite (64bit))
6. under "Choose Storage" make sure you select the correct microSD card (everything on it will be deleted!)
7. Edit Settings → General: add OS customisation settings, I recommend filling out everything (hostname, username, password, wifi config, locale settings)
8. Services: Enable SSH, I recommend using public-key authentification only and pasting the contents of the public key of your normal user `cat ~/.ssh/id_ed25519.pub`
9. save changes, apply the OS settings and confirm flashing the microSD card

### Giving your pi a static IP (optional but recommended)
Since the playbook will configure the pis based on their IP/hostname, giving them static IPs is recommended.
1. install the microSD card in your pi, install the Hifiberry DAC HAT (optional) and connect the power supply
2. once the pi has booted, find out its IP address in your router
3. SSH into the pi via `ssh username@IP/hostname` (replace "username" with the user you set in Raspberry Pi Imager)
4. if you used an up to date image (bookworm as of writing), run `sudo nmtui` and set a static IP, then reboot the pi `sudo reboot`

### Adding your pi to the inventory and setting its variables
[Snapcast](https://github.com/badaix/snapcast) uses a client/server model where all configured clients play in sync what is cast to the server.
1. In the castpi2go directory, edit the inventory `nano inventory` and add the IP/hostname of your pi either under snapclients (installs only snapclient) or under snapservers (installs snapclient and snapserver).
2. create a host variable file for your pi `cp host_vars/example.yml IP/hostname-of-your-pi.yml` and fill it out:
3. "friendly_name" is what the pi will be called in the casting options
4. "hifiberry_overlay" is specific to your DAC, see the [Hifiberry documentation](https://www.hifiberry.com/docs/software/configuring-linux-3-18-x/) to find the correct one.
5. "snapcast_server_ip" this is the IP of the snapserver that the pi will play in sync with. When you cast to the snapserver, all snapclients will play the same in sync.

Note:
You can delete the "hifiberry_overlay" line if you only want to install mpd, upmpdcli and snapserver on a pi without a Hifiberry DAC. This will skip the config steps that alter the audio settings of the pi and also will not install snapclient.

### Running the bootstrap playbook to set up the ansible user (optional)
bootstrap.yml creates a new user "nandor" with passwordless sudo on the pi that will be used by the main playbook. The user will use the "ansible" key created earlier to authenticate.
You can also use a different user ("ansible" if you lack creativity), I chose nandor because this playbook is relentless.
1. In the castpi2go directory, edit the bootstrap playbook `nano bootstrap.yml`, then look for the `add ssh key` task and fill out `key: ""` with your public ansible key `cat ~/.ssh/ansible.pub`.
2. If you want to use a different user, search and replace all instances of "nandor" in bootstrap.yml with your chosen user name. You'll also have to edit `nano ansible.cfg` and replace nandor for the "remote_user" option.
3. Ensure that "private_key_file" in `nano ansible.cfg` points to your ansible SSH key and that the "remote_user" matches your chosen ansible user.
4. Execute the bootstrap playbook `ansible-playbook bootstrap.yml -u user --key-file ~/.ssh/id_ed25519` (replace "user" with the user you set in Raspberry Pi Imager and "--key-file" with your normal SSH key.

### Run the main playbook to fully set up your pi(s)
1. Edit the main playbook `nano castpi2go.yml`, find the "add ssh key for ansible user" task and fill out `key: ""` with your public ansible key `cat ~/.ssh/ansible.pub`. This is also performed in the bootstrap playbook and kept as a means to easily revoke or change the ssh key later on by adding "state: absent" for example. If you use a different ansible user, change "user: nandor" as well.
2. In the castpi2go directory, execute the main playbook `ansible-playbook castpi2go.yml` This can also be used later on to update the pi(s), as it will update all apt packages as well as snapclient/snapserver which are not available on apt.

### Adding more Raspberry Pis
If you want to add more pis, repeat the steps to flash the microSD card (Raspberry Pi Imager should remember your credentials and ssh key so you only have to change the host name).
Then give the pi a static IP and add that to the inventory file. Create a matching host_vars file for it and set the variables, then run the bootstrap playbook and the main playbook.
If you do not want to execute the playbooks on all hosts each time (does no harm but may slow down execution), limit them to a specific host like this: `ansible-playbook bootstrap.yml -u user --key-file ~/.ssh/id_ed25519 --limit pi-IP/hostname` and `ansible-playbook castpi2go.yml --limit pi-IP/hostname``

## Recommended Hardware
For an inexpensive but capable player I suggest using a [Raspberry Pi Zero 2W](https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/), a [Hifiberry Dac+ Zero](https://www.hifiberry.com/shop/boards/hifiberry-dac-zero/) and a 32GB or 64GB microSD card of class A3 at least.
If you have access to a 3D printer, there are also a couple of case designs on Thingiverse that should fit this combo: [Example 1](https://www.thingiverse.com/thing:3751356), [Example 2](https://www.thingiverse.com/thing:4527114)

## What to cast from
I recommend using [Symfonium](https://support.symfonium.app/) on android with [lms](https://github.com/epoupon/lms) as the provider.
When the pi(s) are fully set up they should pop up as cast targets in Symfonium. If you want to listen on a specific pi, cast to that. If you want to use multi-room, cast to the snapserver Pi. You can group the snapclients and adjust their volume individually or in groups by opening Pi-snapcast-IP:1780 in any browser or by using dedicated apps like [Snapdroid](https://github.com/badaix/snapdroid).