import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "topToolbar"
    Layout.fillWidth: true
    Layout.preferredHeight: 60
    color: "#1e1e1e"
    z: 2
    
    property var rootApp
    property color plexOrange: "#E5A00D"

    signal settingsRequested()
    signal sidebarToggleRequested()

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
                color: parent.hovered ? root.plexOrange : "white"
                font: parent.font
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: root.sidebarToggleRequested()
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
            
            Timer {
                id: searchDebounce
                objectName: "searchDebounce"
                interval: 300
                repeat: false
                onTriggered: {
                    if (rootApp && rootApp.controller) {
                        rootApp.controller.performSearch(searchField.text);
                        if (searchField.text.trim() !== "") {
                            searchPopup.open();
                        } else {
                            searchPopup.close();
                        }
                    }
                }
            }
            
            onTextEdited: {
                searchDebounce.restart();
            }
            
            SearchPopup {
                id: searchPopup
                objectName: "searchPopup"
                y: searchField.height + 5
                rootApp: root.rootApp
                onResultClicked: function(ratingKey, serverUrl, type, title) {
                    if (type === "collection") {
                        rootApp.openCollection(ratingKey, serverUrl);
                    } else if (type === "show" || type === "season") {
                        rootApp.openShow(ratingKey, serverUrl);
                    } else if (type === "artist") {
                        rootApp.openArtist(ratingKey, serverUrl);
                    } else if (type === "album") {
                        rootApp.openAlbum(ratingKey, serverUrl);
                    } else {
                        rootApp.openDetails(ratingKey, serverUrl);
                    }
                }
                onMoreResultsClicked: function(query) {
                    rootApp.openSearchResults();
                }
            }
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
                color: parent.hovered ? root.plexOrange : "white"
                font: parent.font
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: root.settingsRequested()
        }
    }
}
