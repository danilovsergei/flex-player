import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Item {
    id: root
    objectName: "collectionMoviesView"
    
    property color plexOrange: "#E5A00D"
    property var collectionMoviesModel
    property Component movieDelegate

    signal backToCollections()

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
                        color: root.plexOrange
                        font.pixelSize: 16
                        font.bold: true
                    }
                    background: Rectangle { color: "transparent" }
                    onClicked: root.backToCollections()
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
            model: root.collectionMoviesModel
            delegate: root.movieDelegate
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
