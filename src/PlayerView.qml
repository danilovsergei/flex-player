import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import flex.mpv 1.0
import flex.plex 1.0

Item {
        id: playerView
        objectName: "playerView"
        anchors.fill: parent
        visible: false

        property bool fullScreenControlsVisible: true
        property bool isFullScreenMode: false
        
        property string currentRatingKey: ""
        property int currentDuration: 0
        
        property var rootApp: null
        property var mediaStreams: []
        property string currentAudioId: "auto"
        property string currentSubId: "no"


        signal playbackStopped()
        signal timelineUpdateRequested(string state, int timeMs)

        function getCurrentAudioName() {
            if (!playerView.mediaStreams) return "Unknown";
            var aid = parseInt(playerView.currentAudioId);
            if (isNaN(aid)) return "Unknown";
            var aIndex = 1;
            for (var i=0; i<playerView.mediaStreams.length; i++) {
                if (playerView.mediaStreams[i].streamType === 2) {
                    if (aIndex === aid) {
                        var s = playerView.mediaStreams[i];
                        return s.extendedDisplayTitle || s.displayTitle || s.title || s.language || "Unknown";
                    }
                    aIndex++;
                }
            }
            return "Unknown";
        }

        function getCurrentSubName() {
            if (playerView.currentSubId === "no") return "None";
            if (!playerView.mediaStreams) return "Unknown";
            var sid = parseInt(playerView.currentSubId);
            if (isNaN(sid)) return "Unknown";
            var sIndex = 1;
            for (var i=0; i<playerView.mediaStreams.length; i++) {
                if (playerView.mediaStreams[i].streamType === 3) {
                    if (sIndex === sid) {
                        var s = playerView.mediaStreams[i];
                        var t = s.extendedDisplayTitle || s.displayTitle || s.title || s.language || "Unknown";
                        if (s.forced && t.indexOf("Forced") === -1 && t.indexOf("forced") === -1) {
                            t += " Forced";
                        }
                        return t;
                    }
                    sIndex++;
                }
            }
            return "Unknown";
        }


        function playMedia(url, offset, ratingKey, duration, audioId, subId, streams) {
            currentRatingKey = ratingKey !== undefined ? ratingKey : ""
            currentDuration = duration !== undefined ? duration : 0
            playerView.mediaStreams = streams || []
            currentAudioId = audioId !== undefined ? audioId : "auto"
            currentSubId = subId !== undefined ? subId : "no"

            console.log("PlayerView playMedia called with " + (playerView.mediaStreams ? playerView.mediaStreams.length : 0) + " streams");

            if (playerView.mediaStreams.length === 0 && currentRatingKey !== "") {
                var req = new XMLHttpRequest();
                var sUrl = playerView.rootApp ? playerView.rootApp.serverUrl : "";
                var tok = playerView.rootApp ? playerView.rootApp.token : "";
                var metadataUrl = sUrl + "/library/metadata/" + currentRatingKey + "?X-Plex-Token=" + tok;
                console.log("PlayerView fetching dynamic streams from: " + metadataUrl);
                req.open("GET", metadataUrl, true);
                req.setRequestHeader("Accept", "application/json");
                req.onreadystatechange = function() {
                    if (req.readyState === XMLHttpRequest.DONE) {
                        if (req.status === 200) {
                            try {
                                var data = JSON.parse(req.responseText);
                                if (data && data.MediaContainer && data.MediaContainer.Metadata && data.MediaContainer.Metadata.length > 0) {
                                    var meta = data.MediaContainer.Metadata[0];
                                    if (meta.Media && meta.Media.length > 0 && meta.Media[0].Part && meta.Media[0].Part.length > 0) {
                                        playerView.mediaStreams = meta.Media[0].Part[0].Stream || [];
                                        console.log("PlayerView fetched " + playerView.mediaStreams.length + " streams dynamically");
                                    }
                                }
                            } catch (e) {
                                console.log("Failed to parse metadata for streams:", e);
                            }
                        }
                    }
                }
                req.send();
            }

            mpvObject.setProperty("aid", currentAudioId)
            mpvObject.setProperty("sid", currentSubId)

            if (offset > 0) {
                mpvObject.setProperty("start", (offset / 1000).toString())
                mpvObject.command(["loadfile", url])
            } else {
                mpvObject.command(["loadfile", url])
            }
            mpvObject.paused = false
        }


        Timer {
            id: timelineTimer
            objectName: "timelineTimer"
            interval: 10000
            running: playerView.visible && playerView.currentRatingKey !== "" && !mpvObject.paused
            repeat: true
            onTriggered: {
                var timeMs = Math.floor(mpvObject.position * 1000);
                playerView.timelineUpdateRequested("playing", timeMs);
            }
        }

        Timer {
            id: hideControlsTimer
            interval: 5000
            running: playerView.isFullScreenMode && playerView.visible && !mpvObject.paused
            onTriggered: {
                playerView.fullScreenControlsVisible = false
            }
        }

        HoverHandler {
            id: playerHover
        }

        ScreenSaverInhibitor {
        id: screensaverInhibitor
        objectName: "screensaverInhibitor"
        active: playerView.visible && !mpvObject.paused
    }



        MpvObject {
            id: mpvObject
            objectName: "mpvObject"
            anchors.fill: parent
            onAidChanged: {
                if (mpvObject.aid !== "") {
                    playerView.currentAudioId = mpvObject.aid;
                }
            }
            onSidChanged: {
                if (mpvObject.sid !== "") {
                    playerView.currentSubId = mpvObject.sid;
                }
            }
            onPausedChanged: {
                if (playerView.currentRatingKey !== "" && playerView.visible) {
                    var state = paused ? "paused" : "playing";
                    var timeMs = Math.floor(mpvObject.position * 1000);
                    playerView.timelineUpdateRequested(state, timeMs);
                }
            }
        }

        MouseArea {
            id: playerMouseArea
            objectName: "playerMouseArea"
            anchors.fill: parent
            hoverEnabled: true

            cursorShape: (playerView.isFullScreenMode && !playerView.fullScreenControlsVisible && !mpvObject.paused) ? Qt.BlankCursor : Qt.ArrowCursor

            onPositionChanged: {
                playerView.fullScreenControlsVisible = true
                if (playerView.isFullScreenMode && !mpvObject.paused) {
                    hideControlsTimer.restart()
                }
            }

            Timer {
                id: singleClickTimer
                interval: 250
                onTriggered: {
                    mpvObject.paused = !mpvObject.paused
                }
            }

            onClicked: {
                playerView.fullScreenControlsVisible = true
                if (playerView.isFullScreenMode && !mpvObject.paused) {
                    hideControlsTimer.restart()
                }
                
                if (!singleClickTimer.running) {
                    singleClickTimer.start()
                }
            }
            
            onDoubleClicked: {
                singleClickTimer.stop()
                mainWindow.toggleFullScreen()
            }
        }

        // Top Overlay Controls
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 60
            color: "#B3000000" // 70% opacity black
            visible: mpvObject.paused || (playerView.isFullScreenMode ? playerView.fullScreenControlsVisible : playerHover.hovered)

            Button {
                id: backButton
                objectName: "backButton"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 20
                text: "⬅"
                font.pixelSize: 24
                contentItem: Text {
                    text: backButton.text
                    font: backButton.font
                    color: backButton.down ? mainWindow.plexOrange : "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: "transparent"
                }
                onClicked: {
                    mpvObject.command(["stop"])
                    playerView.visible = false
                    playbackStopped()
                    if (playerView.isFullScreenMode) {
                        mainWindow.showNormal()
                    }
                }
            }
        }

        // Bottom Overlay Controls
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 80
            color: "#B3000000" // 70% opacity black
            visible: mpvObject.paused || (playerView.isFullScreenMode ? playerView.fullScreenControlsVisible : playerHover.hovered)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // Play / Pause Button
                Button {
                    id: playPauseButton
                    objectName: "playPauseButton"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    padding: 0
                    text: mpvObject.paused ? "▶" : "⏸"
                    font.pixelSize: 24
                    
                    ToolTip.visible: hovered
                    ToolTip.text: mpvObject.paused ? "Play" : "Pause"
                    
                    contentItem: Text {
                        text: playPauseButton.text
                        font: playPauseButton.font
                        color: playPauseButton.hovered ? mainWindow.plexOrange : "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        mpvObject.paused = !mpvObject.paused
                    }
                }

                // Audio Selection Button
                Button {
                    id: playerAudioButton
                    objectName: "playerAudioButton"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    padding: 0
                    text: "🔊\uFE0E"
                    font.pixelSize: 24
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Audio Track: " + playerView.getCurrentAudioName()
                    
                    contentItem: Text {
                        text: playerAudioButton.text
                        font: playerAudioButton.font
                        color: playerAudioButton.hovered || playerAudioMenu.opened ? mainWindow.plexOrange : "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        playerAudioMenu.popup(0, -playerAudioMenu.height)
                    }

                    Menu {
                        id: playerAudioMenu
                        objectName: "playerAudioMenu"
                        background: Rectangle { color: "#222222"; radius: 4; border.color: "#444444" }
                        
                        Repeater {
                            model: {
                                if (!playerView.mediaStreams) return [];
                                var a = [];
                                for (var i=0; i<playerView.mediaStreams.length; i++) {
                                    if (playerView.mediaStreams[i].streamType === 2) a.push(playerView.mediaStreams[i]);
                                }
                                return a;
                            }
                            MenuItem {
                                text: (playerView.currentAudioId === (index + 1).toString() ? "✓ " : "") + (modelData.extendedDisplayTitle || modelData.displayTitle || modelData.title || modelData.language)
                                contentItem: Text {
                                    text: parent.text
                                    color: (playerView.currentAudioId === (index + 1).toString()) ? "#4CAF50" : "white"
                                    font.pixelSize: 16
                                    font.bold: playerView.currentAudioId === (index + 1).toString()
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                background: Rectangle {
                                    color: parent.highlighted ? "#444444" : "transparent"
                                    radius: 4
                                }
                                onClicked: {
                                    playerView.currentAudioId = (index + 1).toString()
                                    mpvObject.setProperty("aid", playerView.currentAudioId)
                                }
                            }
                        }
                    }
                }

                // Subtitle Selection Button
                Button {
                    id: playerSubtitleButton
                    objectName: "playerSubtitleButton"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    padding: 0
                    text: "💬"
                    font.pixelSize: 24
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Subtitles: " + playerView.getCurrentSubName()
                    
                    contentItem: Text {
                        text: playerSubtitleButton.text
                        font: playerSubtitleButton.font
                        color: playerSubtitleButton.hovered || playerSubtitleMenu.opened ? mainWindow.plexOrange : "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        playerSubtitleMenu.popup(0, -playerSubtitleMenu.height)
                    }

                    Menu {
                        id: playerSubtitleMenu
                        objectName: "playerSubtitleMenu"
                        background: Rectangle { color: "#222222"; radius: 4; border.color: "#444444" }
                        
                        MenuItem {
                            text: (playerView.currentSubId === "no" ? "✓ " : "") + "None"
                            contentItem: Text {
                                text: parent.text
                                color: (playerView.currentSubId === "no") ? "#4CAF50" : "white"
                                font.pixelSize: 16
                                font.bold: playerView.currentSubId === "no"
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.highlighted ? "#444444" : "transparent"
                                radius: 4
                            }
                            onClicked: {
                                playerView.currentSubId = "no"
                                mpvObject.setProperty("sid", "no")
                            }
                        }

                        Repeater {
                            model: {
                                if (!playerView.mediaStreams) return [];
                                var s = [];
                                for (var i=0; i<playerView.mediaStreams.length; i++) {
                                    if (playerView.mediaStreams[i].streamType === 3) s.push(playerView.mediaStreams[i]);
                                }
                                return s;
                            }
                            MenuItem {
                                text: {
                                    var t = modelData.extendedDisplayTitle || modelData.displayTitle || modelData.title || modelData.language;
                                    if (modelData.forced && t.indexOf("Forced") === -1 && t.indexOf("forced") === -1) {
                                        t += " Forced";
                                    }
                                    return (playerView.currentSubId === (index + 1).toString() ? "✓ " : "") + t;
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: (playerView.currentSubId === (index + 1).toString()) ? "#4CAF50" : "white"
                                    font.pixelSize: 16
                                    font.bold: playerView.currentSubId === (index + 1).toString()
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                background: Rectangle {
                                    color: parent.highlighted ? "#444444" : "transparent"
                                    radius: 4
                                }
                                onClicked: {
                                    playerView.currentSubId = (index + 1).toString()
                                    mpvObject.setProperty("sid", playerView.currentSubId)
                                }
                            }
                        }
                    }
                }

                // Current Time
                Text {
                    text: mainWindow.formatTime(mpvObject.position)
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Progress Bar
                Slider {
                    id: progressBar
                    objectName: "progressBar"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: mpvObject.duration > 0 ? mpvObject.duration : 1
                    value: mpvObject.position

                    // Stop updating player position while user is dragging
                    onMoved: {
                        mpvObject.position = value
                    }

                    background: Rectangle {
                        x: progressBar.leftPadding
                        y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: progressBar.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#444444"

                        Rectangle {
                            width: progressBar.visualPosition * parent.width
                            height: parent.height
                            color: mainWindow.plexOrange
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: progressBar.leftPadding + progressBar.visualPosition * (progressBar.availableWidth - width)
                        y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: progressBar.pressed ? "white" : mainWindow.plexOrange
                    }
                }

                // Total Time
                Text {
                    text: mainWindow.formatTime(mpvObject.duration)
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Full Screen Button
                Button {
                    id: fullScreenButton
                    objectName: "fullScreenButton"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    padding: 0
                    text: playerView.isFullScreenMode ? "🗗" : "🖵"
                    font.pixelSize: 24
                    
                    ToolTip.visible: hovered
                    ToolTip.text: playerView.isFullScreenMode ? "Exit Full Screen" : "Full Screen"
                    
                    contentItem: Text {
                        text: fullScreenButton.text
                        font: fullScreenButton.font
                        color: fullScreenButton.hovered ? mainWindow.plexOrange : "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        topPadding: 6
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: mainWindow.toggleFullScreen()
                }
            }
        }
    }
