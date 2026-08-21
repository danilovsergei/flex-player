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

        RowLayout {
            spacing: 16

            Button {
                id: refreshButton
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                objectName: "refreshButton"
                padding: 0
                background: Rectangle { color: "transparent" }
                contentItem: Image {
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='22' height='22' viewBox='0 0 24 24' fill='none' stroke='" + (refreshButton.hovered ? "%23E5A00D" : "white") + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8'></path><path d='M3 3v5h5'></path></svg>"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 22
                    sourceSize.height: 22
                    verticalAlignment: Image.AlignVCenter
                    horizontalAlignment: Image.AlignHCenter
                }
                onClicked: {
                    if (rootApp && typeof rootApp.refreshPage === "function") {
                        rootApp.refreshPage();
                    }
                }
            }

            Button {
                id: settingsButton
                objectName: "settingsButton"
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                padding: 0
                background: Rectangle { color: "transparent" }
                contentItem: Image {
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='22' height='22' viewBox='0 0 24 24' fill='none' stroke='" + (settingsButton.hovered ? "%23E5A00D" : "white") + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z'></path><circle cx='12' cy='12' r='3'></circle></svg>"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 22
                    sourceSize.height: 22
                    verticalAlignment: Image.AlignVCenter
                    horizontalAlignment: Image.AlignHCenter
                }
                onClicked: root.settingsRequested()
            }
        }
    }
}
