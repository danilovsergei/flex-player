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

    property bool isTestMode: false

        PlexConnectionManager {
        id: connectionManager
        objectName: "connectionManager"
        // localUrl removed
        // remoteUrl removed
        token: appSettings.token
        
        onActiveUrlChanged: {
            if (activeUrl !== "" && activeUrl !== appSettings.serverUrl) {
                appSettings.serverUrl = activeUrl
            }
        }
    }

    AppConfig {
        id: appSettings
        isTestMode: mainWindow.isTestMode
    }


    property alias appSettings: appSettings
    property alias serverUrl: appSettings.serverUrl
    property alias token: appSettings.token
    property alias homeLibrariesList: controller.homeLibrariesList
    property alias controller: controller

    GlobalController {
        connectionManager: connectionManager
        id: controller
        mainWindow: mainWindow
        appSettings: appSettings
        playerView: playerView
        settingsWindow: settingsWindow
    }

    property int currentTab: 0
    property bool sidebarCollapsed: false
    property Component globalMovieDelegate: movieDelegate

    // Virtual property to allow headless tests to spoof fullscreen states
    property bool manualFullScreen: false
    property bool isFullScreenMode: manualFullScreen || mainWindow.visibility === Window.FullScreen || mainWindow.visibility === Window.AutomaticVisibility

    readonly property color plexOrange: "#E5A00D"

    function startupLogic() { controller.startupLogic() }
    function loadLibraryContent(id, title, type) { controller.loadLibraryContent(id, title, type) }
    function getLibraryIcon(type) { return controller.getLibraryIcon(type) }
    function formatTime(seconds) { return controller.formatTime(seconds) }
    function setLibraryEnabled(id, enabled, type, title) { controller.setLibraryEnabled(id, enabled, type, title) }
    function runHdrCommand(cmd) { controller.runHdrCommand(cmd) }
    function closeSettings() { controller.closeSettings() }

    Component.onCompleted: {
        controller.startupLogic()
    }

    onClosing: {
        if (playerView.hdrWasEnabledByApp) {
            console.log("Main: App closing while HDR active. Disabling system HDR...")
            runHdrCommand(appSettings.hdrDisableCommand)
        }
    }

    function toggleFullScreen() {
        if (isTestMode) { console.log("DEBUG: toggleFullScreen in test mode, manualFullScreen was: " + manualFullScreen);
            manualFullScreen = !manualFullScreen;
            return;
        }
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
                controller.throttleSeek(1)
            }
        }
    }
    
    Shortcut {
        sequence: appSettings.seekBackwardHotkey
        onActivated: {
            if (playerView.visible) {
                controller.throttleSeek(-1)
            }
        }
    }


    property var testGlobalRecentModel: controller.globalRecentModel
    property var testLibraryDeckModel: controller.libraryDeckModel
    property var testGlobalDeckModel: controller.globalDeckModel
    property var testCollectionsModel: controller.collectionsModel
    property var testCollectionMoviesModel: controller.collectionMoviesModel
    property var testAllLibrariesModel: controller.allLibrariesModel
    property var testAppSettings: appSettings


    Component {
        id: movieDelegate
        MoviePosterDelegate {
            onOpenCollection: function(ratingKey) {
                console.log("Opening collection: " + ratingKey)
                controller.collectionMoviesModel.fetchEndpoint(controller.connectionManager.activeUrl, appSettings.token, "/library/collections/" + ratingKey + "/children")
                currentTab = 2
            }
            onOpenShow: function(ratingKey) {
                console.log("Opening show/season: " + ratingKey)
                controller.detailsModel.fetchItemDetails(controller.connectionManager.activeUrl, appSettings.token, ratingKey);
            }
            onPlayMedia: function(title, mediaUrl, viewOffset, ratingKey, duration) {
                console.log("Starting embedded playback for: " + title + " | mediaUrl: " + mediaUrl)
                rootLayout.visible = false
                playerView.visible = true
                playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration)
            }
            onOpenDetails: function(ratingKey) {
                console.log("Opening details for: " + ratingKey);
                controller.detailsModel.fetchItemDetails(controller.connectionManager.activeUrl, appSettings.token, ratingKey);
            }
        }
    }

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent
        spacing: 0


        TopToolbar {
            id: topToolbar
            rootApp: mainWindow
            onSettingsRequested: controller.openSettings()
            onSidebarToggleRequested: mainWindow.sidebarCollapsed = !mainWindow.sidebarCollapsed
        }

        RowLayout {
            id: mainLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0


            SidebarView {
                id: sidebar
                mainWindow: mainWindow
            }


            StackLayout {
                id: contentStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentTab


                HomeView {
                    id: homeView
                    rootApp: mainWindow
                    continueWatchingModel: controller.globalDeckModel
                    recentlyAddedModel: controller.globalRecentModel
                    homeLibrariesList: controller.homeLibrariesList
                    enabledLibraries: appSettings.enabledLibraries
                    movieDelegate: movieDelegate
                    onOpenSettingsRequested: controller.openSettings(1)
                }


                LibraryRecommendView {
                    id: libraryView
                    currentLibraryTitle: controller.currentLibraryTitle
                    continueWatchingModel: controller.libraryDeckModel
                    recentlyAddedModel: controller.libraryRecentModel
                    collectionsModel: controller.libraryCollectionsModel
                    movieDelegate: movieDelegate
                }
                

                CollectionMoviesView {
                    id: collectionMoviesView
                    collectionMoviesModel: controller.collectionMoviesModel
                    movieDelegate: movieDelegate
                    onBackToCollections: currentTab = 1
                }


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
                        controller.detailsModel.fetchItemDetails(appSettings.serverUrl, appSettings.token, ratingKey);
                    }
                }
                

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
            

            Connections {
                target: controller.detailsModel
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
        }
    }


    PlayerView {
        id: playerView
        objectName: "playerView"
        rootApp: mainWindow
        isFullScreenMode: mainWindow.isFullScreenMode
        onTimelineUpdateRequested: function(state, timeMs) {
            if (playerView.currentRatingKey !== "") {
                controller.globalDeckModel.updateTimeline(appSettings.serverUrl, appSettings.token, playerView.currentRatingKey, state, timeMs, playerView.currentDuration)
            }
        }
        onPlaybackStopped: {
            if (playerView.currentRatingKey !== "") {
                controller.globalDeckModel.updateTimeline(appSettings.serverUrl, appSettings.token, playerView.currentRatingKey, "stopped", 0, playerView.currentDuration);
                playerView.currentRatingKey = "";
            }
            rootLayout.visible = true
        }
    }

    SettingsWindow {
        id: settingsWindow
        allLibrariesModel: controller.allLibrariesModel
        collectionsModel: controller.collectionsModel
    }
}

