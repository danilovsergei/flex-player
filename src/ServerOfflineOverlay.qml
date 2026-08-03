import QtQuick
import QtQuick.Controls

Item {
    id: wrapper
    width: 0; height: 0; z: 999
    
    property string serverName: ""
    property var serverNode: null
    property var connectionManager: null

    onServerNameChanged: updateNode()
    
    function updateNode() {
        if (serverName !== "" && connectionManager) {
            serverNode = connectionManager.getServer(serverName)
        } else if (serverName !== "" && typeof mainWindow !== "undefined" && mainWindow.controller && mainWindow.controller.connectionManager) {
            serverNode = mainWindow.controller.connectionManager.getServer(serverName)
        }
    }
    
    Component.onCompleted: updateNode()

    Rectangle {
        id: overlayRect
        x: wrapper.parent ? -wrapper.x : 0
        y: wrapper.parent ? -wrapper.y : 0
        width: wrapper.parent ? wrapper.parent.width : 0
        height: wrapper.parent ? wrapper.parent.height : 0
        
        color: "#E6000000" // Dim the content deeply
        visible: serverNode !== null && !serverNode.isOnline
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true // Block clicks
            onWheel: function(wheel) { wheel.accepted = true } // Block scrolling
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 15
            
            Text {
                text: "❌"
                color: "white"
                font.pixelSize: 64
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: wrapper.serverName ? "Server Offline: " + wrapper.serverName : "Server Offline"
                color: "white"
                font.pixelSize: 28
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "This content is currently unavailable."
                color: "#aaaaaa"
                font.pixelSize: 18
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
