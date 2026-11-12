#!/bin/bash
# Restart the Quickshell bar (~/.config/quickshell), detached via Hyprland.
# Replaces reload_waybar.sh (moved to unused/). Debug variant: reload_bar_debug.sh.

QS_ENV="QT_LOGGING_RULES=qt.qpa.wayland.textinput=false"   # silence a harmless Qt warning

qs kill >/dev/null 2>&1
pkill -x waybar 2>/dev/null   # in case the old bar is still running

# wait (max 3 s) until the old instance is gone, so two bars never stack
for _ in $(seq 30); do
  pgrep -x qs >/dev/null || break
  sleep 0.1
done

hyprctl dispatch "hl.dsp.exec_cmd(\"$QS_ENV qs\")" >/dev/null
