#!/usr/bin/env bash

# Lists all Hyprland keybinds in wofi, grouped by category, and runs the selected one.
#
# Bind data comes from the HyprBinds registry defined in
# ~/.config/hypr/categories/keybinds.lua (Hyprland Lua config):
#   hyprctl repl 'return HyprBinds.dump()'  -> id, category, keys, description, repeating, runnable
#   hyprctl eval 'HyprBinds.run(<id>)'      -> runs a bind
# To add a bind to this list, add it with bind(...) in keybinds.lua.
#
# Originally based on Khing's script for the HyDE Project, rewritten for the Lua config.

# kill an existing wofi instance to avoid stacking
pkill -x wofi && exit

HELP() {
  cat <<HELP
Usage: $(basename "$0") [options]
Options:
    -j     Print the keybinds as JSON
    -p     Print the keybinds to the terminal
    -w     Custom wofi width (pixels)
    -h     Custom wofi height (pixels)
    --help Display this help message
HELP
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  -j) kb_hint_json=true ;;
  -p) kb_hint_pretty=true ;;
  -w) shift; kb_hint_width="$1" ;;
  -h) shift; kb_hint_height="$1" ;;
  *) HELP; exit ;;
  esac
  shift
done

fail() {
  notify-send "Keybinds" "$1" 2>/dev/null
  echo "$1" >&2
  exit 1
}

# --- Get the binds from Hyprland ---
dump="$(hyprctl repl 'return HyprBinds.dump()' 2>&1)"
[[ "$dump" =~ ^[0-9]+$'\t' ]] || fail "Could not read keybinds from Hyprland: $dump"

if [ "$kb_hint_json" = true ]; then
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {
    id: (.[0] | tonumber), category: .[1], keys: .[2], description: .[3],
    repeating: (.[4] == "true"), runnable: (.[5] == "true")
  })' <<<"$dump"
  exit 0
fi

# --- Pretty key names ---
declare -A KEY_ICONS=(
  ["SUPER"]=""
  ["mouse_up"]="󱕑"
  ["mouse_down"]="󱕐"
  ["mouse:272"]="󰍽"
  ["mouse:273"]="󰍽"
  ["up"]=""
  ["down"]=""
  ["left"]=""
  ["right"]=""
  ["XF86AudioLowerVolume"]="󰝞"
  ["XF86AudioMicMute"]="󰍭"
  ["XF86AudioMute"]="󰓄"
  ["XF86AudioNext"]="󰒭"
  ["XF86AudioPause"]="󰏤"
  ["XF86AudioPlay"]="󰐊"
  ["XF86AudioPrev"]="󰒮"
  ["XF86AudioRaiseVolume"]="󰝝"
  ["XF86MonBrightnessDown"]=""
  ["XF86MonBrightnessUp"]=""
  ["switch:on:Lid Switch"]="󰛧"
  ["backspace"]="󰁮 "
)

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

pretty_keys() {
  local IFS='+' part out=()
  read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    part="$(trim "$part")"
    out+=("${KEY_ICONS[$part]:-$part}")
  done
  local joined
  joined="$(printf '%s  + ' "${out[@]}")"
  printf '%s' "${joined%  + }"
}

# pad <width> <text>: like printf %-Ns, but counts characters instead of bytes (icons are multi-byte)
pad() {
  local n=$(($1 - ${#2}))
  ((n < 0)) && n=0
  printf '%s%*s' "$2" "$n" ""
}

# --- Build the menu: category header, its binds, a spacer line ---
# line_ids[i] holds the bind id shown on menu line i (empty for headers/spacers)
declare -A seen_category
categories=()
declare -A cat_lines
while IFS=$'\t' read -r id category keys desc repeating runnable; do
  [[ -z "$id" ]] && continue
  if [[ -z "${seen_category[$category]}" ]]; then
    seen_category[$category]=1
    categories+=("$category")
  fi
  cat_lines[$category]+="$id"$'\t'"$keys"$'\t'"$desc"$'\t'"$repeating"$'\t'"$runnable"$'\n'
done <<<"$dump"

menu_lines=()
pretty_lines=()
line_ids=()
declare -A bind_repeating bind_runnable
for category in "${categories[@]}"; do
  menu_lines+=("<u>${category}</u>")
  pretty_lines+=("${category}")
  line_ids+=("")
  while IFS=$'\t' read -r id keys desc repeating runnable; do
    [[ -z "$id" ]] && continue
    kb="$(pad 20 "$(pretty_keys "$keys")")"
    menu_lines+=("<span font_family=\"monospace\" size=\"large\">${kb}</span><i>${desc}</i>")
    pretty_lines+=("  ${kb} ${desc}")
    line_ids+=("$id")
    bind_repeating[$id]="$repeating"
    bind_runnable[$id]="$runnable"
  done <<<"${cat_lines[$category]}"
  menu_lines+=(" ")
  pretty_lines+=("")
  line_ids+=("")
done

if [ "$kb_hint_pretty" = true ]; then
  printf "%-35s %-1s %-20s\n" "󰌌 Keybinds" "󱧣" "Description"
  printf '%s\n' "${pretty_lines[@]}"
  exit 0
fi

if ! command -v wofi >/dev/null 2>&1; then
  printf '%s\n' "${pretty_lines[@]}"
  echo "wofi not detected. Displaying on terminal instead"
  exit 0
fi

# --- Wofi UI ---
wofi_args=(--dmenu --style "$HOME/.dotfiles/wofi/style_keybinds_list.css" --allow-markup --prompt Keybinds
  -D dmenu-print_line_num=true)
case "$kb_hint_width" in
  ''|*[!0-9]*) : ;;
  *) wofi_args+=(--width "$kb_hint_width") ;;
esac
case "$kb_hint_height" in
  ''|*[!0-9]*) : ;;
  *) wofi_args+=(--height "$kb_hint_height") ;;
esac

# print_line_num makes wofi return the 0-based line index of the selection
line="$(printf '%s\n' "${menu_lines[@]}" | wofi "${wofi_args[@]}")"
[[ "$line" =~ ^[0-9]+$ ]] || exit 0

id="${line_ids[$line]}"
# header, spacer or mouse bind selected: show the list again
if [[ -z "$id" || "${bind_runnable[$id]}" != true ]]; then
  exec "$0" "$@"
fi

run_bind() {
  local out
  out="$(hyprctl eval "HyprBinds.run($id)" 2>&1)"
  [[ "$out" == "ok" ]] || fail "Failed to run keybind: $out"
}

if [ "${bind_repeating[$id]}" = true ]; then
  while true; do
    run_bind
    repeat_command=$(printf "Repeat\nExit\n" | wofi --dmenu --prompt "Repeat?")
    [ "$repeat_command" = "Repeat" ] || exit 0
  done
else
  run_bind
fi
