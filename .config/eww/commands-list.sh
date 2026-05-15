#!/usr/bin/env bash
FILE="$HOME/.config/eww/commands.json"
[ ! -f "$FILE" ] && echo "[]" > "$FILE"
stdbuf -oL python3 -c "import json; print(json.dumps(json.load(open('$FILE'))))"
