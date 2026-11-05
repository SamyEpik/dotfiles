#!/usr/bin/env bash

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

# Number-key selection
# While a menu is open, the Hyprland submap "system_menu" binds 1-9 to
# `system_menu.sh --pick N`, which stores N and closes wofi.
COUNT_FILE="${XDG_RUNTIME_DIR:-/tmp}/system_menu.count"
PICK_FILE="${XDG_RUNTIME_DIR:-/tmp}/system_menu.pick"

# show_menu <array name> [extra wofi args...]
# Prints the 0-based index of the chosen entry, or nothing if cancelled.
show_menu() {
  local -n items=$1
  shift
  local out

  rm -f "$PICK_FILE"
  echo "${#items[@]}" >"$COUNT_FILE"
  trap 'hyprctl dispatch submap reset >/dev/null; rm -f "$COUNT_FILE"' EXIT
  hyprctl dispatch submap system_menu >/dev/null

  # print_line_num makes wofi output the index and disables its cache,
  # which would otherwise reorder entries by usage
  out=$(printf "%s\n" "${items[@]}" | wofi -D dmenu-print_line_num=true "$@")

  hyprctl dispatch submap reset >/dev/null
  rm -f "$COUNT_FILE"
  trap - EXIT

  if [[ -s "$PICK_FILE" ]]; then
    echo $(($(<"$PICK_FILE") - 1))
    rm -f "$PICK_FILE"
  else
    echo "$out"
  fi
}

# Called from the Hyprland submap: select entry N of the open menu
pick() {
  local n=$1 count
  [[ $n =~ ^[1-9]$ && -r $COUNT_FILE ]] || exit 0
  count=$(<"$COUNT_FILE")
  ((n <= count)) || exit 0
  echo "$n" >"$PICK_FILE"
  pkill -x wofi
}

menu() {
  options_array=("" "" "" "" "" "󰠗" "󰙵")

  index=$(show_menu options_array --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --sort-order default)

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

  index=$(show_menu options_array --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --height 390 --sort-order default)

  case $index in
  0)
    menu
    ;;
  1)
    hyprlock
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

  index=$(show_menu options_array --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --height 275 --sort-order default)

  case $index in
  0)
    menu
    ;;
  1)
    ~/.dotfiles/scripts/list_keybinds.sh
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
  options_array=("" "" "" "" "" "󱡓")

  index=$(show_menu options_array --style ~/.config/wofi/style_sidemenu.css --conf ~/.config/wofi/config_sidebar --height 400 --sort-order default)

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
    scaling_settings
    ;;
  5)
    opacity_settings
    ;;
  *)
    echo "No option selected"
    ;;
  esac
}

reload_options() {
  options_array=("" "  <span weight=\"normal\">Waybar</span>" "  <span weight=\"normal\">Pywal</span>" "  <span weight=\"normal\">WiFi firmware</span>" "  <span weight=\"normal\">Hyprland</span>")

  index=$(show_menu options_array --style ~/.config/wofi/style_sidemenu_description.css --conf ~/.config/wofi/config_sidebar --height 345 --width 330 --sort-order default)

  case $index in
  0)
    rice_settings
    ;;
  1)
    bash ~/.dotfiles/scripts/reload_waybar.sh
    ;;
  2)
    wal -R
    ;;
  3)
    kitty --class floating ~/.dotfiles/scripts/pci-rescan-wifi.sh
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
    ~/.dotfiles/scripts/post_theme_reload.sh
  else
    echo "No theme selected."
  fi
}

scaling_settings() {
  $HOME/.dotfiles/scripts/scale_menu.sh
}

opacity_settings() {
  $HOME/.dotfiles/scripts/opacity_menu.sh
}

# Check for flags and validate input
if [[ $1 == --pick && $# -eq 2 ]]; then
  pick "$2"
  exit 0
elif [[ $# -ne 1 ]]; then
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
