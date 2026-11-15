# Dux Desktop on Ubuntu LTS

Hyprland desktop on a stable Ubuntu 26.04 LTS base, using Dux Shell. A step-by-step guide covering NetworkManager, audio, printing, a Snap-free setup with APT and Flatpak apps, and updates, tested on real hardware.

**Daily-desktop installation guide | Updated 15 November 2026**

**Goal:** A cohesive "Omarchy-style" desktop on Ubuntu LTS, letting Dux own the desktop and adding only the services underneath it. No dotfiles (for now).

**Tested on:** a 2017 iMac (iMac18,3, Intel) and a desktop PC with an NVIDIA GPU. Your hardware may need small adjustments; read each step before running it.

**In a hurry?** The [`scripts`](./scripts/INSTALL.md) folder does all of this in two scripts with one reboot in between. This README is the long version, so you know what they're doing.

## Our choices

- Ubuntu Server 26.04.1 LTS as the base, with Snap removed and blocked, the Linux Mint way. (I don't want to add custom repos for too many apps... I am aware of the irony that I have literally done that for Firefox, Brave AND ArtCraft. Shhh.)
- NetworkManager for Wi-Fi, Ethernet and VPNs (Dux's network controls use it) plus stops the silly 2 min Ubuntu Server boot times looking for connections.
- Dux installer with Hyprland, Alacritty and all Dux features (greeter, search, calendar, files).
- APT for system packages and browsers (Firefox straight from Mozilla, Brave straight from Brave), Flathub for other desktop apps.
- Dux provides the bar, launcher, notifications, lock screen, clipboard and more. Thunar and GNOME Text Editor stand in for Dux's own file manager and editor, because, well, I prefer them.

> **Scope:** A normal DHCP home/office PC with local keyboard and monitor. Keep a keyboard handy for the networking change in Section 2.

## 1. Install and update Ubuntu Server

Install [Ubuntu Server 26.04.1 LTS](https://ubuntu.com/download/server) with your normal sudo user. Skip the optional server snaps (we're about to evict Snap anyway). Tip: select OpenSSH Server so you can SSH in and copy and paste the commands below.... much easier than hand typing! (Read the note at the top of Section 2 first though.)

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl wget git ca-certificates gnupg software-properties-common micro
```

### Remove Snap and keep it out

Mint-style. Out it goes, and the pin file makes sure it never sneaks back in as a dependency of something else.

```bash
sudo apt purge -y snapd
sudo rm -rf /snap /var/snap /var/lib/snapd ~/snap

sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
# Keep snapd out, the Linux Mint way
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

sudo reboot
```

This guide is for fresh installs, so there are no Snap apps to lose at this point.

## 2. Switch to NetworkManager

Fine to do over SSH (I did!) as nothing changes until the reboot. But keep a keyboard handy: if the network doesn't come back you'll need it for the undo steps, and the machine may pick up a new IP address, so you might have to go hunting for it to SSH back in.

```bash
sudo apt install -y network-manager wpasupplicant

sudo tee /etc/netplan/01-network-manager-all.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
sudo mv /etc/netplan/00-installer-config.yaml /root/00-installer-config.yaml.bak

sudo tee /etc/NetworkManager/conf.d/10-no-assume.conf >/dev/null <<'EOF'
[device-ethernet]
match-device=type:ethernet
keep-configuration=no
EOF

sudo systemctl disable systemd-networkd.service systemd-networkd.socket
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl disable NetworkManager-wait-online.service
sudo reboot
```

What this does:

Beats me.... I had AI explain it 100 times.... but what I do know is it ends up working!

- The netplan file hands networking to NetworkManager (it's the same file Ubuntu Desktop uses).
- The installer's own netplan file is moved out of the way, with a backup kept in `/root`. If you set up Wi-Fi during the install, its password was in that file, so rejoin Wi-Fi from Dux after the reboot.
- The `10-no-assume.conf` file makes NetworkManager apply its own Ethernet profile at boot. Without it, NetworkManager "assumes" the half-finished network setup left by Ubuntu's boot image, shows a temporary connection named after the device (e.g. `enp4s0f0`), and has no internet until you switch to `Wired connection 1` by hand.
- `systemd-networkd` is turned off. Ubuntu 26.04's boot image leaves a catch-all DHCP rule (`/run/systemd/network/zzzz-dracut-default.network`) that otherwise keeps networkd running your network alongside NetworkManager.
- The wait-online services are disabled so boot doesn't wait for the network. Networking stays on.

After the reboot:

```bash
nmcli device status
```

Ethernet should show `connected` as `Wired connection 1`, and Wi-Fi `disconnected` until you join a network from Dux. `lo` showing `connected (externally)` is normal.

If Ethernet doesn't come back, undo it: delete `/etc/NetworkManager/conf.d/10-no-assume.conf`, move the backup file back to `/etc/netplan/`, run `sudo systemctl enable systemd-networkd.service systemd-networkd.socket`, and reboot.

## 3. NVIDIA only (skip for AMD/Intel)

```bash
sudo apt install -y ubuntu-drivers-common
sudo ubuntu-drivers install --recommended
sudo reboot
nvidia-smi
```

Complete MOK enrolment at reboot if Secure Boot asks. Don't add old Wayland/NVIDIA workarounds unless a real problem appears.

## 4. Desktop plumbing

Install these before Dux so the first login has everything it needs as of right now at least.

```bash
sudo apt install -y \
  pipewire-audio bluez alsa-utils \
  udisks2 gvfs gvfs-backends \
  gnome-keyring libpam-gnome-keyring libsecret-tools dbus-user-session \
  xdg-user-dirs xdg-utils xwayland \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  upower power-profiles-daemon accountsservice \
  brightnessctl ddcutil \
  bubblewrap ffmpegthumbnailer poppler-utils unzip \
  fonts-noto fonts-noto-color-emoji fonts-dejavu-core \
  adwaita-icon-theme hicolor-icon-theme \
  qt6-image-formats-plugins kimageformat6-plugins \
  cups cups-pk-helper cups-browsed avahi-daemon libnss-mdns \
  ipp-usb sane-airscan simple-scan \
  flatpak libfuse2t64 \
  gnome-disk-utility fwupd
xdg-user-dirs-update
sudo flatpak remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
```

What these cover: audio and Bluetooth audio (`pipewire-audio`), USB drives and network shares, keyring, portals for file dialogs and screen sharing, battery/power profiles/brightness for Dux's controls, video and PDF thumbnails, extra image formats for Dux (including AVIF/HEIC/JXL), printing and scanning with automatic network printer discovery (notes below), Flatpak with Flathub and AppImage support (`libfuse2t64`), fonts and icons, GNOME Disks and firmware updates. This clears the optional-feature warnings in Dux's System Check (`dms ipc call welcome doctor`).

### Printing and scanning notes

- `cups` is the print system and `cups-pk-helper` lets Dux manage it; `cups-browsed` and `avahi-daemon` find printers on your network automatically (Ubuntu Server doesn't include them).
- `ipp-usb` lets USB printers that support IPP-over-USB work without drivers; other printers may still need their own driver.
- `sane-airscan` + Simple Scan handle most network and USB scanners without drivers.

Most modern network printers then appear on their own. Check with:

```bash
lpstat -e
```

Then add or manage them from Dux's printer settings. If a printer doesn't show up, install `system-config-printer` and use **Add** there. You don't need to do this now but above command is helpful if you wanna check the install worked.

## 5. Install Dux

Run as your normal user:

```bash
curl -fsSL https://install.duxlabs.dev | sh
```

Select what you want. For me it was **Hyprland**, **Alacritty**, and all optional features (**Greeter, Search, Calendar, Files**). Stable packages, not Git builds.

> **Note:** On Ubuntu, Hyprland comes from a third-party PPA (`ppa:cppiber/hyprland`). It updates quickly, so glance at `apt list --upgradable` before big upgrades.

### Log in

Reboot and log in. Down in session options bottom right select Hyprland as I find the uwsm-managed one craps out on me!

Once in... enjoy the ohhh and the aaahhh of Dux and go through its welcome process.

## 6. Browsers, file manager and text editor

All straight from APT, so they update with everything else and print without any faffing.

### Firefox (from Mozilla's own repository)

```bash
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
  sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
gpg --show-keys /etc/apt/keyrings/packages.mozilla.org.asc

sudo tee /etc/apt/sources.list.d/mozilla.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
```

The key's fingerprint should be `35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3`. The pins make APT use Mozilla's Firefox and never Ubuntu's "firefox" package, which is just a stub that installs the Snap. Sneaky.

### Brave (from Brave's own repository)

```bash
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
```

### Install the browsers, Thunar and GNOME Text Editor

```bash
sudo apt update
sudo apt install -y firefox brave-browser \
  thunar thunar-archive-plugin thunar-volman tumbler xarchiver \
  gnome-text-editor

xdg-mime default thunar.desktop inode/directory
xdg-mime default org.gnome.TextEditor.desktop text/plain
```

- **Thunar** for files: `thunar-archive-plugin` + `xarchiver` give you "Extract here", `thunar-volman` handles USB drives, `tumbler` does thumbnails. Network shares and trash already work thanks to `gvfs` from Section 4.
- **GNOME Text Editor** for quick notes and config tweaks.
- The `xdg-mime` lines make them the defaults for folders and text files.

Want the time in Thunar's "Date Modified" column? Edit → Preferences → Display → Date format. Took me a while to find that one!

Set your default browser in Dux's settings.

## 7. Apps: Flatpak and AppImages

Flatpak and Flathub are already set up from Section 4. Install apps from Flathub, for example the ones I use, Gwenview (image viewer) and the Nextcloud sync client:

```bash
flatpak install -y flathub org.kde.gwenview com.nextcloud.desktopclient.nextcloud
```

For Nextcloud to start quietly in the tray, add it to autostart in Dux's settings with `--background` on the end of its command.

Log out and back in if new app icons don't show in the launcher.

### ArtCraft repository

Look... judge all you want but using the MCP with these apps is making me so productive!!!!! Native packages from ArtCraft's APT repository, so the apps' command-line tools are on your PATH for MCP connections and update with `apt upgrade`.

```bash
sudo install -d -m 755 /etc/apt/keyrings
sudo curl -fsSL https://getartcraft.com/keys/artcraft.gpg -o /etc/apt/keyrings/artcraft.gpg
sudo chmod 644 /etc/apt/keyrings/artcraft.gpg
sudo curl -fsSL https://getartcraft.com/apt/artcraft.sources -o /etc/apt/sources.list.d/artcraft.sources
sudo apt update
```

That just adds the repository. Pick the apps you actually want:

```bash
apt search artcraft
sudo apt install <package-name>
```

The key's fingerprint, at least at the moment, should be `2B76741B414AAD6CD33E631213A005C0B9D7C3ED` (check with `gpg --show-keys /etc/apt/keyrings/artcraft.gpg`). Prefer these debs over ArtCraft's Flatpaks: sandboxed CLIs are awkward to call from MCP tools.

> **Flatpak `--user` tip:** if any app's instructions say `--user`, leave it out and add its remote with `sudo`. Flathub is set up system-wide here, and a `--user` install can't find the runtimes it needs.

### Claude Code

Only if u use it. I do! Shaaammmeee, Shaaaammmmeee! I know!

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Run `claude` in a project folder; the first run opens a browser to log in (needs a paid Claude plan). It updates itself in the background.

### AppImages

No launcher or manager needed, they just run:

```bash
chmod +x ~/Downloads/Example.AppImage
~/Downloads/Example.AppImage
```

### Enable autostart apps

Ohhh and a quirk I hit. I couldn't add startup apps till I did this: Dux's autostart entries only run if the session starts `xdg-desktop-autostart.target`. Check it:

```bash
systemctl --user is-active xdg-desktop-autostart.target
```

If it says `inactive`, find your compositor's session target (for example `hyprland-session`):

```bash
systemctl --user list-units --type=target --state=active
```

Then add the autostart target to it, replacing `<session>` with that name:

```bash
systemctl --user edit <session>.target
```

Add:

```ini
[Unit]
Wants=xdg-desktop-autostart.target
```

Save, then log out and back in. Dux checks the target once at startup. The target can't be started by hand; the session has to pull it in.


## 8. Reboot and check the desktop

Once I've done all the above (plus any other bits I fancy), I do this so I know I've nailed everything and have a healthy system:

```bash
sudo reboot
```

Log in through Dux Greeter and confirm:

- [ ] Bar, launcher, notifications, lock screen, clipboard and emoji picker work.
- [ ] Dux Search and Calendar open; Thunar opens folders, USB drives and network shares.
- [ ] Alacritty opens from the launcher and shortcut.
- [ ] Wi-Fi/Ethernet and VPN controls work.
- [ ] Speakers, microphone and Bluetooth audio work.
- [ ] Firefox and Brave open links and print, and screen sharing works in the browser.
- [ ] Monitors, scaling, sleep/wake, brightness and battery work.
- [ ] Your keyboard layout (UK for me). If it's come up as US, set it in Hyprland's input settings.
- [ ] Printing and scanning (`lpstat -e` lists network printers found).

Diagnostics:

```bash
dms doctor
nmcli device status
systemd-analyze blame | head -25
```

If a session won't start, switch to a text console (`Ctrl+Alt+F3`) and check logs before changing settings.

## 9. Maintenance and updates

Run these together, e.g. weekly:

```bash
sudo apt update && sudo apt upgrade
flatpak update
```

| What | How it updates |
| --- | --- |
| Ubuntu, Dux, Hyprland, Firefox, Brave, ArtCraft and other APT packages | `sudo apt upgrade` |
| Flatpak apps (e.g. Nextcloud) | `flatpak update` |
| Claude Code | Automatic |
| Security updates | Automatic (Ubuntu's unattended upgrades) |

Hyprland comes from a third-party PPA and changes quickly, so glance at `apt list --upgradable` before a big upgrade. Reboot when Dux or the system asks, or when `/var/run/reboot-required` exists. Dux updates arrive through APT; there's no need to rerun its installer.

## What provides what

| Capability | Provided by |
| --- | --- |
| Bar, launcher, notifications, tray, clipboard, emoji, screenshots, wallpaper, lock/idle | Dux Shell |
| Audio, network, Bluetooth, power, printer controls | Dux Shell + Ubuntu services |
| Search / Calendar | Dux Search / Dux Calendar |
| Files | Thunar |
| Text editor | GNOME Text Editor |
| Login | Dux Greeter |
| Terminal | Alacritty |
| Disks and partitions | GNOME Disks |
| Browsers | Firefox (Mozilla APT) and Brave (Brave APT) |

## Sources

- [Dux Installer (flags, Ubuntu support)](https://duxlabs.dev/docs/duxinstall)
- [Dux docs](https://duxlabs.dev/docs/)
- [Netplan](https://netplan.io/)
- [Ubuntu NVIDIA drivers](https://ubuntu.com/desktop/docs/en/latest/how-to/graphics/install-nvidia-drivers/)
- [AppImage FUSE](https://docs.appimage.org/user-guide/troubleshooting/fuse.html)
- [Firefox on Linux (Mozilla)](https://support.mozilla.org/en-US/kb/install-firefox-linux)
- [Brave on Linux](https://brave.com/linux/)
- [ArtCraft on Linux](https://getartcraft.com/linux)

---

**Bottom line:** Ubuntu LTS as the base, no Snap, NetworkManager for networking, Dux for the desktop, and only the services it needs underneath.

---

*Community guide, not affiliated with Canonical or Dux Labs. Use at your own risk.*
