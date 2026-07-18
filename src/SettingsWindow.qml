import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
        id: settingsWindow
        objectName: "settingsWindow"
        anchors.fill: parent
        color: "#1e1e1e" // Full screen background
        visible: false
        z: 999 // Ensure it's on top of everything

        property int connectionState: 0 // 0: Idle, 1: Checking, 2: Success, 3: Failed
        property string connectionError: ""

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
