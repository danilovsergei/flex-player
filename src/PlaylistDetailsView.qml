import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    implicitWidth: 1280
    implicitHeight: 720
    id: root
    objectName: "playlistDetailsView"

    property var rootApp: null
    property var appSettings: rootApp ? rootApp.appSettings : null
    
    property string rawJson: "{}"
    property var detailsData: null
    property var tracksData: null
    property var historyStack: []

    signal backRequested()

    onRawJsonChanged: {
        if (rawJson !== "{}" && rawJson !== "undefined" && rawJson !== "") {
            try {
                var parsed = JSON.parse(rawJson)
                if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                    detailsData = parsed.MediaContainer.Metadata[0]
                    fetchTracks()
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

    function fetchTracks() {
        if (!detailsData || !rootApp) return;
        playlistQueue.playlistModel.clear();
        var req = new XMLHttpRequest();
        var mServerUrl = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : (rootApp ? rootApp.serverUrl : "");
        var mServerToken = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token;
        var url = mServerUrl + "/playlists/" + detailsData.ratingKey + "/items?X-Plex-Token=" + mServerToken;
        req.open("GET", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    var parsed = JSON.parse(req.responseText);
                    if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                        tracksData = parsed.MediaContainer.Metadata;
                        for (var i = 0; i < tracksData.length; i++) {
                            var track = tracksData[i];
                            var trackUrl = "";
                            if (track.Media && track.Media.length > 0 && track.Media[0].Part && track.Media[0].Part.length > 0) {
                                trackUrl = mServerUrl + track.Media[0].Part[0].key + "?X-Plex-Token=" + mServerToken;
                            }
                            var trackData = {
                                "title": track.title || "",
                                "album": detailsData.title || "",
                                "artist": detailsData.parentTitle || "",
                                "mediaUrl": trackUrl,
                                "duration": track.duration || 0,
                                "isSelected": false,
                                "ratingKey": track.ratingKey || track.key || ""
                            };
                            playlistQueue.playlistModel.append(trackData);
                        }
                    } else {
                        tracksData = [];
                    }
                } else {
                    console.log("Failed to fetch tracks: " + req.status);
                    tracksData = [];
                }
            }
        }
        req.send();
    }

    Rectangle {
        anchors.fill: parent
        color: "#111111"
    }

    Rectangle {
        id: topBar
        Layout.fillWidth: true
        height: 60
        color: "#1A1A1A"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10

        Button {
            id: backButton
            objectName: "backButton"
            text: "← Back"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            background: Rectangle { color: "transparent" }
            contentItem: Text {
                text: parent.text
                color: parent.hovered ? "#E5A00D" : "white"
                font.pixelSize: 18
                font.bold: true
            }
            onClicked: {
                if (historyStack.length > 0) {
                    var newStack = historyStack.slice();
                    var prevJson = newStack.pop();
                    historyStack = newStack;
                    rawJson = prevJson;
                } else {
                    root.backRequested();
                }
            }
        }
    }

    ColumnLayout {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 40
        spacing: 20

        Text {
            id: playlistTitleText
            function formatDuration(ms) {
                if (!ms) return "";
                var totalMinutes = Math.floor(ms / 60000);
                var hours = Math.floor(totalMinutes / 60);
                var minutes = totalMinutes % 60;
                if (hours > 0) {
                    return " - " + hours + "h " + minutes + " minutes";
                } else {
                    return " - " + minutes + " minutes";
                }
            }
            text: detailsData ? (detailsData.title + (detailsData.leafCount ? " (" + detailsData.leafCount + ")" : "") + formatDuration(detailsData.duration)) : "Unknown Playlist"
            color: "white"
            font.pixelSize: 48
            font.bold: true
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Button {
                text: "▶ Play All"
                font.pixelSize: 16
                font.bold: true
                implicitWidth: 150
                implicitHeight: 40
                background: Rectangle {
                    color: parent.hovered ? "#FFAA00" : "#E5A00D"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "black"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (playlistQueue.playlistModel.count > 0) {
                        playlistQueue.playTrackAtIndex(0);
                    }
                }
            }

            
            Item { Layout.fillWidth: true }
        }

        PlaylistQueueView {
            id: playlistQueue
            Layout.fillWidth: true
            Layout.fillHeight: true
            isAlbumMode: true
            hideHeader: true
            appCtrl: root.rootApp ? root.rootApp.controller : null
            appSettings: root.rootApp ? root.rootApp.appSettings : null
        }
    }
}
