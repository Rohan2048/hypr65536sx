
#!/usr/bin/env bash
# preload.sh — warm up caches in background at eww startup
# Call this from your eww start script: bash ~/.config/eww/preload.sh &

# ── 1. Calendar cache ─────────────────────────────────────────────────────
# Runs calendar.sh silently so the 18-month cache is already on disk when
# the user opens the popup. Zero visible delay on first open.
(
    python3 ~/.config/eww/calendar.sh >/dev/null 2>&1
) &

# ── 2. App/icon cache for shortcuts-add.sh ────────────────────────────────
# shortcuts-add.sh already has a TSV scan-cache, but it only runs the scan
# when the user clicks "+". This warms it up at startup so rofi opens fast.
ICONS_DIR="$HOME/.config/eww/icons"
APP_CACHE="$ICONS_DIR/.app_cache.tsv"
CACHE_STAMP="$ICONS_DIR/.last_scan"
mkdir -p "$ICONS_DIR"

SCAN_NEEDED=false
{ [ ! -f "$CACHE_STAMP" ] || [ ! -f "$APP_CACHE" ]; } && SCAN_NEEDED=true

if ! $SCAN_NEEDED; then
    CHANGED=$(find /usr/share/applications "$HOME/.local/share/applications" \
        /var/lib/flatpak/exports/share/applications \
        "$HOME/.local/share/flatpak/exports/share/applications" \
        /var/lib/snapd/desktop/applications \
        -maxdepth 1 -name "*.desktop" -newer "$CACHE_STAMP" 2>/dev/null | wc -l)
    [ "$CHANGED" -gt 0 ] && SCAN_NEEDED=true
fi

