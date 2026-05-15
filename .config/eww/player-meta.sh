#!/usr/bin/env bash
EMPTY='{"status":"Stopped","title":"","artist":"","album":"","art":"","duration":0,"duration_fmt":"00:00","position":0,"position_fmt":"00:00"}'

STATE_FILE="/tmp/eww/player_state"
STATUS_FILE="/tmp/eww/player_status_prev"
ART_CACHE="/tmp/eww/art_cache"
mkdir -p /tmp/eww "$ART_CACHE"

echo "$EMPTY"

resolve_art() {
    local url="$1"
    [[ -z "$url" ]] && return

    local hash file
    hash=$(printf '%s' "$url" | md5sum | cut -d' ' -f1)
    file="$ART_CACHE/$hash"

    [[ -f "$file" ]] && { echo "$file"; return; }

    if [[ "$url" == file://* ]]; then
        local src="${url#file://}"
        convert "$src" -resize 200x200 "$file" 2>/dev/null || cp "$src" "$file" 2>/dev/null

    elif [[ "$url" == http://* || "$url" == https://* ]]; then
        curl -sf --max-time 5 -L -o "${file}.tmp" "$url" 2>/dev/null \
            || { rm -f "${file}.tmp"; return; }
        convert "${file}.tmp" -resize 200x200 "$file" 2>/dev/null \
            || mv "${file}.tmp" "$file"
        rm -f "${file}.tmp"

    elif [[ -f "$url" ]]; then
        convert "$url" -resize 200x200 "$file" 2>/dev/null || cp "$url" "$file" 2>/dev/null
    fi

    [[ -f "$file" ]] && echo "$file"
}

emit() {
    local status title artist album art dur_us dur_sec pos_sec art_path

    status=$(playerctl status 2>/dev/null)
    if [[ -z "$status" || "$status" == "Stopped" ]]; then
        echo "$EMPTY" | tee "$STATE_FILE"
        echo "Stopped" > "$STATUS_FILE"
        return
    fi

    title=$(playerctl  metadata xesam:title  2>/dev/null || true)
    artist=$(playerctl metadata xesam:artist 2>/dev/null || true)
    album=$(playerctl  metadata xesam:album  2>/dev/null || true)
    art=$(playerctl    metadata mpris:artUrl  2>/dev/null || true)
    dur_us=$(playerctl metadata mpris:length  2>/dev/null || true)

    pos_sec=$(playerctl position 2>/dev/null || echo 0)

    dur_us="${dur_us//[^0-9]/}"
    dur_us="${dur_us:-0}"
    pos_sec="${pos_sec:-0}"

    dur_sec=$(awk "BEGIN{printf \"%.3f\", ($dur_us/1000000)}")
    pos_sec=$(awk "BEGIN{printf \"%.3f\", $pos_sec}")
    dur_fmt=$(awk "BEGIN{s=int($dur_sec); printf \"%02d:%02d\",s/60,s%60}")
    pos_fmt=$(awk "BEGIN{s=int($pos_sec); printf \"%02d:%02d\",s/60,s%60}")

    art_path=$(resolve_art "$art")

    local out
    out=$(printf '{"status":"%s","title":"%s","artist":"%s","album":"%s","art":"%s","duration":%s,"duration_fmt":"%s","position":%s,"position_fmt":"%s"}' \
        "$(printf '%s' "$status" | sed 's/"/\\"/g')" \
        "$(printf '%s' "$title"  | sed 's/\\/\\\\/g; s/"/\\"/g')" \
        "$(printf '%s' "$artist" | sed 's/\\/\\\\/g; s/"/\\"/g')" \
        "$(printf '%s' "$album"  | sed 's/\\/\\\\/g; s/"/\\"/g')" \
        "$(printf '%s' "${art_path:-}" | sed 's/"/\\"/g')" \
        "$dur_sec" "$dur_fmt" \
        "$pos_sec" "$pos_fmt")

    local prev prev_status
    prev=$(cat "$STATE_FILE" 2>/dev/null)
    prev_status=$(cat "$STATUS_FILE" 2>/dev/null)

    if [[ "$status" != "$prev_status" || "$out" != "$prev" ]]; then
        echo "$out" | tee "$STATE_FILE"
        echo "$status" > "$STATUS_FILE"
    fi
}

emit

playerctl --follow metadata --format '{{status}}' 2>/dev/null | while IFS= read -r _; do
    emit
done
