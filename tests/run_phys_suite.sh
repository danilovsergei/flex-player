#!/bin/bash

# Flex Player - Phys Suite Runner
# This script executes all hardware/driver probes to verify the environment.
# MUST BE RUN IN A WAYLAND SESSION.

if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "ERROR: WAYLAND_DISPLAY is not set. This suite requires an active Wayland session."
    exit 1
fi

# Determine script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BIN_DIR="$SCRIPT_DIR/../build/tests/phys"

# List of probes to run
PROBES=(
    "phys_vaapi"
    "phys_vaapi_wl_connect"
    "phys_hwdec"
    "phys_fps"
)

echo "========================================"
echo " Flex Player - Physical Hardware Probes"
echo "========================================"

for probe in "${PROBES[@]}"; do
    echo ""
    echo ">>> Running $probe..."
    if [ -f "$BIN_DIR/$probe" ]; then
        "$BIN_DIR/$probe"
        if [ $? -eq 0 ]; then
            echo "Result: SUCCESS"
        else
            echo "Result: FAILED"
        fi
    else
        echo "ERROR: Binary $probe not found in $BIN_DIR. Did you build the project?"
    fi
done

echo ""
echo "========================================"
echo " Hardware Probing Complete."
echo "========================================"

