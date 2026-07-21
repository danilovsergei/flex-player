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
    property alias mpvObject: mpvObject

    // HDR state management
    property bool hdrWasEnabledByApp: false

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

    Connections {
        target: mpvObject
        function onVideoIsHdrChanged() {
            console.log("PlayerView: videoIsHdr changed to " + mpvObject.videoIsHdr + " (enabledByApp=" + playerView.hdrWasEnabledByApp + ")")
            if (mpvObject.videoIsHdr && playerView.rootApp && playerView.rootApp.appSettings.autoToggleHdr && !playerView.hdrWasEnabledByApp) {
                console.log("PlayerView: HDR video detected, triggering enable command")
                playerView.rootApp.runHdrCommand(playerView.rootApp.appSettings.hdrEnableCommand)
                playerView.hdrWasEnabledByApp = true
            }
        }
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

    // Loading Spinner (Buffering Indicator)
    BusyIndicator {
        id: loadingSpinner
        objectName: "loadingSpinner"
        anchors.centerIn: parent
        width: 80
        height: 80
        running: mpvObject.buffering && playerView.visible
        visible: running
        
        contentItem: Item {
            implicitWidth: 80
            implicitHeight: 80

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = playerView.rootApp ? playerView.rootApp.plexOrange : "#E5A00D";
                    ctx.lineWidth = 6;
                    ctx.beginPath();
                    ctx.arc(40, 40, 30, 0, Math.PI * 1.5);
                    ctx.stroke();
                }
            }

            RotationAnimation {
                target: canvas
                from: 0
                to: 360
                duration: 1000
                running: loadingSpinner.running
                loops: Animation.Infinite
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
            if (mainWindow) mainWindow.toggleFullScreen()
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

        MouseArea {
            objectName: "topControlShield"
            anchors.fill: parent
            hoverEnabled: true
        }

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
                color: backButton.down ? (playerView.rootApp ? playerView.rootApp.plexOrange : "orange") : "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: "transparent"
            }
            onClicked: {
                console.log("PlayerView: Back button clicked. hdrWasEnabledByApp=" + playerView.hdrWasEnabledByApp)
                if (playerView.hdrWasEnabledByApp && playerView.rootApp) {
                    console.log("PlayerView: Disabling system HDR on exit...")
                    playerView.rootApp.runHdrCommand(playerView.rootApp.appSettings.hdrDisableCommand)
                    playerView.hdrWasEnabledByApp = false
                }
                
                mpvObject.command(["stop"])
                playerView.visible = false
                playbackStopped()
                if (playerView.isFullScreenMode && playerView.rootApp) {
                    playerView.rootApp.showNormal()
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

        MouseArea {
            objectName: "bottomControlShield"
            anchors.fill: parent
            hoverEnabled: true
        }

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
                    color: playPauseButton.hovered ? (playerView.rootApp ? playerView.rootApp.plexOrange : "orange") : "white"
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
                    color: playerAudioButton.hovered || playerAudioMenu.opened ? (playerView.rootApp ? playerView.rootApp.plexOrange : "orange") : "white"
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
                    color: playerSubtitleButton.hovered || playerSubtitleMenu.opened ? (playerView.rootApp ? playerView.rootApp.plexOrange : "orange") : "white"
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
                text: playerView.rootApp ? playerView.rootApp.formatTime(mpvObject.position) : "00:00"
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
                        color: playerView.rootApp ? playerView.rootApp.plexOrange : "orange"
                        radius: 3
                    }
                }

                handle: Rectangle {
                    x: progressBar.leftPadding + progressBar.visualPosition * (progressBar.availableWidth - width)
                    y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 8
                    color: progressBar.pressed ? "white" : (playerView.rootApp ? playerView.rootApp.plexOrange : "orange")
                }
            }

            // Total Time
            Text {
                text: playerView.rootApp ? playerView.rootApp.formatTime(mpvObject.duration) : "00:00"
                color: "white"
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Volume Slider Wrapper
            Item {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                
                Slider {
                    id: volumeSlider
                    objectName: "volumeSlider"
                    anchors.fill: parent
                    from: 0
                    to: 100
                    value: mpvObject.volume
                    onValueChanged: {
                        if (mpvObject.volume !== value) {
                            mpvObject.volume = value
                        }
                    }
                    
                    ToolTip.visible: hovered || pressed
                    ToolTip.text: "Volume: " + Math.round(value) + "%"

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: volumeSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#444444"
                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            color: playerView.rootApp ? playerView.rootApp.plexOrange : "orange"
                            radius: 2
                        }
                    }
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: volumeSlider.pressed ? "#FFA000" : "white"
                    }
                }

                MouseArea {
                    objectName: "volumeMouseArea"
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: function(mouse) {
                        var pad = volumeSlider.leftPadding || 0;
                        var aw = volumeSlider.availableWidth || volumeSlider.width;
                        var pos = (mouse.x - pad) / aw;
                        pos = Math.max(0, Math.min(1, pos));
                        var newVal = volumeSlider.from + pos * (volumeSlider.to - volumeSlider.from);
                        console.log("VOLUME MOUSEAREA PRESSED! pos=" + pos + " newVal=" + newVal);
                        mpvObject.volume = newVal;
                        volumeSlider.value = newVal; // Update slider visually too!
                        mouse.accepted = false; // Pass through
                    }
                }
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
                    color: fullScreenButton.hovered ? (playerView.rootApp ? playerView.rootApp.plexOrange : "orange") : "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    topPadding: 6
                }
                background: Rectangle {
                    color: "transparent"
                }
                onClicked: {
                    if (playerView.rootApp) playerView.rootApp.toggleFullScreen()
                }
            }
        }
    }
}

