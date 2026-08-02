#!/bin/bash

# Resolve the absolute path of the directory containing this script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Default values
PORT=${1:-32401}
CONFIG_DIR=${2:-"$SCRIPT_DIR/config"}
MOVIES_DIR=${3:-"/home/geonix/Movies"}
SERIES_DIR=${4:-"$SCRIPT_DIR/media/series"}

echo "Using configuration:"
echo "  Port:       $PORT"
echo "  Config Dir: $CONFIG_DIR"
echo "  Movies Dir: $MOVIES_DIR"
echo "  Series Dir: $SERIES_DIR"
echo ""

echo "Stopping existing Plex Test Server..."
docker stop plex-test-server || true
docker rm plex-test-server || true

echo "Starting Plex Test Server with bridged networking on port $PORT..."
docker run -d \
  --name=plex-test-server \
  -p $PORT:32400/tcp \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e VERSION=docker \
  -v "$CONFIG_DIR:/config" \
  -v "$MOVIES_DIR:/media/movies" \
  -v "$SERIES_DIR:/media/series" \
  --restart unless-stopped \
  lscr.io/linuxserver/plex:latest

echo ""
echo "Plex is starting!"
echo "Give it a few seconds to initialize, then navigate to:"
echo "http://<your-host-ip>:$PORT/web"
echo ""

