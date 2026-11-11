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

## Wallpaper

Open **Super+Alt+W** and choose a bundled still wallpaper, or select **Choose video** to use a local MP4 or WebM. **Use still wallpaper** returns to your last Glyph image, and **Use live wallpaper** brings back the selected video. Lite mode skips video playback. The player is muted, and pauses per monitor when the workspace has windows. Codec support depends on your Fedora media packages. An unreadable video falls back to the still background.

Your selected video stays on your computer. The repo ships the original Glyph artwork and still wallpapers.

## Fedora shortcuts

| Shortcut | Action |
| --- | --- |
| Super+Space | App launcher |
| Super+Return / Super+Alt+Return | Terminal / floating terminal |
| Super+B / Super+E / Super+F | Default browser / editor / default file manager |
| Super+C / Super+V | ChatGPT / VLC |
| Super+Shift+V | Clipboard history |
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

## Updates and removal

Run `./install.sh --update` to fast-forward the checkout and refresh the dependencies. System → About can also run the rice update and Fedora's normal DNF upgrade. System → Firewall reports firewalld's state and opens Fedora's firewall UI when `firewall-config` is installed. Existing file managers remain selectable under System → Apps.

The Arch login-theme installer is separate. This Fedora installer keeps your current greeter. Optional upstream integrations such as GPU Screen Recorder and Clash Verge need their own packages.

Run `./install.sh --uninstall` to remove this checkout's four configuration links. Switch to your previous desktop before uninstalling. Installed packages, saved preferences, and wallpapers remain.
