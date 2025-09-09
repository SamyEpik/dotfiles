#!/bin/bash

# Path to the external script file
SCRIPT_FILE="/home/samuel/.config/hypr/hyprland.conf"

# Function to enable laptop monitor
enable_monitor() {
    sed -i 's/^#monitor=eDP-1,disable/monitor=eDP-1,disable/' "$SCRIPT_FILE"
}

# Function to disable laptop monitor
disable_monitor() {
    sed -i 's/^monitor=eDP-1,disable/#monitor=eDP-1,disable/' "$SCRIPT_FILE"
}

# Main function
main() {
    while true; do
        # Check lid state
        lid_state=$(cat /proc/acpi/button/lid/LID0/state | awk '{print $2}')
        
        # If lid is closed
        if [ "$lid_state" == "closed" ]; then
            disable_monitor
        else
            enable_monitor
        fi
        
        # Wait for lid state change
        while true; do
            # Check if lid state has changed
            new_lid_state=$(cat /proc/acpi/button/lid/LID0/state | awk '{print $2}')
            if [ "$new_lid_state" != "$lid_state" ]; then
                lid_state="$new_lid_state"
                break
            fi
            sleep 1
        done
    done
}

# Run the main function
main
