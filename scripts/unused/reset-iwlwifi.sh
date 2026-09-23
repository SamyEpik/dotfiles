#!/bin/bash
echo "Resetting iwlwifi..."
sudo rmmod iwlmvm iwlwifi 2>/dev/null
sleep 2
sudo modprobe iwlwifi
sudo modprobe iwlmvm
sudo systemctl restart NetworkManager
echo "Done."
