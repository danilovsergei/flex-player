import sys

def change_listview_to_repeater(path):
    import os
    os.system("git checkout " + path)

    with open(path, 'r') as f:
        content = f.read()

    old_text = r"""                    ListView {
                        id: serverLibrariesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: localServersList.filter(function(s) { return s.enabled })
                        clip: true
                        spacing: 30
                        delegate: ColumnLayout {"""

    new_text = r"""                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: librariesColLayout.implicitHeight
                        clip: true
                        
                        ColumnLayout {
                            id: librariesColLayout
                            width: parent.width
                            spacing: 30
                            
                            Repeater {
                                id: serverLibrariesList
                                objectName: "serverLibrariesList"
                                model: localServersList.filter(function(s) { return s.enabled })
                                delegate: ColumnLayout {"""

    # We also need to fix `width: serverLibrariesList.width` inside the delegate
    content = content.replace(old_text, new_text, 1)
    content = content.replace("width: serverLibrariesList.width", "width: librariesColLayout.width", 1)

    # And add the closing brace for Flickable
    old_end = r"""                            Rectangle { Layout.fillWidth: true; height: 1; color: "#333333"; Layout.topMargin: 10 }
                        }
                    }
                    RowLayout {"""

    new_end = r"""                            Rectangle { Layout.fillWidth: true; height: 1; color: "#333333"; Layout.topMargin: 10 }
                        }
                            }
                        }
                    }
                    RowLayout {"""

    content = content.replace(old_end, new_end, 1)

    with open(path, 'w') as f:
        f.write(content)

change_listview_to_repeater('/home/geonix/Build/flex_player/src/SettingsWindow.qml')

