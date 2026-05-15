#!/bin/bash
TOUCHPAD=$(hyprctl devices | grep -i touchpad | xargs)
STATUS_FILE="/tmp/touchpad_status"

if [ -f "$STATUS_FILE" ] && [ "$(cat $STATUS_FILE)" = "disabled" ]; then
    hyprctl keyword "device[$TOUCHPAD]:enabled" 1
    notify-send "Touchpad" "Enabled"
    echo "enabled" > "$STATUS_FILE"
else
    hyprctl keyword "device[$TOUCHPAD]:enabled" 0
    notify-send "Touchpad" "Disabled"
    echo "disabled" > "$STATUS_FILE"
fi
