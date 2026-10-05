#!/usr/bin/env bash
PLAYER=spotifast
SEP=$'\x1f'
ART=/tmp/waybar-mediaplayer-art
PLAY=$'\uf04c'
PAUSE=$'\uf04b'
last_url="" last_perc=-1
status="" artist="" title="" album="" url="" length=0

rm -f "$ART"

update_art() {
  [ "$1" = "$last_url" ] && return
  last_url=$1
  if [ -z "$1" ]; then
    rm -f "$ART"
  elif [[ $1 == file://* ]]; then
    cp "${1#file://}" "$ART" || rm -f "$ART"
  else
    curl -fsS --max-time 5 "$1" -o "$ART" || rm -f "$ART"
  fi
  pkill -x -RTMIN+4 waybar
}

render() {
  local icon perc=0 pos
  if [ -z "$status" ]; then
    echo '{"text":""}'
    return
  fi

  if [ "${length:-0}" -gt 0 ]; then
    pos=$(playerctl -p "$PLAYER" metadata --format '{{position}}' 2>/dev/null)
    perc=$((${pos:-0} * 100 / length))
    ((perc > 100)) && perc=100
  fi

  # on a progress tick, only emit if the bar actually moved
  [ "$1" = tick ] && [ "$perc" = "$last_perc" ] && return
  last_perc=$perc

  [ "$status" = Playing ] && icon=$PLAY || icon=$PAUSE
  jq -nc \
    --arg text "$icon ${artist:+$artist - }$title" \
    --arg tooltip "$title"$'\n'"$artist"$'\n'"$album" \
    --arg s "${status,,}" \
    --arg p "perc$perc" \
    '{text:$text, tooltip:$tooltip, class:[$s,$p]}'
}

playerctl -p "$PLAYER" metadata --follow \
  --format "{{status}}${SEP}{{artist}}${SEP}{{title}}${SEP}{{album}}${SEP}{{mpris:artUrl}}${SEP}{{mpris:length}}" 2>/dev/null |
  while true; do
    if [ "$status" = Playing ] && [ "${length:-0}" -gt 0 ]; then
      # wake once per 1% of the track (min 0.5s)
      ms=$((length / 100000))
      ((ms < 500)) && ms=500
      read -r -t "$((ms / 1000)).$(printf %03d $((ms % 1000)))" line
    else
      read -r line # paused or no length: sleep until the next event
    fi
    rc=$?

    if [ $rc -eq 0 ]; then
      IFS="$SEP" read -r status artist title album url length <<<"$line"
      render
      update_art "$url"
    elif [ $rc -gt 128 ]; then
      render tick
    else
      break
    fi
  done
