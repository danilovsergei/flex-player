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

        signal playbackStopped()
        signal timelineUpdateRequested(string state, int timeMs)

        function playMedia(url, offset, ratingKey, duration) {
            currentRatingKey = ratingKey !== undefined ? ratingKey : ""
            currentDuration = duration !== undefined ? duration : 0

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
                text: "Back"
                font.bold: true
                font.pixelSize: 16
                contentItem: Text {
                    text: backButton.text
                    font: backButton.font
                    color: backButton.down ? mainWindow.plexOrange : "white"
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
