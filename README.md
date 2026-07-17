# Flex Player

Flex Player is a custom Qt6/QML client for the Plex media server. It uses `libmpv` as its playback engine, natively supporting all the advanced features `mpv` has to offer.

## Why Flex Player?
The main motivation for creating Flex Player was to replace the official Flatpak and Snap Plex clients on Linux to address their architectural limitations. Specifically:
* Flex Player natively supports Wayland.
* Flex Player supports true HDR output on Linux

### 1. Native Wayland Support
The official Plex client on Linux relies on X11 abstraction layers (XWayland) by design, which fundamentally restricts performance and breaks HDR.\
Flex Player runs natively on Wayland and optimally passes video to the `libmpv` renderer, ensuring perfectly smooth playback without X11 overhead.

### 2. HDR Passthrough
Flex Player was built explicitly with HDR in mind. The Qt/QML layer performs proper HDR passthrough to `libmpv`, which boasts excellent Wayland/HDR support and can be finely tuned via `mpv.conf`.

Additionally, Flex Player includes native Lua scripts to automatically toggle the system HDR state in `KDE` Plasma when HDR movie playback starts, and toggle it back off when finished.\
These Lua scripts can be easily customized to support other desktop environments, such as `GNOME`.

## Features

### UI
Flex Player uses the Plex server API directly to fetch and display your library. Currently supported features include:
- **Home Page:**
  - Recently Added items in each library
  - Continue Watching list
- **Series library:**
  - Recently Added group by Serie name. 
  - Count of watched/total episodes groupped by Serie
  - Number of seasonds for each Serie
- **Movies library:**
  - Recently Added movies
  - Collections tab support
- **Movie Posters:**
  - Watched progress bars
  - Watched status checkmarks
- **Playback:** Fully featured embedded playback with auto-hiding controls.

### Settings and Customization
- Configurable Plex libraries to display in UI (Movies and Series are supported now)  

Application settings can be configured either through the in-app settings page or directly by editing `~/.config/flex-player/config.ini`.

### MPV Integration
Flex Player fully supports `mpv` customization via:
- Configuration file: `~/.config/flex-player/mpv/mpv.conf`
- Custom scripts: `~/.config/flex-player/mpv/scripts/`

---

*For detailed instructions on how to build and install Flex Player, see [BUILD.md](BUILD.md).*  
*For detailed information on the E2E UI testing architecture, see [tests/README.md](tests/README.md).*

