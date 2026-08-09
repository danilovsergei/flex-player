import QtQuick
import QtQuick.Controls

Item {
    // When true, UI elements sensitive to mouse hover (like the Three-Dots button)
    // are forced to be visible. This is essential for headless testing where
    // mouse movements are not always reliably processed by the compositor.
    property bool isTestMode: false
    property bool mIsWatched: (typeof model !== "undefined" && model.isWatched !== undefined) ? model.isWatched : ((typeof isWatched !== "undefined") ? isWatched : false)
    property int mLeafCount: (typeof model !== "undefined" && model.leafCount !== undefined) ? model.leafCount : ((typeof leafCount !== "undefined") ? leafCount : 0)
    property int mViewedLeafCount: (typeof model !== "undefined" && model.viewedLeafCount !== undefined) ? model.viewedLeafCount : ((typeof viewedLeafCount !== "undefined") ? viewedLeafCount : 0)

    id: root
    width: 200
    height: 300
    objectName: "movieItem"

    property color plexOrange: "#E5A00D"
    property alias contextMenu: contextMenu

    signal posterClicked()
    signal openCollection(string ratingKey, string serverUrl, string serverToken)
    signal openShow(string ratingKey, string serverUrl, string serverToken)
    signal playMedia(string title, string mediaUrl, int viewOffset, string ratingKey, int duration)
    signal openDetails(string ratingKey, string serverUrl, string serverToken)
    signal deleteCollectionRequested(string ratingKey, string serverUrl)
    signal editSmartCollectionRequested(string ratingKey, string title, string content, string serverUrl)
    signal openAlbum(string ratingKey, string serverUrl, string serverToken)
    signal openArtist(string ratingKey, string serverUrl, string serverToken)
    signal openPlaylist(string ratingKey, string serverUrl, string serverToken)

    Rectangle {
        anchors.fill: parent
        color: "#2e2e2e"
        radius: 8
        clip: true

        Image {
            anchors.fill: parent
            property string rawUrl: (typeof model !== "undefined" && model.thumbUrl) !== undefined ? (typeof model !== "undefined" && model.thumbUrl) : thumbUrl
            source: rawUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            id: titleRect
            anchors.bottom: parent.bottom
            width: parent.width
            height: {
                var mType = (typeof model !== "undefined" && model.type !== undefined) ? model.type : type
                return (mType === "show" || mType === "season" || mType === "album") ? 50 : 40
            }
            color: "#cc000000"

            Column {
                anchors.centerIn: parent
                width: parent.width - 10
                
                Text {
                    id: posterTitleText
                    objectName: "posterTitle"
                    width: parent.width
                    text: {
                        var mType = (typeof model !== "undefined" && model.type !== undefined) ? model.type : type
                        var mTitle = (typeof model !== "undefined" && model.title !== undefined) ? model.title : title
                        if (mType === "episode" && (typeof model !== "undefined" && model.grandparentTitle)) {
                            return (typeof model !== "undefined" && model.grandparentTitle) + " - S" + (typeof model !== "undefined" && model.parentIndex)
                        }
                        if (mType === "album") {
                            var mParentTitle = (typeof model !== "undefined" && model.parentTitle !== undefined) ? model.parentTitle : ""
                            return mParentTitle !== "" ? mParentTitle : mTitle
                        }
                        if (mType === "playlist") {
                            var mDuration = (typeof model !== "undefined" && model.duration !== undefined) ? model.duration : ((typeof duration !== "undefined") ? duration : 0)
                            if (mDuration > 0) {
                                var totalMinutes = Math.floor(mDuration / 60000);
                                var hours = Math.floor(totalMinutes / 60);
                                var minutes = totalMinutes % 60;
                                var durStr = hours > 0 ? (hours + "h" + minutes + "min") : (minutes + "min");
                                return mTitle + " - " + durStr;
                            }
                        }
                        return mType === "season" && (typeof model !== "undefined" && model.parentTitle) ? (typeof model !== "undefined" && model.parentTitle) : mTitle
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
                        var mType = (typeof model !== "undefined" && model.type !== undefined) ? model.type : type
                        var mTitle = (typeof model !== "undefined" && model.title !== undefined) ? model.title : title
                        if (mType === "episode") {
                            return mTitle + " - E" + (typeof model !== "undefined" && model.index)
                        }
                        if (mType === "album") {
                            var mParentTitle = (typeof model !== "undefined" && model.parentTitle !== undefined) ? model.parentTitle : ""
                            var mYear = (typeof model !== "undefined" && model.year !== undefined) ? model.year : 0
                            var line2 = mParentTitle !== "" ? mTitle : ""
                            if (line2 !== "" && mYear > 0) {
                                line2 += " (" + mYear + ")"
                            } else if (line2 === "" && mYear > 0) {
                                line2 = mTitle + " (" + mYear + ")"
                            }
                            return line2
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
                width: ((typeof model !== "undefined" && model.duration) > 0 && (typeof model !== "undefined" && model.viewOffset) > 0) ? ((typeof model !== "undefined" && model.viewOffset) / (typeof model !== "undefined" && model.duration)) * parent.width : 0
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
                var mType = ""
                try { if (model && model.type !== undefined) mType = model.type; else mType = type; } catch(e) { mType = type; }
                return ((mType === "show" || mType === "season") || mType === "playlist") && root.mLeafCount > 0
            }

            Text {
                id: episodeCountText
                objectName: "episodeCountText"
                anchors.centerIn: parent
                text: {
                    var mType = ""
                    try { if (model && model.type !== undefined) mType = model.type; else mType = type; } catch(e) { mType = type; }
                    if (mType === "playlist") return root.mLeafCount.toString()
                    return root.mViewedLeafCount + "/" + root.mLeafCount
                }
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
            visible: root.mIsWatched

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
            visible: {
                var mType = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.type) !== 'undefined' ? (typeof model !== "undefined" && model.type) : type
                return mType !== "collection"
            }
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
                var mRatingKey = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.ratingKey) !== 'undefined' ? (typeof model !== "undefined" && model.ratingKey) : ratingKey
                var mServerUrl = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverUrl) !== 'undefined' ? (typeof model !== "undefined" && model.serverUrl) : serverUrl
                var mServerToken = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverToken) !== 'undefined' ? (typeof model !== "undefined" && model.serverToken) : ""
                root.openDetails(mRatingKey, mServerUrl, mServerToken)
            }
        }
        
        MenuItem {
            id: editFilterMenuItem
            text: "Edit Filter"
            objectName: "editFilterMenuItem"
            visible: {
                var mType = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.type) !== 'undefined' ? (typeof model !== "undefined" && model.type) : type
                var mSmart = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.smart) !== 'undefined' ? (typeof model !== "undefined" && model.smart) : smart
                var mServerToken = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverToken) !== 'undefined' ? (typeof model !== "undefined" && model.serverToken) : ""
                var isGlobal = (mServerToken === "" || (typeof appSettings !== 'undefined' && mServerToken === appSettings.token))
                return mType === "collection" && mSmart && isGlobal
            }
            contentItem: Text {
                text: editFilterMenuItem.text
                color: "#E5A00D"
                font.pixelSize: 16
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: editFilterMenuItem.highlighted ? "#444444" : "transparent"
                radius: 4
            }
            onTriggered: {
                var mRatingKey = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.ratingKey) !== 'undefined' ? (typeof model !== "undefined" && model.ratingKey) : ratingKey
                var mTitle = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.title) !== 'undefined' ? (typeof model !== "undefined" && model.title) : title
                var mContent = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.content) !== 'undefined' ? (typeof model !== "undefined" && model.content) : content
                var mServerUrl = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverUrl) !== 'undefined' ? (typeof model !== "undefined" && model.serverUrl) : serverUrl
                var mServerToken = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverToken) !== 'undefined' ? (typeof model !== "undefined" && model.serverToken) : ""
                console.warn('Firing editSmartCollectionRequested for ' + mRatingKey + ' with content ' + mContent);
                root.editSmartCollectionRequested(mRatingKey, mTitle, mContent, mServerUrl)
            }
        }
        
        MenuItem {
            id: deleteCollectionMenuItem
            text: "Delete Collection"
            objectName: "deleteCollectionMenuItem"
            visible: {
                var mType = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.type) !== 'undefined' ? (typeof model !== "undefined" && model.type) : type
                var mServerToken = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverToken) !== 'undefined' ? (typeof model !== "undefined" && model.serverToken) : ""
                var isGlobal = (mServerToken === "" || (typeof appSettings !== 'undefined' && mServerToken === appSettings.token))
                return mType === "collection" && isGlobal
            }
            contentItem: Text {
                text: deleteCollectionMenuItem.text
                color: "#E53935"
                font.pixelSize: 16
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: deleteCollectionMenuItem.highlighted ? "#444444" : "transparent"
                radius: 4
            }
            onTriggered: {
                var mRatingKey = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.ratingKey) !== 'undefined' ? (typeof model !== "undefined" && model.ratingKey) : ratingKey
                var mServerUrl = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverUrl) !== 'undefined' ? (typeof model !== "undefined" && model.serverUrl) : serverUrl
                var mServerToken = typeof model !== 'undefined' && typeof (typeof model !== "undefined" && model.serverToken) !== 'undefined' ? (typeof model !== "undefined" && model.serverToken) : ""
                root.deleteCollectionRequested(mRatingKey, mServerUrl)
            }
        }
    }

    ToolTip {
        id: posterToolTip
        objectName: "posterToolTip"
        parent: Overlay.overlay
        z: 1000
        x: posterMouseArea.mapToItem(null, posterMouseArea.mouseX, posterMouseArea.mouseY).x + 15
        y: posterMouseArea.mapToItem(null, posterMouseArea.mouseX, posterMouseArea.mouseY).y + 15
        visible: posterMouseArea.containsMouse && posterMouseArea.mouseY >= (root.height - titleRect.height)
        delay: 500
        text: posterTitleText.text
        
        padding: 10
        width: toolTipText.implicitWidth + leftPadding + rightPadding
        height: toolTipText.implicitHeight + topPadding + bottomPadding

        contentItem: Text {
            id: toolTipText
            text: posterToolTip.text
            color: plexOrange
            font.pixelSize: 14
            font.bold: true
            wrapMode: Text.NoWrap
        }
        
        background: Rectangle {
            anchors.fill: parent
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
                if (typeof model !== "undefined" && (typeof model !== "undefined" && model.type !== undefined)) mType = model.type
                else if (typeof type !== "undefined") mType = type
                console.warn("MoviePosterDelegate clicked! Resolved mType is: " + mType);
                
                var mRatingKey = ""
                if (typeof model !== "undefined" && (typeof model !== "undefined" && model.ratingKey) !== undefined) mRatingKey = (typeof model !== "undefined" && model.ratingKey)
                else if (typeof ratingKey !== "undefined") mRatingKey = ratingKey
                
                var mTitle = ""
                if (typeof model !== "undefined" && (typeof model !== "undefined" && model.title !== undefined)) mTitle = model.title
                else if (typeof title !== "undefined") mTitle = title
                
                var mMediaUrl = ""
                if (typeof model !== "undefined" && model.mediaUrl !== undefined) mMediaUrl = model.mediaUrl
                else if (typeof mediaUrl !== "undefined") mMediaUrl = mediaUrl
                
                var mViewOffset = 0
                if (typeof model !== "undefined" && (typeof model !== "undefined" && model.viewOffset) !== undefined) mViewOffset = (typeof model !== "undefined" && model.viewOffset)
                else if (typeof viewOffset !== "undefined") mViewOffset = viewOffset
                
                var mServerUrl = ""
                if (typeof model !== "undefined" && model.serverUrl !== undefined) mServerUrl = model.serverUrl
                else if (typeof serverUrl !== "undefined") mServerUrl = serverUrl
                
                var mServerToken = ""
                if (typeof model !== "undefined" && model.serverToken !== undefined) mServerToken = model.serverToken
                else if (typeof serverToken !== "undefined") mServerToken = serverToken
                
                console.log("MoviePoster clicked! mType=" + mType + " mRatingKey=" + mRatingKey + " mServerUrl=" + mServerUrl + " token: " + (mServerToken ? "custom" : "none"))
                
                if (mType === "collection") {
                    root.openCollection(mRatingKey, mServerUrl, mServerToken)
                } else if (mType === "show" || mType === "season") {
                    root.openShow(mRatingKey, mServerUrl, mServerToken)
                } else if (mType === "artist") {
                    root.openArtist(mRatingKey, mServerUrl, mServerToken)
                } else if (mType === "album") {
                    root.openAlbum(mRatingKey, mServerUrl, mServerToken)
                } else if (mType === "playlist") {
                    root.openPlaylist(mRatingKey, mServerUrl, mServerToken)
                } else {
                    root.openDetails(mRatingKey, mServerUrl, mServerToken)
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
        visible: isTestMode ? true : (posterMouseArea.containsMouse || contextMenu.opened || threeDotsMouseArea.containsMouse)
        
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