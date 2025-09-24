# dotfiles

Dotfiles for my Arch Linux Hyprland rice

## System

- OS: Arch Linux x86_64
- Shell: zsh 5.9
- DE: Hyprland
- Terminal: kitty

## Key Features

- Sleek and productive design
- TUI focused look
- Pywal-based dynamic theming
- Wofi-based system menu

## ToDo

- add choosable custom apps (browser, terminal, etc.)
- create help page/documentation
- might replace dunst with swaync
- optionaly add tty look to more apps (textfox, spotify-tui, etc.)
- theme discord and spotfiy with pywal
- write an install script

## Packages

- install [yay](https://github.com/Jguer/yay?tab=readme-ov-file#installation) first

```bash
yay -S waybar bluetuith-bin btop betterdiscordctl kitty swaylock-effects spicetify hyprpaper wofi dunst catppuccin-gtk-theme-mocha cliphist firefox vesktop-bin spotify obsidian vscodium-bin thunar pamixer playerctl brightnessctl hyprshot zsh pipewire pipewire-pulse pipewire-audio libreoffice-extension-texmaths libreoffice-fresh noto-fonts noto-fonts-cjk noto-fonts-emoji kvantummanager qt5-wayland qt6-wayland swayidle batsignal adw-gtk-theme gradience python-pywal16 waypaper yazi wiremix python-pywalfox
```

### Post install configuration

> This will eventually be handled by the install script

> Also this is not nearly all of configuration required

```bash
pywalfox install
```

## Getting Started

- Clone this repo and install all packages
- Keep the `dotfiles` directory in `$HOME`
- Try *SUPER + A* to open the system menu 
- Learn about this rice in the system menus help section

## Credit

Useful tools and other dotfiles I used:

- Based on: https://github.com/MartinFillon/dotfiles (hypr config), https://github.com/soldoestech/hyprland (hypr config), https://github.com/BinaryHarbinger/hyprdots (system menu)

- Fun features: https://github.com/5hubham5ingh/kitty-panel, https://github.com/raffaem/waybar-mediaplayer

- Pywal: https://github.com/SeniorMatt/Mattthew-s-Dotfiles, https://github.com/eylles/pywal16-libadwaita
