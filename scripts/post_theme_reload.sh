#!/bin/bash
LOCKFILE="/tmp/post_theme_reload.lock"
WALLPAPER_PATH=""

# This ensures the lockfile is removed even if the script is interrupted.
cleanup() {
  rm -f "$LOCKFILE"
}
trap cleanup EXIT INT TERM

while [[ $# -gt 0 ]]; do
  case $1 in
  --wallpaper)
    WALLPAPER_PATH="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--wallpaper /path/to/image]"
    exit 1
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

echo "=== Starting theme/app reload ==="

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
  echo "No wallpaper supplied, skipping wal"
fi

# --- Dunst ---
if ! out=$(dunstctl reload 2>&1); then
  err_msg="Dunst reload failed: $out"
  echo "$err_msg"
  notify-send -u critical "Theme Reloader" "$err_msg"
fi

# --- Gradience ---
if ! out=$(gradience-cli apply -p ~/.cache/wal/pywal.json --gtk both 2>&1); then
  err_msg="Gradience failed: $out"
  echo "$err_msg"
  notify-send -u critical "Theme Reloader" "$err_msg"
fi

# --- Spotify ---
pkill spotify || true
if ! out=$(spicetify apply 2>&1); then
  err_msg="Spicetify Failed: $out"
  echo "$err_msg"
  notify-send -u critical "Theme Reloader" "$err_msg"
fi
if ! out=$(hyprctl dispatch exec "[workspace 9 silent] spotify" 2>&1); then
  err_msg="Spotify launch failed: $out"
  echo "$err_msg"
  notify-send -u critical "Theme Reloader" "$err_msg"
fi

# --- Vesktop ---
pkill -f vesktop || true
sleep 2 # Give it a moment to die gracefully
if ! out=$(hyprctl dispatch exec vesktop 2>&1); then
  err_msg="Vesktop launch failed: $out"
  echo "$err_msg"
  notify-send -u critical "Theme Reloader" "$err_msg"
fi

echo "=== Finished theme/app reload ==="
