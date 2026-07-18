import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Rectangle {
                property var mainWindow
                                Layout.preferredWidth: mainWindow.sidebarCollapsed ? 60 : 200
                Layout.fillHeight: true
                color: "#151515"
                objectName: "sidebar"
                
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 150 }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: mainWindow.sidebarCollapsed ? 10 : 20
                    spacing: 15

                    Text {
                        text: mainWindow.sidebarCollapsed ? "F" : "FLEX"
                        color: mainWindow.plexOrange
                        font.pixelSize: mainWindow.sidebarCollapsed ? 20 : 28
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 30
                    }

                    Button {
                        text: mainWindow.sidebarCollapsed ? "🏠" : "Home"
                        objectName: "homeTabButton"
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: mainWindow.currentTab === 0 ? mainWindow.plexOrange : "white"
                            font.pixelSize: 18
                            font.bold: mainWindow.currentTab === 0
                            horizontalAlignment: mainWindow.sidebarCollapsed ? Text.AlignHCenter : Text.AlignLeft
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: mainWindow.currentTab = 0
                    }

                    Repeater {
                        model: mainWindow.testAllLibrariesModel ? mainWindow.testAllLibrariesModel : mainWindow.allLibrariesModel
                        delegate: Button {
                            // Only show if enabled in settings
                            visible: {
                                var enabledMap = JSON.parse(appSettings.enabledLibraries || "{}");
                                return enabledMap[model.ratingKey] !== undefined && enabledMap[model.ratingKey] !== null && enabledMap[model.ratingKey] !== false;
                            }
                            Layout.preferredHeight: visible ? 40 : 0
                            
                            text: mainWindow.sidebarCollapsed ? mainWindow.getLibraryIcon(model.type) : mainWindow.getLibraryIcon(model.type) + " " + model.title
                            objectName: "libTabButton_" + model.ratingKey
                            Layout.fillWidth: true
                            contentItem: Text {
                                text: parent.text
                                color: (mainWindow.currentTab === 1 || mainWindow.currentTab === 2) && mainWindow.currentLibraryId === model.ratingKey ? mainWindow.plexOrange : "white"
                                font.pixelSize: 18
                                font.bold: (mainWindow.currentTab === 1 || mainWindow.currentTab === 2) && mainWindow.currentLibraryId === model.ratingKey
                                horizontalAlignment: mainWindow.sidebarCollapsed ? Text.AlignHCenter : Text.AlignLeft
                            }
                            background: Rectangle { color: "transparent" }
                            onClicked: {
                                mainWindow.loadLibraryContent(model.ratingKey, model.title, model.type)
                                mainWindow.currentTab = 1 // Switch to library Recommend view
                            }
                        }
                    }

                    Item { Layout.fillHeight: true } // Spacer
                }
            }
