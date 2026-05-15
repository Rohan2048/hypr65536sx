#!/bin/bash

PLAY="/home/rohan/Downloads/MISC/MUSIC/"
FIRST_RUN="/tmp/autoplay_first_run"
WATCHER_PID="/tmp/autoplay_watcher_pid"

if pgrep -x "mpv" > /dev/null; then
    killall mpv
    [ -f "$WATCHER_PID" ] && kill $(cat "$WATCHER_PID") 2>/dev/null && rm -f "$WATCHER_PID"
    notify-send -h string:x-dunst-stack-tag:music-now-playing "Music" "Stopped"
else
    mpv --loop-playlist --no-video --volume=60 --input-ipc-server=/tmp/mpvsocket "$PLAY" &
    if [ ! -f "$FIRST_RUN" ]; then
        touch "$FIRST_RUN"
    else
        notify-send -h string:x-dunst-stack-tag:music-now-playing "Music" "Playing"
    fi
    (
        sleep 2
        PREV=""
        while pgrep -x mpv > /dev/null; do
            CURRENT=$(playerctl metadata title 2>/dev/null)
            if [ -n "$CURRENT" ] && [ "$CURRENT" != "$PREV" ]; then
                notify-send -h string:x-dunst-stack-tag:music-now-playing "Now Playing" "$CURRENT"
                PREV="$CURRENT"
            fi
            sleep 2
        done
    ) &
    echo $! > "$WATCHER_PID"
fi
