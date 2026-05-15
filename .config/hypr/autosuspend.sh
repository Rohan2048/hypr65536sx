#!/bin/bash

# Wait for hyprlock to fully start
sleep 60

# After 60 seconds, suspend
if pidof hyprlock >/dev/null; then
    systemctl suspend -i
fi
