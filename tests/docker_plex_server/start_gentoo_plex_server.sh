#!/bin/bash

# Start the Docker Plex Server using the cloned Gentoo Plex configuration
# Port is set to 32401 to avoid conflicting with your native server.

PORT=32401
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="$SCRIPT_DIR/config"
MOVIES_DIR="/home/geonix/Movies"
SERIES_DIR="/home/geonix/Series"

echo "Starting Gentoo-cloned Plex Server via Docker..."
echo "Ensure you have copied your Gentoo config to: $CONFIG_DIR"

"$SCRIPT_DIR/start.sh" "$PORT" "$CONFIG_DIR" "$MOVIES_DIR" "$SERIES_DIR"

