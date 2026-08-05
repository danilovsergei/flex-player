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
    property string currentlyPlayingMediaUrl: ""
    property int currentlyPlayingIndex: -1
    
    function playTrackAtIndex(idx) {
        if (idx >= 0 && idx < playlistModel.count) {
            playlistView.currentIndex = idx;
            var item = playlistModel.get(idx);
            
            for (var k2 = 0; k2 < playlistModel.count; k2++) {
                playlistModel.setProperty(k2, "isSelected", false);
            }
            playlistModel.setProperty(idx, "isSelected", true);
            
            var pw = root.getPlayerView();
            if (pw) {
                var streams = [{"id": 0, "streamType": 2, "codec": "mp3", "displayTitle": "Audio"}];
                pw.playMedia(item.mediaUrl, 0, item.ratingKey, item.duration, "auto", "none", streams);
                root.currentlyPlayingMediaUrl = item.mediaUrl;
                root.currentlyPlayingIndex = idx;
            }
        }
    }

    ListModel {
        id: treeModel
    }
    
    property bool _isLoadingPlaylist: false
    ListModel {
        id: playlistModel
        objectName: "playlistModel" 
        onCountChanged: {
            if (!root._isLoadingPlaylist) {
                root.savePlaylist();
            }
        }
    }

    function deleteSelectedItems() {
        var hasSelection = false;
        for (var i = playlistModel.count - 1; i >= 0; i--) {
            var m = playlistModel.get(i);
            if (m && m.isSelected) {
                hasSelection = true;
                if (i < root.currentlyPlayingIndex) root.currentlyPlayingIndex--;
                else if (i === root.currentlyPlayingIndex) root.currentlyPlayingIndex = -1;
                playlistModel.remove(i);
            }
        }
        if (!hasSelection && playlistView.currentIndex >= 0 && playlistView.currentIndex < playlistModel.count) {
            if (playlistView.currentIndex < root.currentlyPlayingIndex) root.currentlyPlayingIndex--;
            else if (playlistView.currentIndex === root.currentlyPlayingIndex) root.currentlyPlayingIndex = -1;
            playlistModel.remove(playlistView.currentIndex);
        }
    }

    function triggerShortcut(name) {
        if (name === "Delete") {
            root.deleteSelectedItems();
        } else if (name === "PlayPause") {
            var pw = null;
            if (typeof mainWindow !== "undefined" && mainWindow.playerView) pw = mainWindow.playerView;
            else if (typeof app !== "undefined" && app.playerView) pw = app.playerView;
            if (pw) {
                var modelItem = playlistModel.get(playlistView.currentIndex);
                if (modelItem && pw.currentMediaUrl === modelItem.mediaUrl && root.currentlyPlayingIndex === playlistView.currentIndex) {
                    pw.mpvObject.paused = !pw.mpvObject.paused;
                } else if (modelItem) {
                    var streams = [{"id": 0, "streamType": 2, "codec": "mp3", "displayTitle": "Audio"}];
                    pw.playMedia(modelItem.mediaUrl, 0, "", modelItem.duration, "auto", "none", streams);
                    root.currentlyPlayingMediaUrl = modelItem.mediaUrl;
                    root.currentlyPlayingIndex = playlistView.currentIndex;
                }
            }
        } else if (name === "Ctrl+A") {
            for (var i = 0; i < playlistModel.count; i++) playlistModel.setProperty(i, "isSelected", true);
        } else if (name === "Shift+Up") {
            if (playlistView.currentIndex > 0) {
                playlistModel.setProperty(playlistView.currentIndex, "isSelected", true);
                playlistView.currentIndex--;
                playlistModel.setProperty(playlistView.currentIndex, "isSelected", true);
            }
        } else if (name === "Shift+Down") {
            if (playlistView.currentIndex < playlistModel.count - 1) {
                playlistModel.setProperty(playlistView.currentIndex, "isSelected", true);
                playlistView.currentIndex++;
                playlistModel.setProperty(playlistView.currentIndex, "isSelected", true);
            }
        } else if (name === "Up") {
            if (playlistView.currentIndex > 0) {
                for (var j = 0; j < playlistModel.count; j++) playlistModel.setProperty(j, "isSelected", false);
                playlistView.currentIndex--;
            }
        } else if (name === "Down") {
            if (playlistView.currentIndex < playlistModel.count - 1) {
                for (var k = 0; k < playlistModel.count; k++) playlistModel.setProperty(k, "isSelected", false);
                playlistView.currentIndex++;
            }
        }
    }

    function savePlaylist() {
        if (!appSettings) return;
        try {
            var list = [];
            for (var i = 0; i < playlistModel.count; i++) {
                var item = playlistModel.get(i);
                if (item) {
                    list.push({"title": item.title || "", "album": item.album !== undefined ? item.album : "", "artist": item.artist !== undefined ? item.artist : "", "mediaUrl": item.mediaUrl || "", "duration": item.duration || 0, "ratingKey": item.ratingKey || ""});
                }
            }
            appSettings.defaultPlaylist = JSON.stringify(list);
        } catch (e) {
            console.error("Error saving playlist: " + e);
        }
    }
    
    function loadPlaylist() {
        if (!appSettings) return;
        try {
            var listStr = appSettings.defaultPlaylist;
            if (!listStr || listStr === "[]" || listStr === "") return;
            var list = JSON.parse(listStr);
            root._isLoadingPlaylist = true;
            playlistModel.clear();
            for (var i = 0; i < list.length; i++) {
                var l = list[i];
                l.isSelected = false;
                if (l.ratingKey === undefined) l.ratingKey = "";
                playlistModel.append(l);
            }
            root._isLoadingPlaylist = false;
        } catch(e) {
            console.warn("Failed to load defaultPlaylist: " + e);
            root._isLoadingPlaylist = false;
        }
    }

    property bool _hasLoadedPlaylist: false
    onVisibleChanged: {
        if (visible) {
            if (!_hasLoadedPlaylist) {
                _hasLoadedPlaylist = true;
                loadPlaylist();
            }
            if (treeModel.count === 0 && appCtrl && appCtrl.currentLibraryId !== "") {
                loadFolder(appCtrl.currentLibraryId, "", 0, -1, "");
            }
        }
    }
    
    
    function getPlayerView() {
        if (typeof mainWindow !== "undefined" && mainWindow.playerView) return mainWindow.playerView;
        if (typeof app !== "undefined" && app.playerView) return app.playerView;
        
        // Dynamic fallback for headless testing where playerView isn't bound on mainWindow root
        var mw = typeof mainWindow !== "undefined" ? mainWindow : null;
        if (mw && mw.contentItem && mw.contentItem.children) {
            for (var i = 0; i < mw.contentItem.children.length; i++) {
                if (mw.contentItem.children[i] && mw.contentItem.children[i].objectName === "playerView") return mw.contentItem.children[i];
            }
        } else if (mw && mw.children) {
            for (var j = 0; j < mw.children.length; j++) {
                if (mw.children[j] && mw.children[j].objectName === "playerView") return mw.children[j];
            }
        }
        return null;
    }

    function mediaEndedHandler() {
        if (!root.currentlyPlayingMediaUrl) return;
        var pw = root.getPlayerView();
        
        if (pw && pw.currentMediaUrl !== root.currentlyPlayingMediaUrl) return;

        var rm = (root.appCtrl && root.appSettings) ? root.appSettings.musicRepeatMode : 0;
        var idx = playlistView.currentIndex;
        
        if (rm === 2) {
            playTrackAtIndex(idx);
        } else {
            var nextIdx = idx + 1;
            if (nextIdx < playlistModel.count) {
                playTrackAtIndex(nextIdx);
            } else if (rm === 1 && playlistModel.count > 0) {
                playTrackAtIndex(0);
            } else {
                root.currentlyPlayingMediaUrl = "";
                root.currentlyPlayingIndex = -1;
            }
        }
    }

    Connections {
        target: root.getPlayerView()
        function onMediaEnded() {
            mediaEndedHandler();
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
                                        playlistModel.append({"title": model.title, "album": model.album !== undefined ? model.album : "", "artist": model.artist !== undefined ? model.artist : "", "mediaUrl": model.mediaUrl, "duration": model.duration, "isSelected": false});
                                        
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
                        MenuItem {
                            text: "Add to Playlist"
                            onTriggered: {
                                root.recursivelyAddFolder(contextMenu.folderId, playlistModel.count);
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
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
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
                        
                        background: Rectangle {
                            x: progressBar.leftPadding
                            y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 6
                            width: progressBar.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: "#444444"

                            Rectangle {
                                width: progressBar.visualPosition * parent.width
                                height: parent.height
                                color: typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "orange"
                                radius: 3
                            }
                        }

                        handle: Rectangle {
                            x: progressBar.leftPadding + progressBar.visualPosition * (progressBar.availableWidth - width)
                            y: progressBar.topPadding + progressBar.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: progressBar.pressed ? "white" : (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "orange")
                        }
                    }

                    Text {
                        text: (typeof mainWindow !== "undefined" && mainWindow.playerView && mainWindow.playerView.mpvObject) ? mainWindow.formatTime(mainWindow.playerView.mpvObject.duration) : "00:00"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Button {
                        id: repeatButton
                        objectName: "repeatButton"
                        property int repeatMode: root.appSettings ? root.appSettings.musicRepeatMode : 0
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        background: Rectangle { color: "transparent" }
                        
                        contentItem: Item {
                            anchors.fill: parent
                            Image {
                                id: repeatIconImg
                                objectName: "repeatIconImg"
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                sourceSize.width: 26
                                sourceSize.height: 26
                                source: {
                                    if (repeatButton.repeatMode === 0) return "../assets/repeat.svg";
                                    if (repeatButton.repeatMode === 1) return "../assets/repeat_on.svg";
                                    return "../assets/repeat_one.svg";
                                }
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                        
                        onClicked: {
                            if (root.appSettings) {
                                root.appSettings.musicRepeatMode = (root.appSettings.musicRepeatMode + 1) % 3;
                            }
                        }
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
                        
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 100
                            implicitHeight: 4
                            width: volumeSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: "#444444"

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                color: typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "orange"
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: volumeSlider.pressed ? "white" : (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "orange")
                        }
                    }
                }
                
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicDeleteHotkey : "Delete"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("Delete")
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicPlayPauseHotkey : "Space"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("PlayPause")
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.seekForwardHotkey : "Right"
                    enabled: root.visible
                    onActivated: {
                        if (root.appCtrl) root.appCtrl.throttleSeek(1);
                    }
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.seekBackwardHotkey : "Left"
                    enabled: root.visible
                    onActivated: {
                        if (root.appCtrl) root.appCtrl.throttleSeek(-1);
                    }
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicSelectAllHotkey : "Ctrl+A"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("Ctrl+A")
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicShiftUpHotkey : "Shift+Up"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("Shift+Up")
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicShiftDownHotkey : "Shift+Down"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("Shift+Down")
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicUpHotkey : "Up"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("Up")
                }
                Shortcut {
                    sequence: (root.appCtrl && root.appSettings) ? root.appSettings.musicDownHotkey : "Down"
                    enabled: root.visible
                    onActivated: root.triggerShortcut("Down")
                }
                
                ListView {
                    id: playlistView
                    objectName: "musicPlaylistView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: playlistModel
                    clip: true
                    keyNavigationEnabled: false
                    
                    ScrollBar.vertical: ScrollBar {
                        active: hovered || playlistView.moving
                        policy: ScrollBar.AsNeeded
                        background: Rectangle { color: "transparent" }
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: parent.active ? "#80ffffff" : "#40ffffff"
                        }
                    }
                    
                    onCurrentIndexChanged: {
                        // intentionally blank or handle focus/scrolling if needed in the future
                    }
                    
                    property int hoveredDropIndex: -1
                    
                    delegate: Item {
                        width: playlistView.width
                        height: 50 + (playlistView.hoveredDropIndex === index ? 40 : 0)
                        
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        
                        property bool isContextMenuOpen: false
                        
                        property bool isPlayingTrack: {
                            var pw = (typeof mainWindow !== "undefined" && mainWindow.playerView) ? mainWindow.playerView : ((typeof app !== "undefined" && app.playerView) ? app.playerView : null);
                            if (!pw && root.appCtrl && root.appCtrl.parent) pw = root.appCtrl.parent.playerView;
                            return pw ? (pw.currentMediaUrl === model.mediaUrl && index === root.currentlyPlayingIndex) : false;
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 40
                            y: 0
                            visible: playlistView.hoveredDropIndex === index
                            color: "transparent"
                            Rectangle {
                                width: parent.width - 20
                                height: 2
                                anchors.centerIn: parent
                                color: typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d"
                            }
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 50
                            y: playlistView.hoveredDropIndex === index ? 40 : 0
                            color: (isContextMenuOpen || model.isSelected || playlistView.currentIndex === index) ? "#444444" : (isPlayingTrack ? "#3d2200" : (index % 2 === 0 ? "#222" : "#1a1a1a"))
                            Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }
                        
                        RowLayout {
                            width: parent.width
                            height: 50
                            y: playlistView.hoveredDropIndex === index ? 40 : 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            
                            Text {
                                text: (isPlayingTrack ? "🔊 " : "🎵 ") + model.title
                                color: isPlayingTrack ? (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d") : "white"
                                font.bold: isPlayingTrack
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.4
                                elide: Text.ElideRight
                                font.pixelSize: 16
                            }
                            
                            Text {
                                text: model.album !== undefined ? model.album : ""
                                color: "#ccc"
                                Layout.preferredWidth: parent.width * 0.25
                                elide: Text.ElideRight
                                font.pixelSize: 14
                            }
                            
                            Text {
                                text: model.artist !== undefined ? model.artist : ""
                                color: "#ccc"
                                Layout.preferredWidth: parent.width * 0.2
                                elide: Text.ElideRight
                                font.pixelSize: 14
                            }
                            
                            Text {
                                text: (typeof mainWindow !== "undefined" && model.duration) ? mainWindow.formatTime(model.duration / 1000) : "00:00"
                                color: "#aaa"
                                Layout.preferredWidth: parent.width * 0.1
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 14
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                root.forceActiveFocus();
                                if (mouse.button === Qt.LeftButton) {
                                    if (mouse.modifiers & Qt.ControlModifier) {
                                        var curSel = model.isSelected || false;
                                        playlistModel.setProperty(index, "isSelected", !curSel);
                                        playlistView.currentIndex = index;
                                    } else if (mouse.modifiers & Qt.ShiftModifier) {
                                        var startIdx = Math.min(playlistView.currentIndex, index);
                                        var endIdx = Math.max(playlistView.currentIndex, index);
                                        for (var i = 0; i < playlistModel.count; i++) {
                                            playlistModel.setProperty(i, "isSelected", (i >= startIdx && i <= endIdx));
                                        }
                                        playlistView.currentIndex = index;
                                    } else {
                                        for (var k = 0; k < playlistModel.count; k++) {
                                            playlistModel.setProperty(k, "isSelected", false);
                                        }
                                        playlistView.currentIndex = index;
                                    }
                                }
                                if (mouse.button === Qt.RightButton) {
                                    if (!model.isSelected) {
                                        for (var k2 = 0; k2 < playlistModel.count; k2++) {
                                            playlistModel.setProperty(k2, "isSelected", false);
                                        }
                                        playlistModel.setProperty(index, "isSelected", true);
                                        playlistView.currentIndex = index;
                                    }
                                    isContextMenuOpen = true;
                                    var pt = mapToItem(null, mouse.x, mouse.y);
                                    playlistItemContextMenu.trackRatingKey = playlistModel.get(index).ratingKey || "";
                                    playlistItemContextMenu.clickX = pt.x;
                                    playlistItemContextMenu.clickY = pt.y;
                                    playlistItemContextMenu.popup();
                                }
                            }
                            onDoubleClicked: function(mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    playTrackAtIndex(index);
                                }
                            }
                        }
                        
                        Menu {
                            id: playlistItemContextMenu
                            objectName: "playlistItemContextMenu"
                            property string trackRatingKey: ""
                            property real clickX: 0
                            property real clickY: 0
                            onClosed: {
                                isContextMenuOpen = false;
                            }
                            MenuItem {
                                objectName: "detailsMenuItem"
                                text: "Details"
                                onTriggered: {
                                    var rk = playlistItemContextMenu.trackRatingKey;
                                    detailsDialog.trackPath = "Loading...";
                                    detailsDialog.trackSize = "Loading...";
                                    detailsDialog.trackBitrate = "Loading...";
                                    detailsDialog.open();
                                    
                                    if (rk !== "") {
                                        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
                                        var token = appCtrl.currentServerToken;
                                        var req = new XMLHttpRequest();
                                        
                                        var endpoint = rk.indexOf("/library/metadata/") === 0 ? rk : ("/library/metadata/" + rk);
                                        req.open("GET", url + endpoint);
                                        req.setRequestHeader("X-Plex-Token", token);
                                        req.setRequestHeader("Accept", "application/json");
                                        req.onreadystatechange = function() {
                                            if (req.readyState === XMLHttpRequest.DONE) {
                                                if (req.status === 200) {
                                                    try {
                                                        var json = JSON.parse(req.responseText);
                                                        if (json.MediaContainer && json.MediaContainer.Metadata && json.MediaContainer.Metadata.length > 0) {
                                                            var meta = json.MediaContainer.Metadata[0];
                                                            var physicalPath = "Unknown";
                                                            var sizeBytes = 0;
                                                            var bitrate = 0;
                                                            if (meta.Media && meta.Media.length > 0) {
                                                                bitrate = meta.Media[0].bitrate || 0;
                                                                if (meta.Media[0].Part && meta.Media[0].Part.length > 0) {
                                                                    var part = meta.Media[0].Part[0];
                                                                    physicalPath = part.file || "Unknown";
                                                                    sizeBytes = part.size || 0;
                                                                }
                                                            }
                                                            var sMB = sizeBytes > 0 ? (sizeBytes / (1024 * 1024)).toFixed(2) + " MB" : "Unknown";
                                                            
                                                            detailsDialog.trackPath = physicalPath;
                                                            detailsDialog.trackSize = sMB;
                                                            detailsDialog.trackBitrate = bitrate > 0 ? bitrate + " kbps" : "Unknown";
                                                        } else {
                                                            detailsDialog.trackPath = "Failed to parse details.";
                                                            detailsDialog.trackSize = "Failed";
                                                            detailsDialog.trackBitrate = "Failed";
                                                        }
                                                    } catch (e) {
                                                        detailsDialog.trackPath = "Failed to parse details response.";
                                                        detailsDialog.trackSize = "Error";
                                                        detailsDialog.trackBitrate = "Error";
                                                    }
                                                } else {
                                                    detailsDialog.trackPath = "Failed to fetch details (HTTP " + req.status + ").";
                                                    detailsDialog.trackSize = "Error";
                                                    detailsDialog.trackBitrate = "Error";
                                                }
                                            }
                                        }
                                        req.send();
                                    } else {
                                        detailsDialog.trackPath = "No rating key available.";
                                        detailsDialog.trackSize = "Unknown";
                                        detailsDialog.trackBitrate = "Unknown";
                                    }
                                }
                            }
                            MenuItem {
                                text: "Delete"
                                onTriggered: {
                                    root.deleteSelectedItems();
                                }
                            }
                        }
                        
                        Dialog {
                            id: detailsDialog
                            objectName: "detailsDialog"
                            property string trackPath: ""
                            property string trackSize: ""
                            property string trackBitrate: ""
                            
                            width: 600
                            height: 400
                            
                            parent: Overlay.overlay
                            x: Math.min(Math.max(0, playlistItemContextMenu.clickX), parent ? parent.width - width : 0)
                            y: Math.min(Math.max(0, playlistItemContextMenu.clickY), parent ? parent.height - height : 0)
                            modal: true
                            dim: true
                            
                            enter: Transition {
                                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                            }
                            exit: Transition {
                                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
                                NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 150; easing.type: Easing.InBack }
                            }
                            
                            background: Rectangle {
                                color: "#1A1B26"
                                radius: 12
                                border.color: "#33354D"
                                border.width: 1
                                
                                MouseArea {
                                    width: 20
                                    height: 20
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    cursorShape: Qt.SizeFDiagCursor
                                    
                                    property real startX
                                    property real startY
                                    property real startW
                                    property real startH
                                    
                                    onPressed: function(mouse) {
                                        startX = mouse.x
                                        startY = mouse.y
                                        startW = detailsDialog.width
                                        startH = detailsDialog.height
                                    }
                                    onPositionChanged: function(mouse) {
                                        if (pressed) {
                                            detailsDialog.width = Math.max(400, startW + (mouse.x - startX))
                                            detailsDialog.height = Math.max(300, startH + (mouse.y - startY))
                                        }
                                    }
                                }
                                
                                Text {
                                    text: "↘"
                                    color: "#4C566A"
                                    font.pixelSize: 14
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                }
                            }
                            
                            contentItem: ColumnLayout {
                                spacing: 16
                                anchors.fill: parent
                                anchors.margins: 20
                                
                                Text {
                                    text: "Track Details"
                                    color: "#FFFFFF"
                                    font.pixelSize: 20
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#33354D"
                                }
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    contentWidth: availableWidth
                                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                    
                                    Column {
                                        width: parent.width
                                        spacing: 16
                                        
                                        // File Path
                                        Column {
                                            spacing: 4
                                            width: parent.width
                                            Text {
                                                text: "File Path"
                                                color: "#B0B5D3"
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                            Rectangle {
                                                width: parent.width
                                                height: Math.max(36, pathEdit.contentHeight + 16)
                                                color: "#15161E"
                                                radius: 6
                                                border.color: "#4C566A"
                                                border.width: 1
                                                
                                                TextEdit {
                                                    id: pathEdit
                                                    objectName: "pathEdit"
                                                    text: detailsDialog.trackPath
                                                    color: "#E2E8F0"
                                                    font.pixelSize: 14
                                                    wrapMode: Text.WrapAnywhere
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectionColor: "#81A1C1"
                                                    selectedTextColor: "#2E3440"
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    verticalAlignment: TextEdit.AlignVCenter
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        acceptedButtons: Qt.RightButton
                                                        onClicked: function(mouse) {
                                                            if (mouse.button === Qt.RightButton) {
                                                                pathMenu.popup();
                                                            }
                                                        }
                                                    }
                                                    Menu {
                                                        id: pathMenu
                                                        MenuItem {
                                                            text: "Copy"
                                                            onTriggered: {
                                                                if (pathEdit.selectedText !== "") pathEdit.copy();
                                                                else { pathEdit.selectAll(); pathEdit.copy(); pathEdit.deselect(); }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // File Size
                                        Column {
                                            spacing: 4
                                            width: parent.width
                                            Text {
                                                text: "File Size"
                                                color: "#B0B5D3"
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                            Rectangle {
                                                width: parent.width
                                                height: 36
                                                color: "#15161E"
                                                radius: 6
                                                border.color: "#4C566A"
                                                border.width: 1
                                                
                                                TextEdit {
                                                    id: sizeEdit
                                                    objectName: "sizeEdit"
                                                    text: detailsDialog.trackSize
                                                    color: "#E2E8F0"
                                                    font.pixelSize: 14
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectionColor: "#81A1C1"
                                                    selectedTextColor: "#2E3440"
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    verticalAlignment: TextEdit.AlignVCenter
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        acceptedButtons: Qt.RightButton
                                                        onClicked: function(mouse) {
                                                            if (mouse.button === Qt.RightButton) sizeMenu.popup();
                                                        }
                                                    }
                                                    Menu {
                                                        id: sizeMenu
                                                        MenuItem {
                                                            text: "Copy"
                                                            onTriggered: {
                                                                if (sizeEdit.selectedText !== "") sizeEdit.copy();
                                                                else { sizeEdit.selectAll(); sizeEdit.copy(); sizeEdit.deselect(); }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Bitrate
                                        Column {
                                            spacing: 4
                                            width: parent.width
                                            Text {
                                                text: "Bitrate"
                                                color: "#B0B5D3"
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                            Rectangle {
                                                width: parent.width
                                                height: 36
                                                color: "#15161E"
                                                radius: 6
                                                border.color: "#4C566A"
                                                border.width: 1
                                                
                                                TextEdit {
                                                    id: bitrateEdit
                                                    objectName: "bitrateEdit"
                                                    text: detailsDialog.trackBitrate
                                                    color: "#E2E8F0"
                                                    font.pixelSize: 14
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectionColor: "#81A1C1"
                                                    selectedTextColor: "#2E3440"
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    verticalAlignment: TextEdit.AlignVCenter
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        acceptedButtons: Qt.RightButton
                                                        onClicked: function(mouse) {
                                                            if (mouse.button === Qt.RightButton) bitrateMenu.popup();
                                                        }
                                                    }
                                                    Menu {
                                                        id: bitrateMenu
                                                        MenuItem {
                                                            text: "Copy"
                                                            onTriggered: {
                                                                if (bitrateEdit.selectedText !== "") bitrateEdit.copy();
                                                                else { bitrateEdit.selectAll(); bitrateEdit.copy(); bitrateEdit.deselect(); }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                                Button {
                                    text: "Close"
                                    Layout.alignment: Qt.AlignRight
                                    Layout.preferredHeight: 36
                                    font.pixelSize: 14
                                    font.bold: true
                                    background: Rectangle {
                                        color: parent.hovered ? "#3B4252" : "#2D3748"
                                        radius: 6
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: detailsDialog.close()
                                }
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
                                        drag.accept(Qt.CopyAction);
                }
                onExited: {
                    playlistView.hoveredDropIndex = -1;
                }
                onPositionChanged: function(drag) {
                    var pt = playlistDropArea.mapToItem(playlistView.contentItem, drag.x, drag.y);
                    var idx = playlistView.indexAt(pt.x, pt.y);
                    if (idx !== -1) {
                        playlistView.hoveredDropIndex = idx;
                    } else {
                        playlistView.hoveredDropIndex = -1;
                    }
                }
                onDropped: function(drop) {
                    playlistView.hoveredDropIndex = -1;
                                        if (drop.source && drop.source.dragData) {
                        var data = drop.source.dragData;
                        var pt = playlistDropArea.mapToItem(playlistView.contentItem, drop.x, drop.y);
                        var insertIndex = playlistView.indexAt(pt.x, pt.y);
                        if (insertIndex === -1) {
                            insertIndex = playlistModel.count;
                        }
                        if (data.isFolder) {
                            root.recursivelyAddFolder(data.parentId, insertIndex);
                        } else {
                            playlistModel.insert(insertIndex, {"title": data.title, "album": data.album !== undefined ? data.album : "", "artist": data.artist !== undefined ? data.artist : "", "mediaUrl": data.mediaUrl, "duration": data.duration, "isSelected": false, "ratingKey": data.ratingKey || ""});
                        }
                        drop.accept();
                    }
                }
            }
        }
    }

    function recursivelyAddFolder(folderId, insertIndex) {
        var libId = appCtrl.currentLibraryId;
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken;
        
        var state = { currentIndex: insertIndex !== undefined ? insertIndex : playlistModel.count };
        
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
                            var parsedAlbum2 = item.parentTitle || "";
                            var parsedArtist2 = item.grandparentTitle || item.originalTitle || "";
                            var parsedTitle2 = item.title || "";
                            
                            if (!parsedTitle2 || !parsedAlbum2 || !parsedArtist2) {
                                if (item.Media && item.Media.length > 0 && item.Media[0].Part && item.Media[0].Part.length > 0) {
                                    var filePath2 = item.Media[0].Part[0].file || "";
                                    if (filePath2 !== "") {
                                        var parts2 = filePath2.split("/");
                                        if (!parsedTitle2) {
                                            var fileName2 = parts2[parts2.length - 1];
                                            parsedTitle2 = fileName2.replace(/\.[^/.]+$/, "");
                                        }
                                        if (parts2.length >= 3) {
                                            if (!parsedAlbum2) {
                                                parsedAlbum2 = parts2[parts2.length - 2].replace(/^\d{4}\s*-\s*/, "").replace(/^\d{4}\s+/, "").replace(/!$/, "").trim();
                                            }
                                            if (!parsedArtist2) {
                                                var aStr2 = parts2[parts2.length - 3].trim();
                                                if (aStr2 === aStr2.toUpperCase() && aStr2.length > 1) {
                                                    aStr2 = aStr2.charAt(0) + aStr2.slice(1).toLowerCase();
                                                }
                                                parsedArtist2 = aStr2;
                                            }
                                        }
                                    }
                                }
                            }
                            
                            var trackData = {"title": parsedTitle2, "album": parsedAlbum2, "artist": parsedArtist2, "mediaUrl": trackUrl, "duration": item.duration || 0, "isSelected": false, "ratingKey": item.ratingKey || item.key || ""};
                            if (state.currentIndex >= playlistModel.count) {
                                playlistModel.append(trackData);
                            } else {
                                playlistModel.insert(state.currentIndex, trackData);
                            }
                            state.currentIndex++;
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
