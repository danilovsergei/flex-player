# Plex Docker Test Server

This directory contains a standalone Docker setup to run an isolated Plex Media Server instance. This is useful for testing features like Shared Libraries, Remote Access, or Multi-Server switching without interfering with your primary host server.

By default, `start.sh` will map the container's internal port `32400` to the host's port `32401`. This allows it to run alongside an existing server on `32400`.

## 1. How to Start a Clean Plex Server

If you want a completely fresh, empty Plex Server (e.g., to create a new user account, generate a new claim token, and set up brand new libraries from scratch to test sharing):

1. **Clear the existing config** (if any) to ensure it's a fresh start:
   ```bash
   rm -rf config/*
   ```
2. **(Optional but recommended)** Get a claim token from [https://plex.tv/claim](https://plex.tv/claim) and add it to `start.sh` by appending `-e PLEX_CLAIM=claim-xxxxxxx \` to the `docker run` command. This automatically links the fresh server to your Plex account upon startup.
3. **Run the start script:**
   You can run the start script with defaults, or pass arguments for PORT, CONFIG_DIR, MOVIES_DIR, and SERIES_DIR.
   ```bash
   ./start.sh [PORT] [CONFIG_DIR] [MOVIES_DIR] [SERIES_DIR]
   ```
   **Examples:**
   Using defaults (Port 32401, local config, default media dirs):
   ```bash
   ./start.sh
   ```
   Custom port and directories:
   ```bash
   ./start.sh 32402 /path/to/custom/config /path/to/movies /path/to/series
   ```
4. **Access the Web UI:**
   Navigate to `http://<your-host-ip>:<PORT>/web` (e.g., `http://<your-host-ip>:32401/web`) to complete the initial setup wizard.

## 2. How to Start a Plex Server with an Existing Configuration (like "gentoo")

If you want the test server to boot up using the exact live database, configuration, and media directories of your native Gentoo Plex server:

1. **Ensure the Native Service is Stopped**
   To avoid port collisions on port `32400` and database locking issues, stop the native Gentoo service first:
   ```bash
   sudo systemctl stop plexmediaserver # or equivalent Gentoo rc-service command
   ```

2. **Run the specialized Gentoo start script:**
   ```bash
   ./start_gentoo_plex_server.sh
   ```
   *This script runs via `sudo` under the hood to ensure it has read/write access to `/var/lib/plexmediaserver/...`. It automatically binds the native configuration directory, the `/home/geonix/Movies` directory, and the `/home/geonix/Series` directory directly to the container.*

3. **Access the Web UI:**
   Navigate to `http://<your-host-ip>:32400/web`. It should appear identically to your primary server.

**Important Note on Shared Library Testing:** Because cloning the Gentoo config results in the exact same Machine Identifier, Plex's central backend might get confused if you try to run both servers simultaneously on different ports. To test "Shared Libraries" cleanly with a second user account, it is heavily recommended to use **Method 1 (Clean Server)** so that Plex treats it as a distinctly separate piece of hardware.
