import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    width: 600
    property real maxPopupHeight: rootApp ? rootApp.height * 0.9 : 800
    property real contentBasedHeight: resultsList.contentHeight + 100
    height: Math.min(maxPopupHeight, Math.max(150, contentBasedHeight))
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var rootApp
    signal resultClicked(string ratingKey, string serverUrl, string type, string title)
    signal moreResultsClicked(string query)

    background: Rectangle {
        color: "#2e2e2e"
        radius: 10
        border.color: "#444444"
        border.width: 1
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Text {
            text: rootApp && rootApp.controller && rootApp.controller.isSearching ? "Searching..." : "Search Results"
            color: "gray"
            font.pixelSize: 14
            font.bold: true
            Layout.fillWidth: true
            Layout.leftMargin: 10
        }

        ListView {
            id: resultsList
            objectName: "searchPopupList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: rootApp && rootApp.controller ? rootApp.controller.searchResultsModel : null
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 80
                color: searchDelegateMouse.containsMouse ? "#444444" : "transparent"
                radius: 5
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 15
                    
                    Rectangle {
                        width: 48
                        height: 70
                        color: "#1e1e1e"
                        radius: 4
                        clip: true
                        
                        Image {
                            anchors.fill: parent
                            source: model.thumbUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: model.title
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        RowLayout {
                            spacing: 10
                            Text {
                                text: model.year > 0 ? model.year : ""
                                color: "gray"
                                font.pixelSize: 14
                            }
                            Rectangle { width: 4; height: 4; radius: 2; color: "gray"; visible: model.year > 0 }
                            Text {
                                text: {
                                    if (model.type === "movie") return "Movie"
                                    if (model.type === "show") return "Show"
                                    return model.type
                                }
                                color: "gray"
                                font.pixelSize: 14
                            }
                            Rectangle { width: 4; height: 4; radius: 2; color: "gray" }
                            Text {
                                text: model.serverName
                                color: "#E5A00D"
                                font.pixelSize: 14
                            }
                        }
                    }
                }
                
                MouseArea {
                    id: searchDelegateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.close()
                        root.resultClicked(model.ratingKey, model.serverUrl, model.type, model.title)
                    }
                }
            }
            
            Text {
                text: "No results found."
                color: "gray"
                font.pixelSize: 16
                anchors.centerIn: parent
                visible: resultsList.count === 0 && rootApp && rootApp.controller && !rootApp.controller.isSearching
            }
        }
        
        Button {
            id: moreBtn
            objectName: "moreResultsBtn"
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: resultsList.count > 0
            background: Rectangle {
                color: moreBtn.hovered ? "#333333" : "transparent"
                radius: 5
            }
            contentItem: Text {
                text: "More results"
                color: "#E5A00D"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                root.close()
                root.moreResultsClicked("")
            }
        }
    }
}
