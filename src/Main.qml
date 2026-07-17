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

    function openSettings() {
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
            if (!isTestMode) {
                recentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/1/recentlyAdded")
                continueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/onDeck")
                collectionsModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/1/collections")
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
                    height: 40
                    color: "#cc000000"

                    Text {
                        anchors.fill: parent
                        anchors.margins: 5
                        text: title
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
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
                        mainLayout.visible = false
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
        visible: !playerView.visible

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

                    Button {
                        text: sidebarCollapsed ? "🎬" : "Movies"
                        objectName: "moviesTabButton"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: currentTab === 1 || currentTab === 2 ? plexOrange : "white"
                            font.pixelSize: 18
                            font.bold: currentTab === 1 || currentTab === 2
                            horizontalAlignment: sidebarCollapsed ? Text.AlignHCenter : Text.AlignLeft
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: currentTab = 1
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

                    Text {
                        text: "Continue Watching"
                        color: "white"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 20
                        Layout.leftMargin: 20
                        visible: continueWatchingList.count > 0
                    }

                    ListView {
                        id: continueWatchingList
                        objectName: "continueWatchingList"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 330
                        Layout.leftMargin: 20
                        orientation: ListView.Horizontal
                        spacing: 20
                        model: continueWatchingModel
                        delegate: movieDelegate
                        visible: continueWatchingList.count > 0
                    }

                    Text {
                        text: "Recently Added Movies"
                        color: "white"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.leftMargin: 20
                        visible: recentlyAddedList.count > 0
                    }

                    ListView {
                        id: recentlyAddedList
                        objectName: "recentlyAddedList"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 330
                        Layout.leftMargin: 20
                        orientation: ListView.Horizontal
                        spacing: 20
                        model: recentlyAddedModel
                        delegate: movieDelegate
                        visible: recentlyAddedList.count > 0
                    }
                    
                    Item { Layout.preferredHeight: 20 } // Bottom spacer
                }
            }

            // 1: MOVIES VIEW (Collections)
            Item {
                id: moviesView
                objectName: "moviesView"
                
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
                            
                            Text {
                                text: "Collections"
                                color: "white"
                                font.pixelSize: 20
                                font.bold: true
                            }
                        }
                    }

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
                    }
                }
            }
            
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
                    mainLayout.visible = true
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
                        onClicked: settingsWindow.visible = false
                    }

                    Text {
                        text: "SETTINGS"
                        color: "#E5A00D" // plexOrange
                        font.pixelSize: 24
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 20
                    }

                    Button {
                        text: "Login"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: "#E5A00D" // plexOrange
                            font.pixelSize: 18
                            font.bold: true
                        }
                        background: Rectangle { color: "transparent" }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Main Settings Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 40
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
                            onClicked: settingsWindow.visible = false
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
                                settingsWindow.visible = false
                                
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
            }
        }
    }
}