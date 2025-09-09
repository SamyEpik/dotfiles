#!/usr/bin/env bash

kitty @ goto-layout splits
kitty @ launch --type=window --location=hsplit --bias 80 btop -p 2
kitty @ launch --type=window --location=vsplit btop -p 3
kitty @ launch --type=window --location=hsplit --bias=20 --dont-take-focus cava
kitty @ focus-window
kitty @ launch --type=window --location=vsplit --dont-take-focus --bias=28 sh -c "$(
cat <<'EOF'
while true; do
  echo -e "\u001Bc"
  curl -s wttr.in/"Vienna" | sed -n '2,7p'
  sleep 4h
done
EOF
)"

kitty @ launch --type=window --location=vsplit --bias=61 peaclock
kitty @ send-key s
kitty @ focus-window


kitty @ launch --type=window --location=vsplit --bias=64 --dont-take-focus sh -c "$(
  cat <<'EOF'
	clear
	pfetch
	read
EOF
)"
