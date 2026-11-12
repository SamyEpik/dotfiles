#!/bin/bash
# Restart the Quickshell bar in the foreground, with its log in this terminal.
# Ctrl+C stops it; run reload_bar.sh afterwards to get the normal detached bar back.
# Replaces reload_waybar_debug.sh (moved to unused/).

qs kill >/dev/null 2>&1
pkill -x waybar 2>/dev/null

for _ in $(seq 30); do
  pgrep -x qs >/dev/null || break
  sleep 0.1
done

QT_LOGGING_RULES=qt.qpa.wayland.textinput=false exec qs
