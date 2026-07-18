import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

ColumnLayout {
    objectName: "libraryRailInstance"
    property var rootApp
    property string libraryTitle: ""
    property string libraryId: ""
    property string libraryType: ""

                            Layout.fillWidth: true
                            spacing: 20
                            
                            PlexModel {
                                id: delegateRecentModel
                            }

                            onRootAppChanged: {
                                console.log("onRootAppChanged triggered. rootApp is " + mainWindow);
                                if (rootApp) {
                                    if (rootApp.isTestMode) {
                                        delegateRecentModel.loadMockData(["/home/geonix/Build/flex_player/tests/dummy1.mkv"], "movie", 0, 0, false)
                                    } else {
                                        var endpoint = (libraryType === "show") ? "/library/sections/" + libraryId + "/all?type=2&sort=addedAt:desc" : "/library/sections/" + libraryId + "/recentlyAdded";
                                        delegateRecentModel.fetchEndpoint(rootApp.serverUrl, rootApp.token, endpoint)
                                    }
                                }
                            }
                            
                            Component.onCompleted: {
                                console.log("LibraryRail initialized for " + libraryTitle + " id " + libraryId + " type " + libraryType);
                                if (rootApp) {
                                    if (rootApp.isTestMode) {
                                        delegateRecentModel.loadMockData(["/home/geonix/Build/flex_player/tests/dummy1.mkv"], "movie", 0, 0, false)
                                    } else {
                                        var endpoint = (libraryType === "show") ? "/library/sections/" + libraryId + "/all?type=2&sort=addedAt:desc" : "/library/sections/" + libraryId + "/recentlyAdded";
                                        console.log("Fetching from " + endpoint);
                                        delegateRecentModel.fetchEndpoint(rootApp.serverUrl, rootApp.token, endpoint)
                                    }
                                } else {
                                    console.log("rootApp is null during onCompleted in LibraryRail");
                                }
                            }

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
                                        color: delegateRecentLeftHover.hovered ? rootApp.plexOrange : "white"
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
                                        color: delegateRecentRightHover.hovered ? rootApp.plexOrange : "white"
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
