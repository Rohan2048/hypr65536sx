#!/usr/bin/env bash

source ~/.bashrc
dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

pgrep -x polkit-mate-authentication-agent-1 >/dev/null || /usr/libexec/polkit-mate-authentication-agent-1 &

WALLPAPER="/home/rohan/Downloads/WALLPAPERS/tranquil-pathway-under-a-torii-gate-backiee-5K.jpg"
#WALL_LIVE="/home/rohan/Videos/Hidamari/green.mp4"
# Generate colors (also generates dunstrc from template)
/home/rohan/.local/bin/wal -i "$WALLPAPER"

# Wait for Pywal to finish writing all files

# Set wallpaper
#killall swaybg 2>/dev/null
#swaybg -i "$WALLPAPER" -m fill &

#Or set live wallpaper(But add a nice frame for wal -i)
#killall mpvpaper 2>/dev/null
#mpvpaper -o "no-audio loop" '*' "$WALL_LIVE" &

#Just comment out either sway or mpvpaper if any one of them not needed

# Force eww to reload CSS
touch ~/.config/eww/eww.scss

# Restart eww with new colors
killall -9 eww 2>/dev/null
bash ~/.config/eww/preload.sh &   # <-- add this
eww daemon
eww open bar-window & eww open top-bar-window

# Restart dunst AFTER wal has written the new dunstrc
killall -9 dunst 2>/dev/null
dunst &

#Symlinking and updating gtk3.0
ln -sf ~/.cache/wal/gtk.css ~/.config/gtk-3.0/gtk.css


#Clipboard history (adjust number of items accordindly, or just omit --max-items <number> entirely)
wl-paste --watch cliphist --max-items 10 store &


