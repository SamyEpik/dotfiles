#!/usr/bin/env sh

# jq to parse and create a metadata.
# Users are advised to use bindd to explicitly add the description
# This script was orignially created by Khing for the HyDE Project
# I have modified it to work without HyDE and use wofi instead of rofi
# Might be a bit janky

# kill an existing wofi dmenu instance to avoid stacking
pkill -x wofi && exit

confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
keyconfDir="$confDir/hypr"

# A local, no-hyde override directory (you can create these files here if you want overrides)
hydeConfDir="$confDir/kb-hint"   # intentionally named to keep existing variable usage, but not tied to hyde

kb_hint_conf=("$keyconfDir/hyprland.conf" "$keyconfDir/keybindings.conf" "$keyconfDir/userprefs.conf" )
tmpMapDir="/tmp"
tmpMap="$tmpMapDir/hyde-keybinds.jq"

# override files (optional)
keycodeFile="${hydeConfDir}/keycode.kb"
modmaskFile="${hydeConfDir}/modmask.kb"
keyFile="${hydeConfDir}/key.kb"
categoryFile="${hydeConfDir}/category.kb"
dispatcherFile="${hydeConfDir}/dispatcher.kb"

DEFAULT_DELIM="·"

HELP() {
  cat <<HELP
Usage: $(basename "$0") [options]
Options:
    -j     Show the JSON format
    -p     Show the pretty format
    -d     Add custom delimiter symbol (default '>')
    -f     Add custom file
    -w     Custom width (wofi: pixels; if non-numeric, ignored)
    -h     Custom height (wofi: pixels; if non-numeric, ignored)
    -l     Number of lines shown (header groups still included)
    --help Display this help message
Example:
 $(basename "$0") -j -p -d '>' -f custom_file.txt -w 800 -h 600

Overrides directory (no-hyde): ${hydeConfDir}
  Optional override files:
    ${keycodeFile}     => keycode
    ${modmaskFile}     => modmask
    ${keyFile}         => keys
    ${categoryFile}    => category
    ${dispatcherFile}  => dispatcher

Example for keycode override (JSON fragment lines, no surrounding braces):
    "61": "/",
HELP
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  -j) kb_hint_json=true ;;
  -p) kb_hint_pretty=true ;;
  -d) shift; kb_hint_delim="$1" ;;
  -f) shift; kb_hint_conf+=("${@}") ;;
  -w) shift; kb_hint_width="$1" ;;
  -h) shift; kb_hint_height="$1" ;;
  -l) shift; kb_hint_line="$1" ;;
  -*) HELP; exit ;;
  esac
  shift
done

#? Read all the variables in the configuration file
#! Intentional globbing on the $keyconf variable
# shellcheck disable=SC2086
keyVars="$(awk -F '=' '/^ *\$/ && !/^ *#[^#]/ || /^ *##/ {gsub(/^ *\$| *$/, "", $1); gsub(/#.*/, "", $2); gsub(/^ *| *$/, "", $2); print $1 "='\''"$2"'\''"}' ${kb_hint_conf[@]})"
keyVars+="
"
keyVars+="HOME=$HOME"

# substitute \$vars with values from hypr configs we parsed above
substitute_vars() {
  local s="$1"
  local IFS=$'\n'
  for var in $keyVars; do
    varName="${var%%=*}"
    varValue="${var#*=}"
    varValue="${varValue#\'}"
    varValue="${varValue%\'}"
    s="${s//\$$varName/$varValue}"
  done
  IFS=$' \t\n'
  echo "$s"
}

initialized_comments=$(awk -F ',' '!/^#/ && /bind*/ && $3 ~ /exec/ && NF && $4 !~ /^ *$/ { print $4}' ${kb_hint_conf[@]} | sed "s#\"#'#g")
comments=$(substitute_vars "$initialized_comments" | awk -F'#' \
  '{gsub(/^ */, "", $1);\
    gsub(/ *$/, "", $1);\
     split($2, a, " ");\
      a[1] = toupper(substr(a[1], 1, 1)) substr(a[1], 2);\
       $2 = a[1]; for(i=2;\
        i<=length(a); i++) $2 = $2" "a[i];\
         gsub(/^ */, "", $2);\
          gsub(/ *$/, "", $2);\
           if (length($1) > 0) print "\""$1"\" : \""(length($2) > 0 ? $2 : $1)"\","}' |
  awk '!seen[$0]++')

