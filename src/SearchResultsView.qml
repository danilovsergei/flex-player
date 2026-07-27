import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    implicitWidth: 1280
    implicitHeight: 720
    id: root
    objectName: "searchResultsView"
    
    property var rootApp
    property Component movieDelegate
    property string currentFilter: "Top results"

    ListModel {
        id: filteredModel
    }

    function updateFilteredModel() {
        filteredModel.clear();
        var sourceModel = rootApp && rootApp.controller ? rootApp.controller.searchResultsModel : null;
        if (!sourceModel) return;
        
        var filterType = "";
        if (currentFilter === "Movies") filterType = "movie";
        else if (currentFilter === "Shows") filterType = "show";
        else if (currentFilter === "Episodes") filterType = "episode";
        else if (currentFilter === "Artists") filterType = "artist";
        else if (currentFilter === "Albums") filterType = "album";
        else if (currentFilter === "Tracks") filterType = "track";
        else if (currentFilter === "People") filterType = "person";
        else if (currentFilter === "Photos") filterType = "photo";

        for (var i = 0; i < sourceModel.count; i++) {
            var item = sourceModel.get(i);
            if (currentFilter === "Top results" || item.type === filterType) {
                filteredModel.append({
                    title: item.title,
                    type: item.type,
                    year: item.year,
                    ratingKey: item.ratingKey,
                    thumbUrl: item.thumbUrl,
                    serverName: item.serverName,
                    serverUrl: item.serverUrl,
                    leafCount: item.leafCount !== undefined ? item.leafCount : 0,
                    viewedLeafCount: item.viewedLeafCount !== undefined ? item.viewedLeafCount : 0,
                    isWatched: item.isWatched !== undefined ? item.isWatched : false
                });
            }
        }
    }

    Connections {
        target: rootApp && rootApp.controller ? rootApp.controller : null
        function onIsSearchingChanged() {
            if (target && !target.isSearching) {
                updateFilteredModel();
            }
        }
    }

    onCurrentFilterChanged: updateFilteredModel()

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1e1e1e"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Button {
                    text: "❮ Back"
                    font.pixelSize: 18
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootApp.plexOrange : "white"
                        font: parent.font
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: rootApp.currentTab = rootApp.previousTab
                }

                Text {
                    text: "Search Results"
                    color: "white"
                    font.pixelSize: 28
                    font.bold: true
                    Layout.fillWidth: true
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            contentWidth: filterRow.width
            clip: true

            RowLayout {
                id: filterRow
                spacing: 10
                
                Repeater {
                    model: ["Top results", "Movies", "Shows", "Episodes", "Artists", "Albums", "Tracks", "People", "Photos"]
                    delegate: Button {
                        text: modelData
                        objectName: "filterBtn_" + modelData.replace(" ", "")
                        background: Rectangle {
                            color: root.currentFilter === modelData ? rootApp.plexOrange : (parent.hovered ? "#444444" : "#2e2e2e")
                            radius: 15
                        }
                        contentItem: Text {
                            text: parent.text
                            color: root.currentFilter === modelData ? "black" : "white"
                            font.bold: root.currentFilter === modelData
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.currentFilter = modelData
                    }
                }
            }
        }

        Text {
            text: rootApp && rootApp.controller && rootApp.controller.isSearching ? "Searching..." : ""
            color: "gray"
            font.pixelSize: 18
            visible: text !== ""
            Layout.leftMargin: 20
        }

        GridView {
            id: searchResultsGrid
            objectName: "searchResultsGrid"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            
            cellWidth: 220
            cellHeight: 330
            
            model: filteredModel
            delegate: movieDelegate
            clip: true
            
            ScrollBar.vertical: ScrollBar {
                active: hovered || searchResultsGrid.moving
                policy: ScrollBar.AsNeeded
                background: Rectangle {
                    implicitWidth: 6
                    color: "transparent"
                }
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: parent.active ? "#80ffffff" : "#40ffffff"
                }
            }
        }
        
        Text {
            text: "No results found."
            color: "gray"
            font.pixelSize: 24
            Layout.alignment: Qt.AlignCenter
            visible: filteredModel.count === 0 && rootApp && rootApp.controller && !rootApp.controller.isSearching
        }
    }
}
