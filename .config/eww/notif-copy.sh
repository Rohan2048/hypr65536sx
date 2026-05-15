#!/bin/bash
TITLE="$1"
HASH=$(python3 -c "import hashlib; print(hashlib.md5('$TITLE'.encode()).hexdigest()[:8])")
cat "/tmp/eww-notifs/$HASH" | wl-copy
