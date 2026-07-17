# Flex Player - UI Testing Architecture

This document outlines how the automated End-to-End (E2E) UI testing framework is structured in Flex Player, how the mock data system isolates tests from the network, and how to write and execute new UI tests.

## Architecture Overview

Flex Player uses the **Qt Quick Test (`QTest`)** framework. To ensure clean architecture and prevent test code from bloating the production application, the project compilation is split into two separate targets:

1. **`flex_player_app`**: The main production executable that talks to your real Plex server.
2. **`flex_player_test`**: A headless/standalone test runner that compiles your UI components but executes them under strict test conditions.

### Dependency Injection & Mock Data

A cardinal rule of UI testing is that tests should **never** rely on external network requests or physical servers. If the Plex Server is down, the UI test should still pass.

To achieve this, we use a mocked data injection strategy:

1. **`isTestMode` Flag**: The `Main.qml` file exposes a property `property bool isTestMode: false`. When instantiated normally, the app fetches data from the network. When instantiated by the test suite, we pass `{isTestMode: true}`, which completely disables the `QNetworkAccessManager` fetch routine.
2. **Mock Video Files**: We use `ffmpeg` to generate local dummy `.mkv` files (`tests/dummy1.mkv`, `dummy2.mkv`, etc.) of exact, known durations (e.g., 1 minute, 2 minutes).
3. **`loadMockData()`**: The C++ `PlexModel` exposes a specific function for testing. The test suite manually calls `plexModel.loadMockData()` passing the local paths of the dummy videos. This populates the UI with fake posters that instantly play the local video files when clicked, completely bypassing the network.

---

## How to Run the Tests

Because Flex Player requires a hardware-accelerated OpenGL Core Profile for native MPV Wayland rendering, the tests must be executed within an active Wayland session (or a virtual compositor that supports true hardware acceleration).

To run the test suite from your terminal in an active Wayland session:
```bash
cd build
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-0
./flex_player_test
```

---

## How to Write New Tests

All QML tests reside in the `tests/` directory. The primary test file is currently `tst_playback.qml`.

### 1. The `TestCase` Structure
A Qt Quick Test is defined by a `TestCase` component. Inside it, any function name starting with `test_` will be automatically executed by the test runner.

```qml
import QtQuick
import QtTest
import flex_player_test_module 1.0

TestCase {
    name: "MyNewTestSuite"
    
    // Define how to instantiate the main UI
    Component { id: mainComponent; Main {} }
    Item { id: container; width: 1280; height: 720 }
    
    property var mainWindow
    
    // Runs once before all tests
    function initTestCase() {
        // Instantiate the UI in test mode
        mainWindow = mainComponent.createObject(container, {isTestMode: true})
        verify(mainWindow !== null, "Window created")
        
        // Inject the local dummy video files
        plexModel.loadMockData([
            "/home/geonix/Build/flex_player/tests/dummy1.mkv"
        ]);
    }
    
    // Runs once after all tests finish
    function cleanupTestCase() {
        if (mainWindow) mainWindow.destroy()
    }
    
    // Your actual test function
    function test_my_new_feature() {
        // ... assertions go here ...
    }
}
```

### 2. Targeting UI Elements
To test a button or view, the test suite needs to be able to "find" it. In your production QML code (e.g., `Main.qml`), you must assign an `objectName` to the element:

**In Main.qml:**
```qml
Button {
    objectName: "playPauseButton"
    text: "Pause"
}
```

**In your test function:**
```javascript
var playButton = findChild(mainWindow, "playPauseButton")
verify(playButton !== null, "Play button should exist on screen")
```

### 3. Assertions & Verification
The `QtTest` module provides several powerful assertion methods:

* **`verify(condition, message)`**: Fails the test if the condition is false.
* **`compare(actual, expected, message)`**: Asserts that two values are exactly equal.
* **`mouseClick(item)`**: Simulates a physical user mouse click on a QML item.
* **`wait(ms)`**: Halts the test runner for a specific number of milliseconds (useful for letting UI animations finish).

### Example: Testing a Pause Button
When you build your Play/Pause overlay, here is how you would write a robust test for it:

```javascript
function test_pause_button_changes_state() {
    // 1. Find the button
    var pauseButton = findChild(mainWindow, "playPauseButton")
    
    // 2. Assert initial state
    compare(pauseButton.text, "Pause", "Button should initially say Pause")
    
    // 3. Simulate user clicking the button
    mouseClick(pauseButton)
    
    // 4. Assert the UI updated correctly
    compare(pauseButton.text, "Play", "Button text should change to Play")
    
    // 5. Assert MPV actually paused (requires exposing a property from MpvItem)
    compare(mpvObject.isPaused, true, "MPV engine should be paused")
}
```

### Adding New Test Files
If you create a new `.qml` test file (e.g., `tst_controls.qml`), the test runner will automatically discover and run it, provided you placed it in the `tests/` directory. The `flex_player_test` executable scans the entire `QUICK_TEST_SOURCE_DIR` at runtime.
