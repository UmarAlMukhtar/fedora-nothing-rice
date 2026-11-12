# Fedora Nothing Rice

This Fedora port of [AMM021's rice_nothing](https://github.com/AMM021/rice_nothing) uses the Glyph shell from [Nebelung-cloud](https://github.com/Nebelung-cloud/glyph-rice). It supports **Fedora 44 x86_64**.

## Install

From a terminal in your regular user account:

```bash
git clone https://github.com/UmarAlMukhtar/fedora-nothing-rice.git ~/.local/share/fedora-nothing-rice
cd ~/.local/share/fedora-nothing-rice
./install.sh
```

DNF asks for administrator access and shows the package transaction before applying it. Hyprland and the newer Quickshell packages come from the signed [nett00n/hyprland community COPR](https://copr.fedorainfracloud.org/coprs/nett00n/hyprland/) for that transaction. Fedora supplies the other dependencies. The installer does not add the COPR to your persistent repository list or change your login manager, default apps, bootloader, or desktop settings. It refuses to overwrite an existing Hyprland or Glyph configuration.

Log out and choose **Hyprland** from your login screen's session menu. If your login manager doesn't list Wayland sessions, switch to a text console with **Ctrl+Alt+F3**, log in, and run `start-hyprland`. To return to your previous desktop, exit Hyprland and choose your usual session. Use `./install.sh --dry-run` to preview the link targets, or `--links` when the packages are already installed.

### Optional Glyph login screen

After installing the rice, run `sudo ./config/greeter/install.sh` to install the Glyph Lock greeter. To select it for the next boot, run `sudo systemctl enable --force greetd.service`. Save your work before rebooting. The session picker offers Hyprland and, if installed, bspwm (X11).

To restore your previous login manager from a text console, re-enable its service with `sudo systemctl enable --force lightdm.service` (use the service you previously used) and reboot.

## Wallpaper

Open **Super+Alt+W** and choose a bundled still wallpaper, or select **Choose video** to use a local MP4 or WebM. **Use still wallpaper** returns to your last Glyph image, and **Use live wallpaper** brings back the selected video. Lite mode skips video playback. The player is muted, and pauses per monitor when the workspace has windows. Codec support depends on your Fedora media packages. An unreadable video falls back to the still background.

Your selected video stays on your computer. The repo ships the original Glyph artwork and still wallpapers.

## Fedora shortcuts

| Shortcut | Action |
| --- | --- |
| Super+Space | App launcher |
| Super+Return / Super+Alt+Return | Terminal / floating terminal |
| Super+B / Super+E / Super+F | Default browser / editor / default file manager |
| Super+C / Super+Shift+V | ChatGPT / VLC |
| Super+V | Clipboard history |
| Super+Left / Right | Previous / next workspace |
| Super+1–9 / Super+Ctrl+1–9 | Switch / move a window to a workspace |
| Super+Alt+Arrow | Focus a window in that direction |
| Alt+Tab | Cycle windows |
| Super+X / Alt+A / Alt+F | Close / toggle floating / fullscreen |
| Super+left drag / Super+right drag | Move / resize a window |
| Super+I / Super+R | System settings / Glyph appearance |
| Super+Alt+N / Super+Alt+B / F7 | Network / Bluetooth / display |
| Super+Alt+W / Super+Ctrl+D | Wallpapers / dashboard |
| Super+Alt+P / Super+L | Power menu / lock |
| Print / Shift+Print | Open the screenshot panel |
| Super+Shift+P | Launch scrcpy, if installed |

The app keys use the system default or the installed app where possible. Set personal overrides in `~/.config/hypr/user.lua` (gitignored). bspwm-specific scripts such as xwinwrap, Polybar actions, and the original PiP helpers stay with the bspwm session. Glyph has its own window rules and clipboard history.

## Picture-in-picture and screen sharing

Hyprland pins picture-in-picture windows across workspaces and restores their size and position. Use **Super+left drag** to move and **Super+right drag** to resize.

Brave's automatic PiP can also open when you switch workspaces. With native Brave and automatic PiP enabled for the video site:

1. Open `brave://extensions`, enable **Developer mode**, and use **Load unpacked** to select `fedora/brave-pip/desktop-extension` from this checkout.
2. Copy the extension's ID and run `python3 fedora/brave-pip/register.py EXTENSION_ID` from the checkout. The script preserves an existing registration.
3. Reload the extension, play an audible video, and switch workspaces. The extension checks playback on HTTPS pages and uses a temporary tab to trigger Brave's native PiP. Site and browser support for automatic PiP still applies.

The Fedora installer sets up the Hyprland graphical session target for PipeWire screen sharing. Choose a **Window** in your app's share picker to keep other workspaces private.

## Google Calendar

Add Google in Fedora's **Settings → Online Accounts** and enable **Calendar** for the account. Hover over the Glyph clock to preview the calendar, or click it to keep it open until you click outside or press Escape. Dates with events show a dot. Hover over a date to see its events, or pin the calendar and use Tab. Glyph reads the enabled Google calendars through Evolution Data Server.

## Optional offline Filee conversion wheel

Install the dependencies, then run the Filee setup from the rice checkout as your regular user.

```bash
sudo dnf install nautilus nautilus-python bubblewrap curl
./fedora/filee/install.sh
```

The setup checks the SHA-256 of the [Filee 2.4.0 Linux x64 release](https://github.com/KnifeLemon/Filee/releases/tag/v2.4.0) before installing it. It also works with an existing standard Filee 2.4.0 installation. If you already have the release archive, pass its path to `./fedora/filee/install.sh` to skip the download.

Close any active Filee conversions before running the setup. Run `nautilus -q` and reopen Files to load the extension. Run `hyprctl reload` in the rice session to enable the wheel's cursor placement and opening animation.

Middle-click a local file in **Files (Nautilus)** to open its conversion wheel at the pointer. A three-finger tap does the same when your touchpad maps it to middle-click (Hyprland's default with tap-to-click enabled).

Filee and its conversion tools run in an isolated network namespace. The setup disables automatic update checks, external links, and the GitHub feedback prompt. Built-in and already installed conversion engines work offline. Web downloads, optional engine downloads, and the local Ollama connection are unavailable in this mode. An upstream reinstall can replace the offline launchers.

To remove the wheel gesture, delete `${XDG_DATA_HOME:-$HOME/.local/share}/nautilus-python/extensions/filee_middle_click.py`, restart Files and reload Hyprland. Filee's own uninstaller removes the app. After uninstalling, remove `${XDG_DATA_HOME:-$HOME/.local/share}/filee/offline-payload` to delete the saved offline launch files.

## Updates and removal

Run `./install.sh --update` to fast-forward the checkout and refresh the dependencies. System → About can also run the rice update and Fedora's normal DNF upgrade. System → Firewall reports firewalld's state and opens Fedora's firewall UI when `firewall-config` is installed. Existing file managers remain selectable under System → Apps.

Optional upstream integrations such as GPU Screen Recorder and Clash Verge need their own packages.

Run `./install.sh --uninstall` to remove this checkout's configuration links. Switch to your previous desktop before uninstalling. Installed packages, saved preferences, and wallpapers remain.
