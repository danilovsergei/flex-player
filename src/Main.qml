import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import flex.mpv 1.0
import flex.plex 1.0

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 720
    visible: true
    title: qsTr("Flex Player")
    color: "#1e1e1e"
    objectName: "mainWindow"

    palette.text: "#E5A00D"
    palette.windowText: "#E5A00D"
    palette.highlightedText: "#000000"
    palette.highlight: "#E5A00D"
    palette.buttonText: "#E5A00D"
    palette.base: "#111111"
    palette.window: "#111111"

    property bool isTestMode: false
    property int previousTab: 0

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
    property alias playerView: playerView
    property alias rootLayout: rootLayout

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
    property bool _autoCollapsedForMusic: false
    
    onCurrentTabChanged: {
        if (currentTab !== 7 && _autoCollapsedForMusic) {
            mainWindow.sidebarCollapsed = false;
            _autoCollapsedForMusic = false;
        }
    }
    
    property Component globalMovieDelegate: movieDelegate

    // Virtual property to allow headless tests to spoof fullscreen states
    property bool manualFullScreen: false
    property bool isFullScreenMode: manualFullScreen || mainWindow.visibility === Window.FullScreen || mainWindow.visibility === Window.AutomaticVisibility

    readonly property color plexOrange: "#E5A00D"

    function startupLogic() { controller.startupLogic() }
    function loadLibraryContent(id, title, type, serverUrl, uniqueId, serverToken, serverName) { 
        if (type === "artist" && appSettings && appSettings.minimizeSidebarOnMusic) {
            if (!mainWindow.sidebarCollapsed) {
                mainWindow._autoCollapsedForMusic = true;
                mainWindow.sidebarCollapsed = true;
            }
        }
        controller.loadLibraryContent(id, title, type, serverUrl, uniqueId, serverToken, serverName) 
    }
    function getLibraryIcon(type) { return controller.getLibraryIcon(type) }
    function formatTime(seconds) { return controller.formatTime(seconds) }
    
    function openSearchResults() {
        if (mainWindow.currentTab !== 6) {
            mainWindow.previousTab = mainWindow.currentTab;
            mainWindow.currentTab = 6;
        }
    }

    function openCollection(ratingKey, itemServerUrl) {
        if (mainWindow.currentTab === 0 || mainWindow.currentTab === 1) {
            mainWindow.previousTab = mainWindow.currentTab;
        }
        var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
        controller.collectionMoviesModel.fetchEndpoint(url, appSettings.token, "/library/collections/" + ratingKey + "/children");
        mainWindow.currentTab = 2;
    }

    function openShow(ratingKey, itemServerUrl, itemServerToken) {
        var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
        controller.detailsModel.fetchItemDetails(url, (itemServerToken && itemServerToken !== "") ? itemServerToken : appSettings.token, ratingKey);
    }

    function openDetails(ratingKey, itemServerUrl, itemServerToken) {
        var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
        controller.detailsModel.fetchItemDetails(url, (itemServerToken && itemServerToken !== "") ? itemServerToken : appSettings.token, ratingKey);
    }

    function openArtist(ratingKey, itemServerUrl, itemServerToken) {
        if (mainWindow.currentTab !== 8) {
            if (mainWindow.currentTab === 0 || mainWindow.currentTab === 1 || mainWindow.currentTab === 6) {
                mainWindow.previousTab = mainWindow.currentTab;
            } else if (mainWindow.currentTab === 7) {
                mainWindow.previousTab = mainWindow.currentTab;
            }
            artistDetailsView.historyStack = [];
        } else {
            var newStack = artistDetailsView.historyStack.slice();
            newStack.push(artistDetailsView.rawJson);
            artistDetailsView.historyStack = newStack;
        }
        var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
        controller.detailsModel.fetchItemDetails(url, (itemServerToken && itemServerToken !== "") ? itemServerToken : appSettings.token, ratingKey);
    }

    function openAlbum(ratingKey, itemServerUrl, itemServerToken) {
        if (mainWindow.currentTab !== 9) {
            if (mainWindow.currentTab === 0 || mainWindow.currentTab === 1 || mainWindow.currentTab === 6) {
                mainWindow.previousTab = mainWindow.currentTab;
            } else if (mainWindow.currentTab === 7 || mainWindow.currentTab === 8) {
                mainWindow.previousTab = mainWindow.currentTab;
            }
            albumDetailsView.historyStack = [];
        } else {
            var newStackAlbum = albumDetailsView.historyStack.slice();
            newStackAlbum.push(albumDetailsView.rawJson);
            albumDetailsView.historyStack = newStackAlbum;
        }
        var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
        controller.detailsModel.fetchItemDetails(url, (itemServerToken && itemServerToken !== "") ? itemServerToken : appSettings.token, ratingKey);
    }
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
            onOpenCollection: function(ratingKey, itemServerUrl, itemServerToken) {
                console.log("Opening collection: " + ratingKey)
                if (mainWindow.currentTab === 0 || mainWindow.currentTab === 1) {
                    mainWindow.previousTab = mainWindow.currentTab;
                }
                var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
                controller.collectionMoviesModel.fetchEndpoint(url, appSettings.token, "/library/collections/" + ratingKey + "/children")
                mainWindow.currentTab = 2
            }
            onOpenShow: function(ratingKey, itemServerUrl, itemServerToken) {
                console.log("Opening show/season: " + ratingKey)
                var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
                controller.detailsModel.fetchItemDetails(url, (itemServerToken && itemServerToken !== "") ? itemServerToken : appSettings.token, ratingKey);
            }
            onPlayMedia: function(title, mediaUrl, viewOffset, ratingKey, duration) {
                console.log("Starting embedded playback for: " + title + " | mediaUrl: " + mediaUrl)
                rootLayout.visible = false
                playerView.visible = true
                playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration, "auto", "no", [])
            }
            onOpenDetails: function(ratingKey, itemServerUrl, itemServerToken) {
                console.log("Opening details for: " + ratingKey + " itemServerUrl: " + itemServerUrl);
                var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
                controller.detailsModel.fetchItemDetails(url, (itemServerToken && itemServerToken !== "") ? itemServerToken : appSettings.token, ratingKey);
            }
            onOpenAlbum: function(ratingKey, itemServerUrl, itemServerToken) {
                mainWindow.openAlbum(ratingKey, itemServerUrl, itemServerToken);
            }
            onOpenArtist: function(ratingKey, itemServerUrl, itemServerToken) {
                mainWindow.openArtist(ratingKey, itemServerUrl, itemServerToken);
            }
            onDeleteCollectionRequested: function(ratingKey, itemServerUrl) {
                console.log("Deleting collection: " + ratingKey);
                var url = (itemServerUrl && itemServerUrl !== "") ? itemServerUrl : (controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl);
                var token = controller.currentServerToken !== "" ? controller.currentServerToken : appSettings.token;
                controller.libraryAllModel.deleteEndpoint(url, token, "/library/collections/" + ratingKey);
                
                // Refresh the current view
                refreshCollectionsTimer.start();
            }
            onEditSmartCollectionRequested: function(ratingKey, title, contentUri, itemServerUrl) {
                console.warn("Editing smart collection (caught): " + ratingKey);
                mainWindow.currentTab = 1; // Switch to LibraryRecommendView/LibraryBrowserView
                
                // Using QML object tree navigation instead of findChild since findChild is not natively available in QML JS
                var recommendView = rootLayout.children[1].children[1].children[1]; // libraryView (LibraryRecommendView)
                
                if (recommendView) {
                    recommendView.libraryTab = 2; // 2 is LibraryBrowserView
                    var browserView = recommendView.browserView;
                    if (browserView && browserView.loadSmartCollection) {
                        browserView.loadSmartCollection(ratingKey, title, contentUri);
                    } else {
                        console.error("Could not find loadSmartCollection on browserView property");
                    }
                } else {
                    console.error("Could not find recommendView");
                }
            }
        }

    }

    Timer {
        id: refreshCollectionsTimer
        interval: 1000
        onTriggered: {
            var url = controller.currentServerUrl !== "" ? controller.currentServerUrl : controller.connectionManager.activeUrl;
            if (controller.currentLibraryId !== "") {
                controller.libraryCollectionsModel.fetchEndpoint(url, appSettings.token, "/library/sections/" + controller.currentLibraryId + "/collections")
            }
        }
    }

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent
        spacing: 0


        TopToolbar {
            id: topToolbar
            objectName: "topToolbar"
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
                objectName: "sidebarView"
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
                    currentLibraryId: controller.currentLibraryId
                    currentLibraryTitle: controller.currentLibraryTitle
                    currentLibraryType: controller.currentLibraryType
                    continueWatchingModel: controller.libraryDeckModel
                    recentlyAddedModel: controller.libraryRecentModel
                    collectionsModel: controller.libraryCollectionsModel
                    movieDelegate: movieDelegate
                }
                

                CollectionMoviesView {
                    id: collectionMoviesView
                    collectionMoviesModel: controller.collectionMoviesModel
                    movieDelegate: movieDelegate
                    onBackToCollections: currentTab = mainWindow.previousTab
                }


                MovieDetailsView {
                    id: movieDetailsView
                    rootApp: mainWindow
                    onBackRequested: currentTab = mainWindow.previousTab
                    onPlayMediaRequested: function(title, mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams) {
                        rootLayout.visible = false
                        playerView.visible = true
                        playerView.playMedia(mediaUrl, viewOffset, ratingKey, duration, audioId, subId, streams)
                    }
                }
                

                SeriesDetailsView {
                    id: seriesDetailsView
                    rootApp: mainWindow
                    onBackRequested: currentTab = mainWindow.previousTab
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
                
                SearchResultsView {
                    id: searchResultsView
                    rootApp: mainWindow
                    movieDelegate: globalMovieDelegate
                }
            
                MusicBrowserView {
                    id: musicBrowserView
                }

                ArtistDetailsView {
                    id: artistDetailsView
                    rootApp: mainWindow
                    onBackRequested: currentTab = mainWindow.previousTab
                }

                AlbumDetailsView {
                    id: albumDetailsView
                    rootApp: mainWindow
                    onBackRequested: currentTab = mainWindow.previousTab
                }
            }
            

            Connections {
                target: controller.detailsModel
                function onItemDetailsLoaded(jsonString) {
                    try {
                        var parsed = JSON.parse(jsonString);
                        var type = parsed.MediaContainer.Metadata[0].type;
                        console.warn("onItemDetailsLoaded: got type " + type);
                        
                        if (mainWindow.currentTab === 0 || mainWindow.currentTab === 1 || mainWindow.currentTab === 2 || mainWindow.currentTab === 7) {
                            mainWindow.previousTab = mainWindow.currentTab;
                        }

                        if (type === "show") {
                            seriesDetailsView.rawJson = jsonString;
                            mainWindow.currentTab = 4;
                        } else if (type === "season") {
                            seasonDetailsView.rawJson = jsonString;
                            mainWindow.currentTab = 5;
                        } else if (type === "artist") {
                            artistDetailsView.rawJson = jsonString;
                            mainWindow.currentTab = 8;
                        } else if (type === "album") {
                            albumDetailsView.rawJson = jsonString;
                            mainWindow.currentTab = 9;
                        } else {
                            movieDetailsView.rawJson = jsonString;
                            mainWindow.currentTab = 3;
                        }
                    } catch(e) {
                        if (mainWindow.currentTab === 0 || mainWindow.currentTab === 1 || mainWindow.currentTab === 2 || mainWindow.currentTab === 7) {
                            mainWindow.previousTab = mainWindow.currentTab;
                        }
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
        onPlaybackStopped: function(finalTimeMs) {
            if (playerView.currentRatingKey !== "") {
                controller.globalDeckModel.updateTimeline(appSettings.serverUrl, appSettings.token, playerView.currentRatingKey, "stopped", finalTimeMs, playerView.currentDuration);
                
                var mToken = controller.detailsModel.currentServerToken !== "" ? controller.detailsModel.currentServerToken : appSettings.token;
                var mUrl = controller.detailsModel.currentServerUrl !== "" ? controller.detailsModel.currentServerUrl : appSettings.serverUrl;
                controller.detailsModel.fetchItemDetails(mUrl, mToken, playerView.currentRatingKey);
                
                playerView.currentRatingKey = "";
            }
            controller.refreshAllContent();
            rootLayout.visible = true
        }
    }

    SettingsWindow {
        id: settingsWindow
        allLibrariesModel: controller.allLibrariesModel
        collectionsModel: controller.collectionsModel
    }
}

