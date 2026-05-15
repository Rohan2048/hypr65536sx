#!/usr/bin/env bash

pgrep -x rofi > /dev/null && exit 0

POPUPS="notifications-popup wifi-popup bt-popup battery-popup shortcuts-window commands-window music-popup"

for POPUP in $POPUPS; do
    if eww active-windows 2>/dev/null | grep -q "$POPUP"; then
        for P in $POPUPS; do
            eww close "$P" 2>/dev/null
        done
        exit 0
    fi
done
