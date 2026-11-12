# Install

How to set up this rice on a new machine, from a bare Arch install to a working Hyprland desktop.

> [!NOTE]
> This guide assumes a working, bare Arch Linux install: a user with `sudo` rights, network access, and nothing else set up yet.
> Do the steps in order. Some later steps depend on files that earlier steps create.

## Contents

1. [Bootstrap](#1-bootstrap)
2. [Packages](#2-packages)
3. [Link the configs](#3-link-the-configs)
4. [Shell](#4-shell)
5. [Theme](#5-theme)
6. [Login screen](#6-login-screen)
7. [Services and first boot](#7-services-and-first-boot)
8. [After the first login](#8-after-the-first-login)
9. [Checklist](#9-checklist)
10. [Troubleshooting](#10-troubleshooting)

## 1. Bootstrap

Install the build tools, `git` and `stow`:

```bash
sudo pacman -S --needed git base-devel stow
```

Install the AUR helper [yay](https://github.com/Jguer/yay):

```bash
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
cd ~ && rm -rf /tmp/yay
```

Clone the dotfiles:

```bash
git clone https://github.com/samyepik/dotfiles ~/.dotfiles
```

> [!IMPORTANT]
> The repo must be at `~/.dotfiles`. Keybinds, scripts and some symlinks in the repo use this path.

## 2. Packages

The packages are in groups. `yay` installs packages from both the official repos and the AUR, so every group is one command.
AUR packages are marked in the comment above each command.

**Compositor and session**

```bash
# AUR: hyprosd-git
yay -S --needed hyprland hyprpaper hyprlock hyprtoolkit hyprosd-git quickshell \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk mate-polkit qt5-wayland qt6-wayland
```

**Theming**

```bash
# AUR: python-pywal16, waypaper
yay -S --needed python-pywal16 waypaper kvantum kvantum-qt5 qt6ct adw-gtk-theme papirus-icon-theme \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
```

**Audio and media**

```bash
yay -S --needed pipewire pipewire-pulse wireplumber playerctl pamixer wiremix mpv yt-dlp
```

**Hardware: power, brightness, network, Bluetooth**

```bash
# AUR: bluetuith-bin
yay -S --needed brightnessctl batsignal networkmanager bluez bluez-utils bluetuith-bin
```

**Desktop utilities: launcher, notifications, clipboard, screenshots**

```bash
yay -S --needed wofi dunst libnotify cliphist wl-clipboard grim slurp swappy
```

**Terminal and CLI**

`ripgrep`, `fd`, `nodejs`, `npm` and `unzip` are for Neovim (LazyVim and its language servers).

```bash
yay -S --needed zsh kitty neovim btop yazi fzf fastfetch ripgrep fd nodejs npm unzip
```

**Apps**

```bash
# AUR: python-pywalfox, python-selenium, webcord, spotifast-bin
yay -S --needed firefox python-pywalfox python-selenium geckodriver thunar webcord spotifast-bin
```

**Login screen**

```bash
# AUR: hyprlogin
yay -S --needed greetd hyprlogin
```

## 3. Link the configs

Each top-level folder in the repo is one [GNU Stow](https://www.gnu.org/software/stow/) package. Its contents mirror the paths in `$HOME`.
For example, `kitty/.config/kitty/kitty.conf` is linked to `~/.config/kitty/kitty.conf`.

These folders are **not** stow packages. Do not stow them:

| Folder | What it is |
| --- | --- |
| `scripts/` | Scripts that keybinds and menus call. `hypr` links to it. |
| `wallpapers/` | Wallpapers for waypaper. |
| `hyprlogin/` | Login screen config. It goes to `/etc`, see [Login screen](#6-login-screen). |
| `BetterDiscord/` | Discord themes. Not part of the install. |
| `waybar/` | The old bar. Quickshell replaced it, so it is not linked. |

First, do a dry run. It shows what stow will do and changes nothing:

```bash
cd ~/.dotfiles
stow -nv bluetuith btop cliphist dunst hypr kitty kvantum mpv nvim quickshell swappy wal waypaper wofi zsh
stow -nv --no-folding spotifast
```

If the dry run shows no conflicts, link the configs:

```bash
stow bluetuith btop cliphist dunst hypr kitty kvantum mpv nvim quickshell swappy wal waypaper wofi zsh
stow --no-folding spotifast
```

> [!NOTE]
> **Spotifast**
>
> - `spotifast` uses `--no-folding` because Spotifast writes its settings, skins and visualizer presets into `~/.config/spotifast`. Without that flag, those files would go into the repo.
> - Only `themes/Pywal.json` is linked. `skin-base/base-2.91.wsz` is not linked: `scripts/spotifast_pywal_skin.py` reads it directly from `~/.dotfiles/spotifast/.config/spotifast/skin-base/` and writes the themed Winamp skin to `~/.config/spotifast/skins/`. `spotifast/.stow-local-ignore` tells stow to skip it.

> [!WARNING]
> **Conflicts:** Some programs create a default config the first time they run.
> If a file already exists where stow wants to put a link, stow stops and lists the file:
>
> ```text
> WARNING! stowing kitty would cause conflicts:
>   * cannot stow .../kitty/.config/kitty/kitty.conf over existing target .config/kitty/kitty.conf since neither a link nor a directory and --adopt not specified
> All operations aborted.
> ```
>
> Look at the file. Move it away if you want to keep it, or delete it. Then run the `stow` command again:
>
> ```bash
> mv ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.bak
> ```

When you add a new stow package to the repo, add it to the commands above.

## 4. Shell

Install [Oh My Zsh](https://ohmyz.sh/). `KEEP_ZSHRC=yes` stops the installer from replacing the `.zshrc` that you linked in step 3:

```bash
KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

Make zsh your login shell:

```bash
chsh -s /usr/bin/zsh
```

The new shell starts when you log in again.

## 5. Theme

All colors come from [pywal16](https://github.com/eylles/pywal16). It reads the templates in `~/.config/wal/templates` and writes the color files into `~/.cache/wal`. Hyprland, Quickshell, kitty, wofi, dunst, Kvantum, Neovim and Spotifast read their colors from there.

Wofi reads `~/.cache/wal/colors` by itself. In the wofi stylesheets, `--wofi-color0` to `--wofi-color15` are the pywal colors `color0` to `color15`. Do not use `@import` for colors in a wofi stylesheet: wofi loads the stylesheet as text, so a relative import path would be resolved against the folder wofi was started from.

Make the first color scheme now, before the first login. `-n` skips setting the wallpaper because no compositor is running yet:

```bash
wal -n -i ~/.dotfiles/wallpapers/sunset_wolf_forrest.png
```

The theme reload script also writes a GTK override to `/usr/local/share/gtk-overrides`. Make that folder and give it to your user, so the script can write there without `sudo`:

```bash
sudo install -d -o "$USER" -g "$USER" /usr/local/share/gtk-overrides
```

> [!TIP]
> After the first login, change the wallpaper with waypaper (system menu, _SUPER + A_). Waypaper runs `scripts/post_theme_reload.sh`, which makes a new color scheme from the wallpaper and reloads all themed programs.

## 6. Login screen

The login screen is [hyprlogin](https://github.com/AuthenticSm1les/hyprlogin), a greeter for [greetd](https://sr.ht/~kennylevinsen/greetd/) that runs in its own small Hyprland session.
Its files are in `hyprlogin/`. They go to `/etc`, so they are copied, not linked:

| Repo file | Installed to |
| --- | --- |
| `hyprlogin/greetd-config.toml` | `/etc/greetd/config.toml` |
| `hyprlogin/hyprland-greeter.lua` | `/etc/hyprlogin/hyprland-greeter.lua` |
| `hyprlogin/hyprlogin.conf` | `/etc/hyprlogin/hyprlogin.conf` |
| `hyprlogin/catgirl-anime-girl.png` | `/usr/share/hypr/catgirl-anime-girl.png` |

```bash
cd ~/.dotfiles/hyprlogin
sudo install -Dm644 greetd-config.toml     /etc/greetd/config.toml
sudo install -Dm644 hyprland-greeter.lua   /etc/hyprlogin/hyprland-greeter.lua
sudo install -Dm644 hyprlogin.conf         /etc/hyprlogin/hyprlogin.conf
sudo install -Dm644 catgirl-anime-girl.png /usr/share/hypr/catgirl-anime-girl.png
```

Set your username as the default user on the login screen:

```bash
sudo sed -i "s/^\(\s*default_user = \).*/\1$USER/" /etc/hyprlogin/hyprlogin.conf
```

> [!NOTE]
> In `hyprlogin.conf`, the password field is set to `monitor = eDP-1`, which is a laptop's built-in screen.
> On a desktop, or to show the field on all screens, change it to `monitor =` (empty).

If you change one of these files later, copy it again with the same `install` command.

## 7. Services and first boot

Before you log in for the first time, check the screen layout in `hypr/.config/hypr/categories/monitors.lua`.
It contains the outputs, resolutions and positions of the original machine. The last line is a fallback that enables any other screen with its preferred mode.
Use `hyprctl monitors` later to get the output names.

Enable the services. PipeWire runs as a user service and starts by itself.

```bash
sudo systemctl enable NetworkManager bluetooth greetd
```

Reboot. The hyprlogin screen opens. Log in to start Hyprland:

```bash
reboot
```

## 8. After the first login

### Touch gestures (only for touchscreens)

Touch gestures use the [hyprgrass](https://github.com/horriblename/hyprgrass) plugin. The config works without it, so skip this on devices without a touchscreen.
Run these commands in a terminal inside Hyprland:

```bash
sudo pacman -S --needed cmake meson cpio pkgconf
hyprpm update
hyprpm add https://github.com/horriblename/hyprgrass
hyprpm enable hyprgrass
hyprctl reload
```

Hyprland loads the plugin at every start (see `categories/autostart.lua`).

### Neovim

Start `nvim` once and wait until [LazyVim](https://www.lazyvim.org/) has installed all plugins. Then restart it.

### Firefox

Start Firefox once, so that it makes a profile.

**Pywalfox:** this gives Firefox the pywal colors.

1. Install the native messaging host:

   ```bash
   pywalfox install
   ```

2. Install the [Pywalfox extension](https://addons.mozilla.org/firefox/addon/pywalfox/) and click _Fetch Pywal colors_ in it.

**Dark Reader:** this gives websites the pywal colors.

1. Install the [Dark Reader extension](https://addons.mozilla.org/firefox/addon/darkreader/).
2. Close Firefox.

`scripts/darkreader_reload.py` imports the pywal theme into Dark Reader at each theme reload. It finds the default Firefox profile through `profiles.ini`.
To use a different profile, set `DARKREADER_FF_PROFILE` to the absolute profile path.

## 9. Checklist

Test these after the first login:

- [ ] Quickshell bar is at the top of the screen.
- [ ] _SUPER + A_ opens the system menu. Its help section explains the rice.
- [ ] _SUPER + Q_ opens kitty with the pywal colors and the zsh prompt.
- [ ] _SUPER + R_ opens the app launcher.
- [ ] Change the wallpaper with waypaper. The colors of the bar, kitty, wofi and window borders change.
- [ ] _SUPER + V_ shows the clipboard history.
- [ ] _SUPER + SHIFT + PRINT_ takes a region screenshot and opens it in swappy.
- [ ] Volume keys change the volume and show the on-screen display.
- [ ] _SUPER + SHIFT + L_ locks the screen.

## 10. Troubleshooting

**`stow` stops with "would cause conflicts"**
A program made its own config before you ran stow. Move the file or folder away and run stow again. See [Link the configs](#3-link-the-configs).

**Neovim shows pywal errors**
`~/.cache/wal` is empty. Run the `wal` command from [Theme](#5-theme).

**Touch gestures stop working after a Hyprland update**
The plugin must be built again for the new Hyprland version. Hyprland shows a notification when this is necessary. Run `hyprpm update`, then `hyprctl reload`.

**The login screen does not start**
Press _CTRL + ALT + F2_ to get a TTY and log in there. Look at the log with `journalctl -b -u greetd`.
For more detail, set `debug_mode = true` in `/etc/hyprlogin/hyprlogin.conf`. hyprlogin then writes its log to `/tmp/hyprlogin-debug.log`.

**The theme reload shows an error for a program you do not use**
`post_theme_reload.sh` also themes Obsidian, Discord and Dark Reader. This guide does not install them. You can ignore errors for programs that are not installed.
