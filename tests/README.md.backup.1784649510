# Flex Player - UI Testing Architecture

This document outlines how the automated End-to-End (E2E) UI testing framework is structured in Flex Player, how the mock data system isolates tests from the network, and how to execute the two primary test suites.

## Architecture Overview

Flex Player uses the **Qt Quick Test (`QTest`)** framework for UI logic and standalone C++ probes for hardware verification.

1. **`flex_player_app`**: The main production executable.
2. **`flex_player_test`**: The primary QML test runner for application logic.
3. **`tests/phys/`**: Standalone C++ probes that verify GPU/VAAPI/Wayland support.

---

## Test Suites

### 1. Headless Suite (Application Logic)
This suite verifies UI behavior, property bindings, navigation, and playback states. It uses a **Weston Headless** compositor inside Docker for high-fidelity Wayland testing. 

To ensure maximum reliability and speed, we provide an orchestration script that runs tests in isolated parallel Docker containers.

**Run via Orchestration Script (Recommended):**
```bash
# 1. Build the isolated test environment
docker build -t flex-player-test -f Dockerfile.test .

# 2. Run the orchestration script
# Default is 8 parallel jobs. Use -j to change.
./tests/run_headless_suite.sh -j 8
```

**Why use this script?**
- **Isolation**: Each test runs in its own container/Weston session, preventing `libmpv` state leakage.
- **Speed**: Tests run in parallel, significantly reducing total execution time.
- **Reliability**: Resolves resource exhaustion issues and layout races common in single-process runs.

**Run specific tests via Docker:**
```bash
docker run --rm flex-player-test SidebarAndPlaybackTest::test_49_series_details_view
```

---

### 2. Phys Suite (Hardware Probe)
This suite verifies that the host system is capable of hardware-accelerated playback. It **requires** an active Wayland session and a physical GPU.

**One-line command:**
```bash
./tests/run_phys_suite.sh
```

---

## Best Practices for Headless Tests
- **Use `tryCompare`**: Always use `tryCompare` for visibility or count checks, as headless layouts may take a few frames to stabilize.
- **Avoid `keyClick` for system keys**: Some system keys (like `Qt.Key_F`) can crash headless compositors. Use direct function calls (e.g., `mainWindow.toggleFullScreen()`) in test mode.
- **Mock Data**: Use `plexModel.loadMockData()` to inject local files instead of real Plex URLs.

