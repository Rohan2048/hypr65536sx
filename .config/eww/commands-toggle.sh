#!/usr/bin/env bash
GROUP="$1"
CURRENT=$(eww get COMMANDS_EXPANDED)
if [ "$CURRENT" = "$GROUP" ]; then
    eww update COMMANDS_EXPANDED=""
else
    eww update COMMANDS_EXPANDED="$GROUP"
fi
eww update COMMANDS="$(bash ~/.config/eww/commands-list.sh)"
