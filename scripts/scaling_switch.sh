#!/bin/bash

# Switches the scaling in your Hyprland settings between 1 and 1.175000
# Usefull because some programs do not support fractional scaling with Wayland

# Set the path to your config file
config_file="/home/samuel/.config/hypr/categories/monitors.conf"

# Check if the config file exists
if [ -e "$config_file" ]; then
  # Use awk to find the last value in the specified line and toggle it
  awk -F, '/^monitor=eDP-1,2256x1504,0x2160/{gsub(/[0-9.]+$/, ($NF == 1.175000) ? 1 : 1.175000)}1' OFS=, "$config_file" >temp_file && mv temp_file "$config_file"
  awk -F, '/^monitor=DP-1,3840x2160,0x0/{gsub(/[0-9.]+$/, ($NF == 1.20000000) ? 1 : 1.20000000)}1' OFS=, "$config_file" >temp_file && mv temp_file "$config_file"

else
  echo "Error: Config file not found at $config_file."
fi
