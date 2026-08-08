import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: root
    width: 300
    height: 250
    visible: true
    color: "black"

    FlexComboBox {
        id: cb
        x: 20; y: 20
        width: 200; height: 40
        model: {
            var v = [];
            v.push("Auto (Responsive)");
            v.push("Vertical");
            v.push("Horizontal");
            return v;
        }
        currentIndex: 0
        Component.onCompleted: cb.popup.open()
    }

    Timer {
        interval: 1000; running: true; repeat: false
        onTriggered: {
            var lv = cb.popup.contentItem;
            console.log("popup contentItem:", lv);
            for (var i = 0; i < lv.count; i++) {
                var d = lv.itemAtIndex(i);
                console.log("delegate", i, "type:", d, "color:", d.color);
                for (var c = 0; c < d.children.length; c++) {
                    var ch = d.children[c];
                    console.log("   child", c, ch, "color:", ch.color, "text:", ch.text);
                }
            }
            Qt.quit();
        }
    }
}
