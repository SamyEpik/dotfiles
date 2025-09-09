#!/bin/bash

# Define the list of wallpapers
wallpapers=(
    "~/.config/wallpapers/coastline_street.webp"
    "~/.config/wallpapers/cyberpunk_view.webp"
    "~/.config/wallpapers/house_on_beach.webp"
    "~/.config/wallpapers/island_sunrise.webp"
    "~/.config/wallpapers/madrid_street.webp"
    "~/.config/wallpapers/mountain_lake_pixelart.webp"
    "~/.config/wallpapers/mountain_river_sunny.webp"
    "~/.config/wallpapers/pink_clouds.webp"
    "~/.config/wallpapers/purple_firewatch.webp"
    "~/.config/wallpapers/ranch_sunset.webp"
    "~/.config/wallpapers/sunset_lake_pixelart2.webp"
    "~/.config/wallpapers/sunset_lake_pixelart.webp"
    "~/.config/wallpapers/catppuccin_flower.webp"
    "~/.config/wallpapers/sunset_river_pixelart.webp"
)

# Get the total number of wallpapers
num_wallpapers=${#wallpapers[@]}

# Randomly select an index
random_index=$((RANDOM % num_wallpapers))

# Get the randomly selected wallpaper path
selected_wallpaper=${wallpapers[random_index]}

# Set the wallpaper using hyprctl
hyprctl hyprpaper wallpaper "eDP-1,$selected_wallpaper"
