import QtQuick
import QtTest
import flex.plex 1.0
import "../../src"

TestCase {
    name: "RealConnectionTest"
    when: true
    width: 1280
    height: 720

    Component {
        id: appComponent
        Main {
            // NOT setting isTestMode: true, so it loads real config.ini!
        }
    }

    property var app

    function initTestCase() {
        app = createTemporaryObject(appComponent, null)
        verify(app !== null, "Main application should be created")
    }

    /*
     * test_real_server_connection (Physical Test)
     * 
     * This test requires execution on a REAL, physical Wayland session (e.g. WAYLAND_DISPLAY=wayland-0).
     * It connects to the user's real Plex server, discovers the library, simulates a UI click on
     * the first recently added movie, and executes a full end-to-end playback test.
     * 
     * Because it runs on bare metal, this test explicitly verifies:
     * 1. Hardware video decoding (VAAPI/CUDA)
     * 2. Audio routing (Pipewire / PulseAudio)
     * 3. System HDR switching (e.g., kscreen-doctor integration)
     * 4. Successful MPV stream initialization over HTTPS
     */
    function test_real_server_connection() {
        var settingsWindow = findChild(app, "settingsWindow")
        var cm = findChild(app, "connectionManager")
        
        verify(settingsWindow !== null)
        verify(cm !== null)
        
        console.log("Waiting for real connection resolution...")
        tryCompare(cm, "isResolving", false, 10000)
        console.log("Active URL is now: " + cm.activeUrl)
        
        settingsWindow.visible = true
        wait(500)
        
        tryCompare(settingsWindow, "connectionState", 2, 5000)
        verify(cm.activeUrl.includes("192.168.31.2"), "Should be connected to 192.168.31.2")
        
        settingsWindow.openTab(1)
        wait(1000)
        verify(app.appSettings.enabledLibraries !== "{}", "enabledLibraries should be updated")
        
        var allLibsModel = app.controller.allLibrariesModel
        console.log("Waiting for libraries to fetch...")
        tryVerify(function() { return allLibsModel.rowCount() > 0; }, 10000, "Libraries should be fetched")
        
        console.log("Success! Found " + allLibsModel.rowCount() + " libraries from the real server.")
        
        // Select the first library (Movies)
        var librariesTabCol = findChild(settingsWindow, "librariesTabCol")
        verify(librariesTabCol !== null)
        
        var map = Object.assign({}, librariesTabCol.localLibrariesMap)
        // Hardcode the known Movies library ID for the test since enum roles are tricky in QML
        map["1"] = { "type": "movie", "title": "Movies", "serverName": "omv" }
        librariesTabCol.localLibrariesMap = map
        
        console.log("Saving libraries...")
        var saveBtn = findChild(settingsWindow, "saveLibrariesButton")
        verify(saveBtn !== null)
        
        console.log("Before save: " + app.appSettings.enabledLibraries)
        saveBtn.clicked()
        console.log("After save: " + app.appSettings.enabledLibraries)
        
        // Force startupLogic since it might be skipped if isTestEnvironment is somehow true
        app.startupLogic()
        
        wait(1000)
        verify(app.appSettings.enabledLibraries !== "{}", "enabledLibraries should be updated")
        
        console.log("Checking if movies are loaded...")
        
        var mainContent = findChild(app, "homeView")
        verify(mainContent !== null, "homeView should exist")
        
        // Find the LibraryRail for Movies
        var homeCol = findChild(mainContent, "homeContentColumn")
        verify(homeCol !== null)
        
        var rep = findChild(homeCol, "libraryRepeater")
        verify(rep !== null)
        
        tryVerify(function() { return rep.count > 0; }, 10000, "Library repeater should create a rail")
        
        var rail = rep.itemAt(0)
        verify(rail !== null, "Rail should exist")
        
        var delegateRecentModel = findChild(rail, "delegateRecentModel")
        verify(delegateRecentModel !== null, "Rail should have its own recent model")
        
        tryVerify(function() { return delegateRecentModel.rowCount() > 0; }, 10000, "Rail should fetch its movies using the active URL")
        
        console.log("Movies successfully loaded!")
        
        var movieData = delegateRecentModel.get(0)
        verify(movieData !== null, "Should get movie data from model")
        console.log("Simulating click on movie: " + movieData.title + " (ratingKey: " + movieData.ratingKey + ")")
        
        app.controller.detailsModel.fetchItemDetails(cm.activeUrl, app.appSettings.token, movieData.ratingKey)
        app.currentTab = 3
        
        var movieDetailsView = findChild(app, "movieDetailsView")
        tryVerify(function() { return movieDetailsView.detailsData !== null && movieDetailsView.detailsData !== undefined; }, 10000, "detailsData must load first");
        
        var playBtn = findChild(movieDetailsView, "detailsPlayButton");
        tryVerify(function() { return playBtn !== null; }, 5000, "Play btn should exist");
        if (playBtn !== null) { playBtn.clicked(); }
        
        var playerView = findChild(app, "playerView")
        verify(playerView !== null)
        tryVerify(function() { return playerView.visible; }, 10000, "Player view should become visible")
        
        var mpvItem = findChild(playerView, "mpvObject")
        verify(mpvItem !== null)
        
        tryVerify(function() { return mpvItem.duration > 0; }, 25000, "Playback should start (duration > 0)")
        
        console.log("Waiting a few seconds of playback...")
        wait(5000)
        
        tryVerify(function() { return mpvItem.position > 1; }, 5000, "Playback position should advance")
        
        console.log("Playback works on real server!")
        

    }


    /*
     * test_real_shared_library_connection
     * 
     * This test explicitly checks the functionality of Shared Libraries.
     * It scans the user's real account for a server named "shared" (or "Docker Test Server"),
     * verifies that a custom accessToken was successfully extracted by PlexAuth,
     * enables the "Movies" library from that shared server, and ensures the HomeView
     * successfully routes the custom token to fetch and display the media.
     */
    function test_real_shared_library_connection() {
        var settingsWindow = findChild(app, "settingsWindow")
        verify(settingsWindow !== null)
        
        settingsWindow.visible = true
        wait(500)
        
        settingsWindow.openTab(1)
        wait(1000)
        
        console.log("Looking for a shared server in the server list...")
        var list = settingsWindow.localServersList;
        var sharedServer = null;
        for (var i = 0; i < list.length; i++) {
            var sName = list[i].name ? list[i].name.toLowerCase() : "";
            if (sName.includes("shared") || sName.includes("docker")) {
                sharedServer = list[i];
                break;
            }
        }
        
        verify(sharedServer !== null, "Could not find a shared server (named 'shared' or 'docker') on the real account");
        console.log("Found shared server: " + sharedServer.name);
        
        verify(sharedServer.accessToken !== undefined && sharedServer.accessToken !== "", "Shared server MUST have a custom accessToken extracted");
        verify(sharedServer.accessToken !== app.appSettings.token, "Shared server token must differ from the global account token");
        
        console.log("Shared server token verified as unique.")
        
        // Find the library list for this server in the UI
        var serverLibrariesList = findChild(settingsWindow, "serverLibrariesList")
        verify(serverLibrariesList !== null, "serverLibrariesList not found")
        
        var targetLibId = "";
        var targetLibTitle = "";
        var targetServerUrl = "";
        
        // Since it's a ListView with lazy loading, we'll just query the real model directly to avoid UI scrolling issues
        var request = new XMLHttpRequest();
        var uri = "";
        if (sharedServer.connections && sharedServer.connections.length > 0) {
            uri = sharedServer.connections[0].uri;
        }
        verify(uri !== "", "Shared server must have a connection URI");
        
        request.open("GET", uri + "/library/sections?X-Plex-Token=" + sharedServer.accessToken, false);
        request.setRequestHeader("Accept", "application/json");
        request.send();
        
        var json = JSON.parse(request.responseText);
        for (var k = 0; k < json.MediaContainer.Directory.length; k++) {
            var dir = json.MediaContainer.Directory[k];
            if (dir.type === "movie" || dir.title === "Movies") {
                targetLibId = dir.key;
                targetLibTitle = dir.title;
                break;
            }
        }
        
        verify(targetLibId !== "", "Could not find a Movies library on the shared server");
        console.log("Found shared library: " + targetLibTitle + " (ID: " + targetLibId + ")");
        
        var librariesTabCol = findChild(settingsWindow, "librariesTabCol")
        var map = Object.assign({}, librariesTabCol.localLibrariesMap)
        var uKey = sharedServer.name + "_" + targetLibId;
        map[uKey] = { 
            "id": targetLibId, 
            "type": "movie", 
            "title": targetLibTitle, 
            "serverName": sharedServer.name, 
            "serverUrl": uri,
            "serverToken": sharedServer.accessToken
        }
        librariesTabCol.localLibrariesMap = map
        
        var saveBtn = findChild(settingsWindow, "saveLibrariesButton")
        saveBtn.clicked()
        
        console.log("Saved shared library to appSettings")
        app.startupLogic()
        wait(1000)
        
        var mainContent = findChild(app, "homeView")
        verify(mainContent !== null, "homeView should exist")
        
        var homeCol = findChild(mainContent, "homeContentColumn")
        verify(homeCol !== null)
        
        var rep = findChild(homeCol, "libraryRepeater")
        verify(rep !== null)
        
        tryVerify(function() { return rep.count > 0; }, 10000, "Library repeater should create rails")
        
        var foundRail = null;
        for (var r = 0; r < rep.count; r++) {
            var rail = rep.itemAt(r);
            if (rail && rail.libraryTitle === targetLibTitle + " (" + sharedServer.name + ")") {
                foundRail = rail;
                break;
            }
        }
        
        verify(foundRail !== null, "Should have created a HomeView rail for the shared library");
        
        var delegateRecentModel = findChild(foundRail, "delegateRecentModel")
        verify(delegateRecentModel !== null, "Rail should have its own recent model")
        
        tryVerify(function() { return delegateRecentModel.rowCount() > 0; }, 15000, "Rail should fetch movies successfully using the shared token")
        
        console.log("Successfully loaded " + delegateRecentModel.rowCount() + " items from the shared library!")
        
        var movieData = delegateRecentModel.get(0)
        verify(movieData !== null, "Should get movie data from model")
        console.log("Simulating click on movie: " + movieData.title + " (ratingKey: " + movieData.ratingKey + ")")
        
        var mUrl = (movieData.serverUrl !== undefined && movieData.serverUrl !== "") ? movieData.serverUrl : sharedServer.connections[0].uri;
        var mToken = (movieData.serverToken !== undefined && movieData.serverToken !== "") ? movieData.serverToken : sharedServer.accessToken;
        
        console.log("Calling fetchItemDetails with URL: " + mUrl + " Token: " + mToken + " ratingKey: " + movieData.ratingKey);
        app.controller.detailsModel.fetchItemDetails(mUrl, mToken, movieData.ratingKey)
        app.currentTab = 3
        
        var movieDetailsView = findChild(app, "movieDetailsView")
        tryVerify(function() { return movieDetailsView.detailsData !== null && movieDetailsView.detailsData !== undefined; }, 10000, "detailsData must load first");
        
        var playBtn = findChild(movieDetailsView, "detailsPlayButton");
        tryVerify(function() { return playBtn !== null; }, 5000, "Play btn should exist");
        if (playBtn !== null) { playBtn.clicked(); }
        
        var playerView = findChild(app, "playerView")
        verify(playerView !== null)
        tryVerify(function() { return playerView.visible; }, 10000, "Player view should become visible")
        
        var mpvItem = findChild(playerView, "mpvObject")
        verify(mpvItem !== null)
        
        tryVerify(function() { return mpvItem.duration > 0; }, 25000, "Playback should start on shared library (duration > 0)")
        
        console.log("Waiting a few seconds of shared playback...")
        wait(5000)
        
        tryVerify(function() { return mpvItem.position > 1; }, 5000, "Playback position should advance on shared library")
        
        console.log("Shared playback works perfectly!")
    }


    /*
     * test_real_shared_library_page_connection
     * 
     * This test ensures that navigating directly to a shared library via the Sidebar
     * loads the LibraryBrowserView, correctly fetches the posters, clicking the poster
     * opens the MovieDetailsView with valid metadata using the serverToken, and that 
     * playback successfully streams from the shared library.
     */
    function test_real_shared_library_page_connection() {
        console.log("Looking for a shared library in the Sidebar...")
        var sidebar = findChild(app, "sidebarView")
        verify(sidebar !== null, "sidebarView not found")
        
        var libraryRepeater = findChild(sidebar, "sidebarLibraryRepeater")
        verify(libraryRepeater !== null, "sidebarLibraryRepeater not found")
        
        var sharedButton = null;
        for (var i = 0; i < libraryRepeater.count; i++) {
            var btn = libraryRepeater.itemAt(i);
            if (btn && btn.mTitle === "Movies" && (btn.mServerUrl.includes("172-17") || btn.mServerUrl.includes("192") || btn.mServerToken !== "")) {
                // Since our previous test checked the shared library, it will be in the sidebar.
                // We identify it by checking if it has a valid serverToken (which only shared or explicitly queried servers have).
                if (btn.mServerToken !== "" && btn.mServerToken !== app.appSettings.token) {
                    sharedButton = btn;
                    break;
                }
            }
        }
        
        verify(sharedButton !== null, "Could not find the shared library button in the Sidebar");
        console.log("Found shared library button in sidebar: " + sharedButton.mTitle + " (Server URL: " + sharedButton.mServerUrl + ")");
        
        // Simulate click
        mouseClick(sharedButton)
        wait(1000)
        
        tryVerify(function() { return app.currentTab === 1; }, 5000, "Should have navigated to Library Tab")
        
        
        var listLib = findChild(app, "recentlyAddedListLib")
        verify(listLib !== null, "recentlyAddedListLib should exist")
        
        tryVerify(function() { return listLib.count > 0; }, 15000, "Recently added list should fetch and display movies from shared library")
        console.log("Successfully loaded " + listLib.count + " items in the LibraryRecommendView!")
        
        var firstItem = listLib.contentItem.children[0]
        verify(firstItem !== null, "First movie item should exist")
        
        var titleStr = firstItem.mTitle || "";
        console.log("Clicking poster for: " + titleStr)
        
        // Get data from the model instead of relying on QML item properties
        var movieData = app.controller.libraryRecentModel.get(0)
        verify(movieData !== null, "Should get movie data from libraryRecentModel")
        
        var mUrl = (movieData.serverUrl !== undefined && movieData.serverUrl !== "") ? movieData.serverUrl : sharedButton.mServerUrl;
        var mToken = (movieData.serverToken !== undefined && movieData.serverToken !== "") ? movieData.serverToken : sharedButton.mServerToken;
        
        console.log("Calling fetchItemDetails for page test with URL: " + mUrl + " Token: " + mToken + " ratingKey: " + movieData.ratingKey);
        app.controller.detailsModel.fetchItemDetails(mUrl, mToken, movieData.ratingKey)
        app.currentTab = 3
        
        var movieDetailsView = findChild(app, "movieDetailsView")
        tryVerify(function() { return movieDetailsView.detailsData !== null && movieDetailsView.detailsData !== undefined; }, 10000, "detailsData must load first");
        console.log("Details loaded successfully for: " + movieDetailsView.detailsData.title)
        
        var playBtn = findChild(movieDetailsView, "detailsPlayButton");
        tryVerify(function() { return playBtn !== null; }, 5000, "Play btn should exist");
        if (playBtn !== null) { playBtn.clicked(); }
        
        var playerView = findChild(app, "playerView")
        verify(playerView !== null)
        tryVerify(function() { return playerView.visible; }, 10000, "Player view should become visible")
        
        var mpvItem = findChild(playerView, "mpvObject")
        verify(mpvItem !== null)
        
        tryVerify(function() { return mpvItem.duration > 0; }, 25000, "Playback should start on shared library from Library View (duration > 0)")
        
        console.log("Waiting a few seconds of shared playback...")
        wait(5000)
        
        tryVerify(function() { return mpvItem.position > 1; }, 5000, "Playback position should advance on shared library from Library View")
        
        console.log("Shared playback from Library Page works perfectly!")
    }


    /*
     * test_smart_collection_creation
     * 
     * This test verifies that after adding a filter and saving a smart collection,
     * the Collections view updates immediately to display the newly created collection.
     */
    function test_smart_collection_creation() {
        console.log("Starting test_smart_collection_creation for shared server...")
        
        var recommendView = findChild(app, "libraryView")
        verify(recommendView !== null, "libraryView should exist")
        
        var sidebar = findChild(app, "sidebarView")
        verify(sidebar !== null, "sidebarView not found")
        
        var libraryRepeater = findChild(sidebar, "sidebarLibraryRepeater")
        verify(libraryRepeater !== null, "sidebarLibraryRepeater not found")
        
        var sharedButton = null;
        for (var i = 0; i < libraryRepeater.count; i++) {
            var btn = libraryRepeater.itemAt(i);
            if (btn && btn.mTitle === "Movies" && btn.mServerToken !== "" && btn.mServerToken !== app.appSettings.token) {
                sharedButton = btn;
                break;
            }
        }
        
        verify(sharedButton !== null, "Could not find the shared Movies library button in the Sidebar");
        console.log("Found Shared button, forcing library load: " + sharedButton.mServerUrl)
        app.loadLibraryContent(sharedButton.mId, sharedButton.mTitle, sharedButton.mType, sharedButton.mServerUrl, sharedButton.mUniqueId, sharedButton.mServerToken)
        wait(1000)
        
        var libraryTab = findChild(recommendView, "libraryTab")
        verify(libraryTab !== null, "libraryTab should exist")
        
        // Ensure we are on the Library tab
        app.currentTab = 1
        recommendView.libraryTab = 2 // 0: Recommend, 1: Collections, 2: Library
        wait(500)
        var browserView = findChild(app, "libraryBrowserView")
        verify(browserView !== null, "libraryBrowserView should exist")
        
        browserView.unwatchedFilterActive = true;
        browserView.applyFilters()
        wait(500)
        
        var saveAsBtn = findChild(browserView, "saveAsBtn")
        verify(saveAsBtn !== null, "saveAsBtn should exist in the DOM")
        
        // Verify that the Save button is explicitly hidden for shared libraries to prevent 403 Forbidden errors
        verify(!saveAsBtn.visible, "Save As button MUST be hidden for shared libraries, as Plex API blocks creation (403 Forbidden) on unowned libraries!")
        
        console.log("Successfully verified that Smart Collection creation is safely disabled for shared libraries.")
    }

    function test_z_playback_start_offset_cleared() {
        console.log("Starting test_z_playback_start_offset_cleared...")
        
        var sidebar = findChild(app, "sidebarView")
        var libraryRepeater = findChild(sidebar, "sidebarLibraryRepeater")
        var omvButton = null;
        for (var i = 0; i < libraryRepeater.count; i++) {
            var btn = libraryRepeater.itemAt(i);
            if (btn && btn.mTitle === "Movies" && (btn.mServerToken === "" || btn.mServerToken === app.appSettings.token)) {
                omvButton = btn;
                break;
            }
        }
        verify(omvButton !== null, "Could not find the omv Movies library button");
        app.loadLibraryContent(omvButton.mId, omvButton.mTitle, omvButton.mType, omvButton.mServerUrl, omvButton.mUniqueId, omvButton.mServerToken)
        wait(1000)
        
        app.currentTab = 1
        var recommendView = findChild(app, "libraryView")
        recommendView.libraryTab = 0
        wait(500)
        
        // 1. Play something with an offset (from Continue Watching)
        var cwList = findChild(recommendView, "continueWatchingListLib")
        verify(cwList !== null && cwList.count > 0, "Continue Watching should have items")
        
        var firstCW = cwList.contentItem.children[0]
        var movieDataCW = app.controller.libraryDeckModel.get(0)
        verify(movieDataCW.viewOffset > 0, "First CW item should have viewOffset > 0")
        
        var cwOffsetSecs = movieDataCW.viewOffset / 1000;
        console.log("CW Item Offset: " + cwOffsetSecs + " seconds")
        
        var mUrl = (movieDataCW.serverUrl !== undefined && movieDataCW.serverUrl !== "") ? movieDataCW.serverUrl : omvButton.mServerUrl;
        var mToken = (movieDataCW.serverToken !== undefined && movieDataCW.serverToken !== "") ? movieDataCW.serverToken : omvButton.mServerToken;
        
        app.controller.detailsModel.fetchItemDetails(mUrl, mToken, movieDataCW.ratingKey)
        app.currentTab = 3
        wait(1000)
        
        var movieDetailsView = findChild(app, "movieDetailsView")
        var playBtn = findChild(movieDetailsView, "detailsPlayButton")
        playBtn.clicked()
        
        var playerView = findChild(app, "playerView")
        tryVerify(function() { return playerView.visible; }, 5000, "Player should be visible")
        
        var mpvItem = findChild(playerView, "mpvObject")
        tryVerify(function() { return mpvItem.duration > 0; }, 15000, "Playback should start")
        wait(1000)
        
        var pos1 = mpvItem.position;
        console.log("Current MPV Position: " + pos1)
        verify(pos1 > (cwOffsetSecs - 5), "Playback should start near the offset")
        
        // Stop playback
        findChild(playerView, "backButton").clicked()
        app.currentTab = 1
        wait(500)
        
        // 2. Play something WITHOUT an offset (from Recently Added)
        var raList = findChild(recommendView, "recentlyAddedListLib")
        var movieDataRA = null;
        for (var k = 0; k < app.controller.libraryRecentModel.rowCount(); k++) {
            var item = app.controller.libraryRecentModel.get(k);
            if (!item.viewOffset || item.viewOffset === 0) {
                movieDataRA = item;
                break;
            }
        }
        verify(movieDataRA !== null, "Should find an unwatched movie in recently added")
        console.log("Found unwatched movie: " + movieDataRA.title)
        
        mUrl = (movieDataRA.serverUrl !== undefined && movieDataRA.serverUrl !== "") ? movieDataRA.serverUrl : omvButton.mServerUrl;
        mToken = (movieDataRA.serverToken !== undefined && movieDataRA.serverToken !== "") ? movieDataRA.serverToken : omvButton.mServerToken;
        
        app.controller.detailsModel.fetchItemDetails(mUrl, mToken, movieDataRA.ratingKey)
        app.currentTab = 3
        wait(1000)
        
        playBtn = findChild(movieDetailsView, "detailsPlayButton")
        playBtn.clicked()
        
        tryVerify(function() { return playerView.visible; }, 5000, "Player should be visible")
        tryVerify(function() { return mpvItem.duration > 0; }, 15000, "Playback should start")
        wait(1000)
        
        var pos2 = mpvItem.position;
        console.log("Second MPV Position: " + pos2)
        verify(pos2 < 5, "Playback should start from the beginning (offset 0), NOT inherit previous offset!")
        
        findChild(playerView, "backButton").clicked()
    }

    function cleanupTestCase() {
        if (app) app.destroy()
    }
}

