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
        Text {
            text: "Continue Watching"
            color: "white"
            font.pixelSize: 24
            font.bold: true
            Layout.topMargin: 20
            Layout.leftMargin: 20
            visible: continueWatchingList.count > 0 && !emptyStateView.visible
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 330
            Layout.leftMargin: 20
            visible: continueWatchingList.count > 0 && !emptyStateView.visible

            ListView {
                id: continueWatchingList
                objectName: "continueWatchingList"
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: 20
                model: root.continueWatchingModel
                delegate: root.movieDelegate
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
                Text { anchors.centerIn: parent; text: "❮"; color: continueLeftHover.hovered ? root.plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                HoverHandler { id: continueLeftHover }
                MouseArea { anchors.fill: parent; onClicked: continueWatchingList.contentX = Math.max(0, continueWatchingList.contentX - 880) }
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
                Text { anchors.centerIn: parent; text: "❯"; color: continueRightHover.hovered ? root.plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                HoverHandler { id: continueRightHover }
                MouseArea { anchors.fill: parent; onClicked: continueWatchingList.contentX = Math.min(continueWatchingList.contentWidth - continueWatchingList.width, continueWatchingList.contentX + 880) }
            }
        }

        

        // Individual Library Rails
        Repeater {
            id: libraryRepeater
            objectName: "libraryRepeater"
            model: root.homeLibrariesList
            delegate: LibraryRail {
                libraryTitle: modelData.title
                libraryId: modelData.id
                libraryType: modelData.type
                rootApp: root.rootApp
                movieDelegate: root.movieDelegate
                Layout.fillWidth: true
                Layout.preferredHeight: 400
                visible: !emptyStateView.visible
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
