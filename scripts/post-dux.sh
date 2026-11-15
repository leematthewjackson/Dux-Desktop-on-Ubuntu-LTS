#!/usr/bin/env bash
# =============================================================================
# Dux Desktop on Ubuntu LTS: STEP 2 of 2 - apps and finishing touches
# Covers Sections 5-7 of the guide: browsers, Thunar, GNOME Text Editor,
# Flatpak apps, the ArtCraft repository, Claude Code, and the autostart fix.
#
# WHEN:  After setup.sh, the reboot, and the Dux installer - once you've
#        logged in to the Dux desktop.
# HOW:   Run as your normal user (NOT with sudo), from Alacritty INSIDE the
#        Dux desktop (not over SSH - the autostart check needs your desktop
#        session):
#          ./post-dux.sh
# AFTER: Log out and back in, then do the manual steps listed at the end.
#
# Notes:
# - Stops at the first error (set -e).
# - Repo keys for Mozilla and ArtCraft are checked against known fingerprints
#   and the script stops if they don't match.
# =============================================================================

set -euo pipefail

# --- Settings you might want to change ---------------------------------------

# Flatpak apps to install from Flathub. Add or remove app IDs here.
FLATPAKS=(
  org.kde.gwenview                       # Image viewer
  com.nextcloud.desktopclient.nextcloud  # Nextcloud sync client
)

# Expected repository key fingerprints. If one stops matching, check the
# vendor's site before changing it here:
#   Mozilla:  https://support.mozilla.org/kb/install-firefox-linux
#   ArtCraft: https://getartcraft.com/linux
ARTCRAFT_FINGERPRINT="2B76741B414AAD6CD33E631213A005C0B9D7C3ED"
MOZILLA_FINGERPRINT="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"

# -----------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not with sudo. It will ask for your password."
  exit 1
fi

sudo -v   # ask for the password once, up front

# --- 1. Browsers, file manager and text editor (guide Section 6) ------------
echo "==> 1. Browsers, file manager and text editor (all APT)"

# Firefox from Mozilla's own APT repository (Snap is blocked by setup.sh).
# Steps follow Mozilla's instructions for Ubuntu 26.04 (deb822 .sources file).
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
  sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
if ! gpg --show-keys /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null | tr -d ' ' | grep -q "$MOZILLA_FINGERPRINT"; then
  echo "Mozilla key fingerprint doesn't match $MOZILLA_FINGERPRINT. Stopping."
  sudo rm -f /etc/apt/keyrings/packages.mozilla.org.asc
  exit 1
fi
sudo tee /etc/apt/sources.list.d/mozilla.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
# Pins: prefer anything from Mozilla's repo, and never take Ubuntu's
# "firefox" package (that's only a stub that installs the Snap).
sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox
Pin: release o=Ubuntu
Pin-Priority: -1
EOF

# Brave from Brave's own APT repository (their key + ready-made .sources file).
# Note: unlike Mozilla and ArtCraft, this key isn't fingerprint-checked here.
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

# Install browsers, Thunar (replaces Dux Files) and GNOME Text Editor
# (replaces Dux's editor).
#   thunar-archive-plugin + xarchiver: "Extract here" / "Create archive"
#   thunar-volman: handles USB drives    tumbler: thumbnails
sudo apt update
sudo apt install -y firefox brave-browser \
  thunar thunar-archive-plugin thunar-volman tumbler xarchiver \
  gnome-text-editor

# Make Thunar the default for folders and Text Editor the default for text.
xdg-mime default thunar.desktop inode/directory
xdg-mime default org.gnome.TextEditor.desktop text/plain

# --- 2. Flatpak apps (guide Section 7) --------------------------------------
# Flathub was added system-wide by setup.sh. Edit the FLATPAKS list at the top.
echo "==> 2. Flatpak apps"
flatpak install -y flathub "${FLATPAKS[@]}"

# --- 3. ArtCraft repository (guide Section 7) -------------------------------
# Adds the repository only - no apps are installed. Install the ArtCraft apps
# you want later with apt (see the reminders at the end). Native APT packages
# rather than Flatpaks, so their command-line tools are on your PATH for MCP
# connections and update with apt upgrade.
echo "==> 3. ArtCraft repository (apps installed later, by choice)"
sudo install -d -m 755 /etc/apt/keyrings
sudo curl -fsSL https://getartcraft.com/keys/artcraft.gpg -o /etc/apt/keyrings/artcraft.gpg
sudo chmod 644 /etc/apt/keyrings/artcraft.gpg   # APT's _apt user must be able to read it
if ! gpg --show-keys /etc/apt/keyrings/artcraft.gpg 2>/dev/null | tr -d ' ' | grep -q "$ARTCRAFT_FINGERPRINT"; then
  echo "ArtCraft key fingerprint doesn't match $ARTCRAFT_FINGERPRINT. Stopping."
  echo "Check https://getartcraft.com/linux for the current fingerprint."
  sudo rm -f /etc/apt/keyrings/artcraft.gpg
  exit 1
fi
sudo curl -fsSL https://getartcraft.com/apt/artcraft.sources -o /etc/apt/sources.list.d/artcraft.sources
sudo apt update

# --- 4. Claude Code (guide Section 7) ---------------------------------------
# Official installer: puts `claude` in ~/.local/bin and updates itself.
# ~/.local/bin only joins your PATH after you log out and back in.
echo "==> 4. Claude Code"
curl -fsSL https://claude.ai/install.sh | bash

# --- 5. Autostart fix (guide Section 5) -------------------------------------
# Dux's autostart entries only run if the session starts
# xdg-desktop-autostart.target. If it isn't active, add it to Hyprland's
# session target (what `systemctl --user edit` would do, without the editor).
echo "==> 5. Autostart apps"
if systemctl --user is-active --quiet xdg-desktop-autostart.target; then
  echo "Autostart already works. Nothing to do."
elif systemctl --user is-active --quiet hyprland-session.target; then
  mkdir -p ~/.config/systemd/user/hyprland-session.target.d
  cat > ~/.config/systemd/user/hyprland-session.target.d/autostart.conf <<'EOF'
[Unit]
Wants=xdg-desktop-autostart.target
EOF
  systemctl --user daemon-reload
  echo "Added autostart to hyprland-session.target. Takes effect after you log out and back in."
else
  # Session target has a different name on this machine - do it by hand.
  cat <<'EOF'
Couldn't find hyprland-session.target. Fix autostart by hand:
  systemctl --user list-units --type=target --state=active
  systemctl --user edit <session>.target
and add:
  [Unit]
  Wants=xdg-desktop-autostart.target
EOF
fi

# --- Done: manual steps the script can't do ---------------------------------
cat <<'EOF'

==> Done.

Next (manual):
  1. Log out and back in (picks up autostart, Claude Code's PATH and new app icons).
  2. Join Wi-Fi from Dux if needed.
  3. Run `claude` in a project folder to log in to Claude Code (needs a browser).
  4. In Dux's settings:
     - Set your default browser and image viewer (Gwenview).
     - Add autostart apps. For Nextcloud in the tray, add --background to the
       end of its command.
  5. Sign in to Nextcloud and Firefox/Brave sync.
  6. Install the ArtCraft apps you want (the repository is already added):
       apt search artcraft
       sudo apt install <package-name>
  7. Run through the checklist in Section 8 of the guide (dms doctor, printing,
     audio, Bluetooth, sleep/wake...).
EOF
