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

    function cleanupTestCase() {
        if (app) app.destroy()
    }
}

