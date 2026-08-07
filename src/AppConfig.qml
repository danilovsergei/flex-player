import QtQuick
import QtCore

Item {
    id: root
    visible: false
    
    property bool isTestMode: false

    property alias serverUrl: loginSettings.serverUrl
    property alias token: loginSettings.token
    property alias localServerUrl: loginSettings.localServerUrl
    property alias remoteServerUrl: loginSettings.remoteServerUrl
    property alias enabledLibraries: librarySettings.enabledLibraries
    property alias fullscreenHotkey: hotkeySettings.fullscreenHotkey
    property alias playPauseHotkey: hotkeySettings.playPauseHotkey
    property alias volumeUpHotkey: hotkeySettings.volumeUpHotkey
    property alias volumeDownHotkey: hotkeySettings.volumeDownHotkey
    property alias seekForwardHotkey: hotkeySettings.seekForwardHotkey
    property alias seekBackwardHotkey: hotkeySettings.seekBackwardHotkey
    
    property alias musicUpHotkey: hotkeySettings.musicUpHotkey
    property alias musicDownHotkey: hotkeySettings.musicDownHotkey
    property alias musicSelectAllHotkey: hotkeySettings.musicSelectAllHotkey
    property alias musicDeleteHotkey: hotkeySettings.musicDeleteHotkey
    property alias musicShiftDownHotkey: hotkeySettings.musicShiftDownHotkey
    property alias musicShiftUpHotkey: hotkeySettings.musicShiftUpHotkey
    property alias musicPlayPauseHotkey: hotkeySettings.musicPlayPauseHotkey

    property alias autoToggleHdr: playbackSettings.autoToggleHdr
    property alias minimizeSidebarOnMusic: playbackSettings.minimizeSidebarOnMusic
    property alias hdrEnableCommand: playbackSettings.hdrEnableCommand
    property alias hdrDisableCommand: playbackSettings.hdrDisableCommand
    property alias defaultPlaylist: musicSettings.defaultPlaylist
    property alias musicRepeatMode: musicSettings.musicRepeatMode

    property alias serverList: loginSettings.serverList
    property alias connectionVersion: loginSettings.connectionVersion

    Settings {
        id: loginSettings
        category: "Login"
        location: root.isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string serverUrl: ""
        property string token: ""
        property string localServerUrl: ""
        property string remoteServerUrl: ""
        property string serverList: "[]"
        property int connectionVersion: 0
    }

    Settings {
        id: librarySettings
        category: "Libraries"
        location: root.isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string enabledLibraries: "{}"
    }

    Settings {
        id: hotkeySettings
        category: "Hotkeys"
        location: root.isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string fullscreenHotkey: "f"
        property string playPauseHotkey: "Space"
        property string volumeUpHotkey: "Up"
        property string volumeDownHotkey: "Down"
        property string seekForwardHotkey: "Right"
        property string seekBackwardHotkey: "Left"
        
        property string musicUpHotkey: "Up"
        property string musicDownHotkey: "Down"
        property string musicSelectAllHotkey: "Ctrl+A"
        property string musicDeleteHotkey: "Delete"
        property string musicShiftDownHotkey: "Shift+Down"
        property string musicShiftUpHotkey: "Shift+Up"
        property string musicPlayPauseHotkey: "Space"
    }

    Settings {
        id: playbackSettings
        category: "Playback"
        location: root.isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property bool autoToggleHdr: false
        property bool minimizeSidebarOnMusic: false
        property string hdrEnableCommand: "kscreen-doctor output.DP-1.hdr.enable output.DP-1.wcg.enable"
        property string hdrDisableCommand: "kscreen-doctor output.DP-1.hdr.disable output.DP-1.wcg.disable"
    }

    Settings {
        id: musicSettings
        category: "Music"
        location: root.isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string defaultPlaylist: "[]"
        property int musicRepeatMode: 0
    }
}
