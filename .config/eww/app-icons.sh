#!/bin/bash

# Output directory for resized icons
OUT_DIR="$HOME/.config/eww/icons"
mkdir -p "$OUT_DIR"

# Directories with .desktop files
DESKTOP_DIRS=(
    "/usr/share/applications"
    "$HOME/.local/share/applications"
)

# Standard icon theme directories
ICON_DIRS=(
    "/usr/share/icons/hicolor"
    "/usr/share/pixmaps"
    "$HOME/.local/share/icons"
)

# Function to resolve icon name to a file
resolve_icon() {
    local icon_name="$1"

    # If icon_name is already a file path
    if [ -f "$icon_name" ]; then
        echo "$icon_name"
        return
    fi

    # Search standard icon directories
    for DIR in "${ICON_DIRS[@]}"; do
        # Look for PNG/SVG in subdirs
        local FILE=$(find "$DIR" -type f -name "$icon_name.*" | head -n1)
        if [ -n "$FILE" ]; then
            echo "$FILE"
            return
        fi
    done

    # Not found
    echo ""
}

# Loop through all .desktop files
for DIR in "${DESKTOP_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        for DESKTOP in "$DIR"/*.desktop; do
            [ -e "$DESKTOP" ] || continue

            # Extract icon name
            ICON_NAME=$(grep -E '^Icon=' "$DESKTOP" | head -n1 | cut -d= -f2)
            [ -z "$ICON_NAME" ] && continue

            ICON_PATH=$(resolve_icon "$ICON_NAME")
            [ -z "$ICON_PATH" ] && continue

            FILENAME=$(basename "$ICON_PATH")
            OUT_PATH="$OUT_DIR/$FILENAME.png"

            # Convert and resize to 24x24
            if [[ "$ICON_PATH" == *.svg ]]; then
                rsvg-convert -w 24 -h 24 "$ICON_PATH" -o "$OUT_PATH"
            else
                convert "$ICON_PATH" -resize 24x24 "$OUT_PATH"
            fi

            echo "Saved: $OUT_PATH (from $DESKTOP)"
        done
    fi
done
