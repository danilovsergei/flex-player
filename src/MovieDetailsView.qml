import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    objectName: "movieDetailsView"
    anchors.fill: parent


    property var rootApp: null
    property string rawJson: "{}"
    property var detailsData: null

    property int maxComboWidth: 250

    TextMetrics {
        id: comboTextMetrics
        font.pixelSize: 16
    }

    function updateMaxComboWidth() {
        var maxWidth = 250;
        var padding = 70;
        
        var vModel = videoComboControl.model || [];
        var aModel = audioComboControl.model || [];
        var sModel = subtitleComboControl.model || [];
        
        var allItems = [];
        for(var i=0; i<vModel.length; i++) allItems.push(vModel[i]);
        for(var i=0; i<aModel.length; i++) allItems.push(aModel[i]);
        for(var i=0; i<sModel.length; i++) allItems.push(sModel[i]);
        
        for(var j=0; j<allItems.length; j++) {
            comboTextMetrics.text = allItems[j];
            var w = comboTextMetrics.width + padding;
            if (w > maxWidth) maxWidth = w;
        }
        maxComboWidth = maxWidth;
    }

    signal backRequested()
    signal playMediaRequested(string title, string mediaUrl, int viewOffset, string ratingKey, int duration, string audioId, string subId)

    onRawJsonChanged: {
        console.log("rawJson string length:", rawJson ? rawJson.length : 0)
        if (rawJson !== "{}" && rawJson !== "undefined" && rawJson !== "") {
            try {
                var parsed = JSON.parse(rawJson)
                if (parsed.MediaContainer && parsed.MediaContainer.Metadata) {
                    detailsData = parsed.MediaContainer.Metadata[0]
                    console.log("Assigned detailsData for:", detailsData ? detailsData.title : "null")
                } else {
                    console.log("No Metadata found in JSON!")
                }
            } catch(e) {
                console.log("Parse error details view:", e)
                detailsData = null
            }
        }
    }
    
    onVisibleChanged: {
        if (visible) rawJsonChanged()
    }

    function formatMins(ms) {
        if (!ms) return 0;
        return Math.floor(ms / 60000);
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
                objectName: "detailsBackButton"
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
                objectName: "detailsTitle"
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

            // Left side: Poster & Progress
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 300
                spacing: 15

                Image {
                    id: posterImage
                    objectName: "detailsPoster"
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 450
                    source: detailsData && detailsData.thumb ? (rootApp ? rootApp.serverUrl + detailsData.thumb + "?X-Plex-Token=" + rootApp.token : "") : ""
                    fillMode: Image.PreserveAspectCrop
                }

                // Progress
                Rectangle {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 6
                    color: "#444444"
                    radius: 3
                    visible: detailsData && detailsData.viewOffset > 0
                    Rectangle {
                        width: detailsData && detailsData.duration ? (detailsData.viewOffset / detailsData.duration) * parent.width : 0
                        height: parent.height
                        color: "#E5A00D"
                        radius: 3
                    }
                }

                Text {
                    objectName: "detailsMinsLeft"
                    text: detailsData && detailsData.duration && detailsData.viewOffset ? formatMins(detailsData.duration - detailsData.viewOffset) + " mins left" : ""
                    color: "white"
                    font.pixelSize: 14
                    visible: detailsData && detailsData.viewOffset > 0
                }
            } // End Left side

            // Right side: Details
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: 20

                // Year, Duration, Content Rating, Rating, Genres
                RowLayout {
                    spacing: 20
                    Text { text: detailsData && detailsData.year ? detailsData.year : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                    Text { text: detailsData && detailsData.duration ? formatMins(detailsData.duration) + " mins" : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                    Text { objectName: "detailsContentRating"; text: detailsData && detailsData.contentRating ? detailsData.contentRating : ""; color: "#aaaaaa"; font.pixelSize: 18 }
                    RowLayout {
                        spacing: 15
                        Repeater {
                            model: {
                                if (!detailsData) return [];
                                var ratings = [];
                                if (detailsData.rating) ratings.push({ "val": detailsData.rating, "img": detailsData.ratingImage || "" });
                                if (detailsData.audienceRating) ratings.push({ "val": detailsData.audienceRating, "img": detailsData.audienceRatingImage || "" });
                                return ratings;
                            }
                            delegate: RowLayout {
                                spacing: 4
                                HoverHandler { id: ratingHover }
                                
                                Item {
                                    implicitWidth: imdbImage.visible ? 43 : iconText.implicitWidth
                                    implicitHeight: imdbImage.visible ? 17 : iconText.implicitHeight
                                    Layout.preferredWidth: implicitWidth
                                    Layout.preferredHeight: implicitHeight
                                    
                                    Image {
                                        id: imdbImage
                                        objectName: "detailsRatingIconImdb" + index
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 43
                                        height: 17
                                        source: "../assets/imdb_logo.svg"
                                        sourceSize.width: 43
                                        sourceSize.height: 17
                                        fillMode: Image.PreserveAspectFit
                                        visible: modelData.img && modelData.img.indexOf("imdb") !== -1
                                    }
                                    
                                    Text {
                                        id: iconText
                                        objectName: "detailsRatingIcon" + index
                                        anchors.centerIn: parent
                                        visible: !imdbImage.visible
                                        text: {
                                            var img = modelData.img;
                                            if (!img) return "★";
                                            if (img.indexOf("rottentomatoes://image.rating.ripe") !== -1) return "🍅";
                                            if (img.indexOf("rottentomatoes://image.rating.rotten") !== -1) return "🤢";
                                            if (img.indexOf("rottentomatoes://image.rating.upright") !== -1) return "🍿";
                                            if (img.indexOf("rottentomatoes://image.rating.spilled") !== -1) return "🍿";
                                            if (img.indexOf("themoviedb") !== -1) return "★";
                                            return "★";
                                        }
                                        color: {
                                            var img = modelData.img;
                                            if (!img) return "#aaaaaa";
                                            if (img.indexOf("rottentomatoes") !== -1) return "white"; 
                                            return "#aaaaaa"; 
                                        }
                                        font.pixelSize: 18
                                    }
                                }
                                
                                Text {
                                    id: ratingText
                                    objectName: "detailsRating" + index
                                    text: modelData.val
                                    color: "#aaaaaa"
                                    font.pixelSize: 18
                                    
                                    property string tooltipText: {
                                        var img = modelData.img;
                                        if (!img) return "Rating Source: Unknown";
                                        if (img.indexOf("imdb") !== -1) return "IMDb";
                                        if (img.indexOf("rottentomatoes") !== -1 && img.indexOf("upright") !== -1) return "Rotten Tomatoes Audience";
                                        if (img.indexOf("rottentomatoes") !== -1 && img.indexOf("spilled") !== -1) return "Rotten Tomatoes Audience";
                                        if (img.indexOf("rottentomatoes") !== -1) return "Rotten Tomatoes";
                                        if (img.indexOf("themoviedb") !== -1) return "TMDB";
                                        return "Rating Source: " + img;
                                    }
                                    
                                    ToolTip {
                                        id: ratingTip
                                        visible: ratingHover.hovered
                                        delay: 100
                                        text: ratingText.tooltipText
                                        contentItem: Text {
                                            text: ratingTip.text
                                            color: "#E5A00D"
                                            font.pixelSize: 14
                                        }
                                        background: Rectangle {
                                            color: "#222222"
                                            radius: 4
                                            border.color: "#444444"
                                            border.width: 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    objectName: "detailsGenres"
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

                // Dropdowns (Video, Audio, Subtitles)
                ColumnLayout {
                    spacing: 15
                    Layout.topMargin: 20

                    RowLayout {
                        spacing: 20
                        Text { text: "Video Stream:"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 120 }
                                                                        ComboBox {
                            id: videoComboControl
                            onModelChanged: updateMaxComboWidth()
                            objectName: "detailsVideoCombo"
                            Layout.fillWidth: false
                            Layout.preferredWidth: maxComboWidth
                            Layout.preferredHeight: 40
                            background: Rectangle { color: "#222222"; radius: 4 }
                            contentItem: Text { 
                                text: parent.currentText; color: "#E5A00D"; font.pixelSize: 16; 
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; leftPadding: 10; rightPadding: 30 
                            }
                            indicator: Canvas {
                                x: parent.width - width - 10
                                y: parent.topPadding + (parent.availableHeight - height) / 2
                                width: 12; height: 8; contextType: "2d"
                                Connections {
                                    target: parent
                                    function onPressedChanged() { parent.indicator.requestPaint() }
                                }
                                onPaint: {
                                    var context = getContext("2d");
                                    context.reset(); context.moveTo(0, 0); context.lineTo(width, 0); context.lineTo(width / 2, height); context.closePath();
                                    context.fillStyle = parent.pressed ? "#aaaaaa" : "#E5A00D"; context.fill();
                                }
                            }
                            popup: Popup {
                                y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                                contentItem: ListView {
                                    clip: true; implicitHeight: contentHeight; model: videoComboControl.delegateModel
                                    currentIndex: videoComboControl.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator { }
                                }
                                background: Rectangle { color: "#111111"; border.color: "#444444"; radius: 4 }
                            }
                            delegate: ItemDelegate {
                                width: ListView.view.width
                                highlighted: videoComboControl.highlightedIndex === index
                                onClicked: {
                                    videoComboControl.currentIndex = index;
                                    videoComboControl.popup.close();
                                }
                                contentItem: Text { 
                                    text: modelData 
                                    color: parent.highlighted ? "black" : "#E5A00D"
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter 
                                }
                                background: Rectangle { 
                                    color: parent.highlighted ? "#E5A00D" : "transparent" 
                                }
                            }
                            model: {
                                if (!detailsData || !detailsData.Media || detailsData.Media.length === 0) return [];
                                var streams = detailsData.Media[0].Part[0].Stream;
                                var v = [];
                                for (var i=0; i<streams.length; i++) {
                                    if (streams[i].streamType === 1) {
                                        v.push(streams[i].extendedDisplayTitle || streams[i].displayTitle || streams[i].title || streams[i].codec);
                                    }
                                }
                                return v;
                            }
                        }
                    }

                    RowLayout {
                        spacing: 20
                        Text { text: "Audio Track:"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 120 }
                                                                        ComboBox {
                            id: audioComboControl
                            onModelChanged: updateMaxComboWidth()
                            objectName: "detailsAudioCombo"
                            Layout.fillWidth: false
                            Layout.preferredWidth: maxComboWidth
                            Layout.preferredHeight: 40
                            background: Rectangle { color: "#222222"; radius: 4 }
                            contentItem: Text { 
                                text: parent.currentText; color: "#E5A00D"; font.pixelSize: 16; 
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; leftPadding: 10; rightPadding: 30 
                            }
                            indicator: Canvas {
                                x: parent.width - width - 10
                                y: parent.topPadding + (parent.availableHeight - height) / 2
                                width: 12; height: 8; contextType: "2d"
                                Connections {
                                    target: parent
                                    function onPressedChanged() { parent.indicator.requestPaint() }
                                }
                                onPaint: {
                                    var context = getContext("2d");
                                    context.reset(); context.moveTo(0, 0); context.lineTo(width, 0); context.lineTo(width / 2, height); context.closePath();
                                    context.fillStyle = parent.pressed ? "#aaaaaa" : "#E5A00D"; context.fill();
                                }
                            }
                            popup: Popup {
                                y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                                contentItem: ListView {
                                    clip: true; implicitHeight: contentHeight; model: audioComboControl.delegateModel
                                    currentIndex: audioComboControl.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator { }
                                }
                                background: Rectangle { color: "#111111"; border.color: "#444444"; radius: 4 }
                            }
                            delegate: ItemDelegate {
                                width: ListView.view.width
                                highlighted: audioComboControl.highlightedIndex === index
                                onClicked: {
                                    audioComboControl.currentIndex = index;
                                    audioComboControl.popup.close();
                                }
                                contentItem: Text { 
                                    text: modelData 
                                    color: parent.highlighted ? "black" : "#E5A00D"
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter 
                                }
                                background: Rectangle { 
                                    color: parent.highlighted ? "#E5A00D" : "transparent" 
                                }
                            }
                            model: {
                                if (!detailsData || !detailsData.Media || detailsData.Media.length === 0) return [];
                                var streams = detailsData.Media[0].Part[0].Stream;
                                var a = [];
                                for (var i=0; i<streams.length; i++) {
                                    if (streams[i].streamType === 2) {
                                        a.push(streams[i].extendedDisplayTitle || streams[i].displayTitle || streams[i].title || streams[i].language);
                                    }
                                }
                                return a;
                            }
                        }
                    }

                    RowLayout {
                        spacing: 20
                        Text { text: "Subtitles:"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 120 }
                                                                        ComboBox {
                            id: subtitleComboControl
                            onModelChanged: updateMaxComboWidth()
                            objectName: "detailsSubtitleCombo"
                            Layout.fillWidth: false
                            Layout.preferredWidth: maxComboWidth
                            Layout.preferredHeight: 40
                            background: Rectangle { color: "#222222"; radius: 4 }
                            contentItem: Text { 
                                text: parent.currentText; color: "#E5A00D"; font.pixelSize: 16; 
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; leftPadding: 10; rightPadding: 30 
                            }
                            indicator: Canvas {
                                x: parent.width - width - 10
                                y: parent.topPadding + (parent.availableHeight - height) / 2
                                width: 12; height: 8; contextType: "2d"
                                Connections {
                                    target: parent
                                    function onPressedChanged() { parent.indicator.requestPaint() }
                                }
                                onPaint: {
                                    var context = getContext("2d");
                                    context.reset(); context.moveTo(0, 0); context.lineTo(width, 0); context.lineTo(width / 2, height); context.closePath();
                                    context.fillStyle = parent.pressed ? "#aaaaaa" : "#E5A00D"; context.fill();
                                }
                            }
                            popup: Popup {
                                y: parent.height - 1; width: parent.width; implicitHeight: contentItem.implicitHeight; padding: 1
                                contentItem: ListView {
                                    clip: true; implicitHeight: contentHeight; model: subtitleComboControl.delegateModel
                                    currentIndex: subtitleComboControl.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator { }
                                }
                                background: Rectangle { color: "#111111"; border.color: "#444444"; radius: 4 }
                            }
                            delegate: ItemDelegate {
                                width: ListView.view.width
                                highlighted: subtitleComboControl.highlightedIndex === index
                                onClicked: {
                                    subtitleComboControl.currentIndex = index;
                                    subtitleComboControl.popup.close();
                                }
                                contentItem: Text { 
                                    text: modelData 
                                    color: parent.highlighted ? "black" : "#E5A00D"
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter 
                                }
                                background: Rectangle { 
                                    color: parent.highlighted ? "#E5A00D" : "transparent" 
                                }
                            }
                            model: {
                                if (!detailsData || !detailsData.Media || detailsData.Media.length === 0) return ["None"];
                                var streams = detailsData.Media[0].Part[0].Stream;
                                var s = ["None"];
                                for (var i=0; i<streams.length; i++) {
                                    if (streams[i].streamType === 3) {
                                        var title = streams[i].extendedDisplayTitle || streams[i].displayTitle || streams[i].title || streams[i].language;
                                        if (streams[i].forced && title.indexOf("Forced") === -1 && title.indexOf("forced") === -1) {
                                            title += " Forced";
                                        }
                                        s.push(title);
                                    }
                                }
                                return s;
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    spacing: 15

                    Button {
                        id: playBtn
                        objectName: "detailsPlayButton"
                        text: detailsData && detailsData.viewOffset > 0 ? "Resume" : "Play"
                        contentItem: Text { text: playBtn.text; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { implicitWidth: 120; implicitHeight: 40; color: "#E5A00D"; radius: 8 }
                        onClicked: {
                            if (detailsData && detailsData.Media && detailsData.Media.length > 0) {
                                var part = detailsData.Media[0].Part[0];
                                var url = rootApp ? rootApp.serverUrl + part.key + "?X-Plex-Token=" + rootApp.token : "";
                                
                                var audioId = "auto";
                                if (audioComboControl.currentIndex >= 0) {
                                    audioId = (audioComboControl.currentIndex + 1).toString();
                                }
                                
                                var subId = "no";
                                if (subtitleComboControl.currentIndex > 0) {
                                    subId = subtitleComboControl.currentIndex.toString();
                                }
                                
                                root.playMediaRequested(detailsData.title, url, detailsData.viewOffset || 0, detailsData.ratingKey, detailsData.duration || 0, audioId, subId);
                            }
                        }
                    }

                    Button {
                        id: watchedBtn
                        objectName: "detailsWatchedButton"
                        text: "Mark Watched"
                        contentItem: Text { text: watchedBtn.text; color: "white"; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { implicitWidth: 140; implicitHeight: 40; color: "#444444"; radius: 8 }
                    }
                } // End Buttons RowLayout
            } // End Right side ColumnLayout
        } // End Content RowLayout


                // Cast & Crew
                Text {
                    text: "Cast & Crew"
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                    Layout.topMargin: 20
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160

                    ListView {
                        id: detailsCastList
                        objectName: "detailsCastList"
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 20
                        clip: true
                        interactive: false
                        model: detailsData && detailsData.Role ? detailsData.Role : []
                        
                        Behavior on contentX {
                            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                        }

                        delegate: ColumnLayout {
                            width: 100
                            spacing: 5

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                width: 80
                                height: 80

                                Image {
                                    id: castImg
                                    anchors.fill: parent
                                    source: {
                                        if (!modelData.thumb) return "";
                                        if (modelData.thumb.startsWith("http") || modelData.thumb.startsWith("data:")) return modelData.thumb;
                                        return rootApp ? rootApp.serverUrl + modelData.thumb + "?X-Plex-Token=" + rootApp.token : "";
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    visible: false
                                }

                                Rectangle {
                                    id: maskRect
                                    anchors.fill: parent
                                    radius: 40
                                    color: "black"
                                    layer.enabled: true
                                    visible: false
                                }

                                MultiEffect {
                                    source: castImg
                                    anchors.fill: parent
                                    maskEnabled: true
                                    maskSource: maskRect
                                }
                            }

                        Text {
                            text: modelData.tag || ""
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.role || ""
                            color: "#aaaaaa"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                } // End ListView
                    
                HoverHandler { id: castHover }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 40
                        color: castLeftHover.hovered ? "#CC000000" : "#80000000"
                        visible: detailsCastList.contentX > 0
                        opacity: castHover.hovered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Text { anchors.centerIn: parent; text: "❮"; color: castLeftHover.hovered ? "#E5A00D" : "white"; font.pixelSize: 32; font.bold: true }
                        HoverHandler { id: castLeftHover }
                        MouseArea { anchors.fill: parent; onClicked: detailsCastList.contentX = Math.max(0, detailsCastList.contentX - 400) }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 40
                        color: castRightHover.hovered ? "#CC000000" : "#80000000"
                        visible: detailsCastList.contentWidth > detailsCastList.width && detailsCastList.contentX < (detailsCastList.contentWidth - detailsCastList.width)
                        opacity: castHover.hovered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Text { anchors.centerIn: parent; text: "❯"; color: castRightHover.hovered ? "#E5A00D" : "white"; font.pixelSize: 32; font.bold: true }
                        HoverHandler { id: castRightHover }
                        MouseArea { anchors.fill: parent; onClicked: detailsCastList.contentX = Math.min(detailsCastList.contentWidth - detailsCastList.width, detailsCastList.contentX + 400) }
                    }
                }
        Item {
            Layout.fillHeight: true
        }
    } // End Main ColumnLayout
} // End Root Item
