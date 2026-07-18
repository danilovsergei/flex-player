import QtQuick

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

            Column {
                anchors.centerIn: parent
                width: parent.width - 10
                
                Text {
                    width: parent.width
                    text: {
                        var mType = model.type !== undefined ? model.type : type
                        var mTitle = model.title !== undefined ? model.title : title
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
                    width: parent.width
                    text: {
                        var mType = model.type !== undefined ? model.type : type
                        var mTitle = model.title !== undefined ? model.title : title
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
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.scale = 1.05
        onExited: parent.scale = 1.0
        onClicked: {
            root.posterClicked()
            
            var mType = typeof model.type !== 'undefined' ? model.type : type
            var mRatingKey = typeof model.ratingKey !== 'undefined' ? model.ratingKey : ratingKey
            var mTitle = typeof model.title !== 'undefined' ? model.title : title
            var mMediaUrl = typeof model.mediaUrl !== 'undefined' ? model.mediaUrl : mediaUrl
            var mViewOffset = typeof model.viewOffset !== 'undefined' ? model.viewOffset : viewOffset
            
            if (mType === "collection") {
                root.openCollection(mRatingKey)
            } else if (mType === "show" || mType === "season") {
                root.openShow(mRatingKey)
            } else {
                var urlToPlay = mMediaUrl ? mMediaUrl : ""
                var mDuration = typeof model.duration !== 'undefined' ? model.duration : duration
                root.playMedia(mTitle, urlToPlay, mViewOffset, mRatingKey, mDuration)
            }
        }
    }
    
    Behavior on scale {
        NumberAnimation { duration: 150 }
    }
}
