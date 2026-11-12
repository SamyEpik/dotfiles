#!/usr/bin/env bash
# Dependencies
command -v hyprctl >/dev/null 2>&1 || {
  echo "hyprctl not found" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq not found" >&2
  exit 1
}
command -v wofi >/dev/null 2>&1 || {
  echo "wofi not found" >&2
  exit 1
}

# Presets: "Label|MONITOR=scale MONITOR=scale ..."
# Monitors in a preset that are not connected are skipped.
presets=(
  "DP-6 + eDP-1 @ 1.25|DP-6=1.25 eDP-1=1.25"
)

# Apply a scale to a monitor, keeping its current mode/position.
# The scale is snapped to the nearest clean value via scale_calculator.py.
# runtime only: the rule from categories/monitors.lua is restored on config reload
apply_monitor_scale() {
  local mon="$1" target="$2" width height x y snapped rule out
  read -r width height x y < <(
    hyprctl -j monitors | jq -r --arg mon "$mon" \
      '.[] | select(.name == $mon) | "\(.width) \(.height) \(.x) \(.y)"'
  )
  [[ -z "${width:-}" ]] && return 2

  snapped="$("$HOME/.dotfiles/scripts/scale_calculator.py" "$mon" "$target" | cut -f2)"
  [[ -z "$snapped" ]] && return 1

  rule="hl.monitor({ output = \"${mon}\", mode = \"${width}x${height}\", position = \"${x}x${y}\", scale = \"${snapped}\" })"
  out="$(hyprctl eval "$rule" 2>&1)"
  if [[ "$out" != "ok" ]]; then
    echo "Failed to apply scale ${snapped} to ${mon}: $out" >&2
    return 1
  fi
  echo "$rule"
  applied_scale="$snapped"
}

apply_preset() {
  local spec="$1" entry mon target rc
  local -a ok=() missing=() failed=()
  for entry in $spec; do
    mon="${entry%%=*}"
    target="${entry#*=}"
    apply_monitor_scale "$mon" "$target"
    rc=$?
    case $rc in
    0) ok+=("${mon} ${applied_scale}") ;;
    2) missing+=("$mon") ;;
    *) failed+=("$mon") ;;
    esac
  done

  local msg="" nl=$'\n'
  if ((${#ok[@]})); then
    msg="Applied: $(printf '%s, ' "${ok[@]}")"
    msg="${msg%, }"
  fi
  ((${#missing[@]})) && msg+="${msg:+$nl}Not connected: ${missing[*]}"
  ((${#failed[@]})) && msg+="${msg:+$nl}Failed: ${failed[*]}"
  notify-send "Hyprland Scale" "$msg" 2>/dev/null || true
  ((${#failed[@]} == 0))
}

# Build a map file: "name<TAB>scale"
tmp_map="$(mktemp)"

hyprctl monitors -j |
  jq -r '.[] | "\(.name)\t\((.scale // 1))\t\(.description // "")"' |
  awk 'NF' >"$tmp_map"

# Any monitors found?
if [[ ! -s "$tmp_map" ]]; then
  echo "No monitors found" >&2
  rm -f "$tmp_map"
  exit 1
fi

# Build pretty lines with markup and show wofi
selection="$(
  {
  awk -F'\t' '{
    # $1=name, $2=scale, $3=description
    desc = ($3 == "" ? "" : " (<i>" $3 "</i>)")
    # print:  name (<i>desc</i>): <span alpha="50%">scale</span>
    # NOTE: escape % as %% for awk
    printf "%s%s: <span alpha=\"50%%\">%s</span>\n", $1, desc, $2
  }' "$tmp_map"
  for p in "${presets[@]}"; do
    printf '<b>Preset:</b> %s\n' "${p%%|*}"
  done
  } | wofi --dmenu --allow-markup --prompt 'Select monitor to change scale'
)" || {
  rm -f "$tmp_map"
  exit 0
}

# If cancelled or empty, exit quietly
[[ -z "$selection" ]] && {
  rm -f "$tmp_map"
  exit 0
}

# Preset selected?
for p in "${presets[@]}"; do
  if [[ "$selection" == "<b>Preset:</b> ${p%%|*}" || "$selection" == "Preset: ${p%%|*}" ]]; then
    rm -f "$tmp_map"
    apply_preset "${p#*|}"
    exit $?
  fi
done

# Map selection back to raw name by regenerating the same pretty text and matching it
name="$(
  awk -F'\t' -v sel="$selection" '{
    desc = ($3 == "" ? "" : " (<i>" $3 "</i>)")
    line = sprintf("%s%s: <span alpha=\"50%%\">%s</span>", $1, desc, $2)
    if (line == sel) { print $1; exit }
  }' "$tmp_map"
)"

rm -f "$tmp_map"

# Output only the selected monitor name
echo "$name"

mon="$name"

# if nothing was selected, exit quietly
[[ -z "$mon" ]] && exit 0

# get current scale for info
current_scale="$(
  hyprctl -j monitors | jq -r --arg mon "$mon" '.[] | select(.name == $mon) | (.scale // 1)'
)"

# fixed list of candidate scales (numbers only)
allowed_scales=(0.75 1.05 1.00 1.25 1.45 1.55 1.75 1.95 2.00)

# make sure the monitor still exists before building the menu
hyprctl -j monitors | jq -e --arg mon "$mon" 'any(.[]; .name == $mon)' >/dev/null || {
  echo "Monitor '$mon' not found." >&2
  exit 1
}

# ask Python helper to compute clean/snap using the same method as your snippet
mapfile -t lines < <($HOME/.dotfiles/scripts/scale_calculator.py "$mon" "${allowed_scales[@]}")

# build menu + mapping arrays
declare -a menu_items=()
declare -a apply_values=()
for line in "${lines[@]}"; do
  label="${line%%$'\t'*}"
  val="${line##*$'\t'}"
  menu_items+=("$label")
  apply_values+=("$val")
done

# present the menu; selection is the full label string
new_selection="$(
  printf '%s\n' "${menu_items[@]}" |
    wofi --dmenu --prompt "Changing $mon (Scale: ${current_scale:-?}), reference scale → calculated scale"
)" || exit 0

# if cancelled or empty, exit quietly
[[ -z "$new_selection" ]] && exit 0

# find index of the selected line to map to snapped value
idx=-1
for i in "${!menu_items[@]}"; do
  if [[ "${menu_items[$i]}" == "$new_selection" ]]; then
    idx="$i"
    break
  fi
done

((idx >= 0)) || {
  echo "Selection not recognized." >&2
  exit 1
}

apply_scale="${apply_values[$idx]}"

# apply with the snapped/clean scale (Hyprland will accept this)
if ! apply_monitor_scale "$mon" "$apply_scale"; then
  notify-send "Hyprland Scale" "Failed to apply scale ${apply_scale} to ${mon}" 2>/dev/null || true
  exit 1
fi

notify-send "Hyprland Scale" "Applied scale ${applied_scale} to monitor: ${mon}" 2>/dev/null || true
