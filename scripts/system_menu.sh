#!/usr/bin/env bash

cd ~

# Usage Information
usage() {
  echo -e "\n Usage:
      --drun     : Launches the application launcher (drun).\n
      --run      : Launches the command runner (run). \n
      --menu     : Displays a custom menu with multiple options. \n"
  exit 1
}

# Function: DRUN Launcher
drun_launcher() {
  wofi \
    --show drun \
    --style ~/.config/wofi/style.css \
    --conf ~/.config/wofi/config
}

# Function: RUN Launcher
run_launcher() {
  wofi \
    --show run \
    --style ~/.config/wofi/style.css \
    --conf ~/.config/wofi/config
}

menu() {
  options_array=("" "" "" "" "" "󰠗" "󰙵")

  chosen=$(printf "%s\n" "${options_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar)

  index=-1
  for i in "${!options_array[@]}"; do
    if [[ "${options_array[$i]}" == "$chosen" ]]; then
      index=$i
      break
    fi
  done

  case $index in
  0)
    drun_launcher
    ;;
  1)
    kitty
    ;;
  2)
    thunar
    ;;
  3)
    firefox
    ;;
  4)
    logout_options
    ;;
  5)
    help_options
    ;;
  6)
    rice_settings
    ;;
  *)
    echo "No option selected"
    ;;
  esac
}

logout_options() {
  options_array=("" "󰷛" "" "󰤄" "" "󰍃")

  chosen=$(printf "%s\n" "${options_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --height 370 --sort-order default)

  index=-1
  for i in "${!options_array[@]}"; do
    if [[ "${options_array[$i]}" == "$chosen" ]]; then
      index=$i
      break
    fi
  done

  case $index in
  0)
    menu
    ;;
  1)
    swaylock
    ;;
  2)
    systemctl poweroff
    ;;
  3)
    systemctl hibernate
    ;;
  4)
    systemctl reboot
    ;;
  5)
    hyprctl dispatch exit
    ;;
  *)
    echo "No option selected"
    ;;
  esac
}

help_options() {
  options_array=("" "󰌌" "󰞋" "")

  chosen=$(printf "%s\n" "${options_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --height 255 --sort-order default)

  index=-1
  for i in "${!options_array[@]}"; do
    if [[ "${options_array[$i]}" == "$chosen" ]]; then
      index=$i
      break
    fi
  done

  case $index in
  0)
    menu
    ;;
  1)
    ~/dotfiles/scripts/list_keybinds.sh
    ;;
  2)
    echo "Not implemented yet!"
    ;;
  3)
    firefox https://github.com/samyepik/dotfiles
    ;;
  *)
    echo "No option selected"
    ;;
  esac
}

rice_settings() {
  options_array=("" "" "" "" "")

  chosen=$(printf "%s\n" "${options_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --height 310 --sort-order default)

  index=-1
  for i in "${!options_array[@]}"; do
    if [[ "${options_array[$i]}" == "$chosen" ]]; then
      index=$i
      break
    fi
  done

  case $index in
  0)
    menu
    ;;
  1)
    waypaper
    ;;
  2)
    reload_options
    ;;
  3)
    theme_options
    ;;
  4)
    appearence_options
    ;;
  *)
    echo "No option selected"
    ;;
  esac
}

reload_options() {
  options_array=("" "  <span weight=\"normal\">Waybar</span>" "  <span weight=\"normal\">Pywal</span>" "  <span weight=\"normal\">WiFi firmware</span>" "  <span weight=\"normal\">Hyprland</span>")

  chosen=$(printf "%s\n" "${options_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu_description.css --conf ~/.config/wofi/config_sidebar --height 310 --width 330 --sort-order default)

  index=-1
  for i in "${!options_array[@]}"; do
    if [[ "${options_array[$i]}" == "$chosen" ]]; then
      index=$i
      break
    fi
  done

  case $index in
  0)
    rice_settings
    ;;
  1)
    bash ~/dotfiles/scripts/reload_waybar.sh
    ;;
  2)
    wal -R
    ;;
  3)
    kitty --class floating ~/dotfiles/scripts/pci-rescan-wifi.sh
    ;;
  4)
    hyprctl reload
    ;;
  *)
    echo "No option selected"
    ;;
  esac

}

theme_options() {
  default_themes=($(ls /usr/lib/python3.*/site-packages/pywal/colorschemes/dark | sed 's/\.json$//'))

  user_themes=($(ls ~/.config/wal/colorschemes/dark | sed 's/\.json$//'))

  themes=("${default_themes[@]}" "${user_themes[@]}")

  if [ ${#themes[@]} -eq 0 ]; then
    echo "No themes found."
    return 1
  fi

  chosen=$(printf "%s\n" "${themes[@]}" | wofi --style ~/.config/wofi/style.css --conf ~/.config/wofi/config --show dmenu --prompt "Select a theme")

  if [ -n "$chosen" ]; then
    wal --theme "$chosen"
    ~/dotfiles/scripts/post_theme_reload.sh
  else
    echo "No theme selected."
  fi
}

appearence_options() {
  options_array=("" "  <span weight=\"normal\">Scale</span>" "󱡓  <span weight=\"normal\">Opacity</span>")

  chosen=$(printf "%s\n" "${options_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu_description.css --conf ~/.config/wofi/config_sidebar --height 310 --width 330 --sort-order default)

  index=-1
  for i in "${!options_array[@]}"; do
    if [[ "${options_array[$i]}" == "$chosen" ]]; then
      index=$i
      break
    fi
  done

  case $index in
  0)
    menu
    ;;
  1)
    scaling_settings
    ;;
  2)
    opacity_settings
    ;;
  *)
    echo "No option selected"
    ;;
  esac
}

scaling_settings() {
  $HOME/dotfiles/scripts/scale_menu.sh
}

opacity_settings() {
  $HOME/dotfiles/scripts/opacity_menu.sh
}

# Check for flags and validate input
if [[ $# -ne 1 ]]; then
  usage
fi

# Execute the appropriate function based on the provided flag
case "$1" in
--drun)
  drun_launcher
  ;;
--run)
  run_launcher
  ;;
--menu)
  menu
  ;;
--rice)
  rice_settings
  ;;
*)
  usage
  ;;
esac