if $SCAN_NEEDED; then
    # Reuse shortcuts-add.sh's scan logic without launching rofi.
    # We do a minimal rebuild: parse all .desktop files, cache icons.
    (
        ICON_DIRS=(
            "/usr/share/icons/Papirus/48x48/apps"
            "/usr/share/icons/Papirus-Dark/48x48/apps"
            "/usr/share/icons/hicolor/48x48/apps"
            "/usr/share/icons/hicolor/64x64/apps"
            "/usr/share/icons/hicolor/scalable/apps"
            "/usr/share/icons/Adwaita/48x48/apps"
            "/usr/share/icons/breeze/apps/48"
            "/usr/share/pixmaps"
            "$HOME/.local/share/icons/hicolor/48x48/apps"
            "$HOME/.local/share/icons/hicolor/scalable/apps"
            "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps"
            "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps"
            "$HOME/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps"
            "$HOME/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps"
        )

        resolve_icon() {
            local ICON="$1"
            [ -f "$ICON" ] && echo "$ICON" && return
            for DIR in "${ICON_DIRS[@]}"; do
                [ ! -d "$DIR" ] && continue
                for EXT in png svg xpm; do
                    [ -f "$DIR/$ICON.$EXT" ] && echo "$DIR/$ICON.$EXT" && return
                done
            done
            for BASE in /usr/share/icons /usr/share/pixmaps \
                "$HOME/.local/share/icons" \
                /var/lib/flatpak/exports/share/icons \
                "$HOME/.local/share/flatpak/exports/share/icons"; do
                [ ! -d "$BASE" ] && continue
                FOUND=$(find "$BASE" -type f \( -name "${ICON}.png" -o -name "${ICON}.svg" -o -name "${ICON}.xpm" \) 2>/dev/null | sort | head -1)
                [ -n "$FOUND" ] && echo "$FOUND" && return
            done
            echo ""
        }

        cache_icon() {
            local ICON_PATH="$1" ICON_SAFE="$2"
            local OUT="$ICONS_DIR/${ICON_SAFE}.png"
            [ -f "$OUT" ] && echo "$OUT" && return 0
            if [[ "$ICON_PATH" == *.svg ]]; then
                command -v rsvg-convert &>/dev/null && rsvg-convert -w 48 -h 48 "$ICON_PATH" -o "$OUT" 2>/dev/null && echo "$OUT" && return 0
                command -v convert &>/dev/null && convert -background none -resize 48x48 "$ICON_PATH" "$OUT" 2>/dev/null && echo "$OUT" && return 0
            elif [[ "$ICON_PATH" == *.xpm ]]; then
                command -v convert &>/dev/null && convert "$ICON_PATH" -resize 48x48 "$OUT" 2>/dev/null && echo "$OUT" && return 0
            else
                command -v convert &>/dev/null && convert "$ICON_PATH" -resize 48x48 "$OUT" 2>/dev/null && echo "$OUT" && return 0
                [[ "$ICON_PATH" == *.png ]] && cp "$ICON_PATH" "$OUT" && echo "$OUT" && return 0
            fi
            return 1
        }

        > "$APP_CACHE"

        for DIR in \
            /usr/share/applications \
            /usr/local/share/applications \
            "$HOME/.local/share/applications" \
            /var/lib/flatpak/exports/share/applications \
            "$HOME/.local/share/flatpak/exports/share/applications" \
            /var/lib/snapd/desktop/applications; do
            [ ! -d "$DIR" ] && continue
            while IFS= read -r -d '' DFILE; do
                NAME=$(grep -m1 "^Name=" "$DFILE" | cut -d= -f2-)
                [ -z "$NAME" ] && continue
                [ "$(grep -m1 "^NoDisplay=" "$DFILE" | cut -d= -f2-)" = "true" ] && continue
                [ "$(grep -m1 "^Hidden=" "$DFILE" | cut -d= -f2-)" = "true" ] && continue

                APP_ICON=$(grep -m1 "^Icon=" "$DFILE" | cut -d= -f2-)
                CACHED_ICON=""
                if [ -n "$APP_ICON" ]; then
                    ICON_SAFE=$(echo "$APP_ICON" | tr '/' '_' | tr ' ' '_')
                    CACHED="$ICONS_DIR/${ICON_SAFE}.png"
                    if [ ! -f "$CACHED" ]; then
                        ICON_PATH=$(resolve_icon "$APP_ICON")
                        [ -n "$ICON_PATH" ] && cache_icon "$ICON_PATH" "$ICON_SAFE" >/dev/null
                    fi
                    [ -f "$CACHED" ] && CACHED_ICON="$CACHED"
                fi

                [[ "$NAME" == *$'\t'* ]] && continue
                printf '%s\t%s\t%s\n' "$NAME" "$DFILE" "$CACHED_ICON" >> "$APP_CACHE"
            done < <(find "$DIR" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null)
        done

        awk -F'\t' '!seen[$1]++' "$APP_CACHE" > "${APP_CACHE}.tmp" && mv "${APP_CACHE}.tmp" "$APP_CACHE"
        touch "$CACHE_STAMP"
    ) &
fi

# ── 3. Sink list cache ────────────────────────────────────────────────────
# Pre-populate /tmp/eww/sinks_cache so volume-listener.sh finds it immediately.
mkdir -p /tmp/eww
pactl list sinks 2>/dev/null | awk -F': ' '
/Description/ {
    desc=$2
    gsub(/^ +| +$/,"",desc)
    gsub(/"/,"",desc)
    printf "%s\"%s\"", sep, desc
    sep=","
}
END { print "" }' | awk '{print "["$0"]"}' > /tmp/eww/sinks_cache

pactl get-default-sink 2>/dev/null | while read -r DEFAULT; do
    pactl list sinks 2>/dev/null \
        | grep -A15 "Name: $DEFAULT" \
        | grep 'Description:' | head -n1 \
        | cut -d: -f2- | xargs > /tmp/eww/active_sink
done

# ── 4. Battery energy_full cache ─────────────────────────────────────────
BAT=/sys/class/power_supply/BAT0
[ -f "$BAT/energy_full" ] && cat "$BAT/energy_full" > /tmp/eww/battery_energy_full_cache
