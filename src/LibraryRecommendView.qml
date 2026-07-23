import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Item {
    implicitWidth: 1280
    implicitHeight: 720
    id: root

        Timer {
            running: true
            repeat: true
            interval: 2000
            onTriggered: {
                if (root.visible && typeof recentlyAddedListLib !== "undefined" && recentlyAddedListLib.contentItem) {
                    console.log("=== VISUAL GEOMETRY CHECK ===");
                    var children = recentlyAddedListLib.contentItem.children;
                    var visibleCount = 0;
                    for (var i = 0; i < children.length; i++) {
                        var child = children[i];
                        if (child.objectName === "movieItem") {
                            console.log("Poster " + i + ": x=" + child.x + ", w=" + child.width + ", h=" + child.height + ", visibleToUser=" + (child.x < recentlyAddedListLib.width));
                            if (child.x < recentlyAddedListLib.width && child.width > 0) {
                                visibleCount++;
                            }
                        }
                    }
                    console.log("TOTAL POSTERS VISUALLY ON SCREEN: " + visibleCount);
                }
            }
        }

    objectName: "libraryView"
    
    property int libraryTab: 0 // 0: Recommend, 1: Collections
    
    property string currentLibraryTitle: ""
    property color plexOrange: "#E5A00D"
    property var continueWatchingModel
    property var recentlyAddedModel
    property var collectionsModel
    property Component movieDelegate

    ColumnLayout {
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
                    text: root.currentLibraryTitle
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
                    color: root.libraryTab === 0 ? root.plexOrange : "gray"
                    font.pixelSize: 18
                    font.bold: root.libraryTab === 0
                    renderType: Text.NativeRendering
                    anchors.baseline: collectionsTab.baseline
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.libraryTab = 0
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Text {
                    id: collectionsTab
                    objectName: "collectionsTab"
                    text: "Collections"
                    color: root.libraryTab === 1 ? root.plexOrange : "gray"
                    font.pixelSize: 18
                    font.bold: root.libraryTab === 1
                    renderType: Text.NativeRendering
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.libraryTab = 1
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.libraryTab

            // 0: Recommended
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: root.width
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: root.width
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

                    Timer {
                        running: true
                        repeat: true
                        interval: 1000
                        onTriggered: {
                            console.log("---- LibraryRecommendView DEBUG ----");
                            console.log("recentlyAddedModel rowCount: " + (root.recentlyAddedModel ? root.recentlyAddedModel.rowCount() : "null"));
                            console.log("raRepeater.count: " + raRepeater.count);
                            console.log("raRow.width: " + raRow.width);
                            console.log("recentlyAddedListLib.contentWidth: " + recentlyAddedListLib.contentWidth);
                            console.log("recentlyAddedListLib.width: " + recentlyAddedListLib.width);
                            console.log("recentlyAddedListLib.visible: " + recentlyAddedListLib.visible);
                            console.log("parent width: " + parent.width);
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 330
                        Layout.leftMargin: 20
                        visible: continueWatchingListLib.count > 0

                        ListView {
                            id: continueWatchingListLib
                            objectName: "continueWatchingListLib"
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 20
                            model: root.continueWatchingModel
                            delegate: root.movieDelegate
                            clip: true
                            interactive: false
                            Behavior on contentX { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                            
                            // The ultimate StackLayout geometry bug fix:
                            onWidthChanged: {
                                if (width > 0 && model) {
                                    var m = model;
                                    model = null;
                                    model = m;
                                }
                            }
                        }
                        
                        HoverHandler { id: cwLibHover }
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                            color: cwLibLeftHover.hovered ? "#CC000000" : "#80000000"
                            visible: continueWatchingListLib.contentX > 0
                            opacity: cwLibHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: "❮"; color: cwLibLeftHover.hovered ? root.plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                            HoverHandler { id: cwLibLeftHover }
                            MouseArea { anchors.fill: parent; onClicked: continueWatchingListLib.contentX = Math.max(0, continueWatchingListLib.contentX - 880) }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                            color: cwLibRightHover.hovered ? "#CC000000" : "#80000000"
                            visible: continueWatchingListLib.contentWidth > continueWatchingListLib.width && continueWatchingListLib.contentX < (continueWatchingListLib.contentWidth - continueWatchingListLib.width)
                            opacity: cwLibHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: "❯"; color: cwLibRightHover.hovered ? root.plexOrange : "white"; font.pixelSize: 32; font.bold: true }
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
                            objectName: "recentlyAddedListLib"
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 20
                            model: root.recentlyAddedModel
                            delegate: root.movieDelegate
                            clip: true
                            interactive: false
                            Behavior on contentX { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                            
                            // The ultimate StackLayout geometry bug fix:
                            onWidthChanged: {
                                if (width > 0 && model) {
                                    var m = model;
                                    model = null;
                                    model = m;
                                }
                            }
                        }
                        
                        HoverHandler { id: raLibHover }
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                            color: raLibLeftHover.hovered ? "#CC000000" : "#80000000"
                            visible: recentlyAddedListLib.contentX > 0
                            opacity: raLibHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: "❮"; color: raLibLeftHover.hovered ? root.plexOrange : "white"; font.pixelSize: 32; font.bold: true }
                            HoverHandler { id: raLibLeftHover }
                            MouseArea { anchors.fill: parent; onClicked: recentlyAddedListLib.contentX = Math.max(0, recentlyAddedListLib.contentX - 880) }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                            color: raLibRightHover.hovered ? "#CC000000" : "#80000000"
                            visible: recentlyAddedListLib.contentWidth > recentlyAddedListLib.width && recentlyAddedListLib.contentX < (recentlyAddedListLib.contentWidth - recentlyAddedListLib.width)
                            opacity: raLibHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: "❯"; color: raLibRightHover.hovered ? root.plexOrange : "white"; font.pixelSize: 32; font.bold: true }
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
                model: root.collectionsModel
                delegate: root.movieDelegate
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
}