# --- jq library (unchanged parsing/mapping logic) ---
cat <<OVERRIDES >"$tmpMap"
# hyde-keybinds.jq
def executables_mapping: {
$comments
" empty " :  "Empty",
"r+1" : "Relative Right",
"r-1" : "Relative Left",
"e+1" : "Next",
"e-1" : "Previous",
"movewindow" : "Move window",
"resizewindow" : "Resize window",
"d" : "Down",
"l" : "Left",
"r" : "Right",
"u" : "Up",
"f" : "Forward",
"b" : "Backward",
};

def keycode_mapping: {
 "0": "",
 $([ -f "${keycodeFile}" ] && cat "${keycodeFile}")
};

def modmask_mapping: {
    "64": "",
    "8": "ALT",
    "4": "CTRL",
    "1": "SHIFT",
    "0": " ",
 $([ -f "${modmaskFile}" ] && cat "${modmaskFile}")
};

def key_mapping: {
    "mouse_up" : "󱕑",
    "mouse_down" : "󱕐",
    "mouse:272" : "󰍽",
    "mouse:273" : "󰍽",
    "up" : "",
    "down" : "",
    "left" : "",
    "right" : "",
    "XF86AudioLowerVolume" : "󰝞",
    "XF86AudioMicMute" : "󰍭",
    "XF86AudioMute" : "󰓄",
    "XF86AudioNext" : "󰒭",
    "XF86AudioPause" : "󰏤",
    "XF86AudioPlay" : "󰐊",
    "XF86AudioPrev" : "󰒮",
    "XF86AudioRaiseVolume" : "󰝝",
    "XF86MonBrightnessDown" : "",
    "XF86MonBrightnessUp" : "",
    "switch:on:Lid Switch" : "󰛧",
    "backspace" : "󰁮 ",
    $([ -f "${keyFile}" ] && cat "${keyFile}")
};

def category_mapping: {
    "exec" : "Misc:",
    "global": "Global:",
    "exit" : "Exit Hyprland Session",
    "fullscreen" : "Toggle Functions",
    "fakefullscreen" : "Toggle Functions",
    "mouse" : "Mouse functions",
    "movefocus" : "Window functions",
    "movewindow" : "Window functions",
    "resizeactive" : "Window functions",
    "togglefloating" : "Toggle Functions",
    "togglegroup" : "Toggle Functions",
    "togglespecialworkspace" : "Toggle Functions",
    "togglesplit" : "Toggle Functions",
    "workspace" : "Navigate Workspace",
    "movetoworkspace" : "Navigate Workspace",
    "movetoworkspacesilent" : "Navigate Workspace",
    "changegroupactive" : "Change Active Group",
    "killactive" : "Kill",
    "pseudo" : "Psuedo Tiling",
    $([ -f "${categoryFile}" ] && cat "${categoryFile}")
};

def arg_mapping: {
  "arg2": "mapped_arg2",
};

def description_mapping: {
    "movefocus": "Move Focus",
    "resizeactive": "Resize Active Floating Window",
    "exit" : "End Hyprland Session",
    "movetoworkspacesilent" : "Silently Move to Workspace",
    "movewindow" : "Move Window",
    "exec" : "Executes: " ,
    "movetoworkspace" : "Move To Workspace:",
    "workspace" : "Navigate to Workspace:",
    "togglefloating" : "Toggle Floating",
    "fullscreen" : "Toggle Fullscreen",
    "togglegroup" : "Toggle Group",
    "togglesplit" : "Toggle Split",
    "togglespecialworkspace" : "Toggle Special Workspace",
    "mouse" : "Use Mouse",
    "changegroupactive" : "Switch Active group",
    "killactive" : "Kill Application",
    "pseudo" : "Psuedotile Application"
    $([ -f "${dispatcherFile}" ] && cat "${dispatcherFile}")
};
OVERRIDES

