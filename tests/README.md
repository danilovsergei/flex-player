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


---

## Remote Network Testing & Simulated External IPs

Flex Player dynamically routes connections between local (e.g., `192.168.x.x`) and external (e.g., `99.x.x.x`) Plex server IPs. To guarantee this multi-server external routing never breaks, we simulate a WAN environment directly inside the headless Docker CI.

### Docker DNS Injection
In `tests/run_headless_suite.sh`, the Docker container is launched with an explicit network flag:
`--add-host mock-remote.plex.tv:127.0.0.1`

This maps a fake external-looking domain directly back to the internal Python mock server (`mock_server.py`).

### The TDD "Office Connectivity" Simulation
The integration test `test_76_external_ip_fallback` leverages this DNS injection to prove external routing works:
1. **Mock Payload**: The test injects a fake server payload containing both a local IP (`127.0.0.1`) and the fake remote domain (`mock-remote.plex.tv`).
2. **Network Blackout**: By forcing the test framework out of standard `isTestMode`, the C++ engine physically probes both IPs. The Python mock server refuses the local IP probe but succeeds on the remote domain probe.
3. **Rigorous Validation**: The test rigidly asserts that:
   - The global `PlexConnectionManager` correctly discards the local IP and binds to the external domain.
   - The UI (e.g., `SettingsWindow`) does not eagerly crash or bind to empty arrays.
   - The library checkboxes dynamically inherit the external `mock-remote` URL explicitly via `Connections` property bindings reacting to `onActiveUrlChanged()`.

### Mandates for Future Network Code
To ensure external connectivity is never broken by future commits, all developers **MUST** adhere to these rules:
1. **NO Local IP Biases**: Never write C++ logic that explicitly assumes a valid connection must contain `192.168.` or `10.x.x.x` (e.g., destroying non-local connections on a heartbeat timer).
2. **Dynamic UI Bindings**: Do not calculate URLs "once on boot" in QML if they depend on an active network probe. Use `Connections` to explicitly react to `onActiveUrlChanged()` from the `PlexConnectionManager`.
3. **Silent Background Probes**: QML background models (like settings previews) must fail silently. They MUST NOT report `ConnectionRefusedError` back to the global `connectionManager`, or they will violently poison and destroy the actual external connection state.
4. **Sanitize `plex.direct`**: Always mathematically strip `.plex.direct` wrappers from API payloads into raw `http://<ip>:<port>` strings before fetching. External DNS servers cannot resolve internal `plex.direct` hashes, causing fatal `HostNotFoundError` crashes.
