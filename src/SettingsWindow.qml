import flex.plex 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsWindow
    objectName: "settingsWindow"
    anchors.fill: parent
    color: "#1e1e1e"
    visible: false
    z: 999

    property int connectionState: 0
    property string connectionError: ""
    property var allLibrariesModel: null
    property var collectionsModel: null

    function openTab(tabIndex, serverUrl, token) {
        if (tabIndex !== undefined) {
            settingsSidebarColumn.settingsTab = tabIndex
        } else {
            settingsSidebarColumn.settingsTab = 0
        }
        serverUrlField.text = serverUrl
        tokenField.text = token
        connectionState = 0
        connectionError = ""
        visible = true
    }

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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: {}
    }
        PlexAuth {
            id: plexAuth
            onTokenReceived: function(token) {
                tokenField.text = token
            }
            onAuthError: function(errorMsg) {
                console.error("Plex Auth Error: " + errorMsg)
                settingsWindow.connectionState = -1 // Error
            }
            onPinCodeChanged: {
                if (plexAuth.pinCode !== "") {
                    var authUrl = "https://app.plex.tv/auth#?clientID=" + plexAuth.clientId + "&code=" + plexAuth.pinCode + "&context[device][product]=Flex%20Player"
                    Qt.openUrlExternally(authUrl)
                }
            }
        }

        Rectangle {
            id: pinOverlay
            objectName: "pinOverlay"
            anchors.fill: parent
            color: "#E6000000" // 90% black
            z: 100
            visible: plexAuth.isPolling
            
            // Block mouse clicks from reaching the settings below
            MouseArea { anchors.fill: parent }

            Column {
                anchors.centerIn: parent
                spacing: 30

                Text {
                    text: "Authenticating..."
                    color: "white"
                    font.pixelSize: 36
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "A secure browser window has opened.<br>Please sign in to Plex to continue."
                    color: "gray"
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.RichText
                }
                
                Button {
                    text: "Cancel"
                    anchors.horizontalCenter: parent.horizontalCenter
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { 
                        implicitWidth: 160
                        implicitHeight: 45
                        color: "#444444"
                        radius: 8 
                    }
                    onClicked: plexAuth.cancelLogin()
                }
            }
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
                    objectName: "settingsSidebarColumn"
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

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 20
                        spacing: 10
                        
                        Image {
                            source: "../assets/flex_icon.svg"
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            text: "SETTINGS"
                            color: "#E5A00D" // plexOrange
                            font.pixelSize: 24
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    property int settingsTab: 0

                    Button {
                        text: "Login Configuration"
                        objectName: "settingsTabLogin"
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
                        text: "Manage Libraries"
                        objectName: "settingsTabLibraries"
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
                    
                    Button {
                        text: "Hotkeys"
                        objectName: "settingsTabHotkeys"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: parent.parent.settingsTab === 2 ? "#E5A00D" : "white"
                            font.pixelSize: 18
                            font.bold: parent.parent.settingsTab === 2
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: parent.settingsTab = 2
                    }

                                        Button {
                        text: "Playback"
                        objectName: "settingsTabPlayback"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: parent.parent.settingsTab === 3 ? "#E5A00D" : "white"
                            font.pixelSize: 18
                            font.bold: parent.parent.settingsTab === 3
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: parent.settingsTab = 3
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
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        spacing: 10
                        
                        TextField {
                            id: tokenField
                            objectName: "tokenField"
                            Layout.fillWidth: true
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
                        
                        Button {
                            text: "Login with Plex"
                            objectName: "plexLoginButton"
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
                                color: "#2e2e2e"
                                radius: 8
                                border.color: "#E5A00D"
                                border.width: 1
                            }
                            onClicked: plexAuth.requestPin()
                        }
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
                            id: saveSettingsButton
                            text: "Save & Apply"
                            objectName: "saveSettingsButton"
                            enabled: settingsWindow.connectionState === 2
                            contentItem: Text {
                                text: saveSettingsButton.text
                                color: saveSettingsButton.enabled ? "white" : "#888888"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { 
                                implicitWidth: 160
                                implicitHeight: 40
                                color: saveSettingsButton.enabled ? "#E5A00D" : "#222222"
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
                            enabled: serverUrlField.text.trim() !== "" && tokenField.text.trim() !== ""
                            text: settingsWindow.connectionState === 1 ? "Checking..." : "Check connection"
                            contentItem: Text {
                                text: checkConnectionButton.text
                                color: checkConnectionButton.enabled ? "white" : "#888888"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { 
                                implicitWidth: 160
                                implicitHeight: 40
                                color: checkConnectionButton.enabled ? "#444444" : "#222222"
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
                        objectName: "requiredFieldsWarning"
                        text: (serverUrlField.text.trim() === "" || tokenField.text.trim() === "") ? "Server URL and API Token are required for Plex to operate." : "Please check connection successfully before saving."
                        color: "#E5A00D"
                        font.pixelSize: 14
                        Layout.topMargin: 10
                        visible: !saveSettingsButton.enabled
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
                        id: librariesTabCol
                        spacing: 20
                        
                        property var localLibrariesMap: {
                            try { return JSON.parse(appSettings.enabledLibraries || "{}"); } catch(e) { return {}; }
                        }
                        
                        onVisibleChanged: {
                            if (visible) {
                                try { localLibrariesMap = JSON.parse(appSettings.enabledLibraries || "{}"); } catch(e) { localLibrariesMap = {}; }
                            }
                        }

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
                                    checked: librariesTabCol.localLibrariesMap[model.ratingKey] !== undefined && librariesTabCol.localLibrariesMap[model.ratingKey] !== null && librariesTabCol.localLibrariesMap[model.ratingKey] !== false
                                    onClicked: {
                                        var map = librariesTabCol.localLibrariesMap;
                                        if (checked) {
                                            map[model.ratingKey] = { "type": model.type, "title": model.title };
                                        } else {
                                            delete map[model.ratingKey];
                                        }
                                        librariesTabCol.localLibrariesMap = map;
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
                        
                        RowLayout {
                            Layout.topMargin: 20
                            spacing: 15
                            
                            Button {
                                text: "Cancel"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 120; implicitHeight: 40; color: "#444444"; radius: 8 }
                                onClicked: closeSettings()
                            }
                            
                            Button {
                                id: saveLibrariesButton
                                objectName: "saveLibrariesButton"
                                text: "Save & Apply"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 160; implicitHeight: 40; color: "#E5A00D"; radius: 8 }
                                onClicked: {
                                    appSettings.enabledLibraries = JSON.stringify(librariesTabCol.localLibrariesMap);
                                    closeSettings();
                                    if (!isTestMode) mainWindow.startupLogic();
                                }
                            }
                        }
                    } // END TAB 1
                    
                    // TAB 2: HOTKEYS
                    ColumnLayout {
                        spacing: 20
                        
                        Text {
                            text: "Hotkeys"
                            color: "white"
                            font.pixelSize: 28
                            font.bold: true
                            Layout.bottomMargin: 20
                        }
                        
                        // Header Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 800
                            spacing: 20
                            
                            Text { text: "Action Name"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 200 }
                            Text { text: "Description"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Assigned Hotkey"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 150 }
                            Text { text: "Assign"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 100 }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 800
                            height: 1
                            color: "#444444"
                        }
                        
                        // Row 1: Toggle Full Screen
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 800
                            spacing: 20
                            
                            Text { text: "Toggle Full Screen"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                            Text { text: "Enter/Exit full screen video playback"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                            Text { 
                                id: fsHotkeyText
                                objectName: "fsHotkeyText"
                                text: appSettings.fullscreenHotkey 
                                color: "#E5A00D"
                                font.pixelSize: 18
                                font.bold: true
                                Layout.preferredWidth: 150 
                            }
                            
                            Button {
                                text: "Set"
                                objectName: "setFsHotkeyBtn"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                                onClicked: {
                                    hotkeyOverlay.actionToBind = "fullscreen"
                                    hotkeyOverlay.visible = true
                                    hotkeyOverlay.forceActiveFocus()
                                }
                            }
                        }
                        
                        // Row 2: Toggle Play/Pause
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 800
                            spacing: 20
                            
                            Text { text: "Toggle Play/Pause"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                            Text { text: "Play or pause the active video"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                            Text { 
                                id: ppHotkeyText
                                objectName: "ppHotkeyText"
                                text: appSettings.playPauseHotkey 
                                color: "#E5A00D"
                                font.pixelSize: 18
                                font.bold: true
                                Layout.preferredWidth: 150 
                            }
                            
                            Button {
                                text: "Set"
                                objectName: "setPpHotkeyBtn"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                                onClicked: {
                                    hotkeyOverlay.actionToBind = "playpause"
                                    hotkeyOverlay.visible = true
                                    hotkeyOverlay.forceActiveFocus()
                                }
                            }
                        }
                        
                        // Row 3: Increase Volume
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 800
                            spacing: 20
                            
                            Text { text: "Increase Volume"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                            Text { text: "Increase the video playback volume"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                            Text { 
                                id: volUpHotkeyText
                                objectName: "volUpHotkeyText"
                                text: appSettings.volumeUpHotkey 
                                color: "#E5A00D"
                                font.pixelSize: 18
                                font.bold: true
                                Layout.preferredWidth: 150 
                            }
                            
                            Button {
                                text: "Set"
                                objectName: "setVolUpHotkeyBtn"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                                onClicked: {
                                    hotkeyOverlay.actionToBind = "volup"
                                    hotkeyOverlay.visible = true
                                    hotkeyOverlay.forceActiveFocus()
                                }
                            }
                        }
                        
                        // Row 4: Decrease Volume
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 800
                            spacing: 20
                            
                            Text { text: "Decrease Volume"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                            Text { text: "Decrease the video playback volume"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                            Text { 
                                id: volDownHotkeyText
                                objectName: "volDownHotkeyText"
                                text: appSettings.volumeDownHotkey 
                                color: "#E5A00D"
                                font.pixelSize: 18
                                font.bold: true
                                Layout.preferredWidth: 150 
                            }
                            
                            Button {
                                text: "Set"
                                objectName: "setVolDownHotkeyBtn"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                                onClicked: {
                                    hotkeyOverlay.actionToBind = "voldown"
                                    hotkeyOverlay.visible = true
                                    hotkeyOverlay.forceActiveFocus()
                                }
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    } // END TAB 2: HOTKEYS
                    // TAB 3: PLAYBACK
                    ColumnLayout {
                        spacing: 20

                        Text {
                            text: "Playback Configuration"
                            color: "white"
                            font.pixelSize: 28
                            font.bold: true
                            Layout.bottomMargin: 20
                        }

                        RowLayout {
                            spacing: 10
                            CheckBox {
                                id: hdrEnableCheckbox
                                objectName: "hdrEnableCheckbox"
                                text: "Automatically Toggle system HDR on HDR movie playback"
                                checked: appSettings.autoToggleHdr || false
                                enabled: !collectionsModel.isFlatpak || collectionsModel.hasFlatpakSpawnPermission
                                onCheckedChanged: {
                                    appSettings.autoToggleHdr = checked
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: hdrEnableCheckbox.enabled ? "white" : "gray"
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: parent.indicator.width + parent.spacing
                                }
                            }
                        }

                        ColumnLayout {
                            visible: collectionsModel.isFlatpak && !collectionsModel.hasFlatpakSpawnPermission
                            spacing: 5
                            Layout.fillWidth: true
                            
                            Text {
                                text: "Flatpak permission required to enable automatic HDR. Run this command and **restart the application**:"
                                color: "#FF5252"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            
                            TextField {
                                text: "flatpak override --user --talk-name=org.freedesktop.Flatpak io.github.danilovsergei.flex-player"
                                readOnly: true
                                selectByMouse: true
                                Layout.fillWidth: true
                                font.family: "Monospace"
                                font.pixelSize: 12
                                background: Rectangle {
                                    color: "#000000"
                                    radius: 4
                                    border.color: "#FF5252"
                                    border.width: 1
                                }
                                color: "#00FF00"
                                topPadding: 8
                                bottomPadding: 8
                                leftPadding: 10
                            }

                            }
                        Text {
                            text: "HDR Enable Command"
                            color: "gray"
                            font.pixelSize: 14
                            Layout.topMargin: 10
                        }
                        RowLayout {
                            spacing: 10
                            TextField {
                                id: hdrEnableCommand
                                objectName: "hdrEnableCommand"
                                text: appSettings.hdrEnableCommand || "kscreen-doctor output.DP-1.hdr.enable"
                                color: "white"
                                font.pixelSize: 16
                                Layout.preferredWidth: 400
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 5
                                }
                                onTextChanged: {
                                    appSettings.hdrEnableCommand = text
                                }
                            }
                            Button {
                                objectName: "testHdrEnableButton"
                                text: "Test"
                                onClicked: mainWindow.runHdrCommand(hdrEnableCommand.text)
                            }
                        }

                        Text {
                            text: "HDR Disable Command"
                            color: "gray"
                            font.pixelSize: 14
                            Layout.topMargin: 10
                        }
                        RowLayout {
                            spacing: 10
                            TextField {
                                id: hdrDisableCommand
                                objectName: "hdrDisableCommand"
                                text: appSettings.hdrDisableCommand || "kscreen-doctor output.DP-1.hdr.disable"
                                color: "white"
                                font.pixelSize: 16
                                Layout.preferredWidth: 400
                                background: Rectangle {
                                    color: "#333333"
                                    radius: 5
                                }
                                onTextChanged: {
                                    appSettings.hdrDisableCommand = text
                                }
                            }
                            Button {
                                objectName: "testHdrDisableButton"
                                text: "Test"
                                onClicked: mainWindow.runHdrCommand(hdrDisableCommand.text)
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }

                }
            }
        }
        
        // Hotkey Capture Overlay
        Rectangle {
            id: hotkeyOverlay
            objectName: "hotkeyOverlay"
            anchors.fill: parent
            color: "#E6000000"
            visible: false
            z: 200
            
            property string actionToBind: ""
            
            // It needs focus to capture keys
            focus: visible
            
            function bindKey(newKey) {
                if (!newKey || newKey === "") return;
                if (actionToBind === "fullscreen") {
                    appSettings.fullscreenHotkey = newKey;
                } else if (actionToBind === "playpause") {
                    appSettings.playPauseHotkey = newKey;
                } else if (actionToBind === "volup") {
                    appSettings.volumeUpHotkey = newKey;
                } else if (actionToBind === "voldown") {
                    appSettings.volumeDownHotkey = newKey;
                }
                visible = false;
            }

            Keys.onPressed: function(event) {
                // Ignore modifier keys alone
                if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                    return;
                }
                
                if (event.key === Qt.Key_Escape) {
                    hotkeyOverlay.visible = false;
                    event.accepted = true;
                    return;
                }
                
                var keyStr = "";
                if (event.modifiers & Qt.ControlModifier) keyStr += "Ctrl+";
                if (event.modifiers & Qt.AltModifier) keyStr += "Alt+";
                if (event.modifiers & Qt.ShiftModifier) keyStr += "Shift+";
                if (event.modifiers & Qt.MetaModifier) keyStr += "Meta+";
                
                var baseKey = "";
                if (event.key === Qt.Key_Space) baseKey = "Space";
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) baseKey = "Return";
                else if (event.key === Qt.Key_Tab) baseKey = "Tab";
                else if (event.key === Qt.Key_Backspace) baseKey = "Backspace";
                else if (event.key === Qt.Key_Delete) baseKey = "Delete";
                else if (event.key === Qt.Key_Up) baseKey = "Up";
                else if (event.key === Qt.Key_Down) baseKey = "Down";
                else if (event.key === Qt.Key_Left) baseKey = "Left";
                else if (event.key === Qt.Key_Right) baseKey = "Right";
                else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) {
                    baseKey = "F" + (event.key - Qt.Key_F1 + 1);
                } else if (event.key >= 0x20 && event.key <= 0x0ff) {
                    baseKey = String.fromCharCode(event.key).toUpperCase();
                } else if (event.text !== "") {
                    baseKey = event.text.toUpperCase();
                }
                
                if (baseKey === "") return;
                
                bindKey(keyStr + baseKey);
                event.accepted = true;
            }
            
            MouseArea { anchors.fill: parent } // Block clicks
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "Listening for key press..."
                    color: "white"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "Press any key to assign it to this action.\nPress ESC to cancel."
                    color: "gray"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Button {
                    text: "Cancel"
                    objectName: "cancelHotkeyBtn"
                    anchors.horizontalCenter: parent.horizontalCenter
                    contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { implicitWidth: 120; implicitHeight: 40; color: "#444444"; radius: 6 }
                    onClicked: {
                        hotkeyOverlay.visible = false
                    }
                }
            }
        }
    }
