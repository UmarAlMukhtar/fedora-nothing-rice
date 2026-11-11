#!/bin/sh
# Installs the Lock greeter (the lock screen's look) for greetd. The main install.sh calls this; by hand: sudo config/greeter/install.sh
# Rerun after a glyph update, a new wallpaper or a theme change: the greeter sees copies, not your home.
# It does not switch display managers; it prints the command for that.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
me=${SUDO_USER:?run with sudo from your own account}
home=$(getent passwd "$me" | cut -d: -f6)
here=$(dirname "$(readlink -f "$0")")
glyph=$(readlink -f "$home/.config/quickshell/glyph")
dst=/var/lib/greetd # root-owned: shell copy and state. home/ is the greeter user's own (cache, last pick)
greeter_home="$dst/home"
greeter_user=greeter
greeter_config="$here/config.toml"

. /etc/os-release
if [ "$ID" = fedora ]; then
    dnf5 --repo=fedora --repo=updates install greetd greetd-selinux cage
    dst=/etc/greetd/glyph
    greeter_home=/var/lib/greetd/glyph-home
    greeter_user=greetd
    greeter_config="$here/../../fedora/greetd.toml"
else
    pacman -S --needed --noconfirm greetd cage
fi

# shell: a copy of glyph plus the greeter. LockView is LockSurface without WlSessionLock, user and avatar passed in
mkdir -p "$dst"
stage=$(mktemp -d "$dst/.setup.XXXXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/state/rice"
cp -r "$glyph" "$stage/shell"
cp "$here/greeter.qml" "$stage/shell/"
view="$stage/shell/lock/LockView.qml"
sed -e 's/^WlSessionLockSurface {/Item {/' \
    -e 's/text: Quickshell.env("USER")/text: root.user/' \
    -e 's|url: `file://${Quickshell.env("HOME")}/.face`|url: root.face|' \
    -e 's/^    color: Theme.bg$/    property string user: Quickshell.env("USER")\n    property string face: ""\n    property alias stage: stage/' \
    -e '/^import Quickshell.Hyprland$/d' \
    -e '/\/\/ lock-focus$/d' \
    -e '/mainName = Hyprland.focusedMonitor/d' \
    -e 's/readonly property bool primary: .*/readonly property bool primary: true/' \
    -e 's/readonly property bool power: true.*/readonly property bool power: false/' \
    "$glyph/lock/LockSurface.qml" > "$view"
for want in '^Item {' 'text: root.user' 'url: root.face' 'property alias stage' 'bool power: false'; do
    grep -q "$want" "$view" || { echo "glyph's LockSurface.qml changed, LockView not built (missing: $want)" >&2; exit 1; }
done

# theme state and the wallpaper's screen-sized copy; no notification count before login
# nothing there yet on a first install: the greeter starts from the defaults
if [ "$ID" = fedora ]; then
    if [ -f "$dst/state/rice/glyph.json" ]; then
        cp "$dst/state/rice/glyph.json" "$stage/state/rice/glyph.json"
    else
        printf '{"unread":0}\n' > "$stage/state/rice/glyph.json"
    fi
else
    state="$home/.local/state/rice/glyph.json"
    [ -r "$state" ] || state=/dev/null
    jq -n --slurpfile s "$state" '($s[0] // {}) + { unread: 0 }' > "$stage/state/rice/glyph.json"
    wall=$(jq -r '.wall // ""' "$stage/state/rice/glyph.json")
    mkdir -p "$greeter_home/.cache/glyph/walls"
    [ -n "$wall" ] && cp "$home/.cache/glyph/walls/${wall##*/}.jpg" "$greeter_home/.cache/glyph/walls/" 2>/dev/null || true
fi

# fonts the greeter user can't read from your home
install -Dm644 -t /usr/share/fonts/glyph "$here/../fonts/"*.[ot]tf
fc-cache -f /usr/share/fonts/glyph
[ -f "$home/.face" ] && install -Dm644 "$home/.face" "/var/lib/AccountsService/icons/$me" || true

chown -R root:root "$stage/shell" "$stage/state"
chmod -R a+rX "$stage/shell" "$stage/state"
rm -rf "$dst/shell" "$dst/state"
mv "$stage/shell" "$stage/state" "$dst/"
if [ "$ID" = fedora ]; then
    install -d -m700 -o "$greeter_user" -g "$greeter_user" "$greeter_home"
    restorecon -R "$dst" "$greeter_home"
else
    chown root:root "$dst"
    chmod a+rx "$dst"
    chown -R "$greeter_user:$greeter_user" "$greeter_home"
    usermod -d "$greeter_home" "$greeter_user"
fi

[ -f /etc/greetd/config.toml ] && cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
install -m644 "$greeter_config" /etc/greetd/config.toml
if [ "$ID" = fedora ]; then restorecon /etc/greetd/config.toml; fi

echo "installed. greetd reads its config only at start: reboot to apply config.toml changes"
systemctl -q is-enabled greetd || echo "switch to it at the next boot with: sudo systemctl enable --force greetd.service"
