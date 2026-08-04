import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Item {
    id: root
    objectName: "musicBrowserView"

    ServerOfflineOverlay {
        connectionManager: typeof mainWindow !== "undefined" && mainWindow.controller ? mainWindow.controller.connectionManager : null
        serverName: typeof mainWindow !== "undefined" && mainWindow.controller ? mainWindow.controller.currentServerName : ""
    }

    property var appCtrl: typeof mainWindow !== "undefined" ? mainWindow.controller : null
    
    property var activeRequests: []
    ListModel {
        id: treeModel
    }
    
    ListModel {
        id: playlistModel
    }

    onVisibleChanged: {
        if (visible && treeModel.count === 0 && appCtrl && appCtrl.currentLibraryId !== "") {
            loadFolder(appCtrl.currentLibraryId, "", 0, -1, "");
        }
    }
    
    Connections {
        target: appCtrl
        function onCurrentLibraryIdChanged() {
            treeModel.clear();
            playlistModel.clear();
            if (root.visible && appCtrl && appCtrl.currentLibraryId !== "") {
                loadFolder(appCtrl.currentLibraryId, "", 0, -1, "");
            }
        }
    }

    function loadFolder(libId, parentId, depth, insertIndex, parentModelId) {
        var endpoint = "/library/sections/" + libId + "/folder";
        if (parentId !== "") {
            endpoint += "?parent=" + parentId;
        }
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var fullUrl = url + endpoint;
        var token = appCtrl.currentServerToken;
        
        console.warn("MusicBrowserView loadFolder: " + fullUrl);
        
        var req = new XMLHttpRequest();
        var arr = root.activeRequests;
        arr.push(req);
        root.activeRequests = arr;
        req.open("GET", fullUrl);
        req.setRequestHeader("X-Plex-Token", token);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                console.warn("MusicBrowserView loadFolder DONE, status: " + req.status);
                if (req.status === 200) {
                    var json = JSON.parse(req.responseText);
                    var items = [];
                    if (json.MediaContainer && json.MediaContainer.Metadata) {
                        items = json.MediaContainer.Metadata;
                    } else if (json.MediaContainer && json.MediaContainer.Directory) {
                        items = json.MediaContainer.Directory;
                    }
                    
                    var offset = 0;
                    for (var i = 0; i < items.length; i++) {
                        var item = items[i];
                        var isDir = (item.type === undefined || item.type === "folder" || item.type === "artist" || item.type === "album");
                        
                        var itemKey = item.ratingKey || item.key || "";
                        var pId = "";
                        if (isDir && itemKey) {
                            var pMatch = itemKey.match(/parent=(\d+)/);
                            if (pMatch) pId = pMatch[1];
                            else pId = itemKey;
                        }
                        
                        var trackUrl = "";
                        if (item.type === "track" && item.Media && item.Media.length > 0 && item.Media[0].Part && item.Media[0].Part.length > 0) {
                            var partKey = item.Media[0].Part[0].key || item.Media[0].Part[0].file;
                            trackUrl = url + partKey + "?X-Plex-Token=" + token;
                        }
                        
                        var node = {
                            "nodeId": itemKey,
                            "title": item.title || "",
                            "type": item.type || "folder",
                            "isFolder": isDir,
                            "parentId": pId,
                            "depth": depth,
                            "expanded": false,
                            "mediaUrl": trackUrl,
                            "duration": item.duration || 0,
                            "parentTreeId": parentModelId || ""
                        };
                        
                        if (insertIndex === -1) {
                            treeModel.append(node);
                        } else {
                            treeModel.insert(insertIndex + offset, node);
                            offset++;
                        }
                    }
                }
                // Cleanup req from activeRequests
                var arr2 = root.activeRequests;
                var idx = arr2.indexOf(req);
                if (idx !== -1) { arr2.splice(idx, 1); root.activeRequests = arr2; }
            }
        }
        req.send();
    }
    
    function collapseNode(index) {
        var targetDepth = treeModel.get(index).depth;
        var i = index + 1;
        while (i < treeModel.count) {
            if (treeModel.get(i).depth > targetDepth) {
                treeModel.remove(i, 1);
            } else {
                break;
            }
        }
        treeModel.setProperty(index, "expanded", false);
    }

    SplitView {
        anchors.fill: parent
        
        Rectangle {
            SplitView.preferredWidth: 350
            SplitView.minimumWidth: 200
            color: "#1a1a1a"
            
            ListView {
                id: treeListView
                objectName: "musicTreeView"
                anchors.fill: parent
                anchors.margins: 10
                model: treeModel
                clip: true
                
                delegate: Item {
                    width: treeListView.width
                    height: 40
                    
                    Rectangle {
                        anchors.fill: parent
                        color: mouseArea.containsMouse ? "#333" : "transparent"
                        radius: 4
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: model.depth * 20
                            spacing: 10
                            
                            Text {
                                text: model.isFolder ? (model.expanded ? "-" : "+") : "🎵"
                                color: "white"
                                font.pixelSize: 16
                            }
                            
                            Text {
                                text: model.title
                                color: "white"
                                font.pixelSize: 16
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            
                            drag.target: dragProxyItem
                            
                            onPressed: function(mouse) {
                                globalOverlay.activeDragItem = dragProxyItem;
                            }
                            
                            onReleased: function(mouse) {
                                globalOverlay.activeDragItem = null;
                                if (dragProxyItem.Drag.active) {
                                    dragProxyItem.Drag.drop();
                                }
                                dragProxyItem.x = 0; dragProxyItem.y = 0;
                            }
                            
                            onClicked: function(mouse) {
                                console.warn("Tree item clicked! index=" + index + " isFolder=" + model.isFolder + " title=" + model.title + " parentId=" + model.parentId);
                                if (mouse.button === Qt.RightButton) {
                                    if (model.isFolder) {
                                        contextMenu.folderId = model.parentId;
                                        contextMenu.popup();
                                    }
                                } else {
                                    if (model.isFolder) {
                                        if (model.expanded) {
                                            root.collapseNode(index);
                                        } else {
                                            treeModel.setProperty(index, "expanded", true);
                                            root.loadFolder(root.appCtrl.currentLibraryId, model.parentId, model.depth + 1, index + 1, model.nodeId);
                                        }
                                    } else {
                                        playlistModel.append({"title": model.title, "mediaUrl": model.mediaUrl, "duration": model.duration});
                                        
                                        var pw = null;
                                        if (typeof mainWindow !== "undefined" && mainWindow.playerView) pw = mainWindow.playerView;
                                        else if (typeof app !== "undefined" && app.playerView) pw = app.playerView;
                                        
                                        if (pw) {
                                            var streams = [{"id": 0, "streamType": 2, "codec": "mp3", "displayTitle": "Audio"}];
                                            pw.playMedia(model.mediaUrl, 0, "", model.duration, "auto", "none", streams);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item {
                        id: dragProxyItem
                        width: parent.width; height: parent.height
                        visible: false
                        Drag.active: mouseArea.drag.active
                        Drag.dragType: Drag.Internal
                        Drag.supportedActions: Qt.CopyAction
                        Drag.keys: ["text/plain"]
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        property var dragData: {"title": model.title, "mediaUrl": model.mediaUrl, "duration": model.duration, "isFolder": model.isFolder, "parentId": model.parentId}
                    }
                    
                    Menu {
                        id: contextMenu
                        property string folderId: ""
                        MenuItem {
                            text: "Add to Playlist"
                            onTriggered: {
                                root.recursivelyAddFolder(contextMenu.folderId);
                            }
                        }
                    }
                }
            }
        }
        
        Rectangle {
            SplitView.fillWidth: true
            color: "#111"
            
            ColumnLayout {
                anchors.fill: parent
                
                Text {
                    text: "Playlist"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.margins: 15
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 10
                    spacing: 15

                    Button {
                        id: playPauseButton
                        objectName: "musicPlayPauseButton"
                        text: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject && mainWindow.playerView.mpvObject.paused) ? "▶" : "⏸"
                        font.pixelSize: 24
                        background: Rectangle { color: "transparent" }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 24
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) {
                                mainWindow.playerView.mpvObject.paused = !mainWindow.playerView.mpvObject.paused;
                            }
                        }
                    }

                    Text {
                        text: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) ? mainWindow.formatTime(mainWindow.playerView.mpvObject.position) : "00:00"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Slider {
                        id: progressBar
                        objectName: "musicProgressBar"
                        Layout.fillWidth: true
                        from: 0
                        to: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject && mainWindow.playerView.mpvObject.duration > 0) ? mainWindow.playerView.mpvObject.duration : 1
                        value: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) ? mainWindow.playerView.mpvObject.position : 0

                        onMoved: {
                            if (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) {
                                mainWindow.playerView.mpvObject.position = value;
                            }
                        }
                    }

                    Text {
                        text: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) ? mainWindow.formatTime(mainWindow.playerView.mpvObject.duration) : "00:00"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Slider {
                        id: volumeSlider
                        objectName: "musicVolumeSlider"
                        Layout.preferredWidth: 100
                        from: 0
                        to: 100
                        value: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) ? mainWindow.playerView.mpvObject.volume : 100
                        onValueChanged: {
                            if (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject && mainWindow.playerView.mpvObject.volume !== value) {
                                mainWindow.playerView.mpvObject.volume = value;
                            }
                        }
                    }
                }
                
                ListView {
                    id: playlistView
                    objectName: "musicPlaylistView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: playlistModel
                    clip: true
                    
                    delegate: ItemDelegate {
                        width: playlistView.width
                        height: 50
                        
                        property bool isPlayingTrack: {
                            var pw = (typeof mainWindow !== "undefined" && mainWindow.playerView) ? mainWindow.playerView : ((typeof app !== "undefined" && app.playerView) ? app.playerView : null);
                            if (!pw && root.appCtrl && root.appCtrl.parent) pw = root.appCtrl.parent.playerView;
                            return pw ? pw.currentMediaUrl === model.mediaUrl : false;
                        }
                        
                        background: Rectangle {
                            color: isPlayingTrack ? "#3d2200" : (index % 2 === 0 ? "#222" : "#1a1a1a")
                        }
                        
                        onClicked: {
                            console.warn("Playlist song clicked! " + model.title);
                            var pw = null;
                            if (typeof mainWindow !== "undefined" && mainWindow.playerView) {
                                pw = mainWindow.playerView;
                            } else if (typeof app !== "undefined" && app.playerView) {
                                pw = app.playerView;
                            }
                            
                            console.warn("Found playerView: " + (pw !== null));
                            
                            if (pw) {
                                console.warn("Calling playMedia on playerView...");
                                var streams = [{"id": 0, "streamType": 2, "codec": "mp3", "displayTitle": "Audio"}];
                                pw.playMedia(model.mediaUrl, 0, "", model.duration, "auto", "none", streams);
                            } else {
                                console.error("Failed to find playerView!");
                            }
                        }
                        
                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            
                            Text {
                                text: (isPlayingTrack ? "🔊 " : "🎵 ") + model.title
                                color: isPlayingTrack ? (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d") : "white"
                                font.bold: isPlayingTrack
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 16
                            }
                            
                            Button {
                                text: "X"
                                background: Rectangle { color: "#aa0000"; radius: 4 }
                                contentItem: Text { text: parent.text; color: "white" }
                                onClicked: playlistModel.remove(index)
                            }
                        }
                    }
                }
            }
            
            DropArea {
                id: playlistDropArea
                objectName: "playlistDropArea"
                anchors.fill: parent
                keys: ["text/plain"]
                onEntered: function(drag) {
                    console.warn("DropArea onEntered!");
                    drag.accept(Qt.CopyAction);
                }
                onDropped: function(drop) {
                    console.warn("DropArea onDropped! source=" + drop.source);
                    if (drop.source && drop.source.dragData) {
                        var data = drop.source.dragData;
                        if (data.isFolder) {
                            root.recursivelyAddFolder(data.parentId);
                        } else {
                            playlistModel.append({"title": data.title, "mediaUrl": data.mediaUrl, "duration": data.duration});
                        }
                        drop.accept();
                    }
                }
            }
        }
    }

    function recursivelyAddFolder(folderId) {
        var libId = appCtrl.currentLibraryId;
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken;
        
        function fetchDir(pId) {
            var endpoint = "/library/sections/" + libId + "/folder";
            if (pId !== "") endpoint += "?parent=" + pId;
            var req = new XMLHttpRequest();
            var arr = root.activeRequests; arr.push(req); root.activeRequests = arr;
            console.warn("fetchDir fetching: " + endpoint);
            req.open("GET", url + endpoint);
            req.setRequestHeader("X-Plex-Token", token);
            req.setRequestHeader("Accept", "application/json");
            req.onreadystatechange = function() {
                if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                    var json = JSON.parse(req.responseText);
                    var items = [];
                    if (json.MediaContainer && json.MediaContainer.Metadata) items = json.MediaContainer.Metadata;
                    else if (json.MediaContainer && json.MediaContainer.Directory) items = json.MediaContainer.Directory;
                    
                    for (var i = 0; i < items.length; i++) {
                        var item = items[i];
                        var isDir = (item.type === undefined || item.type === "folder" || item.type === "artist" || item.type === "album");
                        if (isDir) {
                            var itemKey = item.ratingKey || item.key || "";
                            var childPId = "";
                            if (itemKey) {
                                var pMatch = itemKey.match(/parent=(\d+)/);
                                childPId = pMatch ? pMatch[1] : itemKey;
                            }
                            if (childPId !== "") fetchDir(childPId);
                        } else if (item.type === "track") {
                            var trackUrl = "";
                            if (item.Media && item.Media.length > 0 && item.Media[0].Part && item.Media[0].Part.length > 0) {
                                var partKey = item.Media[0].Part[0].key || item.Media[0].Part[0].file;
                                trackUrl = url + partKey + "?X-Plex-Token=" + token;
                            }
                            playlistModel.append({"title": item.title, "mediaUrl": trackUrl, "duration": item.duration || 0});
                        }
                    }
                }
                var arr2 = root.activeRequests;
                var idx = arr2.indexOf(req);
                if (idx !== -1) { arr2.splice(idx, 1); root.activeRequests = arr2; }
            }
            req.send();
        }
        
        fetchDir(folderId);
    }

    Item {
        id: globalOverlay
        anchors.fill: parent
        z: 999
        property var activeDragItem: null
        
        Rectangle {
            id: globalDragVisual
            visible: globalOverlay.activeDragItem !== null && globalOverlay.activeDragItem.Drag.active
            width: globalOverlay.activeDragItem ? globalOverlay.activeDragItem.width : 0
            height: globalOverlay.activeDragItem ? globalOverlay.activeDragItem.height : 0
            x: {
                if (!globalOverlay.activeDragItem) return 0;
                var dummy = globalOverlay.activeDragItem.x;
                return globalOverlay.activeDragItem.mapToItem(globalOverlay, 0, 0).x;
            }
            y: {
                if (!globalOverlay.activeDragItem) return 0;
                var dummy = globalOverlay.activeDragItem.y;
                return globalOverlay.activeDragItem.mapToItem(globalOverlay, 0, 0).y;
            }
            color: playlistDropArea.containsDrag ? "#2E8B57" : "#aa0000"
            opacity: 0.9
            radius: 4
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: globalOverlay.activeDragItem ? globalOverlay.activeDragItem.dragData.title : ""
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: playlistDropArea.containsDrag ? "➕" : "❌"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                }
            }
        }
    }
}
