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
    property var activeServersList: []
    property string currentLibraryId: "1"
    property string currentLibraryUniqueId: "1"
    property string currentLibraryTitle: "Movies"
    property string currentLibraryType: "movie"
    property string currentServerUrl: ""
    property string currentServerToken: ""
    property string currentServerName: ""


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
    PlexModel { connectionManager: root.connectionManager; id: m_libraryAllModel; objectName: "libraryAllModel" }


    property alias globalRecentModel: m_recentlyAddedModel
    property alias globalDeckModel: m_continueWatchingModel
    property alias collectionsModel: m_collectionsModel
    property alias collectionMoviesModel: m_collectionMoviesModel
    property alias allLibrariesModel: m_allLibrariesModel
    property alias detailsModel: m_detailsModel
    property alias libraryRecentModel: m_libraryRecentlyAddedModel
    property alias libraryDeckModel: m_libraryContinueWatchingModel
    property alias libraryCollectionsModel: m_libraryCollectionsModel
    property alias libraryAllModel: m_libraryAllModel

    property var searchResultsModel: ListModel {}
    property int currentSearchId: 0
    property bool isSearching: false

    function performSearch(query) {
        currentSearchId++;
        var reqId = currentSearchId;
        
        searchResultsModel.clear();
        if (!query || query.trim() === "") {
            isSearching = false;
            return;
        }
        
        isSearching = true;
        var servers = activeServersList;
        console.log("performSearch called! servers length: " + servers.length);
        var completedRequests = 0;
        
        var enabledLibs = parseEnabledLibraries();
        var validLibraryIds = {};
        var eKeys = Object.keys(enabledLibs);
        for (var e = 0; e < eKeys.length; e++) {
            var lib = enabledLibs[eKeys[e]];
            var sName = lib.serverName;
            if (!sName) continue;
            var libId = lib.id || eKeys[e].split("_")[1] || eKeys[e];
            if (!validLibraryIds[sName]) validLibraryIds[sName] = [];
            validLibraryIds[sName].push(libId.toString());
        }
        
        for (var i = 0; i < servers.length; i++) {
            var rawServerUrl = servers[i].serverUrl;
            var serverName = servers[i].serverName;
            var serverUrl = rawServerUrl !== "" ? rawServerUrl : connectionManager.activeUrl;
            if (serverUrl === "") continue; // Still unresolved, skip
            
            var targetUrl = serverUrl + "/hubs/search?query=" + encodeURIComponent(query);
            var serverToken = servers[i].serverToken || appSettings.token;
            (function(url, name, token) {
                connectionManager.fetchJson(targetUrl, token, function(responseText) {
                    completedRequests++;
                    if (reqId === currentSearchId && responseText !== "") {
                        try {
                            var json = JSON.parse(responseText);
                            var hubs = json.MediaContainer.Hub;
                            if (hubs) {
                                for (var j = 0; j < hubs.length; j++) {
                                    var hub = hubs[j];
                                    var items = hub.Metadata;
                                    if (items) {
                                        for (var k = 0; k < items.length; k++) {
                                            var item = items[k];
                                            var itemLibId = item.librarySectionID ? item.librarySectionID.toString() : "";
                                            if (itemLibId !== "" && validLibraryIds[name] && validLibraryIds[name].indexOf(itemLibId) === -1) {
                                                continue;
                                            }
                                            var thumb = item.thumb || "";
                                            if (thumb !== "" && thumb.indexOf("http") !== 0) {
                                                thumb = url + thumb + (thumb.indexOf("?") !== -1 ? "&" : "?") + "X-Plex-Token=" + token;
                                            }
                                            var iType = item.type || hub.type;
                                            var leafCount = item.leafCount || 0;
                                            var viewedLeafCount = item.viewedLeafCount || 0;
                                            var isWatched = false;
                                            if (iType === "show" || iType === "season") {
                                                isWatched = (leafCount > 0 && viewedLeafCount === leafCount);
                                            } else {
                                                isWatched = (item.viewCount !== undefined && item.viewCount > 0);
                                            }
                                            
                                            searchResultsModel.append({
                                                title: item.title,
                                                type: iType,
                                                year: item.year || 0,
                                                ratingKey: item.ratingKey || item.key,
                                                thumbUrl: thumb,
                                                serverName: name,
                                                serverUrl: url,
                                                leafCount: leafCount,
                                                viewedLeafCount: viewedLeafCount,
                                                isWatched: isWatched
                                            });
                                        }
                                    }
                                }
                            }
                        } catch(e) { console.log("Search parse error: " + e); }
                    }
                    if (reqId === currentSearchId && completedRequests === servers.length) {
                        isSearching = false;
                    }
                });
            })(serverUrl, serverName, serverToken);
        }
    }

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
            var raw = JSON.parse(appSettings.enabledLibraries);
            var filtered = {};
            var keys = Object.keys(raw);
            for (var i = 0; i < keys.length; i++) {
                if (keys[i].indexOf("_") !== -1) {
                    filtered[keys[i]] = raw[keys[i]];
                }
            }
            return filtered;
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
    
    function loadLibraryContent(id, title, type, serverUrl, uniqueId, serverToken, serverName) {
        console.warn("GlobalController loadLibraryContent -> id: " + id + " url: " + serverUrl + " token: " + (serverToken ? "provided" : "empty"));
        currentLibraryId = id
        currentLibraryUniqueId = uniqueId || id
        currentLibraryTitle = title
        currentLibraryType = type
        currentServerUrl = serverUrl || ""
        currentServerToken = serverToken || appSettings.token
        currentServerName = serverName || "" 
        var url = currentServerUrl !== "" ? currentServerUrl : (connectionManager.activeUrl !== "" ? connectionManager.activeUrl : appSettings.serverUrl);
        var token = currentServerToken;
        
        m_libraryRecentlyAddedModel.clear();
        m_libraryContinueWatchingModel.clear();
        m_libraryCollectionsModel.clear();
        m_libraryAllModel.clear();
        
        // Universally fetch ALL items sorted by addedAt descending to ensure we get the full list
        // instead of relying on the potentially broken or limited /recentlyAdded endpoint per library.
        if (type === "show") {
            m_libraryRecentlyAddedModel.fetchEndpoint(url, token, "/library/sections/" + id + "/all?type=2&sort=addedAt:desc")
        } else {
            m_libraryRecentlyAddedModel.fetchEndpoint(url, token, "/library/sections/" + id + "/all?type=1&sort=addedAt:desc")
        }
        
        m_libraryContinueWatchingModel.fetchEndpoint(url, token, "/library/sections/" + id + "/onDeck")
        m_libraryCollectionsModel.fetchEndpoint(url, token, "/library/sections/" + id + "/collections")
    }

    function openSettings(tabIndex) {
        settingsWindow.openTab(tabIndex, connectionManager.activeUrl, appSettings.token)
    }


    signal homeContentRefreshRequested()

    function refreshAllContent() {
        console.log("GlobalController: Refreshing all content after playback");
        homeContentRefreshRequested();
        
        if (currentLibraryId !== "") {
            console.log("GlobalController: Reloading current library content");
            loadLibraryContent(currentLibraryId, currentLibraryTitle, currentLibraryType, currentServerUrl, currentLibraryUniqueId, currentServerToken, currentServerName);
        }
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
        connectionManager.token = primary.accessToken || appSettings.token;
        connectionManager.syncServers(appSettings.serverList, appSettings.token);
        connectionManager.startExhaustiveProbe(primary.connections || []);

        var enabledLibs = parseEnabledLibraries();
        var libArray = [];
        var enabledServerNames = [];
        for (var k = 0; k < enabledServers.length; k++) { enabledServerNames.push(enabledServers[k].name); }
        console.warn("GlobalController: enabledServerNames -> " + JSON.stringify(enabledServerNames));
        console.warn("GlobalController: enabledLibs -> " + JSON.stringify(enabledLibs));

        var activeServersMap = {};
        var keys = Object.keys(enabledLibs);
        for (var i = 0; i < keys.length; i++) {
            var lib = enabledLibs[keys[i]];
            if (lib.type !== "movie" && lib.type !== "show" && lib.type !== "season" && lib.type !== "artist") continue;
            
            var sName = lib.serverName || primary.name;
            if (enabledServerNames.indexOf(sName) === -1) {
                console.warn("GlobalController: skipping library because " + sName + " is not in enabledServerNames");
                continue;
            }
            
            var sUrl = lib.serverUrl || "";
            if (sName === primary.name) {
                sUrl = ""; // FORCE dynamic resolution for the primary server
            }
            var sToken = lib.serverToken || appSettings.token;
            if (!activeServersMap[sName]) activeServersMap[sName] = { url: sUrl, token: sToken };
            
            libArray.push({
                uniqueId: keys[i],
                id: lib.id || keys[i],
                title: lib.title,
                type: lib.type,
                serverName: sName,
                serverUrl: sUrl,
                serverToken: sToken
            });
        }
        homeLibrariesList = libArray;
        
        var serverArray = [];
        var sKeys = Object.keys(activeServersMap);
        for (var j = 0; j < sKeys.length; j++) {
            serverArray.push({ serverName: sKeys[j], serverUrl: activeServersMap[sKeys[j]].url, serverToken: activeServersMap[sKeys[j]].token });
        }
        activeServersList = serverArray;

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
                var token = connectionManager.token || appSettings.token; // Use the connection manager's resolved primary token
                m_allLibrariesModel.fetchEndpoint(activeUrl, token, "/library/sections");
                m_continueWatchingModel.fetchEndpoint(activeUrl, token, "/library/onDeck");
                m_recentlyAddedModel.fetchEndpoint(activeUrl, token, "/library/recentlyAdded");
            }
        }
    }
}