#!/usr/bin/env bash
set -euo pipefail
umask 077

here=$(cd -- "$(dirname -- "$0")" && pwd -P)
version=2.4.0
release=Filee-$version-linux-x64
checksum=bd62499c837a80216ec4a06bb8cb72ef39600338872a86e1585fb4347106c7b0

die() { printf '%s\n' "$*" >&2; exit 1; }
if [[ ${1:-} == --help ]]; then
    echo "Usage: $0 [path/to/$release.tar.gz]"
    exit 0
fi
(( $# <= 1 )) || die "Pass at most one Filee release archive."
(( EUID != 0 )) || die "Run this installer as your normal user."
[[ $(uname -m) == x86_64 ]] || die "This setup uses the x86_64 Filee release."
rpm -q bubblewrap nautilus nautilus-python >/dev/null ||
    die "Install the dependencies with sudo dnf install bubblewrap nautilus nautilus-python curl"
bwrap --unshare-net --bind / / --dev-bind /dev /dev -- true ||
    die "Bubblewrap could not isolate networking."

data=${XDG_DATA_HOME:-$HOME/.local/share}
settings=${FILEE_DATA_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/Filee}/settings.json
root=$data/filee
app=$root/application
payload=$root/offline-payload
extension=$data/nautilus-python/extensions/filee_middle_click.py

if [[ -e $extension || -L $extension ]]; then
    cmp -s -- "$extension" "$here/filee_middle_click.py" ||
        die "Existing Nautilus extension at $extension. Move it aside before installing."
fi

mkdir -p -- "$root"
exec 9>"$root/.rice-install.lock"
flock -n 9 || die "Another Filee installation is in progress."
stage=$(mktemp -d -- "$root/.rice-install.XXXXXX")
trap 'rm -r -- "$stage"' EXIT

installer=
source=$app
if [[ -e $app || -L $app ]]; then
    [[ ! -L $app && -f $app/.filee-package && $(<"$app/.filee-package") == com.filee.app ]] ||
        die "Expected a standard Filee installation at $app."
    grep -Fq "\"Filee/$version\"" "$app/Filee.deps.json" ||
        die "This setup supports Filee $version."
else
    archive=${1:-$stage/$release.tar.gz}
    if (( $# == 0 )); then
        curl --fail --location --retry 2 --proto '=https' --output "$archive" \
            "https://github.com/KnifeLemon/Filee/releases/download/v$version/$release.tar.gz"
    fi
    actual=$(sha256sum < "$archive")
    [[ ${actual%% *} == "$checksum" ]] || die "Filee archive SHA-256 verification failed."
    mkdir "$stage/archive"
    tar -xzf "$archive" -C "$stage/archive"
    source=$stage/archive/$release
    installer=$source/install.sh
fi

# Verify the stock entry points, or the saved originals on a repeat run.
for entry in Filee filee-cli; do
    original=$source/$entry
    if cmp -s -- "$original" "$here/launch-offline"; then
        original=$payload/$entry
    fi
    case $entry in
        Filee) digest=b58620523863e3c91511fa585f9317ffdf14a782eefd4980e26dbf7d969fd422 ;;
        filee-cli) digest=5fa83d2ccbf24e4b109059421747d2e7956e0d92dc65985f6fe548772602fad5 ;;
    esac
    actual=$(sha256sum < "$original")
    [[ ${actual%% *} == "$digest" ]] || die "Expected Filee $version at $original."
    if [[ -e $payload/$entry || -L $payload/$entry ]]; then
        cmp -s -- "$original" "$payload/$entry" ||
            die "Existing offline binary at $payload/$entry differs from Filee $version."
    fi
done

if [[ -z $installer ]]; then
    timeout 25 "$app/Filee" --quit
fi

mkdir -p -m 700 -- "$payload"
install -D -m 755 -- "$here/xdg-open" "$payload/bin/xdg-open"
sed -E 's/^hosts:.*/hosts: files/' /etc/nsswitch.conf > "$stage/nsswitch.conf"
mv -T -- "$stage/nsswitch.conf" "$payload/nsswitch.conf"
for entry in Filee filee-cli; do
    if [[ ! -e $payload/$entry ]]; then
        ln -- "$source/$entry" "$payload/$entry"
    fi
    install -m 755 -- "$here/launch-offline" "$stage/$entry"
done

python3 - "$settings" <<'PY'
import json
import os
from pathlib import Path
import sys
from tempfile import NamedTemporaryFile

settings = Path(sys.argv[1])
original = settings.read_bytes() if settings.exists() else None
config = json.loads(original) if original is not None else {}
if config.get("checkForUpdates") is False and config.get("feedbackPromptShown") is True:
    raise SystemExit()
if original is not None:
    try:
        with settings.with_name("settings.before-rice-offline.json").open("xb") as backup:
            backup.write(original)
    except FileExistsError:
        pass

config.update(checkForUpdates=False, feedbackPromptShown=True)
settings.parent.mkdir(parents=True, exist_ok=True)
with NamedTemporaryFile(mode="w", dir=settings.parent, delete=False, encoding="utf-8") as handle:
    json.dump(config, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
os.replace(handle.name, settings)
PY

for entry in Filee filee-cli; do
    mv -T -- "$stage/$entry" "$source/$entry"
done
if [[ -n $installer ]]; then
    XDG_CURRENT_DESKTOP=Hyprland "$installer"
fi
"$app/filee-cli" version
install -D -m 644 -- "$here/filee_middle_click.py" "$extension"

printf '%s\n' 'Filee offline setup installed. Restart Files (nautilus -q), then open it again.' \
    'Reload Hyprland (hyprctl reload) to enable cursor placement for the conversion wheel.'
