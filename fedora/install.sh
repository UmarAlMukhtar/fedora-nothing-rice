#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
. /etc/os-release
if [[ $ID != fedora || $VERSION_ID != 44 || $(uname -m) != x86_64 ]]; then
    echo "This installer supports Fedora 44 x86_64." >&2
    exit 1
fi
if (( EUID == 0 )); then
    echo "Run as your normal user. DNF will ask for administrator access." >&2
    exit 1
fi
if [[ ${XDG_CONFIG_HOME:-$HOME/.config} != "$HOME/.config" ]]; then
    echo "Glyph needs the default XDG_CONFIG_HOME ($HOME/.config)." >&2
    exit 1
fi

sources=(config/hypr config/quickshell/glyph config/quickshell/rice config/fonts)
targets=(.config/hypr .config/quickshell/glyph .config/quickshell/rice .local/share/fonts/glyph)
mode=${1:-install}
if (( $# > 1 )); then
    echo "Use one installer option at a time." >&2
    exit 2
fi

case "$mode" in
    --help|-h)
        echo "Usage: ./install.sh [--dry-run | --links | --update | --uninstall]"
        exit 0 ;;
    --uninstall)
        for i in "${!targets[@]}"; do
            dst=$HOME/${targets[i]}
            if [[ -L $dst && $(readlink -- "$dst") == "$repo/${sources[i]}" ]]; then
                unlink -- "$dst"
            fi
        done
        echo "Removed this checkout's config links. Packages and wallpaper choices remain."
        exit 0 ;;
    --update)
        git -C "$repo" pull --ff-only
        exec "$repo/fedora/install.sh" ;;
    install|--dry-run|--links) ;;
    *)
        echo "Unsupported Fedora option: $mode. See ./install.sh --help." >&2
        exit 2 ;;
esac

for i in "${!targets[@]}"; do
    dst=$HOME/${targets[i]}
    if [[ -L $dst && $(readlink -- "$dst") == "$repo/${sources[i]}" ]]; then
        continue
    fi
    if [[ -e $dst || -L $dst ]]; then
        printf 'Existing configuration at %s. Back it up and move it before installing.\n' "$dst" >&2
        exit 1
    fi
done

if [[ $mode == --dry-run ]]; then
    printf 'Install the Fedora Hyprland and Quickshell packages, then link:\n'
    printf '  ~/%s\n' "${targets[@]}"
    echo "LightDM and your other sessions remain available."
    exit 0
fi
[[ $mode == --links ]] || "$repo/fedora/packages.sh"

for i in "${!targets[@]}"; do
    dst=$HOME/${targets[i]}
    if [[ -L $dst && $(readlink -- "$dst") == "$repo/${sources[i]}" ]]; then
        continue
    fi
    mkdir -p -- "${dst%/*}"
    ln -sT -- "$repo/${sources[i]}" "$dst"
done

state=${XDG_STATE_HOME:-$HOME/.local/state}/rice
mkdir -p -- "$state" "$HOME/.config/demonshot" "$HOME/Pictures/Wallpapers"
if [[ ! -e $state/shell ]]; then
    (set -o noclobber; printf 'glyph\n' > "$state/shell")
fi
for wallpaper in "$repo"/assets/wallpapers/*.jpg; do
    cp --update=none -- "$wallpaper" "$HOME/Pictures/Wallpapers/"
done
fc-cache "$HOME/.local/share/fonts"
if command -v Hyprland >/dev/null; then
    result=$(Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" 2>&1)
    if ! grep -qx 'config ok' <<<"$result"; then
        printf '%s\n' "$result" >&2
        echo "Hyprland rejected the configuration. Review the output before logging in." >&2
        exit 1
    fi
fi
printf '\nFedora Nothing Rice is ready. At login select Hyprland, or run start-hyprland from a text console.\n'
