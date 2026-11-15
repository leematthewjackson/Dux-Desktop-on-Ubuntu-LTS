# Quick install with scripts

The fast route through the guide: two scripts, two reboots, and the Dux installer in between.

| Script | What it does | When |
| --- | --- | --- |
| [`setup.sh`](./setup.sh) | Updates, base tools, removes and blocks Snap, desktop plumbing (audio, printing, Flatpak…), optional NVIDIA driver, switch to NetworkManager | Right after installing Ubuntu Server |
| [`post-dux.sh`](./post-dux.sh) | Firefox (Mozilla) and Brave via APT, Thunar, GNOME Text Editor, Flatpak apps (Gwenview, Nextcloud), ArtCraft repository (apps chosen later), Claude Code, autostart fix | After Dux, from a terminal inside the desktop |

## Getting the scripts onto the machine

**From a USB stick** (a second stick, not the Ubuntu installer one):

1. Copy `setup.sh` and `post-dux.sh` onto the stick from any computer.
2. On the new machine, plug it in and find it:
   ```bash
   lsblk
   ```
   Look for the stick by its size, e.g. `sdb1`.
3. Mount it and copy the scripts to your home folder:
   ```bash
   sudo mount /dev/sdb1 /mnt
   cp /mnt/setup.sh /mnt/post-dux.sh ~/
   sudo umount /mnt
   chmod +x ~/setup.sh ~/post-dux.sh
   ```
   (USB sticks usually drop the "executable" flag, which is why the `chmod` is needed.)

**Or over SSH:** copy them across from another computer with `scp setup.sh post-dux.sh you@machine-ip:~/`, then run the `chmod` line above.

## Step 1: Install Ubuntu Server

Install Ubuntu Server 26.04.1 LTS with your normal user. Tick **OpenSSH Server** if you want to copy and paste over SSH.

## Step 2: Run `setup.sh`

```bash
./setup.sh            # Intel/AMD graphics
./setup.sh --nvidia   # NVIDIA graphics
```

Run it as your normal user, not with `sudo`. It asks for your password once and stops if anything fails. Fine over SSH, but keep a keyboard handy in case the network doesn't come back after the reboot.

Then:

```bash
sudo reboot
nmcli device status
```

Ethernet should show `connected` as `Wired connection 1`. On NVIDIA, complete MOK enrolment at reboot if asked, then check with `nvidia-smi`.

## Step 3: Install Dux

```bash
curl -fsSL https://install.duxlabs.dev | sh
```

Pick Hyprland, Alacritty and all optional features (Greeter, Search, Calendar, Files). Reboot, choose the plain **Hyprland** session at the greeter (not the uwsm one), log in and go through Dux's welcome.

## Step 4: Run `post-dux.sh`

Open Alacritty **inside the Dux desktop** (not over SSH, as it needs your desktop session for the autostart fix):

```bash
./post-dux.sh
```

To change which Flatpaks it installs, edit the `FLATPAKS` list at the top of the script first.

## Step 5: Finish off

1. Log out and back in.
2. Join Wi-Fi from Dux if needed.
3. Run `claude` in a project folder to log in to Claude Code.
4. Set your default browser and image viewer in Dux's settings (Thunar and GNOME Text Editor are already set as defaults).
5. Add any autostart apps in Dux's settings. For Nextcloud in the tray, add `--background` to the end of its command.

Then run through the checklist in Section 8 of the main guide.
