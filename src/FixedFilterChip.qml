import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string text: "Filter"
    property bool active: false
    property color activeColor: "#E5A00D"
    signal clicked()
    
    height: 32
    width: rowLayout.width + 30
    radius: 16
    color: active ? activeColor : "transparent"
    border.color: active ? "transparent" : "#555"
    border.width: 1

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: root.active
            text: "✓"
            color: "black"
            font.pixelSize: 14
        }
        Text {
            text: root.text
            color: root.active ? "black" : "white"
            font.pixelSize: 14
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
