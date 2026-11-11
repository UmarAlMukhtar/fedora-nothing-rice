#!/usr/bin/env bash
set -euo pipefail

# Use the community repository only for this transaction. Keep RPM signature checks on.
copr=https://copr-be.cloud.fedoraproject.org/results/nett00n/hyprland
exec sudo dnf5 --repo=fedora --repo=updates \
    --repofrompath="nothing-hyprland,$copr/fedora-44-x86_64/" \
    --setopt=nothing-hyprland.gpgcheck=1 \
    --setopt="nothing-hyprland.gpgkey=$copr/pubkey.gpg" \
    --setopt=install_weak_deps=False "$@" install \
    'hyprland >= 0.56' 'quickshell >= 0.3.1' hypridle hyprsunset hyprpicker hyprland-guiutils \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt6-qtmultimedia qt6-qt5compat \
    qt6-qtimageformats qt6-qtwayland cliphist kitty wl-clipboard grim slurp \
    ImageMagick vips libqalculate brightnessctl playerctl cava udiskie lxqt-policykit \
    python3-dbus python3-gobject zenity gnome-keyring NetworkManager bluez pipewire \
    pipewire-pulseaudio wireplumber upower gvfs gvfs-mtp pavucontrol
