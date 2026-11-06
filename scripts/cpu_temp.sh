#!/bin/bash
# Waybar custom module: CPU package temperature + CPU usage in the tooltip.
# Prints one JSON line per second (waybar "return-type": "json", no interval).

CRITICAL=80

# hwmonN numbers change between boots, so resolve via the stable coretemp device path
temp_file=$(ls /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
prev_idle=$((idle + iowait))
prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

while true; do
  sleep 1

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  cur_idle=$((idle + iowait))
  cur_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  d_total=$((cur_total - prev_total))
  d_idle=$((cur_idle - prev_idle))
  usage=0
  ((d_total > 0)) && usage=$(((100 * (d_total - d_idle) + d_total / 2) / d_total))
  prev_idle=$cur_idle
  prev_total=$cur_total

  temp=0
  [[ -n $temp_file ]] && temp=$(($(<"$temp_file") / 1000))

  class=""
  ((temp >= CRITICAL)) && class="critical"

  printf '{"text": " %s°C", "tooltip": "Open CPU Usage: \\n\\nAverage Core Temperature: %s°C\\n\\nCPU Usage: %s%%", "class": "%s", "percentage": %s}\n' \
    "$temp" "$temp" "$usage" "$class" "$usage"
done
