import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    objectName: "seasonDetailsView"
    anchors.fill: parent

    property var rootApp: null
    property string rawJson: "{}"
    property var detailsData: null
    property var episodesData: null
    property var epToPlay: null
    property var seriesData: null

    signal backRequested()
    signal playMediaRequested(string title, string mediaUrl, int viewOffset, string ratingKey, int duration, string audioId, string subId, var streams)

    onRawJsonChanged: {
        if (rawJson !== "{}" && rawJson !== "undefined" && rawJson !== "") {
            try {
                var parsed = JSON.parse(rawJson)
                if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                    detailsData = parsed.MediaContainer.Metadata[0]
                    fetchEpisodes()
                } else {
                    detailsData = null
                }
            } catch(e) {
                detailsData = null
            }
        }
    }

    onVisibleChanged: {
        if (visible) rawJsonChanged()
    }

    function fetchEpisodes() {
        if (!detailsData || !rootApp) return;
        var req = new XMLHttpRequest();
        var url = rootApp.serverUrl + "/library/metadata/" + detailsData.ratingKey + "/children?X-Plex-Token=" + rootApp.token;
        req.open("GET", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                try {
                    var data = JSON.parse(req.responseText);
                    if (data && data.MediaContainer && data.MediaContainer.Metadata && data.MediaContainer.Metadata.length > 0) {
                        var eps = data.MediaContainer.Metadata;
                        episodesData = eps;
                        var targetEp = eps[0];
                        for (var i = 0; i < eps.length; i++) {
                            if (!eps[i].viewCount || eps[i].viewCount === 0 || eps[i].viewOffset > 0) {
                                targetEp = eps[i];
                                break;
                            }
                        }
                        epToPlay = targetEp;
                    }
                } catch(e) {}
            }
        }
        req.send();
    }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 30


        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Button {
                id: backBtn
                objectName: "seasonDetailsBackButton"
                text: "←"
                font.pixelSize: 24
                contentItem: Text {
                    text: backBtn.text
                    font: backBtn.font
                    color: backBtn.hovered ? "#E5A00D" : "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { color: "transparent" }
                onClicked: root.backRequested()
            }

            Text {
                id: titleText
                objectName: "seasonDetailsTitle"
                text: detailsData ? detailsData.parentTitle + " - " + detailsData.title : ""
                color: "white"
                font.pixelSize: 42
                font.bold: true
                Layout.fillWidth: true
            }
        }


        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 40


            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 300
                spacing: 15

                Image {
                    id: posterImage
                    objectName: "seasonDetailsPoster"
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 450
                    source: detailsData && detailsData.thumb ? (rootApp ? rootApp.serverUrl + detailsData.thumb + "?X-Plex-Token=" + rootApp.token : "") : ""
                    fillMode: Image.PreserveAspectCrop
                }
                
                Text {
                    objectName: "seasonOnDeckLabel"
                    text: root.epToPlay ? "On Deck - E" + root.epToPlay.index : ""
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.epToPlay !== null
                }
            }


            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: 20

                RowLayout {
                    spacing: 20
                    Text { text: detailsData && detailsData.year ? detailsData.year : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                    Text { text: detailsData && detailsData.leafCount ? detailsData.leafCount + " Episodes" : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                }

                Text {
                    text: detailsData && detailsData.summary ? detailsData.summary : ""
                    color: "white"
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: 800
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    spacing: 15

                    Button {
                        id: playBtn
                        objectName: "seasonDetailsPlayButton"
                        text: root.epToPlay && root.epToPlay.viewOffset > 0 ? "Resume" : "Play"
                        contentItem: Text { text: playBtn.text; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { implicitWidth: 120; implicitHeight: 40; color: "#E5A00D"; radius: 8 }
                        onClicked: {
                            if (root.epToPlay && root.epToPlay.Media && root.epToPlay.Media.length > 0) {
                                var part = root.epToPlay.Media[0].Part[0];
                                var mediaUrl = rootApp ? rootApp.serverUrl + part.key + "?X-Plex-Token=" + rootApp.token : "";
                                var streams = part.Stream || [];
                                root.playMediaRequested(root.epToPlay.title, mediaUrl, root.epToPlay.viewOffset || 0, root.epToPlay.ratingKey, root.epToPlay.duration || 0, "auto", "no", streams);
                            }
                        }
                    }
                }
            }
        }
        
        // Episodes List
        Text {
            text: "Episodes"
            color: "white"
            font.pixelSize: 22
            font.bold: true
            Layout.topMargin: 20
        }
        
        GridView {
            id: episodesGrid
            objectName: "seasonEpisodesGrid"
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 320
            cellHeight: 220
            
            model: episodesData ? episodesData : []
            
            delegate: Item {
                width: 300
                height: 200
                
                Rectangle {
                    anchors.fill: parent
                    color: "#2e2e2e"
                    radius: 8
                    clip: true
                    
                    Image {
                        anchors.fill: parent
                        source: modelData && modelData.thumb ? (rootApp ? rootApp.serverUrl + modelData.thumb + "?X-Plex-Token=" + rootApp.token : "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 40
                        color: "#cc000000"
                        
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            text: modelData ? "E" + modelData.index + " - " + modelData.title : ""
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 40
                        width: parent.width
                        height: 4
                        color: "#444444"
                        visible: modelData && modelData.viewOffset > 0
                        Rectangle {
                            width: modelData && modelData.duration ? (modelData.viewOffset / modelData.duration) * parent.width : 0
                            height: parent.height
                            color: "#E5A00D"
                        }
                    }
                    
                    // Watched Checkmark
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 24
                        height: 24
                        radius: 12
                        color: "#E5A00D"
                        visible: modelData && modelData.viewCount > 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    HoverHandler { id: epHover }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "#E5A00D"
                        border.width: 3
                        visible: epHover.hovered
                        radius: 8
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData && modelData.Media && modelData.Media.length > 0) {
                                var part = modelData.Media[0].Part[0];
                                var mediaUrl = rootApp ? rootApp.serverUrl + part.key + "?X-Plex-Token=" + rootApp.token : "";
                                var streams = part.Stream || [];
                                root.playMediaRequested(modelData.title, mediaUrl, modelData.viewOffset || 0, modelData.ratingKey, modelData.duration || 0, "auto", "no", streams);
                            }
                        }
                    }
                }
            }
            clip: true
            
            ScrollBar.vertical: ScrollBar {
                active: hovered || episodesGrid.moving
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
            
            footer: Item {
                width: episodesGrid.width
                height: castList.implicitHeight + 40
                
                DetailsCastList {
                    id: castList
                    anchors.fill: parent
                    anchors.topMargin: 20
                    detailsData: root.seriesData && root.seriesData.Role && root.seriesData.Role.length > 0 ? root.seriesData : root.detailsData
                    rootApp: root.rootApp
                }
            }
        }

    }
}
