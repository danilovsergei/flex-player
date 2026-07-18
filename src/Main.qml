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
        id: appSettings
        location: isTestMode ? StandardPaths.writableLocation(StandardPaths.TempLocation) + "/flex-player-test/config.ini" : StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/flex-player/config.ini"
        property string serverUrl: ""
        property string token: ""
        property string enabledLibraries: "{}"
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

    PlexModel { id: recentlyAddedModel }
    PlexModel { id: continueWatchingModel }
    PlexModel { id: collectionsModel }
    PlexModel { id: collectionMoviesModel }
    PlexModel { id: allLibrariesModel }
    
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
    
    function loadLibraryContent(id, title, type) {
        currentLibraryId = id
        currentLibraryTitle = title
        if (!isTestMode) {
            if (type === "show") {
                recentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/all?type=2&sort=addedAt:desc")
            } else {
                recentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/recentlyAdded")
            }
            continueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/onDeck")
            collectionsModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/collections")
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
        sequence: "f"
        onActivated: toggleFullScreen()
    }

    // Expose models for testing
    property var testRecentlyAddedModel: recentlyAddedModel
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
                collectionMoviesModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/metadata/" + ratingKey + "/allLeaves")
                currentTab = 2 // Switch to Collection Movies view
            }
            onPlayMedia: function(title, mediaUrl, viewOffset) {
                console.log("Starting embedded playback for: " + title + " | mediaUrl: " + mediaUrl)
                rootLayout.visible = false
                playerView.visible = true
                playerView.playMedia(mediaUrl, viewOffset)
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
                movieDelegate: movieDelegate
                onOpenSettingsRequested: openSettings(1)
            }

            // 1: LIBRARY RECOMMEND / COLLECTIONS VIEW
            LibraryRecommendView {
                id: libraryView
                currentLibraryTitle: currentLibraryTitle
                continueWatchingModel: continueWatchingModel
                recentlyAddedModel: recentlyAddedModel
                collectionsModel: collectionsModel
                movieDelegate: movieDelegate
            }
            
            // 2: COLLECTION MOVIES VIEW
            CollectionMoviesView {
                id: collectionMoviesView
                collectionMoviesModel: collectionMoviesModel
                movieDelegate: movieDelegate
                onBackToCollections: currentTab = 1
            }
        }
    }

    }
    // EMBEDDED PLAYER VIEW
    PlayerView {
        id: playerView
        isFullScreenMode: mainWindow.isFullScreenMode
        onPlaybackStopped: rootLayout.visible = true
    }

    SettingsWindow {
        id: settingsWindow
    }
}
