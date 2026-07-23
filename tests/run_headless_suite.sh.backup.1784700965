#!/bin/bash

# Configuration
IMAGE_NAME="flex-player-test"
LOCAL_TEST_EXE="./build/flex_player_test"
PARALLEL_JOBS=4

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -j|--jobs) PARALLEL_JOBS="$2"; shift ;;
        *) POSITIONALS+=("$1") ;;
    esac
    shift
done

# 1. Ensure docker image exists
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "Error: Docker image '$IMAGE_NAME' not found. Please build it first:"
    echo "docker build -t $IMAGE_NAME -f Dockerfile.test ."
    exit 1
fi

# 2. Get test functions
echo "Scanning for test functions..."
FUNCS=$($LOCAL_TEST_EXE -platform offscreen -functions 2>&1 | grep "SidebarAndPlaybackTest::test_")

if [ -z "$FUNCS" ]; then
    echo "Error: Could not list test functions. Ensure the project is built locally in ./build"
    exit 1
fi

# 3. Setup
TOTAL_TESTS=$(echo "$FUNCS" | wc -l)
OUT_DIR="tests/results"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.log
rm -f tests/docker_failed_details.log

echo "--- Starting Weston Headless CI Suite ($TOTAL_TESTS tests) ---"
echo "Parallelism: $PARALLEL_JOBS jobs"

# 4. Execution Loop
CURRENT_JOBS=0

for FUNC in $FUNCS; do
    FNAME=$(echo $FUNC | cut -d'(' -f1)
    
    (
        LOG_FILE="$OUT_DIR/$FNAME.log"
        RES_FILE="$OUT_DIR/$FNAME.res"
        
        # Run test in docker
        docker run --rm --pull=never $IMAGE_NAME "$FNAME" > "$LOG_FILE" 2>&1
        local_ret=$?
        
        if [ $local_ret -eq 0 ] && grep -q "PASS   : .*$FNAME" "$LOG_FILE"; then
            echo "PASS" > "$RES_FILE"
            echo "  [ PASS ] $FNAME"
        else
            echo "FAIL" > "$RES_FILE"
            echo "  [ FAIL ] $FNAME"
        fi
    ) &
    
    ((CURRENT_JOBS++))
    
    if [[ $CURRENT_JOBS -ge $PARALLEL_JOBS ]]; then
        wait -n
        ((CURRENT_JOBS--))
    fi
done

# Wait for remaining
wait

# 5. Reporting
PASS_COUNT=0
FAIL_COUNT=0
FAILED_LIST=""

echo "--------------------------------------------------------"
echo "Final Summary ($TOTAL_TESTS tests total)"
echo "--------------------------------------------------------"

# We sort to keep it deterministic
for FUNC in $(echo "$FUNCS" | sort); do
    FNAME=$(echo $FUNC | cut -d'(' -f1)
    RES_FILE="$OUT_DIR/$FNAME.res"
    if [ -f "$RES_FILE" ] && [ "$(cat "$RES_FILE")" == "PASS" ]; then
        ((PASS_COUNT++))
    else
        ((FAIL_COUNT++))
        FAILED_LIST="$FAILED_LIST\n - $FNAME"
        echo "--- FAILURE IN $FNAME ---" >> tests/docker_failed_details.log
        if [ -f "$OUT_DIR/$FNAME.log" ]; then
            cat "$OUT_DIR/$FNAME.log" >> tests/docker_failed_details.log
        fi
        echo "-------------------------" >> tests/docker_failed_details.log
    fi
done

echo "--------------------------------------------------------"
echo "Total: $PASS_COUNT passed, $FAIL_COUNT failed"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "Failed tests: $FAILED_LIST"
    echo "See tests/docker_failed_details.log for details."
    exit 1
else
    echo "All $PASS_COUNT tests passed successfully!"
    exit 0
fi

