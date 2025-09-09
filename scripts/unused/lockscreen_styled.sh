#!/bin/bash

# Source pywal colors (your file)
FZF_DEFAULT_OPTS=""
source "${HOME}/.cache/wal/colors.sh"

# Choose an secondary for highlights (feel free to change)
secondary="${color8}"
danger="${color1}"
warn="${color6}"
accent="${color5}"

# Build common options for both swaylock and swaylock-effects
opts=(
  # Base colors
  --color           "${background#\#}"
  --text-color      "${foreground#\#}"
  --inside-color    "${background#\#}"
  --ring-color      "${secondary#\#}"
  --line-color      "${secondary#\#}"

  # Verification (while checking password)
  --inside-ver-color "${background#\#}"
  --ring-ver-color   "${accent#\#}"
  --text-ver-color   "${foreground#\#}"

  # Wrong password
  --inside-wrong-color "${background#\#}"
  --ring-wrong-color   "${danger#\#}"
  --text-wrong-color   "${foreground#\#}"

  # “clear/backspace” state
  --inside-clear-color "${background#\#}"
  --ring-clear-color   "${warn#\#}"
  --text-clear-color   "${foreground#\#}"

  # Key/backspace highlight
  --key-hl-color  "${accent#\#}"
  --bs-hl-color   "${warn#\#}"
)

swaylock -f "${opts[@]}"
