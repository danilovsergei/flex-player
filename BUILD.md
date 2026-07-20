# Build and Install Instructions

## Build Requirements

To compile Flex Player from source, ensure your system meets the following prerequisites:

- **C++17 Compiler** (e.g., GCC or Clang)
- **CMake** (version 3.16 or higher)
- **Qt 6** (Required modules: `Quick`, `Network`, `OpenGL`, `Test`, and `Core`)
- **libmpv** (Client API for MPV player)
- **MpvQt** (KDE's `libmpv` QML wrapper for native Wayland rendering)

## Build Instructions

Flex Player uses CMake as its build system. Follow these steps to build the application and the test suite:

1. **Clone the repository with submodules:**
   ```bash
   git clone --recurse-submodules https://github.com/danilovsergei/flex-player.git
   cd flex-player
   ```

2. **Create a build directory:**
   ```bash
   mkdir -p build
   cd build
   ```

3. **Configure the project with CMake:**
   ```bash
   cmake ..
   ```

4. **Compile the binaries:**
   ```bash
   make -j$(nproc)
   ```
   This will generate two binaries:
   - `flex_player_app` (The main application)
   - `flex_player_test` (The headless TDD UI test suite)

## Running the Automated Tests

Flex Player uses strict Test-Driven Development (TDD). Before deploying or running the application, it is highly recommended to execute the UI test suite to verify the integrity of the application.

```bash
./flex_player_test
```
If running through ssh remotely, you will need to set also
```bash
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-0
```

*Note: A successful test run should finish with `Totals: XX passed, 0 failed`.*

## Running the Application

To run the application natively on a Wayland display, use the following command:

```bash
./flex_player_app
```

**Zero-Copy Hardware Decoding Note:** 
The application configures `mpv` to use `hwdec=auto-safe` and native Wayland HDR output. Ensure your system has the appropriate graphics drivers (e.g., VAAPI) installed and configured for optimal zero-copy playback performance.

