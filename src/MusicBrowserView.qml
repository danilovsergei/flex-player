import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Item {
    id: root
    objectName: "musicBrowserView"
    focus: true

    ServerOfflineOverlay {
        connectionManager: typeof mainWindow !== "undefined" && mainWindow.controller ? mainWindow.controller.connectionManager : null
        serverName: typeof mainWindow !== "undefined" && mainWindow.controller ? mainWindow.controller.currentServerName : ""
    }

    property var appCtrl: typeof mainWindow !== "undefined" ? mainWindow.controller : null
    property var appSettings: typeof mainWindow !== "undefined" ? mainWindow.appSettings : null
    
    property var activeRequests: []
    property color plexOrange: "#E5A00D"
    property int libraryTab: 0

    ListModel { id: treeModel }
    property int leftViewMode: 0
    property alias plexPlaylistsModel: playlistQueue.plexPlaylistsModel
    function loadPlexPlaylists() { playlistQueue.loadPlexPlaylists(); }
    property alias currentlyPlayingMediaUrl: playlistQueue.currentlyPlayingMediaUrl
    property alias currentlyPlayingIndex: playlistQueue.currentlyPlayingIndex
    property alias _isLoadingPlaylist: playlistQueue._isLoadingPlaylist
    function playTrackAtIndex(idx) { playlistQueue.playTrackAtIndex(idx); }
    function deleteSelectedItems() { playlistQueue.deleteSelectedItems(); }
    function triggerShortcut(name) { playlistQueue.triggerShortcut(name); }
    function recursivelyAddFolder(id, idx) { playlistQueue.recursivelyAddFolder(id, idx); }
    function addPlexPlaylist(id, idx) { playlistQueue.addPlexPlaylist(id, idx); }
    function getQueueRatingKeys() { return playlistQueue.getQueueRatingKeys(); }
    function saveQueueAsNewPlaylist(title) { playlistQueue.saveQueueAsNewPlaylist(title); }
    function replacePlaylistWithQueue(id) { playlistQueue.replacePlaylistWithQueue(id); }
    function appendQueueToPlaylist(id) { playlistQueue.appendQueueToPlaylist(id); }
    
    function getPlayerView() { return playlistQueue; }
    onVisibleChanged: {
        if (visible) {
            if (treeModel.count === 0 && appCtrl && appCtrl.currentLibraryId !== "") {
                loadFolder(appCtrl.currentLibraryId, "", 0, -1, "");
            }
        }
    }


    Connections {
        target: appCtrl
        function onCurrentLibraryIdChanged() {
            treeModel.clear();
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
                        
                        var parsedAlbum = item.parentTitle || "";
                        var parsedArtist = item.grandparentTitle || item.originalTitle || "";
                        var parsedTitle = item.title || "";
                        
                        if ((!parsedTitle || !parsedAlbum || !parsedArtist) && item.type === "track") {
                            if (item.Media && item.Media.length > 0 && item.Media[0].Part && item.Media[0].Part.length > 0) {
                                var filePath = item.Media[0].Part[0].file || "";
                                if (filePath !== "") {
                                    var parts = filePath.split("/");
                                    if (!parsedTitle) {
                                        var fileName = parts[parts.length - 1];
                                        parsedTitle = fileName.replace(/\.[^/.]+$/, "");
                                    }
                                    if (parts.length >= 3) {
                                        if (!parsedAlbum) {
                                            parsedAlbum = parts[parts.length - 2].replace(/^\d{4}\s*-\s*/, "").replace(/^\d{4}\s+/, "").replace(/!$/, "").trim();
                                        }
                                        if (!parsedArtist) {
                                            var aStr = parts[parts.length - 3].trim();
                                            if (aStr === aStr.toUpperCase() && aStr.length > 1) {
                                                aStr = aStr.charAt(0) + aStr.slice(1).toLowerCase();
                                            }
                                            parsedArtist = aStr;
                                        }
                                    }
                                }
                            }
                        }

                        var node = {
                            "nodeId": itemKey,
                            "title": parsedTitle,
                            "album": parsedAlbum,
                            "artist": parsedArtist,
                            "type": item.type || "folder",
                            "isFolder": isDir,
                            "parentId": pId,
                            "depth": depth,
                            "expanded": false,
                            "mediaUrl": trackUrl,
                            "duration": item.duration || 0,
                            "parentTreeId": parentModelId || "",
                            "ratingKey": itemKey || ""
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#1a1a1a"
            
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 20
                spacing: 30
                
                Text {
                    id: libraryTitleText
                    text: typeof mainWindow !== "undefined" && mainWindow.controller ? mainWindow.controller.currentLibraryTitle : "Music"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                    renderType: Text.NativeRendering
                    anchors.baseline: playerTab.baseline
                }

                Text {
                    id: playerTab
                    text: "Player"
                    color: root.libraryTab === 0 ? root.plexOrange : "gray"
                    font.pixelSize: 18
                    font.bold: root.libraryTab === 0
                    renderType: Text.NativeRendering
                    anchors.baseline: recommendedTab.baseline
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.libraryTab = 0
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Text {
                    id: recommendedTab
                    objectName: "recommendedTab"
                    text: "Recommended"
                    color: root.libraryTab === 1 ? root.plexOrange : "gray"
                    font.pixelSize: 18
                    font.bold: root.libraryTab === 1
                    renderType: Text.NativeRendering
                    anchors.baseline: playerTab.baseline
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.libraryTab = 1
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.libraryTab

            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
        
        Rectangle {
            SplitView.preferredWidth: 350
            SplitView.minimumWidth: 200
            color: "#1a1a1a"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.margins: 10
                    
                    Button {
                        objectName: "foldersTabButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        background: Rectangle { 
                            color: root.leftViewMode === 0 ? "#444" : "transparent"
                            radius: 4 
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            Image {
                                source: Qt.resolvedUrl("../assets/folder.svg")
                                width: 16; height: 16; sourceSize.width: 16; sourceSize.height: 16
                            }
                            Text { text: "Folders"; color: "white"; font.pixelSize: 14 }
                        }
                        onClicked: root.leftViewMode = 0
                    }
                    Button {
                        objectName: "playlistsTabButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        background: Rectangle { 
                            color: root.leftViewMode === 1 ? "#444" : "transparent"
                            radius: 4 
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            Image {
                                source: Qt.resolvedUrl("../assets/list-ul.svg")
                                width: 16; height: 16; sourceSize.width: 16; sourceSize.height: 16
                            }
                            Text { text: "Playlists"; color: "white"; font.pixelSize: 14 }
                        }
                        onClicked: {
                            root.leftViewMode = 1;
                            if (plexPlaylistsModel.count === 0) {
                                root.loadPlexPlaylists();
                            }
                        }
                    }
                }
                
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.leftViewMode
                    
                    ListView {
                        id: treeListView
                        objectName: "musicTreeView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: treeModel
                        clip: true
                        Layout.margins: 10
                
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
                                        playlistQueue.playlistModel.append({"title": model.title, "album": model.album !== undefined ? model.album : "", "artist": model.artist !== undefined ? model.artist : "", "mediaUrl": model.mediaUrl, "duration": model.duration, "isSelected": false});
                                        
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
                        property var dragData: {"title": model.title, "album": model.album !== undefined ? model.album : "", "artist": model.artist !== undefined ? model.artist : "", "mediaUrl": model.mediaUrl, "duration": model.duration, "isFolder": model.isFolder, "parentId": model.parentId, "ratingKey": model.nodeId || ""}
                    }
                    
                    Menu {
                        id: contextMenu
                        objectName: "contextMenu"
                        property string folderId: ""
                        background: Rectangle {
                            color: "#222"
                            radius: 4
                            border.color: "#444"
                            border.width: 1
                        }
                        MenuItem {
                            text: "Add to Queue"
                            contentItem: Text {
                                text: parent.text
                                color: "#E5A00D"
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
                            onTriggered: {
                                root.recursivelyAddFolder(contextMenu.folderId, playlistQueue.playlistModel.count);
                            }
                        }
                    }
                }
            }
            
            ListView {
                id: plexPlaylistsListView
                objectName: "plexPlaylistsListView"
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: plexPlaylistsModel
                clip: true
                Layout.margins: 10
                
                ScrollBar.vertical: ScrollBar {
                    active: hovered || plexPlaylistsListView.moving
                    policy: ScrollBar.AsNeeded
                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: parent.active ? "#80ffffff" : "#40ffffff"
                    }
                }
                
                delegate: Item {
                    width: plexPlaylistsListView.width
                    height: 40
                    
                    Rectangle {
                        anchors.fill: parent
                        color: plMouseArea.containsMouse ? "#333" : "transparent"
                        radius: 4
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 10
                            
                            Image {
                                source: Qt.resolvedUrl("../assets/list-ul.svg")
                                width: 16; height: 16; sourceSize.width: 16; sourceSize.height: 16
                            }
                            
                            Text {
                                text: model.title
                                color: "white"
                                font.pixelSize: 16
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: model.leafCount + " tracks"
                                color: "#aaa"
                                font.pixelSize: 12
                                Layout.rightMargin: 10
                            }
                        }
                        
                        MouseArea {
                            id: plMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            
                            drag.target: plDragProxyItem
                            
                            onPressed: function(mouse) {
                                globalOverlay.activeDragItem = plDragProxyItem;
                            }
                            
                            onReleased: function(mouse) {
                                globalOverlay.activeDragItem = null;
                                if (plDragProxyItem.Drag.active) {
                                    plDragProxyItem.Drag.drop();
                                }
                                plDragProxyItem.x = 0; plDragProxyItem.y = 0;
                            }
                            
                            onClicked: function(mouse) {
                                console.log("Clicked plex playlist: " + model.title);
                                if (mouse.button === Qt.RightButton) {
                                    plContextMenu.playlistId = model.ratingKey;
                                    plContextMenu.popup();
                                }
                            }
                        }
                    }
                    
                    Item {
                        id: plDragProxyItem
                        width: parent.width; height: parent.height
                        visible: false
                        Drag.active: plMouseArea.drag.active
                        Drag.dragType: Drag.Internal
                        Drag.supportedActions: Qt.CopyAction
                        Drag.keys: ["text/plain"]
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        property var dragData: {"title": model.title, "isPlexPlaylist": true, "ratingKey": model.ratingKey || ""}
                    }
                    
                    Menu {
                        id: plContextMenu
                        objectName: "plContextMenu"
                        property string playlistId: ""
                        background: Rectangle {
                            color: "#222"
                            radius: 4
                            border.color: "#444"
                            border.width: 1
                        }
                        MenuItem {
                            objectName: "plContextMenuAdd"
                            text: "Add to Queue"
                            contentItem: Text {
                                text: parent.text
                                color: "#E5A00D"
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
                            onTriggered: {
                                root.addPlexPlaylist(plContextMenu.playlistId, playlistQueue.playlistModel.count);
                            }
                        }
                    }
                }
            }
        } // end StackLayout
        } // end ColumnLayout
        } // end Rectangle
        
        PlaylistQueueView {
            id: playlistQueue
            SplitView.fillWidth: true
            appCtrl: root.appCtrl
            appSettings: root.appSettings
        }
    }
    
    ScrollView {
        id: musicRecommendedTab
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        contentHeight: recommendedContentLayout.implicitHeight
        clip: true
        
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: recommendedContentLayout
            objectName: "recommendedContentLayout"
            width: musicRecommendedTab.availableWidth
            spacing: 30
            
            Item { Layout.preferredHeight: 10 }
            
            LibraryRail {
                libraryTitle: root.appCtrl && root.appCtrl.currentLibraryTitle ? root.appCtrl.currentLibraryTitle : "Music"
                libraryId: root.appCtrl && root.appCtrl.currentLibraryId ? root.appCtrl.currentLibraryId : ""
                libraryType: "artist"
                serverName: root.appCtrl && root.appCtrl.currentServerName ? root.appCtrl.currentServerName : ""
                serverUrl: root.appCtrl && root.appCtrl.currentServerUrl ? root.appCtrl.currentServerUrl : ""
                serverToken: root.appCtrl && root.appCtrl.currentServerToken ? root.appCtrl.currentServerToken : ""
                rootApp: typeof mainWindow !== "undefined" ? mainWindow : null
                movieDelegate: typeof mainWindow !== "undefined" ? mainWindow.globalMovieDelegate : null
                customTitle: "Recently Played Artists"
                customEndpoint: libraryId !== "" ? "/library/sections/" + libraryId + "/all?type=8&sort=lastViewedAt:desc" : ""
                Layout.fillWidth: true
                Layout.preferredHeight: hasItems ? 400 : 0
                visible: hasItems
            }

            LibraryRail {
                libraryTitle: root.appCtrl && root.appCtrl.currentLibraryTitle ? root.appCtrl.currentLibraryTitle : "Music"
                libraryId: root.appCtrl && root.appCtrl.currentLibraryId ? root.appCtrl.currentLibraryId : ""
                libraryType: "artist"
                serverName: root.appCtrl && root.appCtrl.currentServerName ? root.appCtrl.currentServerName : ""
                serverUrl: root.appCtrl && root.appCtrl.currentServerUrl ? root.appCtrl.currentServerUrl : ""
                serverToken: root.appCtrl && root.appCtrl.currentServerToken ? root.appCtrl.currentServerToken : ""
                rootApp: typeof mainWindow !== "undefined" ? mainWindow : null
                movieDelegate: typeof mainWindow !== "undefined" ? mainWindow.globalMovieDelegate : null
                customTitle: "Recently Added in " + libraryTitle
                customEndpoint: libraryId !== "" ? "/library/sections/" + libraryId + "/all?type=9&sort=addedAt:desc" : ""
                Layout.fillWidth: true
                Layout.preferredHeight: hasItems ? 400 : 0
                visible: hasItems
            }

            LibraryRail {
                libraryTitle: root.appCtrl && root.appCtrl.currentLibraryTitle ? root.appCtrl.currentLibraryTitle : "Music"
                libraryId: root.appCtrl && root.appCtrl.currentLibraryId ? root.appCtrl.currentLibraryId : ""
                libraryType: "artist"
                serverName: root.appCtrl && root.appCtrl.currentServerName ? root.appCtrl.currentServerName : ""
                serverUrl: root.appCtrl && root.appCtrl.currentServerUrl ? root.appCtrl.currentServerUrl : ""
                serverToken: root.appCtrl && root.appCtrl.currentServerToken ? root.appCtrl.currentServerToken : ""
                rootApp: typeof mainWindow !== "undefined" ? mainWindow : null
                movieDelegate: typeof mainWindow !== "undefined" ? mainWindow.globalMovieDelegate : null
                customTitle: "Recently Played Playlists"
                customEndpoint: "/playlists?playlistType=audio&sort=lastViewedAt:desc"
                Layout.fillWidth: true
                Layout.preferredHeight: hasItems ? 400 : 0
                visible: hasItems
            }
            
            Item { Layout.fillHeight: true }
        }
    }
    } // StackLayout
    } // ColumnLayout

    Item {
        id: globalOverlay
        anchors.fill: parent
        z: 999
        property var activeDragItem: null
        
        Rectangle {
            id: globalDragVisual
            objectName: "globalDragVisual"
            visible: globalOverlay.activeDragItem !== null && globalOverlay.activeDragItem.Drag.active
            width: globalOverlay.activeDragItem ? globalOverlay.activeDragItem.width : 0
            height: globalOverlay.activeDragItem ? globalOverlay.activeDragItem.height : 0
            x: {
                if (!globalOverlay.activeDragItem) return 0;
                var dummyX = globalOverlay.activeDragItem.x;
                return globalOverlay.activeDragItem.mapToItem(globalOverlay, 0, 0).x;
            }
            y: {
                if (!globalOverlay.activeDragItem) return 0;
                var dummyY = globalOverlay.activeDragItem.y;
                return globalOverlay.activeDragItem.mapToItem(globalOverlay, 0, 0).y;
            }
            color: playlistQueue.playlistDropArea.containsDrag ? "#2E8B57" : "#aa0000"
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
                    text: playlistQueue.playlistDropArea.containsDrag ? "➕" : "❌"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                }
            }
        }
    }

}
