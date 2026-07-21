import QtQuick
import flex.plex 1.0

Item {
    id: root
    visible: false

    property var mainWindow
    property var appSettings
    property var playerView
    property var settingsWindow
    
    // State properties
    property bool isScrubbing: false
    property bool wasPausedBeforeScrub: false
    property real lastSeekTime: 0
    property int consecutiveSeekCount: 0
    
    property var homeLibrariesList: []
    property string currentLibraryId: "1"
    property string currentLibraryTitle: "Movies"

    // Testing signals
    signal hdrCommandExecuted(string command)

    // Models
    PlexModel { id: m_recentlyAddedModel }
    PlexModel { id: m_continueWatchingModel }
    PlexModel { id: m_collectionsModel }
    PlexModel { id: m_collectionMoviesModel }
    PlexModel { id: m_allLibrariesModel }
    PlexModel { id: m_detailsModel }
    PlexModel { id: m_libraryRecentlyAddedModel }
    PlexModel { id: m_libraryContinueWatchingModel }
    PlexModel { id: m_libraryCollectionsModel }

    // Expose models for easier access from Main
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

    // Now a no-op as logic is moved to QML/C++ properties
    function deployHdrScript() {
        console.log("GlobalController: performing legacy HDR script cleanup...")
        if (m_continueWatchingModel) {
            m_continueWatchingModel.deployHdrScript(false, "", "");
        }
    }
    
    function loadLibraryContent(id, title, type) {
        currentLibraryId = id
        currentLibraryTitle = title
        if (!mainWindow.isTestMode) {
            if (type === "show") {
                m_libraryRecentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/all?type=2&sort=addedAt:desc")
            } else {
                m_libraryRecentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/recentlyAdded")
            }
            m_libraryContinueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/onDeck")
            m_libraryCollectionsModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections/" + id + "/collections")
        }
    }

    function openSettings(tabIndex) {
        settingsWindow.openTab(tabIndex, appSettings.serverUrl, appSettings.token)
    }

    function startupLogic() {
        if (appSettings.serverUrl === "" || appSettings.token === "") {
            console.log("Missing config, showing settings")
            openSettings()
        } else {
            console.log("Fetching data from " + appSettings.serverUrl);
            var enabledMap = parseEnabledLibraries()
            var keys = Object.keys(enabledMap)
            var libArray = []
            for (var i = 0; i < keys.length; i++) {
                var key = keys[i]
                libArray.push({
                    id: key,
                    title: enabledMap[key].title || "Library",
                    type: enabledMap[key].type || "movie"
                })
            }
            homeLibrariesList = libArray
            console.log("GlobalController: homeLibrariesList updated, count: " + libArray.length);
                
            if (!mainWindow.isTestMode) {
                m_allLibrariesModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/sections")
                if (keys.length > 0) {
                    m_continueWatchingModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/onDeck")
                    m_recentlyAddedModel.fetchEndpoint(appSettings.serverUrl, appSettings.token, "/library/recentlyAdded")
                } else {
                    m_continueWatchingModel.loadMockData([], "")
                }
            }
        }
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
}

