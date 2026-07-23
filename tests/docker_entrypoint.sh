#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 0700 $XDG_RUNTIME_DIR

export WAYLAND_DISPLAY=wayland-0
export QT_QPA_PLATFORM=wayland
if [ "$FLEX_PLAYER_TEST_MODE" = "0" ]; then unset FLEX_PLAYER_TEST_MODE; elif [ -z "$FLEX_PLAYER_TEST_MODE" ]; then export FLEX_PLAYER_TEST_MODE=1; fi
export LIBGL_ALWAYS_SOFTWARE=1
export QT_QUICK_BACKEND=software
export QT_LOGGING_RULES="qt.qpa.*=false;qt.wayland*=false"

# Start Weston in background
weston --backend=headless --socket=wayland-0 --width=1280 --height=720 &
WESTON_PID=$!

# Wait for socket
for i in {1..100}; do
    if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
        break
    fi
    sleep 0.1
done

if [ ! -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
    echo "ERROR: Wayland socket not found!"
    kill $WESTON_PID
    exit 1
fi

# Create mock config.ini
mkdir -p ~/.config/flex-player
cat << 'EOF' > ~/.config/flex-player/config.ini
[Login]
serverList="[{\"connections\":[{\"local\":true,\"uri\":\"https://127.0.0.1:32400\"}],\"enabled\":true,\"name\":\"mockserver\",\"product\":\"Plex Media Server\"}]"
connectionVersion=5
token=mocktoken

[Libraries]
enabledLibraries={}
EOF

python3 /app/tests/mock_server.py &
MOCK_SERVER_PID=$!
sleep 1

cd /app/build_container

# Run the test(s)
# If no arguments are passed, it runs all tests.
./flex_player_test "$@"
RET=$?

# Cleanup
kill $MOCK_SERVER_PID 2>/dev/null
kill $WESTON_PID
wait $WESTON_PID 2>/dev/null

exit $RET

