import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 200
    height: 200
    visible: true

    ListModel {
        id: myModel
        Component.onCompleted: {
            append({"title": "Hello", "ratingKey": "123"})
        }
    }

    ListView {
        anchors.fill: parent
        model: myModel
        delegate: ItemDelegate {
            width: ListView.view.width
            height: 50
            text: model.title !== undefined ? "model.title: " + model.title : "undefined"
            
            contentItem: Text {
                text: parent.text + " | direct: " + (typeof title !== "undefined" ? title : "missing")
            }
        }
    }
}
