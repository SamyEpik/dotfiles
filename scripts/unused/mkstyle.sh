#!/usr/bin/env bash
# mkstyle.sh > ~/.config/waybar/mediaplayer.css
OVERLAY='rgba(110, 115, 141, 0.3)'
SURFACE='rgba(54, 58, 79, 0.3)'
for i in $(seq 0 100); do
  printf '#custom-mediaplayer.perc%d {\n  background-image: linear-gradient(to right, %s %d%%, %s %d.1%%);\n}\n' \
    "$i" "$OVERLAY" "$i" "$SURFACE" "$i"
done
