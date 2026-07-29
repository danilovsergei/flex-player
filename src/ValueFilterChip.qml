import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Rectangle {
    id: root
    
    property string text: "Filter"
    property string filterType: ""
    property string selectedValue: ""
    property string selectedLabel: ""
    property var appCtrl: null
    property var appSet: null
    
    property bool isAdded: false
    visible: isAdded
    
    property bool active: selectedValue !== ""
    property color activeColor: "#E5A00D"
    property int maxPopupWidth: 250
    
    signal valueSelected(string value)
    signal removeClicked()
    
    height: 32
    width: rowLayout.width + 30
    radius: 16
    color: active ? activeColor : "transparent"
    border.color: active ? "transparent" : "#555"
    border.width: 1

    PlexModel {
        id: filterOptionsModel
        connectionManager: appCtrl ? appCtrl.connectionManager : null
    }

    Row {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 8
        
        Item {
            width: innerRow.width
            height: innerRow.height
            
            Row {
                id: innerRow
                spacing: 8
                Text {
                    text: root.active ? (root.text + ": " + root.selectedLabel) : root.text
                    color: root.active ? "black" : "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: "▾"
                    color: root.active ? "black" : "white"
                    font.pixelSize: 14
                }
            }
            
            MouseArea {
                objectName: "chipClickArea"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    filterPopup.open()
                    if (appCtrl && appCtrl.currentLibraryId !== "") {
                        var endpoint = "/library/sections/" + appCtrl.currentLibraryId + "/" + root.filterType
                        var params = []
                        if (appCtrl.currentLibraryType === "show") {
                            params.push("type=2")
                        } else {
                            params.push("type=1")
                        }
                        if (params.length > 0) {
                            endpoint += "?" + params.join("&")
                        }
                        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : (appCtrl.connectionManager.activeUrl !== "" ? appCtrl.connectionManager.activeUrl : appSet.serverUrl);
                        filterOptionsModel.fetchEndpoint(url, appSet.token, endpoint)
                    }
                }
            }
        }
        
        Text {
            text: "✕"
            color: root.active ? "black" : "white"
            font.pixelSize: 14
            font.bold: true
            MouseArea {
                objectName: "chipRemoveArea"
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeClicked()
            }
        }
    }

    Popup {
        id: filterPopup
        y: root.height + 5
        width: root.maxPopupWidth
        height: Math.min(420, contentLayout.implicitHeight + 20)
        padding: 0
        background: Rectangle {
            color: "#222"
            border.color: "#555"
            radius: 8
        }
        
        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0
            
            ListView {
                id: filterListView
                objectName: "filterListView"
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight > 0 ? Math.min(contentHeight, 400) : 0
                clip: true
                model: filterOptionsModel
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 100000
                ScrollBar.vertical: ScrollBar {
                    active: parent.hovered || parent.moving
                    policy: ScrollBar.AsNeeded
                }
                
                delegate: ItemDelegate {
                    objectName: "filterOption_" + index
                    width: implicitWidth
                    height: 40
                    Component.onCompleted: {
                        if (implicitWidth + 20 > root.maxPopupWidth) {
                            root.maxPopupWidth = implicitWidth + 20
                        }
                    }
                    onImplicitWidthChanged: {
                        if (implicitWidth + 20 > root.maxPopupWidth) {
                            root.maxPopupWidth = implicitWidth + 20
                        }
                    }
                    text: model.title !== undefined ? model.title : "" 
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 10
                    }
                    background: Rectangle {
                        width: ListView.view ? ListView.view.width : 0
                        height: 40
                        color: parent.hovered ? "#444" : "transparent"
                    }
                    onClicked: {
                        var val = model.ratingKey !== undefined ? model.ratingKey : ""
                        var lbl = model.title !== undefined ? model.title : ""
                        
                        root.selectedValue = val
                        root.selectedLabel = lbl
                        root.valueSelected(val)
                        filterPopup.close()
                    }
                }
            }
        }
    }
}
