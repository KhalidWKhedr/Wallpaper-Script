#!/bin/bash

# Define paths
GENERIC_DIR="$HOME/.config/hypr/generic"
THEMES_DIR="$HOME/.config/hypr/themes"
LOGDIR="$HOME/.config/hypr/themes/zzz"
THEMES_LIST_FILE="$GENERIC_DIR/themes.txt"
CURRENT_THEME_IMAGE_FILE="$GENERIC_DIR/current_theme_image.txt"
CURRENT_THEME_VIDEO_FILE="$GENERIC_DIR/current_theme_video.txt"
LOGFILE="$LOGDIR/change_wallpaper.log"
HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"

# Ensure necessary directories exist
mkdir -p "$GENERIC_DIR" "$LOGDIR"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

kill_existing_videos() {
    log_message "Attempting to kill all mpvpaper processes."
    if pgrep mpvpaper > /dev/null; then
        while IFS= read -r p; do
            log_message "Attempting to kill process $p."
            if ! kill -9 "$p" 2>/dev/null; then
                log_message "Failed to kill process $p."
            else
                log_message "Successfully killed process $p."
            fi
        done < <(pgrep mpvpaper)
        log_message "All mpvpaper processes killed."
    else
        log_message "No running mpvpaper processes found."
    fi
    }

# Set video wallpaper
set_video_wallpaper() {
    local monitor="$1"
    local video_path="$2"
    log_message "Setting video wallpaper on $monitor with $video_path..."
    prime-run mpvpaper --mpv-options="vo=libmpv --gpu-api=vulkan --hwdec=auto --no-audio --loop --loop-playlist" "$monitor" "$video_path" &
    disown
    log_message "Video wallpaper applied on $monitor."
}

# Apply colors from an image using wallust
apply_image_theme() {
    local image_path="$1"
    log_message "Applying image theme using wallust: $image_path"
    if command -v wallust &>/dev/null && [ -f "$image_path" ]; then
        wallust run "$image_path" && log_message "Successfully applied theme from $image_path."
    else
        log_message "Error: wallust not found or image file missing."
    fi

    # Update hyprlock.conf with the new background image path
    log_message "Updating hyprlock.conf with new background image path: $image_path"
    sed -i "s|path = .*|path = $image_path|" "$HYPRLOCK_CONF" && log_message "Updated hyprlock.conf successfully." || log_message "Failed to update hyprlock.conf."
}

# Apply last-used video wallpaper
apply_last_video() {
    if [ -f "$CURRENT_THEME_VIDEO_FILE" ]; then
        local last_video=$(cat "$CURRENT_THEME_VIDEO_FILE")
        if [ -f "$last_video" ]; then
            log_message "Applying last video wallpaper: $last_video"
            OUTPUT_DEVICES=$(hyprctl monitors | grep "Monitor" | awk '{print $2}')
            for monitor in $OUTPUT_DEVICES; do
                set_video_wallpaper "$monitor" "$last_video"
            done
            return 0
        else
            log_message "Last video file not found: $last_video"
        fi
    fi
    return 1
}

# Main logic
log_message "Starting theme application script."

# Apply last video wallpaper if available
if ! apply_last_video; then
    log_message "No last video wallpaper applied. Prompting for new theme."
fi

# Ensure themes list exists
if [ ! -f "$THEMES_LIST_FILE" ]; then
    log_message "Error: Themes list file not found: $THEMES_LIST_FILE"
    exit 1
fi

# Use hyprlauncher to select a theme
THEME_NAME=$(cat "$THEMES_LIST_FILE" | hyprlauncher --dmenu)
if [ -z "$THEME_NAME" ]; then
    log_message "No theme selected. Exiting."
    exit 1
fi

log_message "Selected theme: $THEME_NAME"
THEME_PATH="$THEMES_DIR/$THEME_NAME"
if [ ! -d "$THEME_PATH" ]; then
    log_message "Error: Theme directory not found: $THEME_PATH"
    exit 1
fi

# Find video and image files in the theme directory
VIDEO_PATH=$(find "$THEME_PATH" -type f -iname "*.mp4" | head -n 1)
IMAGE_PATH=$(find "$THEME_PATH" -type f \( -iname "*.png" -o -iname "*.jpg" \) | head -n 1)

if [ -z "$VIDEO_PATH" ]; then
    log_message "Error: No video file found in theme directory: $THEME_PATH"
    exit 1
fi

if [ -z "$IMAGE_PATH" ]; then
    log_message "Error: No image file found in theme directory: $THEME_PATH"
    exit 1
fi

# Log and apply selected theme
log_message "Applying theme: $THEME_NAME"
log_message "Video wallpaper: $VIDEO_PATH"
log_message "Image wallpaper: $IMAGE_PATH"

kill_existing_videos

# Apply the selected video wallpaper on monitors
OUTPUT_DEVICES=$(hyprctl monitors | grep "Monitor" | awk '{print $2}')
for monitor in $OUTPUT_DEVICES; do
    set_video_wallpaper "$monitor" "$VIDEO_PATH"
done

# Apply the image theme and update hyprlock.conf
apply_image_theme "$IMAGE_PATH"

# Save current theme details for future use
echo "$VIDEO_PATH" > "$CURRENT_THEME_VIDEO_FILE"
echo "$IMAGE_PATH" > "$CURRENT_THEME_IMAGE_FILE"
log_message "Saved current video and image paths."

log_message "Theme application complete."
