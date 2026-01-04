#!/bin/bash
LOCKFILE="/tmp/post_theme_reload.lock"
WALLPAPER_PATH=""
FORCE_LIGHT=0

# This ensures the lockfile is removed even if the script is interrupted.
cleanup() {
  rm -f "$LOCKFILE"
}
trap cleanup EXIT INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
  --wallpaper)
    if [[ $# -ge 2 && "$2" != -* ]]; then
      WALLPAPER_PATH="$2"
      shift 2
    else
      WALLPAPER_PATH=""
      shift 1
    fi
    ;;
  --force-light)
    echo "Forcing light, wont prompt for scope"
    FORCE_LIGHT=1
    shift
    ;;
  --)
    shift
    break
    ;;
  -*)
    echo "Unknown option: $1" >&2
    echo "Usage: $0 [--wallpaper [/path/to/image]] [--force-light]" >&2
    exit 1
    ;;
  *)
    shift
    ;;
  esac
done

# Prevent double execution
exec 200>"$LOCKFILE"
flock -n 200 || {
  notify-send -u critical "Theme Reloader" "Reload Failed: Script already running" 2>/dev/null || true
  echo "Script already running, exiting."
  exit 1
}

pkill waypaper || true

reloads_light() {
  # --- Wal ---
  if [[ -n "$WALLPAPER_PATH" ]]; then
    if [[ -f "$WALLPAPER_PATH" ]]; then
      if ! out=$(wal -i "$WALLPAPER_PATH" 2>&1); then
        err_msg="Wal failed: $out"
        echo "$err_msg"
        notify-send -u critical "Theme Reloader" "$err_msg"
      fi
    else
      err_msg="Wallpaper file not found: $WALLPAPER_PATH"
      echo "$err_msg"
      notify-send -u critical "Theme Reloader" "$err_msg"
    fi
  else
    echo "No wallpaper supplied, skipping wal -i"
  fi

  # --- Dunst ---
  if ! out=$(dunstctl reload 2>&1); then
    err_msg="Dunst reload failed: $out"
    echo "$err_msg"
    notify-send -u critical "Theme Reloader" "$err_msg"
  fi

  # --- Gradience ---
  if ! out=$(
    {
      gradience-cli apply -p ~/.cache/wal/pywal.json --gtk both &&
        install -m 0644 ~/.config/gtk-4.0/gtk.css /usr/local/share/gtk-overrides/gtk.css
    } 2>&1
  ); then
    err_msg="Gradience failed: $out"
    echo "$err_msg"
    notify-send -u critical "Theme Reloader" "$err_msg"
  fi
}

reloads_require_restart() {
  # --- Spotify ---
  if pgrep -x spotify >/dev/null; then
    echo "Spotify is running. Restarting to apply theme..."
    pkill spotify || true

    if ! out=$(spicetify apply); then
      handle_error "Spicetify" "apply" "$out"
    fi
    if ! out=$(spicetify restart); then
      handle_error "Spicetify" "restart" "$out"
    fi
  fi

  # --- Vesktop ---
  if pgrep -f vesktop >/dev/null; then
    echo "Vesktop is running. Reloading..."
    vesktop_addr="$(
      hyprctl -j clients |
        jq -r '.[] | select((.class|test("(?i)vesktop|discord")) or (.title|test("(?i)vesktop|discord"))) | .address' |
        head -n1 || true
    )"
    if [[ -n "${vesktop_addr:-}" ]]; then
      echo "vesktop_addr: $vesktop_addr"
      if ! out=$(hyprctl dispatch sendshortcut "CTRL, R, address:$vesktop_addr"); then
        handle_error "Vesktop" "reload" "$out"
      fi
    else
      handle_error "Vesktop" "reload" "Couldn't find vesktop/discord window"
    fi
  fi
  sleep 1

  # --- Obsidian ---
  reload_obsidian

  ## --- DarkReader ---
  reload_darkreader
}

handle_error() {
  local app_name="$1"
  local action="$2" # e.g., "launch" or "apply"
  local output="$3"
  local err_msg="$app_name $action failed: $output"
  echo "$err_msg"
  notify-send -u critical "Theme Reloader" "$err_msg"
}

