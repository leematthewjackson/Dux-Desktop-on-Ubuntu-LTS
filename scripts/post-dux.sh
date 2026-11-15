#!/usr/bin/env bash
# =============================================================================
# Dux Desktop on Ubuntu LTS: STEP 2 of 2 - apps and finishing touches
# Covers Sections 5-7 of the guide: browsers, Thunar, GNOME Text Editor,
# VLC, Flatpak apps, ArtCraft apps, Claude Code, the autostart fix, and
# your default apps.
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
  org.desktop_plus.desktop-plus          # Desktop+
)

# ArtCraft apps to install from ArtCraft's APT repository (no launcher).
# See what's available with:
#   grep -h '^Package:' /var/lib/apt/lists/*getartcraft*Packages | sort -u
ARTCRAFT_APPS=(
  anicraft deckcraft effectcraft figcraft filmcraft gridcraft
  pdfcraft photocraft soundcraft vectorcraft wordcraft
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

# Install browsers, Thunar (alongside Dux Files, as the default),
# GNOME Text Editor, and VLC (Ubuntu's normal APT package, not a Snap).
#   thunar-archive-plugin + xarchiver: "Extract here" / "Create archive"
#   thunar-volman: handles USB drives    tumbler: thumbnails
# Default apps for all of these are set in step 6.
sudo apt update
sudo apt install -y firefox brave-browser \
  thunar thunar-archive-plugin thunar-volman tumbler xarchiver \
  gnome-text-editor vlc


# --- 2. Flatpak apps (guide Section 7) --------------------------------------
# Flathub was added system-wide by setup.sh. Edit the FLATPAKS list at the top.
echo "==> 2. Flatpak apps"
flatpak install -y flathub "${FLATPAKS[@]}"

# --- 3. ArtCraft repository and apps (guide Section 7) ----------------------
# Native APT packages rather than Flatpaks, so their command-line tools are
# on your PATH for MCP connections and update with apt upgrade.
# The apps to install are in the ARTCRAFT_APPS list at the top (no launcher).
echo "==> 3. ArtCraft repository and apps"
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
sudo apt install -y "${ARTCRAFT_APPS[@]}"

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

# --- 6. Default apps -------------------------------------------------------
# Copied from the iMac's ~/.config/mimeapps.list (what Dux's default-apps
# settings saved). Machine-specific entries Firefox and Claude Code create
# by themselves are left out. Change them later in Dux's settings, or check
# what's set with:  cat ~/.config/mimeapps.list
echo "==> 6. Default apps"

# Folders -> Thunar (Dux Files stays installed as an alternative)
xdg-mime default thunar.desktop inode/directory

# Text -> GNOME Text Editor
xdg-mime default org.gnome.TextEditor.desktop text/plain

# Web, links and PDFs/comics -> Firefox
xdg-mime default firefox.desktop \
  text/html application/xhtml+xml \
  x-scheme-handler/http x-scheme-handler/https \
  application/pdf application/x-bzpdf application/x-ext-pdf application/x-gzpdf \
  application/vnd.comicbook+zip application/vnd.comicbook-rar

# Calendar files and links -> Dux Calendar
xdg-mime default dev.duxlabs.calendar.desktop \
  text/calendar x-scheme-handler/calendar x-scheme-handler/webcal x-scheme-handler/webcals

# Archives -> Xarchiver
xdg-mime default xarchiver.desktop \
  application/zip application/gzip application/x-tar application/x-xz \
  application/x-bzip2 application/x-7z-compressed application/x-rar

# Office documents -> ArtCraft apps
xdg-mime default ai.storyteller.wordcraft.desktop \
  application/msword application/rtf \
  application/vnd.oasis.opendocument.text \
  application/vnd.openxmlformats-officedocument.wordprocessingml.document
xdg-mime default ai.storyteller.gridcraft.desktop \
  application/vnd.ms-excel text/csv \
  application/vnd.oasis.opendocument.spreadsheet \
  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
xdg-mime default ai.storyteller.deckcraft.desktop \
  application/vnd.ms-powerpoint \
  application/vnd.oasis.opendocument.presentation \
  application/vnd.openxmlformats-officedocument.presentationml.presentation

# Video and audio -> VLC
xdg-mime default vlc.desktop \
  video/avi video/mp4 video/mpeg video/quicktime video/webm video/x-matroska video/x-msvideo \
  audio/aac audio/mpeg audio/ogg audio/wav audio/webm audio/x-flac

# --- Done: manual steps the script can't do ---------------------------------
cat <<'EOF'

==> Done.

Next (manual):
  1. Log out and back in (picks up autostart, Claude Code's PATH and new app icons).
  2. Join Wi-Fi from Dux if needed.
  3. Run `claude` in a project folder to log in to Claude Code (needs a browser).
  4. In Dux's settings:
     - Default apps are already set (step 6). Images aren't - pick Gwenview
       for them if you like.
     - Add autostart apps. For Nextcloud in the tray, add --background to the
       end of its command.
  5. Sign in to Nextcloud and Firefox/Brave sync.
  6. Want more ArtCraft apps later? List what's available with:
       grep -h '^Package:' /var/lib/apt/lists/*getartcraft*Packages | sort -u
  7. Run through the checklist in Section 8 of the guide (dms doctor, printing,
     audio, Bluetooth, sleep/wake...).
EOF
