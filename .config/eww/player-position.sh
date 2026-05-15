#!/usr/bin/env bash
# Skip emit if user is seeking
[ -f /tmp/eww/player_seeking ] && cat /tmp/eww/player_pos_cache 2>/dev/null && exit 0

if ! playerctl status 2>/dev/null | grep -q Playing; then
    echo '{"secs":0,"fmt":"00:00"}' | tee /tmp/eww/player_pos_cache
    exit 0
fi

POS=$(playerctl position 2>/dev/null || echo 0)
M=$(awk "BEGIN{print int($POS/60)}")
S=$(awk "BEGIN{print int($POS%60)}")
printf '{"secs":%.3f,"fmt":"%02d:%02d"}\n' "$POS" "$M" "$S" | tee /tmp/eww/player_pos_cache
