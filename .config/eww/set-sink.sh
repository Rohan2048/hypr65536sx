#!/bin/bash
TARGET="$1"

# Find the sink name corresponding to the description
SINK_NAME=$(pactl list sinks | awk -v target="$TARGET" '
  $1=="Name:" {name=$2}
  $1=="Description:" {
    desc=substr($0,index($0,$2)); gsub(/^ +| +$/,"",desc)
    if(desc==target) {print name; exit}
  }
')

# Set default if found
[[ -n "$SINK_NAME" ]] && pactl set-default-sink "$SINK_NAME"

eww update VOLUME_STATE="$(bash ~/.config/eww/volume-listener.sh | head -1)"
