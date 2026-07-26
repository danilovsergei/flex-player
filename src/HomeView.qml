import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

ScrollView {
    implicitWidth: 1280
    implicitHeight: 720
    id: root
    objectName: "homeView"
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    property var rootApp
    property var continueWatchingModel
    property var recentlyAddedModel
    property var homeLibrariesList
    property string enabledLibraries: "{}"
    property Component movieDelegate
    property color plexOrange: "#E5A00D"

    signal openSettingsRequested()

    ColumnLayout {
        objectName: "homeContentColumn"
        width: root.width
        spacing: 20

        Item {
            id: emptyStateView
            objectName: "emptyStateView"
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            visible: {
                var libs = [];
                try {
                    libs = JSON.parse(root.enabledLibraries);
                } catch(e) {}
                return Object.keys(libs).length === 0;
            }

            Column {
                anchors.centerIn: parent
                spacing: 20
                Text {
                    text: "Welcome to Flex Player"
                    color: "white"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Please enable some libraries in settings to get started."
                    color: "gray"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Button {
                    text: "Open Settings"
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: root.openSettingsRequested()
                }
            }
        }

        // Continue Watching Section
        Repeater {
            id: continueWatchingRepeater
            objectName: "continueWatchingRepeater"
            model: rootApp && rootApp.controller ? rootApp.controller.activeServersList : []
            delegate: ContinueWatchingRail {
                serverName: modelData.serverName
                serverUrl: modelData.serverUrl
                rootApp: root.rootApp
                movieDelegate: root.movieDelegate
                Layout.fillWidth: true
                Layout.preferredHeight: hasItems ? 400 : 0
                visible: !emptyStateView.visible && hasItems
            }
        }

        // Individual Library Rails
        Repeater {
            id: libraryRepeater
            objectName: "libraryRepeater"
            model: root.homeLibrariesList
            delegate: LibraryRail {
                libraryTitle: modelData.title + (modelData.serverName ? " (" + modelData.serverName + ")" : "")
                libraryId: modelData.id
                libraryType: modelData.type
                serverUrl: (typeof modelData.serverUrl !== 'undefined' && modelData.serverUrl !== null) ? modelData.serverUrl : ""
                rootApp: root.rootApp
                movieDelegate: root.movieDelegate
                Layout.fillWidth: true
                Layout.preferredHeight: hasItems ? 400 : 0
                visible: !emptyStateView.visible && hasItems
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
