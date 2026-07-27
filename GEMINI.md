# Remote Network Testing & TDD Architecture

## The Multi-Server Fallback Problem
Flex Player is architected to dynamically switch between local and external network connections. A critical failure mode occurs when the C++ backend or QML frontend is biased towards local IPs (e.g., hardcoded `192.168.` or `10.` heartbeat constraints, or eagerly binding to the first local array element).
When the application is run from outside the home network, local IPs will naturally throw `ConnectionRefusedError` or `HostNotFoundError` (especially with `plex.direct` local DNS wrappers). If the UI or background models (like `SettingsWindow`) eagerly catch these local timeouts and blindly propagate them, they will poison the global `PlexConnectionManager` state, completely destroying any valid external connection (e.g., `99.31...`).

## The Solution: Simulated External Connection Testing
To mathematically guarantee that multi-server support and external IP routing never break again, we implemented an immutable integration test (`test_76_external_ip_fallback`) inside the Headless Weston Docker CI environment.

### How it works:
1. **Docker DNS Injection (`mock-remote.plex.tv`)**:
   In `tests/run_headless_suite.sh`, the Docker container is launched with `--add-host mock-remote.plex.tv:127.0.0.1`. This creates a fake "external" DNS record that actually routes to the internal mock python server. This tricks the C++ engine into treating the connection as a remote WAN connection, explicitly bypassing any local network biases.

2. **The "Left the House" Scenario**:
   The test loads a mock server payload containing both a local IP (`127.0.0.1`) and the fake external domain (`mock-remote.plex.tv`).
   By setting `mainWindow.isTestMode = false`, we force the `PlexConnectionManager` to run its *actual* HTTP probe loop.
   The python mock server refuses or times out the local IP probe (because the mock server only listens on specific test ports, forcing the simulated local IP `127.0.0.1:9999` to fail), while the `mock-remote.plex.tv:32400` probe flawlessly succeeds.

3. **Strict QML Fallback Assertions**:
   The test rigorously verifies that the `PlexConnectionManager` drops the dead local IP and permanently sets `activeUrl` to the external domain.
   It then explicitly asserts that the UI (specifically `SettingsWindow.qml` and the library checkboxes) safely inherits this external domain by reacting dynamically to `onActiveUrlChanged()` rather than trying to resolve the URL on boot when the arrays are still empty.

## Mandates for Future Code
Whenever writing new C++ networking logic or QML data-fetching modules, you MUST adhere to the following rules to ensure the external connection fallback is never broken:

1. **NO LOCAL IP BIAS**: Never hardcode constraints that assume a valid connection must start with `192.168.`, `10.`, or `172.`.
2. **DECOUPLE BACKGROUND MODELS**: If a QML view (like a popup or settings page) fetches data in the background, it MUST NOT report its `QNetworkReply` errors back to the global `connectionManager`. Background probes must fail silently so they don't poison the global application state.
3. **DYNAMIC QML BINDINGS**: QML components MUST NOT evaluate `serverUrl` or `activeUrl` exactly once on boot. Because the C++ exhaustive probe takes a few milliseconds, initial arrays are empty. You MUST use explicit `Connections { target: connectionManager; function onActiveUrlChanged() {...} }` blocks to force the UI to aggressively recalculate its URLs the instant the C++ engine broadcasts the external winner.
4. **SANITIZE plex.direct**: Any raw server array payload will contain `plex.direct` URLs. You MUST mathematically strip these down to raw `http://<ip>:<port>` strings before querying them, otherwise the application will throw fatal `HostNotFoundError` crashes when external DNS servers try to resolve them.
5. **NEVER BYPASS TEST 76**: `test_76_external_ip_fallback` is the ultimate regression guard. If your code changes cause it to fail, you have broken the multi-server external routing. You must revert your changes and fix the architectural flow.

