import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    objectName: "seriesDetailsView"
    anchors.fill: parent

    property var rootApp: null
    property string rawJson: "{}"
    property var detailsData: null
    property var seasonsData: null
    property var epToPlay: null

    signal backRequested()
    signal playMediaRequested(string title, string mediaUrl, int viewOffset, string ratingKey, int duration, string audioId, string subId, var streams)
    signal openSeasonRequested(string ratingKey)

    onRawJsonChanged: {
        if (rawJson !== "{}" && rawJson !== "undefined" && rawJson !== "") {
            try {
                var parsed = JSON.parse(rawJson)
                if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                    detailsData = parsed.MediaContainer.Metadata[0]
                    fetchSeasons()
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

    function fetchSeasons() {
        if (!detailsData || !rootApp) return;
        var req = new XMLHttpRequest();
        var url = rootApp.serverUrl + "/library/metadata/" + detailsData.ratingKey + "/children?X-Plex-Token=" + rootApp.token;
        req.open("GET", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    try {
                        var data = JSON.parse(req.responseText);
                        if (data && data.MediaContainer && data.MediaContainer.Metadata) {
                            seasonsData = data.MediaContainer.Metadata;
                        }
                    } catch(e) {}
                }
            }
        }
        req.send();
    }

    function fetchEpisodes() {
        if (!detailsData || !rootApp) return;
        var req = new XMLHttpRequest();
        var url = rootApp.serverUrl + "/library/metadata/" + detailsData.ratingKey + "/allLeaves?X-Plex-Token=" + rootApp.token;
        req.open("GET", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                try {
                    var data = JSON.parse(req.responseText);
                    if (data && data.MediaContainer && data.MediaContainer.Metadata && data.MediaContainer.Metadata.length > 0) {
                        var eps = data.MediaContainer.Metadata;
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

    // Main layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 30

        // Header: Back Button + Title
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Button {
                id: backBtn
                objectName: "seriesDetailsBackButton"
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
                objectName: "seriesDetailsTitle"
                text: detailsData ? detailsData.title : ""
                color: "white"
                font.pixelSize: 42
                font.bold: true
                Layout.fillWidth: true
            }
        }

        // Content
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 40

            // Left side: Poster
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 300
                spacing: 15

                Image {
                    id: posterImage
                    objectName: "seriesDetailsPoster"
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 450
                    source: detailsData && detailsData.thumb ? (rootApp ? rootApp.serverUrl + detailsData.thumb + "?X-Plex-Token=" + rootApp.token : "") : ""
                    fillMode: Image.PreserveAspectCrop
                }
                
                Text {
                    objectName: "seriesOnDeckLabel"
                    text: root.epToPlay ? "On Deck - S" + root.epToPlay.parentIndex + " E" + root.epToPlay.index : ""
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.epToPlay !== null
                }
            }

            // Right side: Details
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: 20

                RowLayout {
                    spacing: 20
                    Text { text: detailsData && detailsData.year ? detailsData.year : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                    Text { text: detailsData && detailsData.childCount ? detailsData.childCount + " Seasons" : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                    Text { objectName: "seriesContentRating"; text: detailsData && detailsData.contentRating ? detailsData.contentRating : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                }

                Text {
                    objectName: "seriesDetailsGenres"
                    text: {
                        if (!detailsData || !detailsData.Genre) return "";
                        var g = [];
                        for (var i=0; i<detailsData.Genre.length; i++) g.push(detailsData.Genre[i].tag);
                        return g.join(", ");
                    }
                    color: "white"
                    font.pixelSize: 18
                    font.italic: true
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
                        objectName: "seriesDetailsPlayButton"
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
        
        // Seasons List
        Text {
            text: "Seasons"
            color: "white"
            font.pixelSize: 22
            font.bold: true
            Layout.topMargin: 20
        }
        
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 250
            
            ListView {
                id: seasonsList
                objectName: "seriesSeasonsList"
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: 20
                clip: true
                model: seasonsData ? seasonsData : []
                
                delegate: ColumnLayout {
                    width: 150
                    spacing: 10
                    
                    Item {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 225
                        
                        Image {
                            anchors.fill: parent
                            source: modelData && modelData.thumb ? (rootApp ? rootApp.serverUrl + modelData.thumb + "?X-Plex-Token=" + rootApp.token : "") : ""
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                        }

                        // Watched/Total count (Top Left)
                        Rectangle {
                            objectName: "seasonCountRect"
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 5
                            width: seasonCountText.width + 12
                            height: 20
                            radius: 4
                            color: "#b3000000"
                            visible: modelData.leafCount !== undefined && modelData.leafCount > 0
                            
                            Text {
                                id: seasonCountText
                                objectName: "seasonCountText" 
                                anchors.centerIn: parent
                                text: (modelData.viewedLeafCount || 0) + "/" + modelData.leafCount
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        // Watched Checkmark (Top Right)
                        Rectangle {
                            objectName: "seasonWatchedCheckmark"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 5
                            width: 20
                            height: 20
                            radius: 10
                            color: "#E5A00D"
                            visible: modelData.leafCount !== undefined && modelData.leafCount > 0 && modelData.viewedLeafCount === modelData.leafCount
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                        
                        HoverHandler { id: seasonHover }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#E5A00D"
                            border.width: 3
                            visible: seasonHover.hovered
                            radius: 4
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData && modelData.ratingKey) {
                                    root.openSeasonRequested(modelData.ratingKey);
                                }
                            }
                        }
                    }
                    
                    Text {
                        text: modelData.title || ""
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }

        DetailsCastList {
            detailsData: root.detailsData
            rootApp: root.rootApp
        }
        
        Item {
            Layout.fillHeight: true
        }
    }
}
