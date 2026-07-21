#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/1000
export LIBGL_ALWAYS_SOFTWARE=1
export QT_QUICK_BACKEND=software
export WAYLAND_DISPLAY=wayland-virt

# Start kwin_wayland in background
kwin_wayland --virtual --width 1280 --height 720 --socket wayland-virt > kwin_virt.log 2>&1 &
KWIN_PID=$!

# Wait for socket to be ready
for i in {1..50}; do
    if [ -S "$XDG_RUNTIME_DIR/wayland-virt" ]; then
        break
    fi
    sleep 0.1
done

# Run tests
/home/geonix/Build/flex_player/build/flex_player_test "$@"

# Cleanup
kill $KWIN_PID
wait $KWIN_PID 2>/dev/null
