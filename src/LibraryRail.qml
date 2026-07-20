import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

ColumnLayout {
    id: railRoot
    objectName: "libraryRail_" + libraryId
    property var rootApp
    property string libraryTitle: ""
    property string libraryId: ""
    property string libraryType: ""
    
    property string lastFetchedEndpoint: ""

    spacing: 10

    PlexModel {
        id: delegateRecentModel
        objectName: "delegateRecentModel"
        onModelReset: {
            console.log("LibraryRail [" + libraryTitle + "]: model reset, count: " + rowCount());
        }
    }

    function refresh() {
        if (!rootApp || !libraryId || libraryId === "" || libraryId === "undefined") {
            return;
        }
        
        var endpoint = "";
        if (libraryType === "show") {
            // RE-USE the exact logic from Series page: Shows sorted by added date
            endpoint = "/library/sections/" + libraryId + "/all?type=2&sort=addedAt:desc";
        } else {
            endpoint = "/library/sections/" + libraryId + "/recentlyAdded";
        }
        
        lastFetchedEndpoint = endpoint;
        
        if (rootApp.isTestMode) {
            console.log("LibraryRail [" + libraryTitle + "]: Test mode, endpoint would be: " + endpoint);
            return;
        }

        if (rootApp.serverUrl && rootApp.serverUrl !== "") {
            console.log("LibraryRail [" + libraryTitle + "] (Type: " + libraryType + "): Fetching from " + endpoint);
            delegateRecentModel.fetchEndpoint(rootApp.serverUrl, rootApp.token, endpoint);
        } else {
            retryTimer.restart();
        }
    }

    onRootAppChanged: refresh()
    onLibraryIdChanged: refresh()
    onLibraryTypeChanged: refresh()
    onLibraryTitleChanged: refresh()
    
    Timer {
        id: retryTimer
        interval: 1000
        repeat: false
        onTriggered: railRoot.refresh()
    }

    Component.onCompleted: refresh()

    Text {
        text: "Recently Added in " + libraryTitle
        color: "white"
        font.pixelSize: 22
        font.bold: true
        Layout.leftMargin: 20
        visible: delegateRecentList.count > 0
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 330
        Layout.leftMargin: 20
        visible: delegateRecentList.count > 0

        ListView {
            id: delegateRecentList
            objectName: "recentlyAddedList"
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 20
            model: delegateRecentModel
            delegate: rootApp ? rootApp.globalMovieDelegate : null
            clip: true
            interactive: false
            
            Behavior on contentX {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }
        }

        HoverHandler { id: delegateRecentHover }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 50
            color: delegateRecentLeftHover.hovered ? "#CC000000" : "#80000000"
            visible: delegateRecentList.contentX > 0
            opacity: delegateRecentHover.hovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: "❮"
                color: (rootApp && delegateRecentLeftHover.hovered) ? rootApp.plexOrange : "white"
                font.pixelSize: 32
                font.bold: true
            }
            
            HoverHandler { id: delegateRecentLeftHover }
            MouseArea {
                anchors.fill: parent
                onClicked: delegateRecentList.contentX = Math.max(0, delegateRecentList.contentX - 880)
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 50
            color: delegateRecentRightHover.hovered ? "#CC000000" : "#80000000"
            visible: delegateRecentList.contentWidth > delegateRecentList.width && delegateRecentList.contentX < (delegateRecentList.contentWidth - delegateRecentList.width)
            opacity: delegateRecentHover.hovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: "❯"
                color: (rootApp && delegateRecentRightHover.hovered) ? rootApp.plexOrange : "white"
                font.pixelSize: 32
                font.bold: true
            }
            
            HoverHandler { id: delegateRecentRightHover }
            MouseArea {
                anchors.fill: parent
                onClicked: delegateRecentList.contentX = Math.min(delegateRecentList.contentWidth - delegateRecentList.width, delegateRecentList.contentX + 880)
            }
        }
    }
}
