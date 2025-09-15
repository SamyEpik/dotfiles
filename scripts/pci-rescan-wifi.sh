#!/bin/bash
set -e
PCI_ID=$(lspci -nn | awk '/Network controller/ {print $1; exit}')
echo "Removing PCI device $PCI_ID"
echo 1 | sudo tee /sys/bus/pci/devices/0000:$PCI_ID/remove
sleep 1
echo 1 | sudo tee /sys/bus/pci/rescan
sudo modprobe iwlwifi
sudo systemctl restart NetworkManager
