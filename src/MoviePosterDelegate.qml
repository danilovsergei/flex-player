import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 200
    height: 300
    objectName: "movieItem"

    property color plexOrange: "#E5A00D"

    signal posterClicked()
    signal openCollection(string ratingKey)
    signal openShow(string ratingKey)
    signal playMedia(string title, string mediaUrl, int viewOffset, string ratingKey, int duration)
    signal openDetails(string ratingKey)

    Rectangle {
        anchors.fill: parent
        color: "#2e2e2e"
        radius: 8
        clip: true

        Image {
            anchors.fill: parent
            source: model.thumbUrl !== undefined ? model.thumbUrl : thumbUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: {
                var mType = model.type !== undefined ? model.type : type
                return (mType === "show" || mType === "season") ? 50 : 40
            }
            color: "#cc000000"

            HoverHandler {
                id: titleHover
                objectName: "titleHover"
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 10
                
                Text {
                    id: posterTitleText
                    objectName: "posterTitle"
                    width: parent.width
                    text: {
                        var mType = model.type !== undefined ? model.type : type
                        var mTitle = model.title !== undefined ? model.title : title
                        if (mType === "episode" && model.grandparentTitle) {
                            return model.grandparentTitle + " - S" + model.parentIndex
                        }
                        return mType === "season" && model.parentTitle ? model.parentTitle : mTitle
                    }
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    objectName: "posterSubTitle"
                    width: parent.width
                    text: {
                        var mType = model.type !== undefined ? model.type : type
                        var mTitle = model.title !== undefined ? model.title : title
                        if (mType === "episode") {
                            return mTitle + " - E" + model.index
                        }
                        return mType === "season" ? mTitle : (mType === "show" ? model.childCount + " Season" + (model.childCount !== 1 ? "s" : "") : "")
                    }
                    color: "gray"
                    font.pixelSize: 12
                    visible: text !== ""
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                height: 4
                width: (model.duration > 0 && model.viewOffset > 0) ? (model.viewOffset / model.duration) * parent.width : 0
                color: plexOrange
                visible: width > 0
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
            width: episodeCountText.width + 12
            height: 24
            radius: 4
            color: "#b3000000"
            visible: {
                var mType = model.type !== undefined ? model.type : type
                return (mType === "show" || mType === "season") && model.leafCount > 0
            }

            Text {
                id: episodeCountText
                anchors.centerIn: parent
                text: model.viewedLeafCount + "/" + model.leafCount
                color: "white"
                font.pixelSize: 14
                font.bold: true
            }
        }

        Rectangle {
            objectName: "watchedCheckmark"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            width: 24
            height: 24
            radius: 12
            color: plexOrange
            visible: model.isWatched !== undefined ? model.isWatched : false

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
        }


    }
    
    Menu {
        id: contextMenu
        objectName: "contextMenu"
        background: Rectangle {
            color: "#222222"
            radius: 4
            border.color: "#444444"
        }
        MenuItem {
            id: detailsMenuItem
            text: "Details"
            objectName: "detailsMenuItem"
            contentItem: Text {
                text: detailsMenuItem.text
                color: "#E5A00D"
                font.pixelSize: 16
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: detailsMenuItem.highlighted ? "#444444" : "transparent"
                radius: 4
            }
            onTriggered: {
                var mRatingKey = typeof model !== 'undefined' && typeof model.ratingKey !== 'undefined' ? model.ratingKey : ratingKey
                root.openDetails(mRatingKey)
            }
        }
    }

    ToolTip {
        id: posterToolTip
        objectName: "posterToolTip"
        parent: Overlay.overlay
        x: posterMouseArea.mapToItem(null, posterMouseArea.mouseX, posterMouseArea.mouseY).x + 15
        y: posterMouseArea.mapToItem(null, posterMouseArea.mouseX, posterMouseArea.mouseY).y + 15
        visible: titleHover.hovered
        delay: 500
        text: posterTitleText.text
        padding: 8
        contentItem: Text {
            text: posterToolTip.text
            color: plexOrange
            font.pixelSize: 14
            font.bold: true
        }
        background: Rectangle {
            color: "black"
            radius: 4
            border.color: "#444444"
            border.width: 1
        }
    }

    MouseArea {
        id: posterMouseArea
        objectName: "posterMouseArea"
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: parent.scale = 1.05
        onExited: parent.scale = 1.0
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
                return
            }
            root.posterClicked()
            
            try {
                var mType = ""
                if (typeof model !== "undefined" && model.type !== undefined) mType = model.type
                else if (typeof type !== "undefined") mType = type
                
                var mRatingKey = ""
                if (typeof model !== "undefined" && model.ratingKey !== undefined) mRatingKey = model.ratingKey
                else if (typeof ratingKey !== "undefined") mRatingKey = ratingKey
                
                var mTitle = ""
                if (typeof model !== "undefined" && model.title !== undefined) mTitle = model.title
                else if (typeof title !== "undefined") mTitle = title
                
                var mMediaUrl = ""
                if (typeof model !== "undefined" && model.mediaUrl !== undefined) mMediaUrl = model.mediaUrl
                else if (typeof mediaUrl !== "undefined") mMediaUrl = mediaUrl
                
                var mViewOffset = 0
                if (typeof model !== "undefined" && model.viewOffset !== undefined) mViewOffset = model.viewOffset
                else if (typeof viewOffset !== "undefined") mViewOffset = viewOffset
                
                if (mType === "collection") {
                    root.openCollection(mRatingKey)
                } else if (mType === "show" || mType === "season") {
                    root.openShow(mRatingKey)
                } else {
                    var urlToPlay = mMediaUrl ? mMediaUrl : ""
                    var mDuration = 0
                    if (typeof model !== "undefined" && model.duration !== undefined) mDuration = model.duration
                    else if (typeof duration !== "undefined") mDuration = duration
                    root.playMedia(mTitle, urlToPlay, mViewOffset, mRatingKey, mDuration)
                }
            } catch(e) {
                console.log("Error in poster click:", e)
            }
        }
    }

    Rectangle {
        id: threeDotsButton
        objectName: "threeDotsButton"
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: 32
        height: 32
        radius: 16
        color: "#88000000"
        border.color: "transparent"
        visible: posterMouseArea.containsMouse || contextMenu.opened || threeDotsMouseArea.containsMouse
        
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -3
            text: "⋮"
            color: "white"
            font.pixelSize: 20
            font.bold: true
        }

        MouseArea {
            id: threeDotsMouseArea
            objectName: "threeDotsMouseArea"
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.color = "#E5A00D"
            onExited: parent.color = "#88000000"
            onClicked: function(mouse) {
                contextMenu.popup(threeDotsButton, 0, threeDotsButton.height)
            }
        }
    }
    
    Behavior on scale {
        NumberAnimation { duration: 150 }
    }
}