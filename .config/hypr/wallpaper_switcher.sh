#!/bin/bash

WALLPAPER_DIR="$HOME/Downloads/WALLPAPERS"
THUMB_DIR="$HOME/.cache/wallpaper_thumbs"
mkdir -p "$THUMB_DIR"

ROFI_THEME="$HOME/.config/rofi/wallpaper-selector.rasi"

# Check for required programs
for cmd in rofi swaybg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "$cmd is not installed."
        exit 1
    fi
done

# Check for ImageMagick
if ! command -v convert &>/dev/null && ! command -v magick &>/dev/null; then
    echo "ImageMagick is required for thumbnail generation."
    exit 1
fi

convert_cmd=$(command -v magick || command -v convert)

# Returns true if any wallpaper is missing a thumbnail
needs_thumbnails() {
    for ext in jpg jpeg png webp bmp gif; do
        shopt -s nullglob
        for img in "$WALLPAPER_DIR"/*."$ext"; do
            [ -f "$img" ] || continue
            filename=$(basename "$img")
            name="${filename%.*}"
            thumb_path="$THUMB_DIR/${name}_thumb.png"
            if [ ! -f "$thumb_path" ] || [ "$img" -nt "$thumb_path" ]; then
                shopt -u nullglob
                return 0
            fi
        done
        shopt -u nullglob
    done
    return 1
}

generate_thumbnails() {
    for ext in jpg jpeg png webp bmp gif; do
        shopt -s nullglob
        for img in "$WALLPAPER_DIR"/*."$ext"; do
            [ -f "$img" ] || continue
            filename=$(basename "$img")
            name="${filename%.*}"
            thumb_path="$THUMB_DIR/${name}_thumb.png"

            if [ ! -f "$thumb_path" ] || [ "$img" -nt "$thumb_path" ]; then
                "$convert_cmd" "$img[0]" -strip -thumbnail 500x500^ -gravity center -extent 500x500 "$thumb_path" 2>/dev/null
            fi
        done
        shopt -u nullglob
    done
}

create_rofi_entries() {
    mapping_file="/tmp/wallpaper_mapping_$$"
    > "$mapping_file"

    for ext in jpg jpeg png webp bmp gif; do
        shopt -s nullglob
        for img in "$WALLPAPER_DIR"/*."$ext"; do
            [ -f "$img" ] || continue
            filename=$(basename "$img")
            name="${filename%.*}"
            thumb="$THUMB_DIR/${name}_thumb.png"

            echo "$name|$img" >> "$mapping_file"

            if [ -f "$thumb" ]; then
                printf "%s\x00icon\x1f%s\n" "$name" "$thumb"
            else
                echo "$name"
            fi
        done
        shopt -u nullglob
    done
}

# Show "Generating thumbnails" notice in rofi if needed, then generate
if needs_thumbnails; then
    (
        echo "Generating thumbnails, please wait..." | rofi -dmenu \
            -p "" \
            -mesg "Choose Wallpaper" \
            -theme "$ROFI_THEME" \
            -mesg "⏳ Generating thumbnails, please wait..." \
            -no-custom \
            -theme-str 'listview { lines: 0; } inputbar { enabled: false; }' \
            &
        ROFI_PID=$!

        generate_thumbnails
        kill "$ROFI_PID" 2>/dev/null
    )
    sleep 0.2
else
    generate_thumbnails
fi

mapping_file="/tmp/wallpaper_mapping_$$"

selection=$(create_rofi_entries | rofi -dmenu -i \
    -p "  Wallpaper" \
    -show-icons \
    -theme "$ROFI_THEME")

[ -z "$selection" ] && { rm -f "$mapping_file"; exit 0; }

selected_line=$(grep -F "$selection|" "$mapping_file")
selected_path=$(echo "$selected_line" | cut -d'|' -f2)
rm -f "$mapping_file"

[ -f "$selected_path" ] || { echo "Error: File not found - $selected_path"; exit 1; }

# Update shellwrapper
sed -i "s|^WALLPAPER=.*|WALLPAPER=\"$selected_path\"|" ~/.config/hypr/shellwrapper.sh

# Generate Pywal colors
/home/rohan/.local/bin/wal -i "$selected_path" -q

# Set wallpaper
killall swaybg 2>/dev/null
swaybg -i "$selected_path" -m fill &

# Restart dunst with new colors
killall dunst 2>/dev/null
dunst &

# Force eww to reload CSS
touch ~/.config/eww/eww.scss
killall -9 eww 2>/dev/null
eww daemon &
sleep 1
eww open bar-window && eww open top-bar-window

# Reload Hyprland
hyprctl reload

notify-send "Wallpaper Changed" "Applied $(basename "$selected_path")"
