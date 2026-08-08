import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    implicitWidth: 1280
    implicitHeight: 720
    id: root
    objectName: "artistDetailsView"

    property var rootApp: null
    property string rawJson: "{}"
    property var detailsData: null
    property var albumsData: null
    property var similarArtistsData: null
    property var historyStack: []

    signal backRequested()

    onRawJsonChanged: {
        if (rawJson !== "{}" && rawJson !== "undefined" && rawJson !== "") {
            try {
                var parsed = JSON.parse(rawJson)
                if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                    detailsData = parsed.MediaContainer.Metadata[0]
                    fetchAlbums()
                    fetchSimilarArtists()
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

    function fetchSimilarArtists() {
        var req = new XMLHttpRequest();
        var url = (rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : (rootApp ? rootApp.serverUrl : "")) + "/library/metadata/" + detailsData.ratingKey + "/similar?X-Plex-Token=" + rootApp.token;
        req.open("GET", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    var parsed = JSON.parse(req.responseText);
                    if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                        similarArtistsData = parsed.MediaContainer.Metadata;
                    } else {
                        similarArtistsData = [];
                    }
                } else {
                    console.log("Failed to fetch similar artists: " + req.status);
                    similarArtistsData = [];
                }
            }
        }
        req.send();
    }

    function fetchAlbums() {
        var req = new XMLHttpRequest();
        var url = (rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : (rootApp ? rootApp.serverUrl : "")) + "/library/metadata/" + detailsData.ratingKey + "/children?X-Plex-Token=" + rootApp.token;
        req.open("GET", url, true);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    var parsed = JSON.parse(req.responseText);
                    if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                        albumsData = parsed.MediaContainer.Metadata;
                    } else {
                        albumsData = [];
                    }
                } else {
                    console.log("Failed to fetch albums: " + req.status);
                    albumsData = [];
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

    ScrollView {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true

        ColumnLayout {
            width: root.width
            spacing: 30

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 40
                spacing: 40

                Rectangle {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 300
                    color: "transparent"
                    radius: 12
                    clip: true

                    Image {
                        id: artistThumb
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
                    spacing: 15

                    Text {
                        text: detailsData && detailsData.title ? detailsData.title : "Unknown Artist"
                        color: "white"
                        font.pixelSize: 48
                        font.bold: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: detailsData && (detailsData.Country || detailsData.rating || detailsData.userRating || detailsData.Style)

                        // Country
                        RowLayout {
                            spacing: 10
                            visible: detailsData && detailsData.Country && detailsData.Country.length > 0
                            Text {
                                text: "Country:"
                                color: "#888888"
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Text {
                                text: detailsData && detailsData.Country && detailsData.Country.length > 0 ? detailsData.Country[0].tag : ""
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
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 40
                spacing: 20
                visible: albumsData && albumsData.length > 0

                Text {
                    text: "Albums"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 20
                    Repeater {
                        model: albumsData ? albumsData.length : 0
                        delegate: Rectangle {
                            width: 200
                            height: 250
                            color: "transparent"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 200
                                    Layout.preferredHeight: 200
                                    color: "#333"
                                    radius: 8
                                    clip: true
                                    Image {
                                        id: albumThumb
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: albumsData && albumsData[index] && albumsData[index].thumb && rootApp ? 
                                                ((rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl) + albumsData[index].thumb + "?X-Plex-Token=" + (rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token)) : 
                                                ""
                                        visible: true
                                    }
                                }
                                Text {
                                    text: albumsData && albumsData[index] ? albumsData[index].title : ""
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    text: albumsData && albumsData[index] && albumsData[index].year ? albumsData[index].year : ""
                                    color: "#888"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootApp && albumsData && albumsData[index]) {
                                        var mRatingKey = albumsData[index].ratingKey;
                                        var mServerUrl = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl;
                                        var mServerToken = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token;
                                        rootApp.openAlbum(mRatingKey, mServerUrl, mServerToken);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 40
                spacing: 20
                visible: similarArtistsData && similarArtistsData.length > 0

                Text {
                    text: "Similar Artists"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 30
                    Repeater {
                        model: similarArtistsData ? similarArtistsData.length : 0
                        delegate: Rectangle {
                            width: 200
                            height: 250
                            color: "transparent"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 15
                                
                                Rectangle {
                                    Layout.preferredWidth: 200
                                    Layout.preferredHeight: 200
                                    color: "#333"
                                    radius: 100
                                    clip: true
                                    
                                    Image {
                                        id: similarThumb
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: similarArtistsData && similarArtistsData[index] && similarArtistsData[index].thumb && rootApp ? 
                                                ((rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl) + similarArtistsData[index].thumb + "?X-Plex-Token=" + (rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token)) : 
                                                ""
                                        visible: true
                                    }
                                }
                                Text {
                                    text: similarArtistsData && similarArtistsData[index] ? similarArtistsData[index].title : ""
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootApp && similarArtistsData && similarArtistsData[index]) {
                                        var mRatingKey = similarArtistsData[index].ratingKey;
                                        var mServerUrl = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerUrl !== "" ? rootApp.controller.detailsModel.currentServerUrl : rootApp.serverUrl;
                                        var mServerToken = rootApp && rootApp.controller && rootApp.controller.detailsModel && rootApp.controller.detailsModel.currentServerToken !== "" ? rootApp.controller.detailsModel.currentServerToken : rootApp.token;
                                        rootApp.openArtist(mRatingKey, mServerUrl, mServerToken);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
