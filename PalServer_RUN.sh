#!/bin/sh

# Resolve script name and project root
UE_TRUE_SCRIPT_NAME=$(echo \"$0\" | xargs readlink -f)
UE_PROJECT_ROOT=$(dirname "$UE_TRUE_SCRIPT_NAME")

# Define paths
SOURCE="$UE_PROJECT_ROOT/linux64/steamclient.so"
DESTINATION="$UE_PROJECT_ROOT/Pal/Binaries/Linux/steamclient.so"
LD_PRELOAD_PATH="/home/$(whoami)/libUE4SS.so"
PAL_SERVER_EXEC="$UE_PROJECT_ROOT/Pal/Binaries/Linux/PalServer-Linux-Shipping"

# Ensure the destination directory exists
if [ ! -d "$(dirname "$DESTINATION")" ]; then
    echo "The destination directory does not exist: $(dirname "$DESTINATION")"
    exit 1
fi

# Copy steamclient.so if not already present
if [ -f "$DESTINATION" ]; then
    echo "The file already exists: $DESTINATION"
else
    if cp "$SOURCE" "$DESTINATION"; then
        echo "The file has been successfully copied: $SOURCE -> $DESTINATION"
    else
        echo "Failed to copy the file: $SOURCE -> $DESTINATION"
        exit 1
    fi
fi

# Ensure the server binary is executable
chmod +x "$PAL_SERVER_EXEC"

# Run the server with LD_PRELOAD set
export LD_PRELOAD="$LD_PRELOAD_PATH"
"$PAL_SERVER_EXEC" Pal "$@"
