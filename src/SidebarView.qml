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

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 30
                        spacing: 10
                        
                        Image {
                            source: "../assets/flex_icon.svg"
                            sourceSize.width: mainWindow.sidebarCollapsed ? 48 : 64
                            sourceSize.height: mainWindow.sidebarCollapsed ? 48 : 64
                            fillMode: Image.PreserveAspectFit
                        }
                        
                        Text {
                            text: "FLEX"
                            color: mainWindow.plexOrange
                            font.pixelSize: 28
                            font.bold: true
                            visible: !mainWindow.sidebarCollapsed
                        }
                    }

                    Button {
                        text: mainWindow.sidebarCollapsed ? "🏠" : "🏠 Home"
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
                        id: sidebarLibraryRepeater
                        objectName: "sidebarLibraryRepeater"
                        model: mainWindow.controller ? mainWindow.controller.homeLibrariesList : []
                        delegate: Button {
                            visible: true
                            Layout.preferredHeight: 40
                            
                            text: {
                                var sName = (typeof modelData !== 'undefined' && modelData.serverName) ? " (" + modelData.serverName + ")" : ((typeof model !== 'undefined' && model.serverName) ? " (" + model.serverName + ")" : "");
                                var mType = (typeof modelData !== 'undefined' && modelData.type) ? modelData.type : model.type;
                                var mTitle = (typeof modelData !== 'undefined' && modelData.title) ? modelData.title : model.title;
                                return mainWindow.sidebarCollapsed ? mainWindow.getLibraryIcon(mType) : mainWindow.getLibraryIcon(mType) + " " + mTitle + sName;
                            }
                            
                            property string mUniqueId: (typeof modelData !== 'undefined' && modelData.uniqueId) ? modelData.uniqueId : ((typeof modelData !== 'undefined' && modelData.id) ? modelData.id : model.ratingKey)
                            property string mId: (typeof modelData !== 'undefined' && modelData.id) ? modelData.id : model.ratingKey
                            property string mType: (typeof modelData !== 'undefined' && modelData.type) ? modelData.type : model.type
                            property string mTitle: (typeof modelData !== 'undefined' && modelData.title) ? modelData.title : model.title
                            property string mServerUrl: (typeof modelData !== 'undefined' && modelData.serverUrl) ? modelData.serverUrl : ((typeof model !== 'undefined' && model.serverUrl) ? model.serverUrl : "")
                            property string mServerToken: (typeof modelData !== 'undefined' && modelData.serverToken) ? modelData.serverToken : ((typeof model !== 'undefined' && model.serverToken) ? model.serverToken : "")
                            
                            objectName: "libTabButton_" + mUniqueId
                            Layout.fillWidth: true
                            contentItem: Text {
                                text: parent.text
                                color: (mainWindow.currentTab === 1 || mainWindow.currentTab === 2 || mainWindow.currentTab === 3 || mainWindow.currentTab === 4 || mainWindow.currentTab === 5) && mainWindow.controller && mainWindow.controller.currentLibraryUniqueId && mainWindow.controller.currentLibraryUniqueId.toString() === mUniqueId.toString() ? mainWindow.plexOrange : "white"
                                font.pixelSize: 18
                                font.bold: (mainWindow.currentTab === 1 || mainWindow.currentTab === 2 || mainWindow.currentTab === 3 || mainWindow.currentTab === 4 || mainWindow.currentTab === 5) && mainWindow.controller && mainWindow.controller.currentLibraryUniqueId && mainWindow.controller.currentLibraryUniqueId.toString() === mUniqueId.toString()
                                horizontalAlignment: mainWindow.sidebarCollapsed ? Text.AlignHCenter : Text.AlignLeft
                            }
                            background: Rectangle { color: "transparent" }
                            onClicked: {
                                mainWindow.loadLibraryContent(mId, mTitle, mType, mServerUrl, mUniqueId, mServerToken)
                                mainWindow.currentTab = 1 // Switch to library Recommend view
                            }
                        }
                    }

                    Item { Layout.fillHeight: true } // Spacer
                }
            }