reload_darkreader() {
  if pgrep -x firefox >/dev/null; then
    notify-send "Theme Reloader" "Firefox is running. Please quit Firefox to reload DarkReader" -u normal
    mode_array=("  <span weight=\"normal\">Try Reload</span>" "  <span weight=\"normal\">Skip DarkReader</span>")
    mode=$(printf "%s\n" "${mode_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu_description.css --conf ~/.config/wofi/config_confirm --height 145 --width 430 --sort-order default --prompt "Firefox is running!" --normal-window)
    mode_index=-1
    for i in "${!mode_array[@]}"; do
      if [[ "${mode_array[$i]}" == "$mode" ]]; then
        mode_index=$i
        break
      fi
    done

    case $mode_index in
    0)
      reload_darkreader
      ;;
    1)
      echo "Skipping DarkReader reload"
      ;;
    *)
      echo "No option selected"
      ;;
    esac
  else
    notify-send "Theme Reloader" "Firefox quickly opening and closing is intended behaviour.\nThis is unfortunately the only way to reload DarkReader." -u normal
    $HOME/dotfiles/scripts/darkreader_reload.py
  fi
}

reload_obsidian() {
  if pgrep -f obsidian >/dev/null; then
    echo "Obsidian is running. Reloading..."

    obsidian_cfg="$HOME/.config/obsidian/obsidian.json"

    # Ensure Obsidian native config exists
    if [[ ! -f "$obsidian_cfg" ]]; then
      handle_error "Obsidian" "restart" \
        "Couldn't find ~/.config/obsidian/obsidian.json. Is Obsidian installed natively?"
      exit 1
    fi

    # Extract the last/opened vault path from obsidian.json
    vault_path="$(
      jq -er '
        .vaults
        | (to_entries[] | select(.value.open == true) | .value.path)
      ' "$obsidian_cfg" 2>/dev/null
    )" || {
      handle_error "Obsidian" "restart" \
        "Failed to read vault path from ~/.config/obsidian/obsidian.json"
      exit 1
    }

    # Check hotkeys.json for Ctrl+Shift+R on app:reload
    hotkeys="$vault_path/.obsidian/hotkeys.json"
    if [[ ! -f "$hotkeys" ]]; then
      handle_error "Obsidian" "restart" \
        "Keybind CTRL + SHIFT + R isn't set to reload Obsidian.
        Set it in Obsidian: Settings > Hotkeys > Reload app without saving."
      exit 1
    fi

    # Reload Obsidian with CTRL + SHIFT + R (only if the hotkey exists)
    if jq -e '
        (.["app:reload"] // [])
        | any(.key == "R" and ((.modifiers | index("Mod")) and (.modifiers | index("Shift"))))
      ' "$hotkeys" >/dev/null; then

      obsidian_addr="$(
        hyprctl -j clients |
          jq -r '
            .[]
            | select(
                (.class | test("obsidian"))
              )
            | .address
          ' | head -n1 || true
      )"

      if [[ -n "${obsidian_addr:-}" ]]; then
        if ! hyprctl dispatch sendshortcut "CTRL, S, address:$obsidian_addr"; then
          handle_error "Vesktop" "save" "Failed to send Ctrl+S"
        fi
        sleep 0.3
        if ! out=$(hyprctl dispatch sendshortcut "CTRL SHIFT, R, address:$obsidian_addr" 2>&1); then
          handle_error "Vesktop" "reload" "$out"
        fi
      else
        handle_error "Vesktop" "reload" "Couldn't find vesktop/discord window"
      fi

    else
      handle_error "Obsidian" "restart" \
        "Keybind CTRL + SHIFT + R isn't set to reload Obsidian.
        Set it in Obsidian: Settings > Hotkeys > Reload app without saving."
    fi
  fi
}

mode_index=-1
if ! ((FORCE_LIGHT)); then
  mode_array=("  <span weight=\"normal\">Reload All</span>" "  <span weight=\"normal\">Skip Restarts</span>" "  <span weight=\"normal\">Only Wallpaper</span>")
  mode=$(printf "%s\n" "${mode_array[@]}" | wofi --style ~/.config/wofi/style_sidemenu_description.css --conf ~/.config/wofi/config_confirm --height 210 --width 340 --sort-order default --hide-search)
  for i in "${!mode_array[@]}"; do
    if [[ "${mode_array[$i]}" == "$mode" ]]; then
      mode_index=$i
      break
    fi
  done
else
  mode_index=1
fi

case $mode_index in
0)
  reloads_light
  reloads_require_restart
  ;;
1)
  reloads_light
  ;;
2)
  if [[ -z "$WALLPAPER_PATH" ]]; then
    echo "No wallpaper supplied: Only Wallpaper does nothing"
  fi
  ;;
*)
  echo "No option selected"
  ;;
esac
