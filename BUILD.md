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

## Running the Application

To run the application natively on a Wayland display, use the following command:

```bash
./flex_player_app
```

**Zero-Copy Hardware Decoding Note:** 
The application configures `mpv` to use `hwdec=auto-safe` and native Wayland HDR output. Ensure your system has the appropriate graphics drivers (e.g., VAAPI) installed and configured for optimal zero-copy playback performance.


## Building the Flatpak

Flex Player provides an official Flatpak manifest (`io.github.danilovsergei.flex-player.json`) to securely containerize the application, compile its dependencies (including `libmpv`, `ffmpeg`, `libplacebo`, and `libass`), and natively bind to Wayland and host GPUs.

To guarantee a perfectly reproducible build environment that matches the GitHub Actions CI pipeline, we strongly recommend building the Flatpak locally using Docker:

1. **Launch the Flathub CI Container:**
   From the root of the `flex_player` repository, start the official KDE 6.8 build container:
   ```bash
   docker run --rm -it \
     --privileged \
     -v $(pwd):/workspace \
     -w /workspace \
     ghcr.io/flathub-infra/flatpak-github-actions:kde-6.8 \
     bash
   ```
   *(Note: `--privileged` is strictly required for `flatpak-builder` to create secure Bubblewrap namespaces during compilation.)*

2. **Fix Container DBus (Inside Docker):**
   Docker containers lack a machine-id by default, which Flatpak requires. Generate one:
   ```bash
   dbus-uuidgen > /etc/machine-id
   ```

3. **Run the Build:**
   Compile the Flatpak while bypassing the FUSE filesystem wrapper (which requires X11/Wayland context):
   ```bash
   flatpak-builder build-dir io.github.danilovsergei.flex-player.json --force-clean --disable-rofiles-fuse --repo=repo
   ```

4. **Export the Bundle (Inside Docker):**
   Once the build completes, export the application into a standalone `.flatpak` installer:
   ```bash
   flatpak build-export repo build-dir
   flatpak build-bundle repo flex-player.flatpak io.github.danilovsergei.flex-player
   ```
   You can now type `exit` to leave the Docker container.

5. **Install and Run (On Host):**
   Install the newly generated Flatpak bundle directly to your local user environment:
   ```bash
   flatpak install --user -y flex-player.flatpak
   flatpak run io.github.danilovsergei.flex-player
   ```

*(Note: If you prefer not to use Docker, you can install `flatpak-builder` on your host system and install the `org.kde.Platform//6.8` and `org.kde.Sdk//6.8` runtimes via Flathub.)*
