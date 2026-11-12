#!/bin/bash

pkill waybar
hyprctl dispatch 'hl.dsp.exec_cmd("waybar")'
