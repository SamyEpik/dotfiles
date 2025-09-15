#!/bin/bash

# --- Dependencies ---
for dep in hyprctl jq wofi sed awk; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "$dep not found" >&2
    exit 1
  }
done

# --- Collect unique class names from current clients ---
classes="$(hyprctl clients -j | jq -r '
  [ .[] | .class ] | map(select(. != null)) | unique | .[]
')"

if [[ -z "$classes" ]]; then
  echo "No open windows / classes found." >&2
  exit 1
fi

# --- First wofi: pick a class (only names shown) ---
class="$(printf '%s\n' "$classes" | wofi --dmenu --prompt 'Select class to change its opacity')" || exit 0
[[ -z "$class" ]] && exit 0

# --- Build fixed opacity options: 0.1 .. 1.0 in 0.1 steps ---
opacity_options="$(awk 'BEGIN { for (i=1;i<=10;i++) printf "%.1f\n", i/10 }')"

# --- Second wofi: choose an opacity from the list ---
opacity="$(printf '%s\n' "$opacity_options" | wofi --dmenu --prompt "Select opacity for \"$class\" or input custom opacity (0 > value <= 1)")" || exit 0
[[ -z "$opacity" ]] && exit 0

# Normalize: strip spaces
opacity="${opacity//[[:space:]]/}"

# Validate numeric and range (0.1..1 / 1.0)
if ! [[ "$opacity" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]]; then
  notify-send "Hyprland Opacity" "Invalid opacity: $opacity (must be 0.1–1.0)" 2>/dev/null || {
    echo "Invalid opacity: $opacity (must be 0.1–1.0)" >&2
  }
  exit 1
fi

# Escape regex metacharacters so the rule targets the class exactly
escape_regex() {
  sed -E 's/([][(){}.^$|?*+\\])/\\\1/g'
}
escaped_class="$(printf '%s' "$class" | escape_regex)"

# --- Apply the rule (runtime only) ---
cmd=(hyprctl keyword windowrulev2 "opacity ${opacity}, class:^(${escaped_class})$")
if ! "${cmd[@]}"; then
  echo "Failed to apply opacity rule." >&2
  exit 1
fi

# Optional: notify success
notify-send "Hyprland Opacity" "Applied opacity ${opacity} to class: ${class}" 2>/dev/null || true

# Echo what we did (for logs / debugging)
echo "windowrulev2 = opacity ${opacity}, class:^(${class})$"
