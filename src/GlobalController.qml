import QtQuick
import flex.plex 1.0

Item {
    id: root
    visible: false

    property var mainWindow
    property var appSettings
    property var playerView
    property var settingsWindow
    property var connectionManager
    

    property bool isScrubbing: false
    property bool wasPausedBeforeScrub: false
    property real lastSeekTime: 0
    property int consecutiveSeekCount: 0
    
    property var homeLibrariesList: []
    property string currentLibraryId: "1"
    property string currentLibraryTitle: "Movies"


    signal hdrCommandExecuted(string command)


    PlexModel { connectionManager: root.connectionManager; id: m_recentlyAddedModel; objectName: "recentlyAddedModel" }
    PlexModel { connectionManager: root.connectionManager; id: m_continueWatchingModel }
    PlexModel { connectionManager: root.connectionManager; id: m_collectionsModel }
    PlexModel { connectionManager: root.connectionManager; id: m_collectionMoviesModel }
    PlexModel { connectionManager: root.connectionManager; id: m_allLibrariesModel }
    PlexModel { connectionManager: root.connectionManager; id: m_detailsModel }
    PlexModel { connectionManager: root.connectionManager; id: m_libraryRecentlyAddedModel }
    PlexModel { connectionManager: root.connectionManager; id: m_libraryContinueWatchingModel }
    PlexModel { connectionManager: root.connectionManager; id: m_libraryCollectionsModel }


    property alias globalRecentModel: m_recentlyAddedModel
    property alias globalDeckModel: m_continueWatchingModel
    property alias collectionsModel: m_collectionsModel
    property alias collectionMoviesModel: m_collectionMoviesModel
    property alias allLibrariesModel: m_allLibrariesModel
    property alias detailsModel: m_detailsModel
    property alias libraryRecentModel: m_libraryRecentlyAddedModel
    property alias libraryDeckModel: m_libraryContinueWatchingModel
    property alias libraryCollectionsModel: m_libraryCollectionsModel

    function throttleSeek(direction) {
        var now = Date.now()
        if (now - lastSeekTime < 50) return 
        
        lastSeekTime = now
        consecutiveSeekCount++
        scrubEndTimer.restart()
        
        if (!isScrubbing && consecutiveSeekCount > 1) {
            isScrubbing = true
            wasPausedBeforeScrub = playerView.mpvObject.paused
            playerView.mpvObject.paused = true
        }
        
        var seekAmount = 5
        if (consecutiveSeekCount > 30) seekAmount = 30
        else if (consecutiveSeekCount > 5) seekAmount = 10
        
        playerView.mpvObject.command(["seek", direction * seekAmount, "relative", "keyframes"])
    }

    Timer {
        id: scrubEndTimer
        interval: 300
        onTriggered: {
            if (isScrubbing) {
                isScrubbing = false
                if (playerView.visible) {
                    playerView.mpvObject.command(["seek", "0", "relative", "exact"])
                    playerView.mpvObject.paused = wasPausedBeforeScrub
                }
            }
            consecutiveSeekCount = 0
        }
    }

    function getLibraryIcon(type) {
        if (type === "show") return "📺"
        if (type === "artist") return "🎵"
        if (type === "photo") return "📷"
        return "🎬"
    }
    
    function parseEnabledLibraries() {
        try {
            return JSON.parse(appSettings.enabledLibraries)
        } catch (e) {
            return {}
        }
    }
    
    function setLibraryEnabled(id, enabled, type, title) {
        var libs = parseEnabledLibraries()
        if (enabled) {
            libs[id] = { type: type, title: title }
        } else {
            delete libs[id]
        }
        appSettings.enabledLibraries = JSON.stringify(libs)
    }

    function closeSettings() {
        settingsWindow.visible = false
        startupLogic()
    }

    function runHdrCommand(cmd) {
        if (m_continueWatchingModel && cmd !== "") {
            console.log("GlobalController: Executing system command: " + cmd)
            m_continueWatchingModel.executeSystemCommand(cmd);
            hdrCommandExecuted(cmd)
        }
    }

    function deployHdrScript() {
        console.log("GlobalController: performing legacy HDR script cleanup...")
        if (m_continueWatchingModel) {
            m_continueWatchingModel.deployHdrScript(false, "", "");
        }
    }
    
    function loadLibraryContent(id, title, type) {
        currentLibraryId = id
        currentLibraryTitle = title
        var url = connectionManager.activeUrl !== "" ? connectionManager.activeUrl : appSettings.serverUrl;
        
        // Universally fetch ALL items sorted by addedAt descending to ensure we get the full list
        // instead of relying on the potentially broken or limited /recentlyAdded endpoint per library.
        if (type === "show") {
            m_libraryRecentlyAddedModel.fetchEndpoint(url, appSettings.token, "/library/sections/" + id + "/all?type=2&sort=addedAt:desc")
        } else {
            m_libraryRecentlyAddedModel.fetchEndpoint(url, appSettings.token, "/library/sections/" + id + "/all?type=1&sort=addedAt:desc")
        }
        
        m_libraryContinueWatchingModel.fetchEndpoint(url, appSettings.token, "/library/sections/" + id + "/onDeck")
        m_libraryCollectionsModel.fetchEndpoint(url, appSettings.token, "/library/sections/" + id + "/collections")
    }

    function openSettings(tabIndex) {
        settingsWindow.openTab(tabIndex, connectionManager.activeUrl, appSettings.token)
    }

    function startupLogic() {
        // ONE-TIME FACTORY RESET for Connectivity Refactor
        if (appSettings.connectionVersion < 4) {
            console.log("[Migration] Connection logic version mismatch. Performing factory reset of server list.");
            appSettings.serverList = "[]";
            appSettings.connectionVersion = 4;
            // Force return to login state if no servers
            return;
        }
        console.log("GlobalController: startupLogic running...");
        
                if (mainWindow.isTestMode) {
            console.log("Test mode detected, loading mock libraries but using real endpoints");
            homeLibrariesList = [
                { id: "1", title: "Test Movies", type: "movie", serverName: "omv" },
                { id: "2", title: "Test Series", type: "show", serverName: "omv" }
            ];
            // Do NOT return here. Allow fetchEndpoint to run against mock server.
        }

        if (appSettings.token === "") {
            console.log("Missing token, showing settings");
            openSettings();
            return;
        }

        var serverList = [];
        try {
            serverList = JSON.parse(appSettings.serverList || "[]");
        } catch(e) { serverList = []; }
        
        // MANDATORY PURGE: Eliminate plex.direct from storage
        var needsSaving = false;
        for (var i = 0; i < serverList.length; i++) {
            var s = serverList[i];
            if (s.localUrl && s.localUrl.indexOf("plex.direct") !== -1) {
                console.log("[Migration] Purging plex.direct from localUrl of " + s.name);
                // Extract IP from hostname if possible
                var match = s.localUrl.match(/(\d+-\d+-\d+-\d+)/);
                if (match) {
                    var ip = match[1].replace(/-/g, ".");
                    s.localUrl = "http://" + ip + ":32400";
                } else {
                    s.localUrl = ""; // Force re-discovery
                }
                needsSaving = true;
            }
            if (s.remoteUrl && s.remoteUrl.indexOf("plex.direct") !== -1) {
                console.log("[Migration] Purging plex.direct from remoteUrl of " + s.name);
                var matchR = s.remoteUrl.match(/(\d+-\d+-\d+-\d+)/);
                if (matchR) {
                    var ipR = matchR[1].replace(/-/g, ".");
                    s.remoteUrl = "http://" + ipR + ":32400";
                } else {
                    s.remoteUrl = "";
                }
                needsSaving = true;
            }
        }
        if (needsSaving) {
            appSettings.serverList = JSON.stringify(serverList);
        }

        var enabledServers = serverList.filter(function(s) { return s.enabled });
        
        if (enabledServers.length === 0) {
            console.log("No enabled servers, showing settings");
            openSettings();
            return;
        }

        var primary = enabledServers[0];
        console.log("GlobalController: Probing primary server: " + primary.name);
        connectionManager.token = appSettings.token;
                console.log("GlobalController: Probing primary " + primary.name + " with " + (primary.connections ? primary.connections.length : 0) + " connections");
        if (primary.connections) {
            for (var i = 0; i < primary.connections.length; i++) {
                var c = primary.connections[i];
                console.log("  - Candidate: " + c.address + ":" + c.port + " (" + c.protocol + ", local: " + c.local + ")");
            }
        }
        connectionManager.startExhaustiveProbe(primary.connections || []);

        var enabledLibs = parseEnabledLibraries();
        var libArray = [];
        var keys = Object.keys(enabledLibs);
        for (var i = 0; i < keys.length; i++) {
            var lib = enabledLibs[keys[i]];
            libArray.push({
                id: keys[i],
                title: lib.title,
                type: lib.type,
                serverName: lib.serverName || primary.name
            });
        }
        homeLibrariesList = libArray;

        // Fetching will happen in onResolutionFinished
        console.log("GlobalController: Waiting for connection resolution...");
    }

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "00:00";
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        var h = Math.floor(m / 60);
        m = m % 60;
        var mStr = (m < 10 ? "0" : "") + m;
        var sStr = (s < 10 ? "0" : "") + s;
        if (h > 0) return h + ":" + mStr + ":" + sStr;
        return mStr + ":" + sStr;
    }

    Connections {
        target: connectionManager
        function onResolutionFinished(success) {
            console.log("GlobalController: Resolution finished, success=" + success + " activeUrl=" + connectionManager.activeUrl);
            if (success) {
                var activeUrl = connectionManager.activeUrl;
                m_allLibrariesModel.fetchEndpoint(activeUrl, appSettings.token, "/library/sections");
                m_continueWatchingModel.fetchEndpoint(activeUrl, appSettings.token, "/library/onDeck");
                m_recentlyAddedModel.fetchEndpoint(activeUrl, appSettings.token, "/library/recentlyAdded");
            }
        }
    }
}