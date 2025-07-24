#!/usr/bin/env bash
# this script doesn't really do anything because there are NO apps which actually set the CLIPBOARD_STATE to sensitive

# 1) Spawn wl-paste in watch‐mode, echo its CLIPBOARD_STATE once, then kill wl-paste
CLIP_STATE=$(wl-paste --watch bash -c 'echo "$CLIPBOARD_STATE"; kill -TERM $PPID')

echo "$CLIP_STATE"

# 2) If it was “sensitive”, confirm with Wofi
if [[ "$CLIP_STATE" == "sensitive" ]]; then
    choice=$(printf "%s\n%s" \
      "<span color='#f38ba8'>No</span>" \
      "<span color='#a6e3a1'>Yes</span>" |
      wofi --dmenu \
           --normal-window \
           --hide-scroll \
           --allow-markup \
           --width 550 --height 100 \
           --prompt "The clipboard has sensitive data stored! Do you really want to continue?")

    clean=$(printf "%s" "$choice" | sed -E 's/<[^>]+>//g')
    [[ "$clean" != "Yes" ]] && exit 0
fi

# 3) Finally, show history and copy the picked entry
cliphist list \
  | wofi --dmenu --normal-window \
  | cliphist decode \
  | wl-copy

