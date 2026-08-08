import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    objectName: "playlistQueueView"
    property var appCtrl: null
    property var appSettings: null
    property bool isActiveView: visible
    property bool isAlbumMode: false
    property alias playlistModel: playlistModel
    property alias playlistDropArea: playlistDropArea
    property var activeRequests: []

    TextMetrics {
        id: titleMetrics
        font.pixelSize: 16
        font.bold: true
    }
    TextMetrics {
        id: textMetrics
        font.pixelSize: 14
    }
    
    property real requiredPlaylistWidth: 400
    property bool _isUpdatingWidth: false
    
    function updateRequiredWidth() {
        if (!playlistContainer) return;
        var maxT = 0, maxA = 0, maxAr = 0;
        for (var i = 0; i < playlistModel.count; i++) {
            var item = playlistModel.get(i);
            titleMetrics.text = "🔊 " + (item.title || "");
            if (titleMetrics.advanceWidth > maxT) maxT = titleMetrics.advanceWidth;
            textMetrics.text = (item.album || "");
            if (textMetrics.advanceWidth > maxA) maxA = textMetrics.advanceWidth;
            textMetrics.text = (item.artist || "");
            if (textMetrics.advanceWidth > maxAr) maxAr = textMetrics.advanceWidth;
        }
        if (_isUpdatingWidth) return;
        _isUpdatingWidth = true;
        
        var totalText = maxT + maxA + maxAr;
        if (totalText > 0 && !playlistContainer.userHasResizedColumns) {
            var remaining = 1.0 - playlistContainer.colTimeWidth - 0.05; // 0.85 for main text columns
            var nT = Math.max(0.15, (maxT / totalText) * remaining);
            var nA = Math.max(0.15, (maxA / totalText) * remaining);
            var nAr = Math.max(0.15, (maxAr / totalText) * remaining);
            
            var normTotal = nT + nA + nAr;
            playlistContainer.colTitleWidth = (nT / normTotal) * remaining;
            playlistContainer.colAlbumWidth = (nA / normTotal) * remaining;
            playlistContainer.colArtistWidth = (nAr / normTotal) * remaining;
        }

        var reqW = 0;
        if (playlistContainer.colTitleWidth > 0) reqW = Math.max(reqW, maxT / playlistContainer.colTitleWidth);
        if (playlistContainer.colAlbumWidth > 0) reqW = Math.max(reqW, maxA / playlistContainer.colAlbumWidth);
        if (playlistContainer.colArtistWidth > 0) reqW = Math.max(reqW, maxAr / playlistContainer.colArtistWidth);
        
        reqW += 40; // Only add scrollbar margins, columns manage their own ratios
        requiredPlaylistWidth = Math.max(400, reqW);
        _isUpdatingWidth = false;
    }
    
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


    property alias plexPlaylistsModel: plexPlaylistsModel
    ListModel {
        id: plexPlaylistsModel
        objectName: "plexPlaylistsModel"
    }

    function loadPlexPlaylists() {
        console.warn("loadPlexPlaylists called! appCtrl: " + !!appCtrl);
        if (!appCtrl) return;
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken || "dummy_token";
        console.warn("loadPlexPlaylists url: " + url + " token: " + !!token);
        if (!url) return;

        var req = new XMLHttpRequest();
        console.warn("Sending request to " + url + "/playlists");
        req.open("GET", url + "/playlists");
        req.setRequestHeader("X-Plex-Token", token);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                console.warn("loadPlexPlaylists DONE, status: " + req.status);
            }
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    try {
                        var json = JSON.parse(req.responseText);
                        var items = (json.MediaContainer && json.MediaContainer.Metadata) ? json.MediaContainer.Metadata : [];
                        plexPlaylistsModel.clear();
                        for (var i = 0; i < items.length; i++) {
                            var item = items[i];
                            if (item.playlistType === "audio") {
                                plexPlaylistsModel.append({
                                    "title": item.title,
                                    "ratingKey": item.ratingKey,
                                    "smart": item.smart || false,
                                    "duration": item.duration || 0,
                                    "leafCount": item.leafCount || 0
                                });
                            }
                        }
                    } catch (e) {
                        console.error("Error parsing playlists", e);
                    }
                }
            }
        };
        req.send();
    }

    property bool _isLoadingPlaylist: false
    ListModel {
        id: playlistModel
        objectName: "playlistModel" 
        onCountChanged: {
            root.updateRequiredWidth();
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
            if (plexPlaylistsModel.count === 0) {
                root.loadPlexPlaylists();
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

        var rm = (appCtrl && appSettings) ? appSettings.musicRepeatMode : 0;
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

    Rectangle {
        id: playlistContainer
        anchors.fill: parent
        color: "#111"
        
        property real colTitleWidth: 0.40
        property real colAlbumWidth: 0.25
        property real colArtistWidth: 0.20
        property bool userHasResizedColumns: false
        onColTitleWidthChanged: root.updateRequiredWidth()
        onColAlbumWidthChanged: root.updateRequiredWidth()
        onColArtistWidthChanged: root.updateRequiredWidth()
        property real colTimeWidth: 0.10
        
        ColumnLayout {
            anchors.fill: parent
            
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 15
                Text {
                    text: root.isAlbumMode ? "Tracks" : "Playlist"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.fillWidth: true
                }
                Rectangle {
                    id: saveQueueBtn
                    objectName: "saveQueueBtn"
                    visible: playlistModel.count > 0 && !root.isAlbumMode
                    height: 30
                    width: saveQueueRow.implicitWidth + 30
                    radius: 6
                    color: saveQueueMouse.containsMouse ? Qt.lighter(typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d", 1.1) : (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d")
                    
                    ToolTip.visible: saveQueueMouse.containsMouse
                    ToolTip.text: "Save as new playlist, append, or update"
                    ToolTip.delay: 500
                    ToolTip.timeout: 5000
                    
                    RowLayout {
                        id: saveQueueRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "Save"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    MouseArea {
                        id: saveQueueMouse
                        objectName: "saveQueueMouse"
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (plexPlaylistsModel.count === 0) root.loadPlexPlaylists();
                            saveQueueDialog.open()
                        }
                    }
                }
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
            
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 10
                Layout.topMargin: 0
                Layout.bottomMargin: 0
                
                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: playlistContainer.width * playlistContainer.colTitleWidth
                    height: 30
                    Text { text: "TITLE"; color: "#666"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 12; height: parent.height; anchors.right: parent.right; anchors.rightMargin: -6; color: "transparent"
                        Rectangle { width: 1; height: 16; anchors.centerIn: parent; color: "#333" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SplitHCursor
                            property real startX: 0
                            property real startLeft: 0
                            property real startRight: 0
                            onPressed: function(mouse) { 
                                playlistContainer.userHasResizedColumns = true;
                                startX = mapToItem(null, mouse.x, mouse.y).x; 
                                startLeft = playlistContainer.colTitleWidth; 
                                startRight = playlistContainer.colAlbumWidth; 
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var pt = mapToItem(null, mouse.x, mouse.y);
                                    var delta = (pt.x - startX) / playlistContainer.width;
                                    var newLeft = startLeft + delta;
                                    var newRight = startRight - delta;
                                    if (newLeft >= 0.1 && newRight >= 0.1) {
                                        playlistContainer.colTitleWidth = newLeft;
                                        playlistContainer.colAlbumWidth = newRight;
                                    } else if (newLeft < 0.1) {
                                        playlistContainer.colTitleWidth = 0.1;
                                        playlistContainer.colAlbumWidth = startLeft + startRight - 0.1;
                                    } else if (newRight < 0.1) {
                                        playlistContainer.colAlbumWidth = 0.1;
                                        playlistContainer.colTitleWidth = startLeft + startRight - 0.1;
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.preferredWidth: playlistContainer.width * playlistContainer.colAlbumWidth
                    height: 30
                    Text { text: "ALBUM"; color: "#666"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 12; height: parent.height; anchors.right: parent.right; anchors.rightMargin: -6; color: "transparent"
                        Rectangle { width: 1; height: 16; anchors.centerIn: parent; color: "#333" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SplitHCursor
                            property real startX: 0
                            property real startLeft: 0
                            property real startRight: 0
                            onPressed: function(mouse) { 
                                playlistContainer.userHasResizedColumns = true;
                                startX = mapToItem(null, mouse.x, mouse.y).x; 
                                startLeft = playlistContainer.colAlbumWidth; 
                                startRight = playlistContainer.colArtistWidth; 
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var pt = mapToItem(null, mouse.x, mouse.y);
                                    var delta = (pt.x - startX) / playlistContainer.width;
                                    var newLeft = startLeft + delta;
                                    var newRight = startRight - delta;
                                    if (newLeft >= 0.1 && newRight >= 0.1) {
                                        playlistContainer.colAlbumWidth = newLeft;
                                        playlistContainer.colArtistWidth = newRight;
                                    } else if (newLeft < 0.1) {
                                        playlistContainer.colAlbumWidth = 0.1;
                                        playlistContainer.colArtistWidth = startLeft + startRight - 0.1;
                                    } else if (newRight < 0.1) {
                                        playlistContainer.colArtistWidth = 0.1;
                                        playlistContainer.colAlbumWidth = startLeft + startRight - 0.1;
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.preferredWidth: playlistContainer.width * playlistContainer.colArtistWidth
                    height: 30
                    Text { text: "ARTIST"; color: "#666"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: 12; height: parent.height; anchors.right: parent.right; anchors.rightMargin: -6; color: "transparent"
                        Rectangle { width: 1; height: 16; anchors.centerIn: parent; color: "#333" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SplitHCursor
                            property real startX: 0
                            property real startLeft: 0
                            property real startRight: 0
                            onPressed: function(mouse) { 
                                playlistContainer.userHasResizedColumns = true;
                                startX = mapToItem(null, mouse.x, mouse.y).x; 
                                startLeft = playlistContainer.colArtistWidth; 
                                startRight = playlistContainer.colTimeWidth; 
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var pt = mapToItem(null, mouse.x, mouse.y);
                                    var delta = (pt.x - startX) / playlistContainer.width;
                                    var newLeft = startLeft + delta;
                                    var newRight = startRight - delta;
                                    if (newLeft >= 0.1 && newRight >= 0.08) {
                                        playlistContainer.colArtistWidth = newLeft;
                                        playlistContainer.colTimeWidth = newRight;
                                    } else if (newLeft < 0.1) {
                                        playlistContainer.colArtistWidth = 0.1;
                                        playlistContainer.colTimeWidth = startLeft + startRight - 0.1;
                                    } else if (newRight < 0.08) {
                                        playlistContainer.colTimeWidth = 0.08;
                                        playlistContainer.colArtistWidth = startLeft + startRight - 0.08;
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.preferredWidth: playlistContainer.width * playlistContainer.colTimeWidth
                    height: 30
                    Text { text: "TIME"; color: "#666"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#222"
                Layout.leftMargin: 10
                Layout.rightMargin: 10
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
                            Layout.preferredWidth: playlistContainer.width * playlistContainer.colTitleWidth
                            elide: Text.ElideRight
                            font.pixelSize: 16
                        }
                        
                        Text {
                            text: model.album !== undefined ? model.album : ""
                            color: "#ccc"
                            Layout.preferredWidth: playlistContainer.width * playlistContainer.colAlbumWidth
                            elide: Text.ElideRight
                            font.pixelSize: 14
                        }
                        
                        Text {
                            text: model.artist !== undefined ? model.artist : ""
                            color: "#ccc"
                            Layout.preferredWidth: playlistContainer.width * playlistContainer.colArtistWidth
                            elide: Text.ElideRight
                            font.pixelSize: 14
                        }
                        
                        Text {
                            text: (typeof mainWindow !== "undefined" && model.duration) ? mainWindow.formatTime(model.duration / 1000) : "00:00"
                            color: "#aaa"
                            Layout.preferredWidth: playlistContainer.width * playlistContainer.colTimeWidth
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
                        background: Rectangle {
                            color: "#222"
                            radius: 4
                            border.color: "#444"
                            border.width: 1
                        }
                        MenuItem {
                            objectName: "detailsMenuItem"
                            text: "Details"
                            contentItem: Text {
                                text: parent.text
                                color: "#E5A00D"
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
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
                            contentItem: Text {
                                text: parent.text
                                color: "#E5A00D"
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
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
                                                    background: Rectangle {
                                                        color: "#222"
                                                        radius: 4
                                                        border.color: "#444"
                                                        border.width: 1
                                                    }
                                                    MenuItem {
                                                        text: "Copy"
                                                        contentItem: Text {
                                                            text: parent.text
                                                            color: "#E5A00D"
                                                            font.pixelSize: 16
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                        background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
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
                                                    background: Rectangle {
                                                        color: "#222"
                                                        radius: 4
                                                        border.color: "#444"
                                                        border.width: 1
                                                    }
                                                    MenuItem {
                                                        text: "Copy"
                                                        contentItem: Text {
                                                            text: parent.text
                                                            color: "#E5A00D"
                                                            font.pixelSize: 16
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                        background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
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
                                                    background: Rectangle {
                                                        color: "#222"
                                                        radius: 4
                                                        border.color: "#444"
                                                        border.width: 1
                                                    }
                                                    MenuItem {
                                                        text: "Copy"
                                                        contentItem: Text {
                                                            text: parent.text
                                                            color: "#E5A00D"
                                                            font.pixelSize: 16
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                        background: Rectangle { color: parent.highlighted ? "#444" : "transparent"; radius: 4 }
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
            enabled: !root.isAlbumMode
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
                    } else if (data.isPlexPlaylist) {
                        root.addPlexPlaylist(data.ratingKey, insertIndex);
                    } else {
                        playlistModel.insert(insertIndex, {"title": data.title, "album": data.album !== undefined ? data.album : "", "artist": data.artist !== undefined ? data.artist : "", "mediaUrl": data.mediaUrl, "duration": data.duration, "isSelected": false, "ratingKey": data.ratingKey || ""});
                    }
                    drop.accept();
                }
            }
        }
    }

    function addPlexPlaylist(playlistId, insertIndex) {
        console.warn("addPlexPlaylist called with playlistId: " + playlistId);
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken || "dummy";
        if (!url) return;
        
        var state = { currentIndex: insertIndex !== undefined ? insertIndex : playlistModel.count };
        var req = new XMLHttpRequest();
        var arr = root.activeRequests; arr.push(req); root.activeRequests = arr;
        var endpoint = "/playlists/" + playlistId + "/items";
        console.warn("addPlexPlaylist fetching: " + url + endpoint);
        req.open("GET", url + endpoint);
        req.setRequestHeader("X-Plex-Token", token);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                console.warn("addPlexPlaylist DONE status 200");
                try {
                    var json = JSON.parse(req.responseText);
                    var items = (json.MediaContainer && json.MediaContainer.Metadata) ? json.MediaContainer.Metadata : [];
                    console.warn("Found " + items.length + " items in playlist");
                    for (var i = 0; i < items.length; i++) {
                        var item = items[i];
                        if (item.type === "track") {
                            var trackUrl = "";
                            if (item.Media && item.Media.length > 0 && item.Media[0].Part && item.Media[0].Part.length > 0) {
                                var partKey = item.Media[0].Part[0].key || item.Media[0].Part[0].file;
                                trackUrl = url + partKey + "?X-Plex-Token=" + token;
                            }
                            var parsedAlbum2 = item.parentTitle || "";
                            var parsedArtist2 = item.grandparentTitle || item.originalTitle || "";
                            var parsedTitle2 = item.title || "";
                            
                            var trackData = {"title": parsedTitle2, "album": parsedAlbum2, "artist": parsedArtist2, "mediaUrl": trackUrl, "duration": item.duration || 0, "isSelected": false, "ratingKey": item.ratingKey || item.key || ""};
                            if (state.currentIndex >= playlistModel.count) {
                                playlistModel.append(trackData);
                            } else {
                                playlistModel.insert(state.currentIndex, trackData);
                            }
                            state.currentIndex++;
                        }
                    }
                } catch (e) {
                    console.error("Error parsing playlist items", e);
                }
                var arr2 = root.activeRequests;
                var idx = arr2.indexOf(req);
                if (idx !== -1) { arr2.splice(idx, 1); root.activeRequests = arr2; }
            }
        };
        req.send();
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

    function getQueueRatingKeys() {
        var keys = [];
        for (var i = 0; i < playlistModel.count; i++) {
            var rk = playlistModel.get(i).ratingKey;
            if (rk) keys.push(rk);
        }
        return keys.join(",");
    }

    function saveQueueAsNewPlaylist(title) {
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken || "dummy";
        if (!url) return;
        var keysStr = getQueueRatingKeys();
        if (!keysStr) return;
        
        var req = new XMLHttpRequest();
        req.open("GET", url + "/");
        req.setRequestHeader("X-Plex-Token", token);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                var json = JSON.parse(req.responseText);
                var machineId = json.MediaContainer.machineIdentifier;
                
                var postReq = new XMLHttpRequest();
                var uri = "server://" + machineId + "/com.plexapp.plugins.library/library/metadata/" + keysStr;
                postReq.open("POST", url + "/playlists?type=audio&smart=0&title=" + encodeURIComponent(title) + "&uri=" + encodeURIComponent(uri));
                postReq.setRequestHeader("X-Plex-Token", token);
                postReq.setRequestHeader("Accept", "application/json");
                postReq.onreadystatechange = function() {
                    if (postReq.readyState === XMLHttpRequest.DONE) {
                        console.warn("Created playlist:", postReq.status);
                        root.loadPlexPlaylists();
                    }
                };
                postReq.send();
            }
        };
        req.send();
    }

    function replacePlaylistWithQueue(playlistId) {
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken || "dummy";
        if (!url) return;
        var keysStr = getQueueRatingKeys();
        if (!keysStr) return;
        
        var req = new XMLHttpRequest();
        req.open("GET", url + "/");
        req.setRequestHeader("X-Plex-Token", token);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                var json = JSON.parse(req.responseText);
                var machineId = json.MediaContainer.machineIdentifier;
                
                var delReq = new XMLHttpRequest();
                delReq.open("DELETE", url + "/playlists/" + playlistId + "/items");
                delReq.setRequestHeader("X-Plex-Token", token);
                delReq.setRequestHeader("Accept", "application/json");
                delReq.onreadystatechange = function() {
                    if (delReq.readyState === XMLHttpRequest.DONE) {
                        var putReq = new XMLHttpRequest();
                        var uri = "server://" + machineId + "/com.plexapp.plugins.library/library/metadata/" + keysStr;
                        putReq.open("PUT", url + "/playlists/" + playlistId + "/items?uri=" + encodeURIComponent(uri));
                        putReq.setRequestHeader("X-Plex-Token", token);
                        putReq.setRequestHeader("Accept", "application/json");
                        putReq.onreadystatechange = function() {
                            if (putReq.readyState === XMLHttpRequest.DONE) {
                                console.warn("Replaced playlist:", putReq.status);
                                root.loadPlexPlaylists();
                            }
                        };
                        putReq.send();
                    }
                };
                delReq.send();
            }
        };
        req.send();
    }

    function appendQueueToPlaylist(playlistId) {
        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : appCtrl.connectionManager.activeUrl;
        var token = appCtrl.currentServerToken || "dummy";
        if (!url) return;
        var keysStr = getQueueRatingKeys();
        if (!keysStr) return;
        
        var req = new XMLHttpRequest();
        req.open("GET", url + "/");
        req.setRequestHeader("X-Plex-Token", token);
        req.setRequestHeader("Accept", "application/json");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                var json = JSON.parse(req.responseText);
                var machineId = json.MediaContainer.machineIdentifier;
                
                var putReq = new XMLHttpRequest();
                var uri = "server://" + machineId + "/com.plexapp.plugins.library/library/metadata/" + keysStr;
                putReq.open("PUT", url + "/playlists/" + playlistId + "/items?uri=" + encodeURIComponent(uri));
                putReq.setRequestHeader("X-Plex-Token", token);
                putReq.setRequestHeader("Accept", "application/json");
                putReq.onreadystatechange = function() {
                    if (putReq.readyState === XMLHttpRequest.DONE) {
                        console.warn("Appended to playlist:", putReq.status);
                        root.loadPlexPlaylists();
                    }
                };
                putReq.send();
            }
        };
        req.send();
    }

    Popup {
        id: saveQueueDialog
        objectName: "saveQueueDialog"
        property string selectedPlaylistId: ""
        property string selectedPlaylistTitle: ""
        
        onOpened: {
            playlistNameInput.text = "";
            selectedPlaylistId = "";
            selectedPlaylistTitle = "";
            existingPlaylistsView.forceLayout();
        }

        anchors.centerIn: parent
        width: 400
        height: 550
        modal: true
        focus: true
        padding: 0
        background: Rectangle {
            color: "#111"
            border.color: "#444"
            radius: 8
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Text {
                text: "Save Queue to Playlist"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: "#222"
                radius: 4
                border.color: "#444"
                
                TextInput {
                    id: playlistNameInput
                    objectName: "playlistNameInput"
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "white"
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 14
                    clip: true
                    
                    onTextChanged: {
                        if (text !== saveQueueDialog.selectedPlaylistTitle) {
                            saveQueueDialog.selectedPlaylistId = "";
                            saveQueueDialog.selectedPlaylistTitle = "";
                        }
                    }
                    
                    Text {
                        text: "Search or enter playlist name..."
                        color: "#888"
                        font.pixelSize: 14
                        visible: parent.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            
            ListView {
                id: existingPlaylistsView
                objectName: "existingPlaylistsView"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: plexPlaylistsModel
                
                ScrollBar.vertical: ScrollBar {
                    active: hovered || existingPlaylistsView.moving
                    policy: ScrollBar.AsNeeded
                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: parent.active ? "#80ffffff" : "#40ffffff"
                    }
                }
                
                delegate: ItemDelegate {
                    objectName: "plOpt_" + model.ratingKey
                    property string searchText: playlistNameInput.text
                    property string myTitle: model.title !== undefined ? model.title : ""
                    property bool match: searchText === "" || (myTitle !== "" && myTitle.toLowerCase().indexOf(searchText.toLowerCase()) !== -1)
                    width: ListView.view.width
                    height: match ? 50 : 0
                    visible: match
                    text: myTitle !== "" ? myTitle : "Unnamed Playlist"
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        elide: Text.ElideRight
                        font.bold: saveQueueDialog.selectedPlaylistId === model.ratingKey
                    }
                    
                    background: Rectangle {
                        color: saveQueueDialog.selectedPlaylistId === model.ratingKey ? "#444" : (parent.hovered ? "#333" : "transparent")
                        radius: 4
                    }
                    
                    onClicked: {
                        saveQueueDialog.selectedPlaylistId = model.ratingKey;
                        saveQueueDialog.selectedPlaylistTitle = model.title;
                        playlistNameInput.text = model.title;
                    }
                }
            }
            
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: playlistNameInput.text !== "" || saveQueueDialog.selectedPlaylistId !== ""
                
                RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    
                    // Create New Button
                Rectangle {
                    id: createPlaylistBtn
                    objectName: "createPlaylistBtn"
                    Layout.fillWidth: true
                    height: 40
                    visible: saveQueueDialog.selectedPlaylistId === "" && playlistNameInput.text !== ""
                    radius: 4
                    color: cpMouse.containsMouse ? Qt.lighter(typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d", 1.1) : (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d")
                    
                    Text {
                        text: "Save as New Playlist"
                        color: "white"
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    
                    MouseArea {
                        id: cpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (playlistNameInput.text !== "") {
                                root.saveQueueAsNewPlaylist(playlistNameInput.text);
                                saveQueueDialog.close();
                            }
                        }
                    }
                }
                
                // Replace Button
                Rectangle {
                    id: replacePlaylistBtn
                    objectName: "replacePlaylistBtn"
                    Layout.fillWidth: true
                    height: 40
                    visible: saveQueueDialog.selectedPlaylistId !== ""
                    radius: 4
                    color: repMouse.containsMouse ? Qt.lighter(typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d", 1.1) : (typeof mainWindow !== "undefined" ? mainWindow.plexOrange : "#e5a00d")
                    
                    Text {
                        text: "Update Playlist"
                        color: "white"
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    
                    MouseArea {
                        id: repMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.replacePlaylistWithQueue(saveQueueDialog.selectedPlaylistId);
                            saveQueueDialog.close();
                        }
                    }
                }
                
                // Append Button
                Rectangle {
                    id: appendPlaylistBtn
                    objectName: "appendPlaylistBtn"
                    Layout.fillWidth: true
                    height: 40
                    visible: saveQueueDialog.selectedPlaylistId !== ""
                    radius: 4
                    color: appMouse.containsMouse ? "#555" : "#444"
                    
                    Text {
                        text: "Append to Playlist"
                        color: "white"
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.appendQueueToPlaylist(saveQueueDialog.selectedPlaylistId);
                            saveQueueDialog.close();
                        }
                    }
                }
            }
            }
        }
    }
}
