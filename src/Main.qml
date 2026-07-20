import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import flex.mpv 1.0
import flex.plex 1.0

Window {
    id: mainWindow
    width: 1280
    height: 720
    visible: true
    title: qsTr("Flex Player")
    color: "#1e1e1e"
    objectName: "mainWindow"

    Settings {
        id: loginSettings
        category: "Login"
        location: isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string serverUrl: ""
        property string token: ""
    }

    Settings {
        id: librarySettings
        category: "Libraries"
        location: isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string enabledLibraries: "{}"
    }

    Settings {
        id: hotkeySettings
        category: "Hotkeys"
        location: isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string fullscreenHotkey: "f"
        property string playPauseHotkey: "Space"
        property string volumeUpHotkey: "Up"
        property string volumeDownHotkey: "Down"
        property string seekForwardHotkey: "Right"
        property string seekBackwardHotkey: "Left"
    }

    Settings {
        id: playbackSettings
        category: "Playback"
        location: isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property bool autoToggleHdr: false
        property string hdrEnableCommand: "kscreen-doctor output.DP-1.hdr.enable output.DP-1.wcg.enable"
        property string hdrDisableCommand: "kscreen-doctor output.DP-1.hdr.disable output.DP-1.wcg.disable"
    }

    QtObject {
        id: appSettings
        property alias serverUrl: loginSettings.serverUrl
        property alias token: loginSettings.token
        property alias enabledLibraries: librarySettings.enabledLibraries
        property alias fullscreenHotkey: hotkeySettings.fullscreenHotkey
        property alias playPauseHotkey: hotkeySettings.playPauseHotkey
        property alias volumeUpHotkey: hotkeySettings.volumeUpHotkey
        property alias volumeDownHotkey: hotkeySettings.volumeDownHotkey
        property alias seekForwardHotkey: hotkeySettings.seekForwardHotkey
        property alias seekBackwardHotkey: hotkeySettings.seekBackwardHotkey
        property alias autoToggleHdr: playbackSettings.autoToggleHdr
        property alias hdrEnableCommand: playbackSettings.hdrEnableCommand
        property alias hdrDisableCommand: playbackSettings.hdrDisableCommand
    }

    property string serverUrl: appSettings.serverUrl
    property string token: appSettings.token
    property bool isTestMode: false
    property int currentTab: 0
    property bool sidebarCollapsed: false
    property Component globalMovieDelegate: movieDelegate

    // Virtual property to allow headless tests to spoof fullscreen states
    property bool isFullScreenMode: mainWindow.visibility === Window.FullScreen

    readonly property color plexOrange: "#E5A00D"

    property bool isScrubbing: false
    property bool wasPausedBeforeScrub: false
    property real lastSeekTime: 0
    property int consecutiveSeekCount: 0

    function throttleSeek(direction) {
        var now = Date.now()
        // High frequency (20Hz) to match mpv snappiness
        if (now - lastSeekTime < 50) return 
        
        lastSeekTime = now
        consecutiveSeekCount++
        scrubEndTimer.restart()
        
        // Smart Scrubbing: Only force-pause if we detect consecutive repeats (hold)
        if (!isScrubbing && consecutiveSeekCount > 1) {
            isScrubbing = true
            wasPausedBeforeScrub = playerView.mpvObject.paused
            playerView.mpvObject.paused = true
        }
        
        // Multi-stage acceleration: 5s -> 10s -> 30s
        var seekAmount = 5
        if (consecutiveSeekCount > 30) seekAmount = 30
        else if (consecutiveSeekCount > 5) seekAmount = 10
        
        playerView.mpvObject.command(["seek", direction * seekAmount, "relative", "keyframes"])
    }

    Timer {
        id: scrubEndTimer
        interval: 300
        onTriggered: {
            if (isScrubbing) {
                isScrubbing = false
                if (playerView.visible) {
                    // Final precise seek to snap to exact frame on release
                    playerView.mpvObject.command(["seek", "0", "relative", "exact"])
                    // Restore original playback state
                    playerView.mpvObject.paused = wasPausedBeforeScrub
                }
            }
            consecutiveSeekCount = 0
        }
    }

    PlexModel { id: recentlyAddedModel }
    PlexModel { id: continueWatchingModel }
    PlexModel { id: collectionsModel }
    PlexModel { id: collectionMoviesModel }
    PlexModel { id: allLibrariesModel }
    
    // Dedicated model for fetching item metadata (details, seasons, episodes)
    PlexModel { id: detailsModel }
    
    // Library-specific models for the Recommend/Collections view
    PlexModel { id: libraryRecentlyAddedModel }
    PlexModel { id: libraryContinueWatchingModel }
    PlexModel { id: libraryCollectionsModel }
    
    property var homeLibrariesList: []
    property string currentLibraryId: "1"
    property string currentLibraryTitle: "Movies"
    
    function getLibraryIcon(type) {
        if (type === "show") return "📺"
        if (type === "artist") return "🎵"
        if (type === "photo") return "📷"
        return "🎬"
    }
    
    function parseEnabledLibraries() {
        try {
            return JSON.parse(appSettings.enabledLibraries)
        } catch (e) {
            return {}
        }
    }
    
    function setLibraryEnabled(id, enabled, type, title) {
        var libs = parseEnabledLibraries()
        if (enabled) {
            libs[id] = { type: type, title: title }
        } else {
            delete libs[id]
        }
        appSettings.enabledLibraries = JSON.stringify(libs)
    }

    function closeSettings() {
        settingsWindow.visible = false
        startupLogic()
    }

    function runHdrCommand(cmd) {
        if (continueWatchingModel) {
            continueWatchingModel.executeSystemCommand(cmd);
        }
    }

    function deployHdrScript() {
        if (continueWatchingModel) {
            continueWatchingModel.deployHdrScript(appSettings.autoToggleHdr, appSettings.hdrEnableCommand, appSettings.hdrDisableCommand);
        }
    }
    
    function loadLibraryContent(id, title, type) {
        currentLibraryId = id
        currentLibraryTitle = title
        if (!isTestMode) {
            if (type === "show") {
                libraryRecentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/all?type=2&sort=addedAt:desc")
            } else {
                libraryRecentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/recentlyAdded")
            }
            libraryContinueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/onDeck")
            libraryCollectionsModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/collections")
        }
    }

    function openSettings(tabIndex) {
        settingsWindow.openTab(tabIndex, appSettings.serverUrl, appSettings.token)
    }

    function startupLogic() {
        if (appSettings.serverUrl === "" || appSettings.token === "") {
            console.log("Missing config, showing settings")
            openSettings()
        } else {
            console.log("Fetching data from " + appSettings.serverUrl);
            var enabledMap = parseEnabledLibraries()
            var keys = Object.keys(enabledMap)
            var libArray = []
            for (var i = 0; i < keys.length; i++) {
                var key = keys[i]
                libArray.push({
                    id: key,
                    title: enabledMap[key].title || "Library",
                    type: enabledMap[key].type || "movie"
                })
            }
            homeLibrariesList = libArray
                
            if (!isTestMode) {
                allLibrariesModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections")
                if (keys.length > 0) {
                    continueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/onDeck")
                } else {
                    continueWatchingModel.loadMockData([], "")
                }
            }
        }
    }

    Component.onCompleted: {
        startupLogic()
    }

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "00:00";
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        var h = Math.floor(m / 60);
        m = m % 60;
        var mStr = (m < 10 ? "0" : "") + m;
        var sStr = (s < 10 ? "0" : "") + s;
        if (h > 0) return h + ":" + mStr + ":" + sStr;
        return mStr + ":" + sStr;
    }

    function toggleFullScreen() {
        if (mainWindow.visibility === Window.FullScreen) {
            mainWindow.showNormal()
        } else {
            mainWindow.showFullScreen()
        }
    }

    Shortcut {
        sequence: appSettings.fullscreenHotkey
        onActivated: toggleFullScreen()
    }
    
    Shortcut {
        sequence: appSettings.playPauseHotkey
        onActivated: {
            if (playerView.visible) {
                playerView.mpvObject.paused = !playerView.mpvObject.paused;
            }
        }
    }
    
    Shortcut {
        sequence: appSettings.volumeUpHotkey
        onActivated: {
            if (playerView.visible) {
                playerView.mpvObject.volume = Math.min(100, playerView.mpvObject.volume + 5);
            }
        }
    }
    
    Shortcut {
        sequence: appSettings.volumeDownHotkey
        onActivated: {
            if (playerView.visible) {
                playerView.mpvObject.volume = Math.max(0, playerView.mpvObject.volume - 5);
            }
        }
    }

    
    Shortcut {
        sequence: appSettings.seekForwardHotkey
        onActivated: {
            if (playerView.visible) {
                throttleSeek(1)
            }
        }
    }
    
    Shortcut {
        sequence: appSettings.seekBackwardHotkey
        onActivated: {
            if (playerView.visible) {
                throttleSeek(-1)
            }
        }
    }

    // Expose models for testing
    property var testRecentlyAddedModel: recentlyAddedModel
    property var testLibraryContinueWatchingModel: libraryContinueWatchingModel
    property var testContinueWatchingModel: continueWatchingModel
    property var testCollectionsModel: collectionsModel
    property var testCollectionMoviesModel: collectionMoviesModel
    property var testAllLibrariesModel: allLibrariesModel
    property var testAppSettings: appSettings



    // Movie Poster Delegate
    Component {
        id: movieDelegate
        MoviePosterDelegate {
            onOpenCollection: function(ratingKey) {
                console.log("Opening collection: " + ratingKey)
                collectionMoviesModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/collections/" + ratingKey + "/children")
                currentTab = 2 // Switch to Collection Movies view
            }
            onOpenShow: function(ratingKey) {
                console.log("Opening show/season: " + ratingKey)
                detailsModel.fetchItemDetails(appSettings.serverUrl, appSettings.token, ratingKey);
            }
            onPlayMedia: function(title, mediaUrl, viewOffset, ratingKey, duration) {
                console.log("Starting embedded playback for: " + title + " | mediaUrl: " + mediaUrl)
                rootLayout.visible = false
                playerView.visible = true
                playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration)
            }
            onOpenDetails: function(ratingKey) {
                console.log("Opening details for: " + ratingKey);
                detailsModel.fetchItemDetails(appSettings.serverUrl, appSettings.token, ratingKey);
            }
        }
    }

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent
        spacing: 0


        // UPPER TOOLBAR
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#1e1e1e"
            z: 2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 20

                Button {
                    id: hamburgerButton
                    objectName: "hamburgerButton"
                    text: "☰"
                    font.pixelSize: 24
                    padding: 0
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? plexOrange : "white"
                        font: parent.font
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: mainWindow.sidebarCollapsed = !mainWindow.sidebarCollapsed
                }

                TextField {
                    id: searchField
                    objectName: "searchField"
                    placeholderText: "Search..."
                    Layout.preferredWidth: 300
                    color: "white"
                    background: Rectangle {
                        color: "#2e2e2e"
                        radius: 15
                    }
                    leftPadding: 15
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: settingsButton
                    objectName: "settingsButton"
                    text: "⚙"
                    font.pixelSize: 24
                    padding: 0
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? plexOrange : "white"
                        font: parent.font
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: openSettings()
                }
            }
        }

        RowLayout {
            id: mainLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // SIDEBAR
            SidebarView {
                id: sidebar
                mainWindow: mainWindow
            }

        // MAIN CONTENT
        Connections {
            target: detailsModel
            function onItemDetailsLoaded(jsonString) {
                try {
                    var parsed = JSON.parse(jsonString);
                    var type = parsed.MediaContainer.Metadata[0].type;
                    if (type === "show") {
                        seriesDetailsView.rawJson = jsonString;
                        mainWindow.currentTab = 4;
                    } else if (type === "season") {
                        seasonDetailsView.rawJson = jsonString;
                        mainWindow.currentTab = 5;
                    } else {
                        movieDetailsView.rawJson = jsonString;
                        mainWindow.currentTab = 3;
                    }
                } catch(e) {
                    movieDetailsView.rawJson = jsonString;
                    mainWindow.currentTab = 3;
                }
            }
        }

        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentTab

            // 0: HOME VIEW
            HomeView {
                id: homeView
                rootApp: mainWindow
                continueWatchingModel: continueWatchingModel
                homeLibrariesList: mainWindow.homeLibrariesList
                enabledLibraries: appSettings.enabledLibraries
                movieDelegate: movieDelegate
                onOpenSettingsRequested: openSettings(1)
            }

            // 1: LIBRARY RECOMMEND / COLLECTIONS VIEW
            LibraryRecommendView {
                id: libraryView
                currentLibraryTitle: currentLibraryTitle
                continueWatchingModel: libraryContinueWatchingModel
                recentlyAddedModel: libraryRecentlyAddedModel
                collectionsModel: libraryCollectionsModel
                movieDelegate: movieDelegate
            }
            
            // 2: COLLECTION MOVIES VIEW
            CollectionMoviesView {
                id: collectionMoviesView
                collectionMoviesModel: collectionMoviesModel
                movieDelegate: movieDelegate
                onBackToCollections: currentTab = 1
            }

            // 3: MOVIE DETAILS VIEW
            MovieDetailsView {
                id: movieDetailsView
                rootApp: mainWindow
                onBackRequested: currentTab = 0
                onPlayMediaRequested: function(title, mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams) {
                    rootLayout.visible = false
                    playerView.visible = true
                    playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams)
                }
            }
            
            // 4: SERIES DETAILS VIEW
            SeriesDetailsView {
                id: seriesDetailsView
                rootApp: mainWindow
                onBackRequested: currentTab = 0
                onPlayMediaRequested: function(title, mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams) {
                    rootLayout.visible = false
                    playerView.visible = true
                    playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams)
                }
                onOpenSeasonRequested: function(ratingKey) {
                    console.log("Opening season from series: " + ratingKey);
                    seasonDetailsView.seriesData = seriesDetailsView.detailsData;
                    detailsModel.fetchItemDetails(appSettings.serverUrl, appSettings.token, ratingKey);
                }
            }
            
            // 5: SEASON DETAILS VIEW
            SeasonDetailsView {
                id: seasonDetailsView
                rootApp: mainWindow
                onBackRequested: currentTab = 4
                onPlayMediaRequested: function(title, mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams) {
                    rootLayout.visible = false
                    playerView.visible = true
                    playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams)
                }
            }
        }
    }

    }
    // EMBEDDED PLAYER VIEW
    PlayerView {
        id: playerView
        rootApp: mainWindow
        isFullScreenMode: mainWindow.isFullScreenMode
        onTimelineUpdateRequested: function(state, timeMs) {
            if (playerView.currentRatingKey !== "") {
                continueWatchingModel.updateTimeline(appSettings.serverUrl, appSettings.token, playerView.currentRatingKey, state, timeMs, playerView.currentDuration)
            }
        }
        onPlaybackStopped: {
            if (playerView.currentRatingKey !== "") {
                continueWatchingModel.updateTimeline(appSettings.serverUrl, appSettings.token, playerView.currentRatingKey, "stopped", 0, playerView.currentDuration);
                playerView.currentRatingKey = "";
            }
            rootLayout.visible = true
        }
    }

    SettingsWindow {
        id: settingsWindow
    }
}