# --- hyprctl -> jq (unchanged pipeline) ---
jsonData="$(
  hyprctl binds -j | jq -L "$tmpMapDir" -c '
include "hyde-keybinds";

  def get_keys:
    if . == 0 then
      ""
    elif . >= 64 then
      . -= 64 | modmask_mapping["64"] + " " + get_keys
    elif . >= 32 then
      . -= 32 | modmask_mapping["32"] + " " + get_keys
    elif . >= 16 then
      . -= 16 | modmask_mapping["16"] + " " + get_keys
    elif . >= 8 then
      . -= 8 | modmask_mapping["8"] + " " + get_keys
    elif . >= 4 then
      . -= 4 | modmask_mapping["4"] + " " + get_keys
    elif . >= 2 then
      . -= 2 | modmask_mapping["2"] + " " + get_keys
    elif . >= 1 then
      . -= 1 | modmask_mapping["1"] + " " + get_keys
    else
      .
    end;

  def get_keycode: (keycode_mapping[(. | tostring)] // .);

  
.[] |
  .dispatcher as $dispatcher | .desc_dispatcher = $dispatcher |
  .dispatcher as $dispatcher | .category = $dispatcher |
  .arg as $arg | .desc_executable = $arg |
  .modmask |= (get_keys | ltrimstr(" ")) |
  .keycode |= (get_keycode // .) |
  .key |= (key_mapping[.] // .) |
  .modlist = ((.modmask | tostring) | split(" ") | map(select(length > 0))) |
  .keytext = (if (.key // "") != "" then .key else ((.keycode // 0) | tostring) end) |
  .keybind = ((.modlist + [ .keytext ]) | join("  + ")) |
  .flags = " locked=" + (.locked | tostring)
         + " mouse=" + (.mouse | tostring)
         + " release=" + (.release | tostring)
         + " repeat=" + (.repeat | tostring)
         + " non_consuming=" + (.non_consuming | tostring) |
  .category |= (category_mapping[.] // .) |
  .category |= (if (. // "") != "" then "<u>\(.)</u>" else . end) |
  .arg |= (arg_mapping[.] // .) |
  .desc_executable |= (executables_mapping[.] // .) |
  .desc_dispatcher |= (description_mapping[.] // .) |
  .description =
    if (.has_description // false) == false then
      (if (.desc_executable == .arg) then
         "\(.desc_dispatcher) <span alpha=\"50%\">\(.arg)</span>"
       else
         "\(.desc_dispatcher) \(.desc_executable)"
       end)
    else
      .description
    end
')"

GROUP() {
awk -v cols="$cols" -F '!=!' '
{
    category = $1
    binds[category] = binds[category]? binds[category] "\n" $0 : $0
}
END {
    n = asorti(binds, b)
    for (i = 1; i <= n; i++) {
      print b[i]
      gsub(/\[.*\] =/, "", b[i])
      split(binds[b[i]], lines, "\n")
      for (j in lines) {
        line = substr(lines[j], index(lines[j], "=") + 2)
        print line
      }
      for (j = 1; j <= cols; j++) printf " "
      printf "\n"
    }
}'
}

[ "$kb_hint_json" = true ] && jq <<< "$jsonData" && exit 0

DISPLAY() {
  awk -v delim="${kb_hint_delim:-$DEFAULT_DELIM}" -F '!=!' '
    # remove Pango tags; treat HTML entities as 1 char; trim ends
    function strip_tags(s,    t) {
      t = s
      gsub(/<[^>]*>/, "", t)          # drop <span ...>, </span>, etc.
      gsub(/&[^;]+;/, "x", t)         # &nbsp; &#xf000; → 1 char
      sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      return t
    }
    {
      raw[NR] = $0
      isbind[NR] = ($0 ~ /!=!/ && $6 != "") ? 1 : 0   # lines with fields
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (!isbind[i]) { print raw[i]; continue }    # category headers etc.
        # fields: 0=category 1=modmask 2=key 3=dispatcher 4=arg 5=keybind 6=description 7=flags
        n = split(raw[i], f, "!=!")
        kb_raw   = strip_tags(f[5])
        kb_fmt = sprintf("%-20s", kb_raw)
        kb_span = "<span font_family=\"monospace\" size=\"large\">" kb_fmt "</span>"
        desc_raw = f[6]
        desc_span = "<i>" desc_raw "</i>"
        printf "%s%s\n", kb_span, desc_span
      }
    }
  '
}

header="$(printf "%-35s %-1s %-20s\n" "󰌌 Keybinds" "󱧣" "Description")"
cols=$(tput cols 2>/dev/null)
cols=${cols:-999}
linebreak="$(printf '%.0s━' $(seq 1 "${cols}") "")"

metaData="$(jq -r '"\(.category) !=! \(.modmask) !=! \(.key) !=! \(.dispatcher) !=! \(.arg) !=! \(.keybind) !=! \(.description) !=! \(.flags)"' <<< "${jsonData}" | tr -s ' ' | sort -k 1)"
display="$(GROUP <<< "$metaData" | DISPLAY)"

output=$(echo -e "${header}\n${linebreak}\n${display}")

[ "$kb_hint_pretty" = true ] && echo -e "$output" && exit 0

# ---- WOFI UI (no-hyde, no rofi) ----
if ! command -v wofi >/dev/null 2>&1; then
  echo "$output"
  echo "wofi not detected. Displaying on terminal instead"
  exit 0
fi

# only feed the list (not the header) to the menu
menu_input="$display"

# Optional numeric width/height for wofi (ignore non-numeric like '35em')
wofi_args="--dmenu --style $HOME/dotfiles/wofi/style_keybinds_list.css --allow-markup --prompt Keybinds"
case "$kb_hint_width" in
  ''|*[!0-9]*) : ;;
  *) wofi_args="$wofi_args --width $kb_hint_width" ;;
esac
case "$kb_hint_height" in
  ''|*[!0-9]*) : ;;
  *) wofi_args="$wofi_args --height $kb_hint_height" ;;
esac

selected=$(printf "%s\n" "$menu_input" | wofi $wofi_args)
[ -z "$selected" ] && exit 0

sel_1=$(awk -v d="${kb_hint_delim:->}" -F "$d" '{s=$1; sub(/[[:space:]]+$/,"",s); print s}' <<< "$selected")
sel_2=$(awk -v d="${kb_hint_delim:->}" -F "$d" '{s=$2; sub(/^[[:space:]]+/,"",s); print s}' <<< "$selected")

run="$(grep -F "$sel_1" <<< "$metaData" | grep -F "$sel_2")"

run_flg="$(echo "$run" | awk -F '!=!' '{print $8}')"
run_sel="$(echo "$run" | awk -F '!=!' '{gsub(/^ *| *$/, "", $5); if ($5 ~ /[[:space:]]/ && $5 !~ /^[0-9]+$/ && substr($5, 1, 1) != "-") print $4, "\""$5"\""; else print $4, $5}')"

RUN() { case "$(eval "hyprctl dispatch $run_sel")" in *"Not enough arguments"*) exec "$0" ;; esac }

if [ -n "$run_sel" ] && [ "$(echo "$run_sel" | wc -l)" -eq 1 ]; then
  # turn " locked=true repeat=false ..." into shell vars
  eval "$run_flg"
  if [ "$repeat" = true ]; then
    while true; do
      repeat_command=$(printf "Repeat\nExit\n" | wofi --dmenu --prompt "Repeat?")
      [ "$repeat_command" = "Repeat" ] && RUN || exit 0
    done
  else
    RUN
  fi
else
  exec "$0"
fi

