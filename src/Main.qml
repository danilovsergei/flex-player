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
        if (tabIndex !== undefined) {
            settingsSidebarColumn.settingsTab = tabIndex
        } else {
            settingsSidebarColumn.settingsTab = 0
        }
        serverUrlField.text = appSettings.serverUrl
        tokenField.text = appSettings.token
        settingsWindow.connectionState = 0
        settingsWindow.connectionError = ""
        settingsWindow.visible = true
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
        Item {
            width: 200
            height: 300
            objectName: "movieItem"

            Rectangle {
                anchors.fill: parent
                color: "#2e2e2e"
                radius: 8
                clip: true

                Image {
                    anchors.fill: parent
                    source: thumbUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: (type === "show" || type === "season") ? 50 : 40
                    color: "#cc000000"

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 10
                        
                        Text {
                            width: parent.width
                            text: type === "season" && model.parentTitle ? model.parentTitle : title
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Text {
                            width: parent.width
                            text: type === "season" ? title : (type === "show" ? model.childCount + " Season" + (model.childCount !== 1 ? "s" : "") : "")
                            color: "gray"
                            font.pixelSize: 12
                            visible: text !== ""
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        height: 4
                        width: (model.duration > 0 && model.viewOffset > 0) ? (model.viewOffset / model.duration) * parent.width : 0
                        color: plexOrange
                        visible: width > 0
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 10
                    width: episodeCountText.width + 12
                    height: 24
                    radius: 4
                    color: "#b3000000"
                    visible: (type === "show" || type === "season") && model.leafCount > 0

                    Text {
                        id: episodeCountText
                        anchors.centerIn: parent
                        text: model.viewedLeafCount + "/" + model.leafCount
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Rectangle {
                    objectName: "watchedCheckmark"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    width: 24
                    height: 24
                    radius: 12
                    color: plexOrange
                    visible: model.isWatched

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.scale = 1.05
                onExited: parent.scale = 1.0
                onClicked: {
                    if (type === "collection") {
                        console.log("Opening collection: " + ratingKey)
                        collectionMoviesModel.fetchEndpoint(serverUrl, token, "/library/collections/" + ratingKey + "/children")
                        currentTab = 2 // Switch to Collection Movies view
                    } else {
                        console.log("Starting embedded playback for: " + title + " at offset: " + model.viewOffset)
                        rootLayout.visible = false
                        playerView.visible = true
                        if (model.viewOffset > 0) {
                            mpvObject.setProperty("start", (model.viewOffset / 1000).toString())
                            mpvObject.command(["loadfile", mediaUrl])
                        } else {
                            mpvObject.command(["loadfile", mediaUrl])
                        }
                        mpvObject.paused = false
                    }
                }
            }
            
            Behavior on scale {
                NumberAnimation { duration: 150 }
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
            Rectangle {
                Layout.preferredWidth: sidebarCollapsed ? 60 : 200
                Layout.fillHeight: true
                color: "#151515"
                objectName: "sidebar"
                
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 150 }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: sidebarCollapsed ? 10 : 20
                    spacing: 15

                    Text {
                        text: sidebarCollapsed ? "F" : "FLEX"
                        color: plexOrange
                        font.pixelSize: sidebarCollapsed ? 20 : 28
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 30
                    }

                    Button {
                        text: sidebarCollapsed ? "🏠" : "Home"
                        objectName: "homeTabButton"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: currentTab === 0 ? plexOrange : "white"
                            font.pixelSize: 18
                            font.bold: currentTab === 0
                            horizontalAlignment: sidebarCollapsed ? Text.AlignHCenter : Text.AlignLeft
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: currentTab = 0
                    }

                    Repeater {
                        model: allLibrariesModel
                        delegate: Button {
                            // Only show if enabled in settings
                            visible: {
                                var enabledMap = JSON.parse(appSettings.enabledLibraries || "{}");
                                return enabledMap[model.ratingKey] !== undefined && enabledMap[model.ratingKey] !== null && enabledMap[model.ratingKey] !== false;
                            }
                            Layout.preferredHeight: visible ? 40 : 0
                            
                            text: sidebarCollapsed ? getLibraryIcon(model.type) : getLibraryIcon(model.type) + " " + model.title
                            objectName: "libTabButton_" + model.ratingKey
                            Layout.fillWidth: true
                            contentItem: Text {
                                text: parent.text
                                color: (currentTab === 1 || currentTab === 2) && currentLibraryId === model.ratingKey ? plexOrange : "white"
                                font.pixelSize: 18
                                font.bold: (currentTab === 1 || currentTab === 2) && currentLibraryId === model.ratingKey
                                horizontalAlignment: sidebarCollapsed ? Text.AlignHCenter : Text.AlignLeft
                            }
                            background: Rectangle { color: "transparent" }
                            onClicked: {
                                loadLibraryContent(model.ratingKey, model.title, model.type)
                                currentTab = 1 // Switch to library Recommend view
                            }
                        }
                    }

                    Item { Layout.fillHeight: true } // Spacer
                }
            }

        // MAIN CONTENT
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentTab

            // 0: HOME VIEW
            ScrollView {
                id: homeView
                objectName: "homeView"
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: contentStack.width
                    spacing: 20

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 300
                        visible: {
                            var str = appSettings.enabledLibraries;
                            try {
                                return Object.keys(JSON.parse(str || "{}")).length === 0;
                            } catch(e) {
                                return true;
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 15

                            Text {
                                text: "No Plex libraries selected."
                                color: "white"
                                font.pixelSize: 24
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "<u>Click here to select libraries to display in Settings</u>"
                                color: plexOrange
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: openSettings(1)
                                }
                            }
                        }
                    }

                    Text {
                        text: "Continue Watching"
                        color: "white"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 20
                        Layout.leftMargin: 20
                        visible: continueWatchingList.count > 0
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 330
                        Layout.leftMargin: 20
                        visible: continueWatchingList.count > 0

                        ListView {
                            id: continueWatchingList
                            objectName: "continueWatchingList"
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 20
                            model: continueWatchingModel
                            delegate: movieDelegate
                            clip: true
                            interactive: false
                            
                            Behavior on contentX {
                                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                            }
                        }

                        HoverHandler { id: continueHover }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 50
                            color: continueLeftHover.hovered ? "#CC000000" : "#80000000"
                            visible: continueWatchingList.contentX > 0
                            opacity: continueHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: "❮"
                                color: continueLeftHover.hovered ? plexOrange : "white"
                                font.pixelSize: 32
                                font.bold: true
                            }
                            
                            HoverHandler { id: continueLeftHover }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: continueWatchingList.contentX = Math.max(0, continueWatchingList.contentX - 880)
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 50
                            color: continueRightHover.hovered ? "#CC000000" : "#80000000"
                            visible: continueWatchingList.contentWidth > continueWatchingList.width && continueWatchingList.contentX < (continueWatchingList.contentWidth - continueWatchingList.width)
                            opacity: continueHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: "❯"
                                color: continueRightHover.hovered ? plexOrange : "white"
                                font.pixelSize: 32
                                font.bold: true
                            }
                            
                            HoverHandler { id: continueRightHover }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: continueWatchingList.contentX = Math.min(continueWatchingList.contentWidth - continueWatchingList.width, continueWatchingList.contentX + 880)
                            }
                        }
                    }

                    Repeater {
                        model: homeLibrariesList
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            
                            PlexModel {
                                id: delegateRecentModel
                                Component.onCompleted: {
                                    if (isTestMode) {
                                        loadMockData(["/home/geonix/Build/flex_player/tests/dummy1.mkv"], "movie", 0, 0, false)
                                    } else {
                                        var endpoint = (modelData.type === "show") ? "/library/sections/" + modelData.id + "/all?type=2&sort=addedAt:desc" : "/library/sections/" + modelData.id + "/recentlyAdded";
                                        fetchEndpoint(appSettings.serverUrl, appSettings.token, endpoint)
                                    }
                                }
                            }

                            Text {
                                text: "Recently Added in " + modelData.title
                                color: "white"
                                font.pixelSize: 22
                                font.bold: true
                                Layout.leftMargin: 20
                                visible: delegateRecentList.count > 0
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 330
                                Layout.leftMargin: 20
                                visible: delegateRecentList.count > 0

                                ListView {
                                    id: delegateRecentList
                                    objectName: "recentlyAddedList"
                                    anchors.fill: parent
                                    orientation: ListView.Horizontal
                                    spacing: 20
                                    model: delegateRecentModel
                                    delegate: movieDelegate
                                    clip: true
                                    interactive: false
                                    
                                    Behavior on contentX {
                                        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                                    }
                                }

                                HoverHandler { id: delegateRecentHover }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 50
                                    color: delegateRecentLeftHover.hovered ? "#CC000000" : "#80000000"
                                    visible: delegateRecentList.contentX > 0
                                    opacity: delegateRecentHover.hovered ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "❮"
                                        color: delegateRecentLeftHover.hovered ? plexOrange : "white"
                                        font.pixelSize: 32
                                        font.bold: true
                                    }
                                    
                                    HoverHandler { id: delegateRecentLeftHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: delegateRecentList.contentX = Math.max(0, delegateRecentList.contentX - 880)
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 50
                                    color: delegateRecentRightHover.hovered ? "#CC000000" : "#80000000"
                                    visible: delegateRecentList.contentWidth > delegateRecentList.width && delegateRecentList.contentX < (delegateRecentList.contentWidth - delegateRecentList.width)
                                    opacity: delegateRecentHover.hovered ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "❯"
                                        color: delegateRecentRightHover.hovered ? plexOrange : "white"
                                        font.pixelSize: 32
                                        font.bold: true
                                    }
                                    
                                    HoverHandler { id: delegateRecentRightHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: delegateRecentList.contentX = Math.min(delegateRecentList.contentWidth - delegateRecentList.width, delegateRecentList.contentX + 880)
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.preferredHeight: 20 } // Bottom spacer
                }
            }

            // 1: LIBRARY RECOMMEND / COLLECTIONS VIEW
            Item {
                id: libraryView
                objectName: "libraryView"
                
                property int libraryTab: 0 // 0: Recommend, 1: Collections

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Top Bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#1a1a1a"
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            spacing: 30
                            
                            Text {
                                id: libraryTitleText
                                objectName: "libraryTitleText"
                                text: currentLibraryTitle
                                color: "white"
                                font.pixelSize: 24
                                font.bold: true
                                renderType: Text.NativeRendering
                                anchors.baseline: collectionsTab.baseline
                            }

                            Text {
                                id: recommendedTab
                                objectName: "recommendedTab"
                                text: "Recommended"
                                color: libraryView.libraryTab === 0 ? plexOrange : "gray"
                                font.pixelSize: 18
                                font.bold: libraryView.libraryTab === 0
                                renderType: Text.NativeRendering
                                anchors.baseline: collectionsTab.baseline
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: libraryView.libraryTab = 0
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }

                            Text {
                                id: collectionsTab
                                objectName: "collectionsTab"
                                text: "Collections"
                                color: libraryView.libraryTab === 1 ? plexOrange : "gray"
                                font.pixelSize: 18
                                font.bold: libraryView.libraryTab === 1
                                renderType: Text.NativeRendering
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: libraryView.libraryTab = 1
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: libraryView.libraryTab

                        // 0: Recommended
                        ScrollView {
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: contentStack.width
                                spacing: 20

                                Text {
                                    text: "Continue Watching"
                                    color: "white"
                                    font.pixelSize: 22
                                    font.bold: true
                                    Layout.topMargin: 20
                                    Layout.leftMargin: 20
                                    visible: continueWatchingListLib.count > 0
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 330
                                    Layout.leftMargin: 20
                                    visible: continueWatchingListLib.count > 0

                                    ListView {
                                        id: continueWatchingListLib
                                        anchors.fill: parent
                                        orientation: ListView.Horizontal
                                        spacing: 20
                                        model: continueWatchingModel
                                        delegate: movieDelegate
                                        clip: true
                                        interactive: false
                                        Behavior on contentX { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                    }
                                    
                                    HoverHandler { id: cwLibHover }
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                                        color: cwLibLeftHover.hovered ? "#CC000000" : "#80000000"
                                        visible: continueWatchingListLib.contentX > 0
                                        opacity: cwLibHover.hovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Text { anchors.centerIn: parent; text: "❮"; color: cwLibLeftHover.hovered ? plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                                        HoverHandler { id: cwLibLeftHover }
                                        MouseArea { anchors.fill: parent; onClicked: continueWatchingListLib.contentX = Math.max(0, continueWatchingListLib.contentX - 880) }
                                    }
                                    Rectangle {
                                        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                                        color: cwLibRightHover.hovered ? "#CC000000" : "#80000000"
                                        visible: continueWatchingListLib.contentWidth > continueWatchingListLib.width && continueWatchingListLib.contentX < (continueWatchingListLib.contentWidth - continueWatchingListLib.width)
                                        opacity: cwLibHover.hovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Text { anchors.centerIn: parent; text: "❯"; color: cwLibRightHover.hovered ? plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                                        HoverHandler { id: cwLibRightHover }
                                        MouseArea { anchors.fill: parent; onClicked: continueWatchingListLib.contentX = Math.min(continueWatchingListLib.contentWidth - continueWatchingListLib.width, continueWatchingListLib.contentX + 880) }
                                    }
                                }

                                Text {
                                    text: "Recently Added"
                                    color: "white"
                                    font.pixelSize: 22
                                    font.bold: true
                                    Layout.leftMargin: 20
                                    visible: recentlyAddedListLib.count > 0
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 330
                                    Layout.leftMargin: 20
                                    visible: recentlyAddedListLib.count > 0

                                    ListView {
                                        id: recentlyAddedListLib
                                        anchors.fill: parent
                                        orientation: ListView.Horizontal
                                        spacing: 20
                                        model: recentlyAddedModel
                                        delegate: movieDelegate
                                        clip: true
                                        interactive: false
                                        Behavior on contentX { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                    }
                                    
                                    HoverHandler { id: raLibHover }
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                                        color: raLibLeftHover.hovered ? "#CC000000" : "#80000000"
                                        visible: recentlyAddedListLib.contentX > 0
                                        opacity: raLibHover.hovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Text { anchors.centerIn: parent; text: "❮"; color: raLibLeftHover.hovered ? plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                                        HoverHandler { id: raLibLeftHover }
                                        MouseArea { anchors.fill: parent; onClicked: recentlyAddedListLib.contentX = Math.max(0, recentlyAddedListLib.contentX - 880) }
                                    }
                                    Rectangle {
                                        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                                        color: raLibRightHover.hovered ? "#CC000000" : "#80000000"
                                        visible: recentlyAddedListLib.contentWidth > recentlyAddedListLib.width && recentlyAddedListLib.contentX < (recentlyAddedListLib.contentWidth - recentlyAddedListLib.width)
                                        opacity: raLibHover.hovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Text { anchors.centerIn: parent; text: "❯"; color: raLibRightHover.hovered ? plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                                        HoverHandler { id: raLibRightHover }
                                        MouseArea { anchors.fill: parent; onClicked: recentlyAddedListLib.contentX = Math.min(recentlyAddedListLib.contentWidth - recentlyAddedListLib.width, recentlyAddedListLib.contentX + 880) }
                                    }
                                }
                                
                                Item { Layout.preferredHeight: 20 }
                            }
                        }

                        // 1: Collections
                        GridView {
                        id: collectionsGrid
                        objectName: "collectionsGrid"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 20
                        cellWidth: 220
                        cellHeight: 330
                        model: collectionsModel
                        delegate: movieDelegate
                        clip: true
                        
                        ScrollBar.vertical: ScrollBar {
                            active: hovered || collectionsGrid.moving
                            policy: ScrollBar.AsNeeded
                            background: Rectangle {
                                color: "transparent"
                            }
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: parent.active ? "#80ffffff" : "#40ffffff"
                            }
                        }
                    }
                }
            }
            } // END OF libraryView
            
            // 2: COLLECTION MOVIES VIEW
            Item {
                id: collectionMoviesView
                objectName: "collectionMoviesView"
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Top Bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#1a1a1a"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            
                            Button {
                                text: "< Back to Collections"
                                objectName: "backToCollectionsButton"
                                contentItem: Text {
                                    text: parent.text
                                    color: plexOrange
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                background: Rectangle { color: "transparent" }
                                onClicked: currentTab = 1
                            }
                        }
                    }

                    GridView {
                        id: collectionMoviesGrid
                        objectName: "collectionMoviesGrid"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 20
                        cellWidth: 220
                        cellHeight: 330
                        model: collectionMoviesModel
                        delegate: movieDelegate
                        clip: true
                        
                        ScrollBar.vertical: ScrollBar {
                            active: hovered || collectionMoviesGrid.moving
                            policy: ScrollBar.AsNeeded
                            background: Rectangle {
                                color: "transparent"
                            }
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: parent.active ? "#80ffffff" : "#40ffffff"
                            }
                        }
                    }
                }
            }
        }
    }

    // EMBEDDED PLAYER VIEW
    Item {
        id: playerView
        objectName: "playerView"
        anchors.fill: parent
        visible: false

        property bool fullScreenControlsVisible: true

        Timer {
            id: hideControlsTimer
            interval: 5000
            running: mainWindow.isFullScreenMode && playerView.visible && !mpvObject.paused
            onTriggered: {
                playerView.fullScreenControlsVisible = false
            }
        }

        HoverHandler {
            id: playerHover
        }

        MpvObject {
            id: mpvObject
            objectName: "mpvObject"
            anchors.fill: parent
        }

        MouseArea {
            id: playerMouseArea
            objectName: "playerMouseArea"
            anchors.fill: parent
            hoverEnabled: true

            cursorShape: (mainWindow.isFullScreenMode && !playerView.fullScreenControlsVisible && !mpvObject.paused) ? Qt.BlankCursor : Qt.ArrowCursor

            onPositionChanged: {
                playerView.fullScreenControlsVisible = true
                if (mainWindow.isFullScreenMode && !mpvObject.paused) {
                    hideControlsTimer.restart()
                }
            }

            Timer {
                id: singleClickTimer
                interval: 250
                onTriggered: {
                    mpvObject.paused = !mpvObject.paused
                }
            }

            onClicked: {
                playerView.fullScreenControlsVisible = true
                if (mainWindow.isFullScreenMode && !mpvObject.paused) {
                    hideControlsTimer.restart()
                }
                
                if (!singleClickTimer.running) {
                    singleClickTimer.start()
                }
            }
            
            onDoubleClicked: {
                singleClickTimer.stop()
                toggleFullScreen()
            }
        }

        // Top Overlay Controls
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 60
            color: "#B3000000" // 70% opacity black
            visible: mpvObject.paused || (mainWindow.isFullScreenMode ? playerView.fullScreenControlsVisible : playerHover.hovered)

            Button {
                id: backButton
                objectName: "backButton"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 20
                text: "Back"
                font.bold: true
                font.pixelSize: 16
                contentItem: Text {
                    text: backButton.text
                    font: backButton.font
                    color: backButton.down ? plexOrange : "white"
                }
                background: Rectangle {
                    color: "transparent"
                }
                onClicked: {
                    mpvObject.command(["stop"])
                    playerView.visible = false
                    rootLayout.visible = true
                    if (mainWindow.isFullScreenMode) {
                        mainWindow.showNormal()
                    }
                }
            }
        }

        // Bottom Overlay Controls
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 80
            color: "#B3000000" // 70% opacity black
            visible: mpvObject.paused || (mainWindow.isFullScreenMode ? playerView.fullScreenControlsVisible : playerHover.hovered)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // Play / Pause Button
                Button {
                    id: playPauseButton
                    objectName: "playPauseButton"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    padding: 0
                    text: mpvObject.paused ? "▶" : "⏸"
                    font.pixelSize: 24
                    
                    ToolTip.visible: hovered
                    ToolTip.text: mpvObject.paused ? "Play" : "Pause"
                    
                    contentItem: Text {
                        text: playPauseButton.text
                        font: playPauseButton.font
                        color: playPauseButton.hovered ? plexOrange : "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        mpvObject.paused = !mpvObject.paused
                    }
                }

                // Current Time
                Text {
                    text: formatTime(mpvObject.position)
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Progress Bar
                Slider {
                    id: progressBar
                    objectName: "progressBar"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: mpvObject.duration > 0 ? mpvObject.duration : 1
                    value: mpvObject.position

                    // Stop updating player position while user is dragging
                    onMoved: {
                        mpvObject.position = value
                    }

                    background: Rectangle {
                        x: progressBar.leftPadding
                        y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: progressBar.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#444444"

                        Rectangle {
                            width: progressBar.visualPosition * parent.width
                            height: parent.height
                            color: plexOrange
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: progressBar.leftPadding + progressBar.visualPosition * (progressBar.availableWidth - width)
                        y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: progressBar.pressed ? "white" : plexOrange
                    }
                }

                // Total Time
                Text {
                    text: formatTime(mpvObject.duration)
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Full Screen Button
                Button {
                    id: fullScreenButton
                    objectName: "fullScreenButton"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    padding: 0
                    text: mainWindow.isFullScreenMode ? "🗗" : "🖵"
                    font.pixelSize: 24
                    
                    ToolTip.visible: hovered
                    ToolTip.text: mainWindow.isFullScreenMode ? "Exit Full Screen" : "Full Screen"
                    
                    contentItem: Text {
                        text: fullScreenButton.text
                        font: fullScreenButton.font
                        color: fullScreenButton.hovered ? plexOrange : "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        topPadding: 6
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: toggleFullScreen()
                }
            }
        }
    }

    Rectangle {
        id: settingsWindow
        objectName: "settingsWindow"
        anchors.fill: parent
        color: "#1e1e1e" // Full screen background
        visible: false
        z: 999 // Ensure it's on top of everything

        property int connectionState: 0 // 0: Idle, 1: Checking, 2: Success, 3: Failed
        property string connectionError: ""

        Connections {
            target: collectionsModel
            function onConnectionChecked(success, errorMessage) {
                if (success) {
                    settingsWindow.connectionState = 2
                    settingsWindow.connectionError = ""
                } else {
                    settingsWindow.connectionState = 3
                    settingsWindow.connectionError = errorMessage
                }
            }
        }

        // Absorb clicks
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onWheel: {}
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Settings Sidebar
            Rectangle {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                color: "#151515"

                ColumnLayout {
                    id: settingsSidebarColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    Button {
                        id: settingsBackButton
                        text: "←"
                        Layout.alignment: Qt.AlignLeft
                        contentItem: Text {
                            text: settingsBackButton.text
                            color: settingsBackButton.hovered ? "#E5A00D" : "white"
                            font.pixelSize: 28
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: closeSettings()
                    }

                    Text {
                        text: "SETTINGS"
                        color: "#E5A00D" // plexOrange
                        font.pixelSize: 24
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 20
                    }

                    property int settingsTab: 0

                    Button {
                        text: "Login"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: parent.parent.settingsTab === 0 ? "#E5A00D" : "white"
                            font.pixelSize: 18
                            font.bold: parent.parent.settingsTab === 0
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: parent.settingsTab = 0
                    }

                    Button {
                        text: "Libraries"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: parent.parent.settingsTab === 1 ? "#E5A00D" : "white"
                            font.pixelSize: 18
                            font.bold: parent.parent.settingsTab === 1
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: parent.settingsTab = 1
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Main Settings Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                StackLayout {
                    anchors.fill: parent
                    anchors.margins: 40
                    currentIndex: settingsSidebarColumn.settingsTab // Access the sidebar's property

                    // TAB 0: LOGIN
                    ColumnLayout {
                        spacing: 20

                        Text {
                            text: "Login Configuration"
                            color: "white"
                            font.pixelSize: 28
                            font.bold: true
                            Layout.bottomMargin: 20
                        }

                    Text {
                        text: "Server URL"
                        color: "gray"
                        font.pixelSize: 14
                    }
                    TextField {
                        id: serverUrlField
                        objectName: "serverUrlField"
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        placeholderText: "http://192.168.x.x:32400"
                        text: appSettings.serverUrl
                        color: "white"
                        font.pixelSize: 16
                        background: Rectangle { color: "#2e2e2e"; radius: 8 }
                        leftPadding: 15
                        topPadding: 10
                        bottomPadding: 10
                        onTextEdited: settingsWindow.connectionState = 0
                    }

                    Text {
                        text: "API Token"
                        color: "gray"
                        font.pixelSize: 14
                        Layout.topMargin: 10
                    }
                    TextField {
                        id: tokenField
                        objectName: "tokenField"
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        placeholderText: "Plex Token"
                        text: appSettings.token
                        color: "white"
                        font.pixelSize: 16
                        echoMode: TextInput.Password
                        background: Rectangle { color: "#2e2e2e"; radius: 8 }
                        leftPadding: 15
                        topPadding: 10
                        bottomPadding: 10
                        onTextEdited: settingsWindow.connectionState = 0
                    }

                    RowLayout {
                        Layout.topMargin: 20
                        spacing: 15
                        
                        Button {
                            text: "Cancel"
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { 
                                implicitWidth: 120
                                implicitHeight: 40
                                color: "#444444"
                                radius: 8 
                            }
                            onClicked: closeSettings()
                        }
                        
                        Button {
                            text: "Save & Apply"
                            objectName: "saveSettingsButton"
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { 
                                implicitWidth: 160
                                implicitHeight: 40
                                color: "#E5A00D" // plexOrange
                                radius: 8 
                            }
                            onClicked: {
                                appSettings.serverUrl = serverUrlField.text
                                appSettings.token = tokenField.text
                                closeSettings()
                                
                                if (!isTestMode) {
                                    recentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/1/recentlyAdded")
                                    continueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/onDeck")
                                    collectionsModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/1/collections")
                                }
                            }
                        }

                        Button {
                            id: checkConnectionButton
                            objectName: "checkConnectionButton"
                            text: settingsWindow.connectionState === 1 ? "Checking..." : "Check connection"
                            contentItem: Text {
                                text: checkConnectionButton.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { 
                                implicitWidth: 160
                                implicitHeight: 40
                                color: "#444444"
                                radius: 8 
                            }
                            onClicked: {
                                settingsWindow.connectionState = 1
                                settingsWindow.connectionError = ""
                                collectionsModel.checkConnection(serverUrlField.text, tokenField.text, isTestMode)
                            }
                        }

                        Text {
                            objectName: "connectionStatusIcon"
                            text: settingsWindow.connectionState === 2 ? "✓" : (settingsWindow.connectionState === 3 ? "✗" : "")
                            color: settingsWindow.connectionState === 2 ? "#4CAF50" : "#FF5252"
                            font.pixelSize: 24
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                            visible: settingsWindow.connectionState === 2 || settingsWindow.connectionState === 3
                        }
                    }

                    Text {
                        objectName: "connectionErrorLog"
                        text: settingsWindow.connectionError
                        color: "#FF5252"
                        font.pixelSize: 14
                        Layout.topMargin: 10
                        visible: settingsWindow.connectionState === 3
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                        Item { Layout.fillHeight: true }
                    }

                    // TAB 1: LIBRARIES
                    ColumnLayout {
                        spacing: 20

                        Text {
                            text: "Manage Libraries"
                            color: "white"
                            font.pixelSize: 28
                            font.bold: true
                            Layout.bottomMargin: 20
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: allLibrariesModel
                            clip: true
                            delegate: RowLayout {
                                width: ListView.view.width
                                spacing: 15
                                
                                CheckBox {
                                    id: libCheckbox
                                    checked: {
                                        var map = JSON.parse(appSettings.enabledLibraries || "{}");
                                        return map[model.ratingKey] !== undefined && map[model.ratingKey] !== null && map[model.ratingKey] !== false;
                                    }
                                    onToggled: {
                                        mainWindow.setLibraryEnabled(model.ratingKey, checked, model.type, model.title)
                                    }
                                }
                                
                                Text {
                                    text: getLibraryIcon(model.type) + " " + model.title + " (" + model.type + ")"
                                    color: "white"
                                    font.pixelSize: 18
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}}
