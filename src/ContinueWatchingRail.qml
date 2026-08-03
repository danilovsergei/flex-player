import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

ColumnLayout {
    id: cwRoot

    ServerOfflineOverlay {
        connectionManager: cwRoot.rootApp ? cwRoot.rootApp.controller.connectionManager : null
        serverName: cwRoot.serverName
    }

    Layout.preferredWidth: 1200
    objectName: "continueWatchingRail_" + serverName
    property var rootApp
    property string serverName: ""
    property string serverUrl: ""
    property string serverToken: ""
    property Component movieDelegate
    property bool hasItems: delegateCwList.count > 0

    spacing: 10

    PlexModel {
        id: delegateCwModel
        objectName: "delegateCwModel"
    }

    function refresh() {
        var activeUrl = serverUrl !== "" ? serverUrl : (rootApp.controller.connectionManager ? rootApp.controller.connectionManager.activeUrl : "");
        if (activeUrl !== "") {
            delegateCwModel.fetchEndpoint(activeUrl, serverToken !== "" ? serverToken : rootApp.appSettings.token, "/library/onDeck");
        } else {
            retryTimer.restart();
        }
    }

    onRootAppChanged: refresh()
    Connections {
        target: rootApp && rootApp.controller.connectionManager ? rootApp.controller.connectionManager : null
        function onActiveUrlChanged() { cwRoot.refresh() }
    }
    onServerUrlChanged: refresh()
    
    Timer {
        id: retryTimer
        interval: 1000
        repeat: false
        onTriggered: cwRoot.refresh()
    }

    Component.onCompleted: refresh()

    Text {
        text: "Continue Watching" + (serverName !== "" ? " (" + serverName + ")" : "")
        color: "white"
        font.pixelSize: 24
        font.bold: true
        Layout.topMargin: 20
        Layout.leftMargin: 20
        visible: delegateCwList.count > 0
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 330
        Layout.leftMargin: 20
        visible: delegateCwList.count > 0

        ListView {
            id: delegateCwList
            objectName: "continueWatchingList"
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 20
            model: delegateCwModel
            delegate: movieDelegate
            clip: true
            interactive: false
            
            Behavior on contentX {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }
        }

        HoverHandler { id: delegateCwHover }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 50
            color: delegateCwLeftHover.hovered ? "#CC000000" : "#80000000"
            visible: delegateCwList.contentX > 0
            opacity: delegateCwHover.hovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: "❮"
                color: (rootApp && delegateCwLeftHover.hovered) ? rootApp.plexOrange : "white"
                font.pixelSize: 32
                font.bold: true
            }
            
            HoverHandler { id: delegateCwLeftHover }
            MouseArea {
                anchors.fill: parent
                onClicked: delegateCwList.contentX = Math.max(0, delegateCwList.contentX - 880)
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 50
            color: delegateCwRightHover.hovered ? "#CC000000" : "#80000000"
            visible: delegateCwList.contentWidth > delegateCwList.width && delegateCwList.contentX < (delegateCwList.contentWidth - delegateCwList.width)
            opacity: delegateCwHover.hovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: "❯"
                color: (rootApp && delegateCwRightHover.hovered) ? rootApp.plexOrange : "white"
                font.pixelSize: 32
                font.bold: true
            }
            
            HoverHandler { id: delegateCwRightHover }
            MouseArea {
                anchors.fill: parent
                onClicked: delegateCwList.contentX = Math.min(delegateCwList.contentWidth - delegateCwList.width, delegateCwList.contentX + 880)
            }
        }
    }
}
