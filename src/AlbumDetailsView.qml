import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    implicitWidth: 1280
    implicitHeight: 720
    id: root
    objectName: "albumDetailsView"

    property var rootApp: null
    property var appSettings: rootApp ? rootApp.appSettings : null
    property int albumLayoutMode: appSettings ? appSettings.albumLayoutMode : 0
    
    Connections {
        target: root.appSettings
        function onAlbumLayoutModeChanged() {
            if (root.appSettings) {
                root.albumLayoutMode = root.appSettings.albumLayoutMode;
            }
        }
    }
    property string rawJson: "{}"
    property var detailsData: null
    property var tracksData: null
    property var historyStack: []
    // 40 (left margin) + 40 (spacing between poster and text) + 40 (right margin)
    property real layoutMarginsTotal: 120 
    // Safe buffer for the ScrollView's vertical scrollbar width and internal Qt padding
    property real scrollbarBuffer: 60 
    
    property real requiredDetailsWidth: posterRect.width + layoutMarginsTotal + scrollbarBuffer + Math.max(albumTitleText.implicitWidth, albumArtistText.implicitWidth)
    property real responsiveBreakpoint: Math.max(900, requiredDetailsWidth + playlistQueue.requiredPlaylistWidth)

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

    function saveRating(ratingValue) {
        if (!detailsData || !rootApp) return;
        var req = new XMLHttpRequest();
        var sUrl = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl;
        var sToken = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token;
        var url = sUrl + "/:/rate?key=" + detailsData.ratingKey + "&identifier=com.plexapp.plugins.library&rating=" + ratingValue;
        req.open("PUT", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("X-Plex-Token", sToken);
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    console.log("Rating saved successfully to " + ratingValue);
                } else {
                    console.error("Failed to save rating: " + req.status);
                }
            }
        }
        req.send();
    }

    function fetchTracks() {
        if (!detailsData || !rootApp) return;
        playlistQueue.playlistModel.clear();
        var req = new XMLHttpRequest();
        var mServerUrl = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : (rootApp ? rootApp.serverUrl : "");
        var mServerToken = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token;
        var url = mServerUrl + "/library/metadata/" + detailsData.ratingKey + "/children?X-Plex-Token=" + mServerToken;
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

    SplitView {
        id: mainSplitView
        objectName: "mainSplitView"
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        orientation: root.albumLayoutMode === 1 ? Qt.Vertical : (root.albumLayoutMode === 2 ? Qt.Horizontal : (root.width < root.responsiveBreakpoint ? Qt.Vertical : Qt.Horizontal))
        
        ScrollView {
            id: albumScrollView
            objectName: "albumScrollView"
            SplitView.preferredWidth: mainSplitView.orientation === Qt.Horizontal ? requiredDetailsWidth : -1
            SplitView.fillWidth: mainSplitView.orientation === Qt.Vertical
            SplitView.fillHeight: mainSplitView.orientation === Qt.Horizontal
            SplitView.minimumWidth: 400
            SplitView.minimumHeight: 200
            clip: true

            ColumnLayout {
            width: albumScrollView.availableWidth
            spacing: 30

            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                Layout.margins: 40
                spacing: 40

                Rectangle {
                    id: posterRect
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 300
                    color: "transparent"
                    radius: 12
                    clip: true

                    Image {
                        id: albumThumb
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: detailsData && detailsData.thumb && rootApp ? 
                                ((rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl) + detailsData.thumb + "?X-Plex-Token=" + (rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token)) : 
                                ""
                        visible: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    Text {
                        id: albumArtistText
                        text: detailsData && detailsData.parentTitle ? detailsData.parentTitle : "Unknown Artist"
                        color: "#E5A00D"
                        font.pixelSize: 24
                        font.bold: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootApp && detailsData && detailsData.parentRatingKey) {
                                    var mServerUrl = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl;
                                    var mServerToken = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token;
                                    rootApp.openArtist(detailsData.parentRatingKey, mServerUrl, mServerToken);
                                }
                            }
                        }
                    }

                    Text {
                        id: albumTitleText
                        text: detailsData && detailsData.title ? detailsData.title : "Unknown Album"
                        color: "white"
                        font.pixelSize: 48
                        font.bold: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: detailsData && (detailsData.year || detailsData.rating || detailsData.userRating || detailsData.studio || detailsData.Style)

                        // Year
                        RowLayout {
                            spacing: 10
                            visible: detailsData && detailsData.year !== undefined
                            Text {
                                text: "Year:"
                                color: "#888888"
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Text {
                                text: detailsData && detailsData.year ? detailsData.year.toString() : ""
                                color: "#CCCCCC"
                                font.pixelSize: 16
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        // Record Label (studio)
                        RowLayout {
                            spacing: 10
                            visible: detailsData && detailsData.studio !== undefined
                            Text {
                                text: "Label:"
                                color: "#888888"
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Text {
                                text: detailsData && detailsData.studio ? detailsData.studio : ""
                                color: "#CCCCCC"
                                font.pixelSize: 16
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        // Style
                        RowLayout {
                            spacing: 10
                            visible: detailsData && detailsData.Style && detailsData.Style.length > 0
                            Text {
                                text: "Style:"
                                color: "#888888"
                                font.pixelSize: 16
                                font.bold: true
                                Layout.alignment: Qt.AlignTop
                            }
                            Text {
                                text: detailsData && detailsData.Style ? detailsData.Style.map(function(s){ return s.tag }).join(" • ") : ""
                                color: "#CCCCCC"
                                font.pixelSize: 16
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }

                        // Rating
                        RowLayout {
                            id: ratingRow
                            spacing: 10
                            visible: detailsData !== null
                            property real ratingVal: detailsData ? (detailsData.userRating !== undefined ? detailsData.userRating : (detailsData.rating !== undefined ? detailsData.rating : 0)) : 0
                            
                            Text {
                                text: "Rating:"
                                color: "#888888"
                                font.pixelSize: 16
                                font.bold: true
                            }
                            
                            Item {
                                Layout.preferredWidth: emptyStars.implicitWidth
                                Layout.preferredHeight: emptyStars.implicitHeight
                                width: Layout.preferredWidth
                                height: Layout.preferredHeight
                                
                                Text {
                                    id: emptyStars
                                    text: "★★★★★"
                                    color: "#444444"
                                    font.pixelSize: 18
                                }
                                Item {
                                    width: parent.width * (ratingRow.ratingVal / 10.0)
                                    height: parent.height
                                    clip: true
                                    Text {
                                        text: "★★★★★"
                                        color: "#E5A00D"
                                        font.pixelSize: 18
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    
                                    function updateRating(mouseX) {
                                        var newRating = (mouseX / width) * 10.0;
                                        newRating = Math.round(newRating * 2) / 2.0;
                                        newRating = Math.max(0.0, Math.min(10.0, newRating));
                                        ratingRow.ratingVal = newRating;
                                    }
                                    
                                    onPressed: function(mouse) {
                                        updateRating(mouse.x);
                                    }
                                    onPositionChanged: function(mouse) {
                                        if (pressed) {
                                            updateRating(mouse.x);
                                        }
                                    }
                                    onReleased: function(mouse) {
                                        root.saveRating(ratingRow.ratingVal);
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: detailsData && detailsData.summary ? detailsData.summary : ""
                        color: "#CCCCCC"
                        font.pixelSize: 16
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        visible: text !== ""
                        Layout.topMargin: 15
                    }
                }
            }

        }
        }
        
        PlaylistQueueView {
            id: playlistQueue
            
            isAlbumMode: true
            SplitView.fillWidth: mainSplitView.orientation === Qt.Horizontal
            SplitView.fillHeight: mainSplitView.orientation === Qt.Vertical
            SplitView.minimumWidth: 300
            SplitView.minimumHeight: 200
            appCtrl: root.rootApp ? root.rootApp.controller : null
            appSettings: root.rootApp ? root.rootApp.appSettings : null
        }
    }

}
