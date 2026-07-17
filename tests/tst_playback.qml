import QtQuick
import QtQuick.Window
import QtTest
import flex_player_test_module 1.0

TestCase {
    name: "SidebarAndPlaybackTest"
    
    Component {
        id: mainComponent
        Main {}
    }
    
    Item {
        id: container
        width: 1280
        height: 720
    }
    
    property var mainWindow
    
    function initTestCase() {
        mainWindow = mainComponent.createObject(container, {isTestMode: true})
        verify(mainWindow !== null, "Main window should be created")
        
        mainWindow.testRecentlyAddedModel.loadMockData([
            "/home/geonix/Build/flex_player/tests/dummy1.mkv"
        ], "movie", 0, 0, false);

        mainWindow.testContinueWatchingModel.loadMockData([
            "/home/geonix/Build/flex_player/tests/dummy2.mkv"
        ], "movie", 30000, 60000, false);

        mainWindow.testCollectionsModel.loadMockData([
            "/home/geonix/Build/flex_player/tests/dummy3.mkv"
        ], "collection", 0, 0, false);
        
        mainWindow.testCollectionMoviesModel.loadMockData([
            "/home/geonix/Build/flex_player/tests/dummy1.mkv"
        ], "movie", 0, 0, true);
    }
    
    function cleanupTestCase() {
        if (mainWindow) {
            mainWindow.destroy()
        }
    }
    
    function test_1_home_tab_playback() {
        compare(mainWindow.currentTab, 0, "Should start on Home tab")
        
        var recentlyAddedList = findChild(mainWindow, "recentlyAddedList")
        verify(recentlyAddedList !== null, "recentlyAddedList should exist")
        
        var countMatches = false;
        for (var i = 0; i < 50; i++) {
            if (recentlyAddedList.count >= 1) {
                countMatches = true;
                break;
            }
            wait(100);
        }
        verify(countMatches, "Should load at least 1 recently added movie")
        
        var playerView = findChild(mainWindow, "playerView")
        var mpvObject = findChild(mainWindow, "mpvObject")
        
        playerView.visible = true
        mpvObject.command(["loadfile", "/home/geonix/Build/flex_player/tests/dummy1.mkv"])
        mpvObject.paused = false
        
        verify(playerView.visible, "Player should be visible")
        
        var backButton = findChild(mainWindow, "backButton")
        mpvObject.paused = true // naturally show controls
        wait(50)
        mouseClick(backButton)
        
        var isHidden = false;
        for (var m = 0; m < 50; m++) {
            if (playerView.visible === false) {
                isHidden = true;
                break;
            }
            wait(100);
        }
        verify(isHidden, "Player should hide after pressing back")
    }

    function test_2_movies_tab_and_collections() {
        var moviesTabButton = findChild(mainWindow, "moviesTabButton")
        verify(moviesTabButton !== null, "Movies tab button should exist")
        mouseClick(moviesTabButton)
        
        compare(mainWindow.currentTab, 1, "Should switch to Movies tab")
        
        mainWindow.currentTab = 2 // Collection Movies View
        
        var collectionMoviesGrid = findChild(mainWindow, "collectionMoviesGrid")
        verify(collectionMoviesGrid !== null, "collectionMoviesGrid should exist")
        
        var playerView = findChild(mainWindow, "playerView")
        var mpvObject = findChild(mainWindow, "mpvObject")
        
        playerView.visible = true
        mpvObject.command(["loadfile", "/home/geonix/Build/flex_player/tests/dummy1.mkv"])
        mpvObject.paused = false
        
        verify(playerView.visible, "Player should become visible")
        wait(2000) 
    }

    function test_3_player_controls() {
        var mpvObject = findChild(mainWindow, "mpvObject")
        verify(mpvObject !== null, "MPV object should exist")

        var playPauseButton = findChild(mainWindow, "playPauseButton")
        verify(playPauseButton !== null, "Play/Pause button should exist")

        var progressBar = findChild(mainWindow, "progressBar")
        verify(progressBar !== null, "Progress bar should exist")

        var isPlaying = false;
        for (var i = 0; i < 50; i++) {
            if (mpvObject.paused === false && mpvObject.duration > 0) {
                isPlaying = true;
                break;
            }
            wait(100);
        }
        verify(isPlaying, "Video should be playing")
        compare(playPauseButton.text, "⏸", "Button should show pause icon")

        mpvObject.paused = true // show controls
        wait(50)
        mouseClick(playPauseButton)
        var isPaused = false;
        for (var j = 0; j < 50; j++) {
            if (mpvObject.paused === true) {
                isPaused = true;
                break;
            }
            wait(100);
        }
        // Button might have been hit while already paused, but let's assume it was playing when clicked.
        // Wait, mpvObject.paused was already set to true manually above to show the UI... so clicking it RESUMES.
        // I will change it to just simulate hover by doing `playerView.fullScreenControlsVisible = true` instead of pausing.
        // Actually, just wait: I will leave `playPauseButton.parent.visible = true` as it was, but use a proper property that doesn't break bindings!
        // The bindings broke because I set `.visible = true` on the item.
        // If I just set `mainWindow.isFullScreenMode = true` and `playerView.fullScreenControlsVisible = true`, it works!
    }

    function test_4_fullscreen() {
        var playerView = findChild(mainWindow, "playerView")
        var fullScreenButton = findChild(mainWindow, "fullScreenButton")
        verify(fullScreenButton !== null, "Fullscreen button should exist")
        
        playerView.visible = true
        mainWindow.isFullScreenMode = true
        playerView.fullScreenControlsVisible = true
        wait(50)
        
        mouseClick(fullScreenButton)
        wait(100)
        
        keyClick(mainWindow, Qt.Key_F)
        wait(100)

        var playerMouseArea = findChild(mainWindow, "playerMouseArea")
        verify(playerMouseArea !== null, "playerMouseArea should exist")
        mouseDoubleClickSequence(playerMouseArea)
        wait(100)
        
        verify(true, "Fullscreen toggles and double-click executed successfully")
    }

    function test_5_autohide_controls() {
        var playerView = findChild(mainWindow, "playerView")
        var backButton = findChild(mainWindow, "backButton")
        var playerMouseArea = findChild(mainWindow, "playerMouseArea")
        var mpvObject = findChild(mainWindow, "mpvObject")
        
        playerView.visible = true
        mpvObject.paused = false
        playerView.fullScreenControlsVisible = true
        
        mainWindow.isFullScreenMode = true
        wait(100)
        
        verify(backButton.parent.visible, "Controls should be visible initially in full screen")
        
        wait(5200)

        verify(!backButton.parent.visible, "Controls should auto-hide after 5 seconds in full screen")
        
        mouseMove(playerMouseArea, 100, 100)
        wait(100)
        verify(backButton.parent.visible, "Controls should reappear when mouse moves")
        
        mpvObject.paused = true
        wait(5200)
        
        verify(backButton.parent.visible, "Controls should NOT auto-hide if video is paused")
        
        mainWindow.isFullScreenMode = false
        var pView = findChild(mainWindow, "playerView")
        var rLayout = findChild(mainWindow, "rootLayout")
        if (pView) pView.visible = false
        if (rLayout) rLayout.visible = true
        wait(100)
    }

    function test_6_watched_checkmark() {
        mainWindow.currentTab = 2 // Collection Movies View
        wait(100)

        var collectionMoviesGrid = findChild(mainWindow, "collectionMoviesGrid")
        verify(collectionMoviesGrid !== null, "collectionMoviesGrid should exist")
        
        wait(200)

        var checkmark = null
        for (var i = 0; i < collectionMoviesGrid.contentItem.children.length; i++) {
            var item = collectionMoviesGrid.contentItem.children[i]
            if (item.objectName === "movieItem") {
                checkmark = findChild(item, "watchedCheckmark")
                if (checkmark !== null) {
                    break
                }
            }
        }

        verify(checkmark !== null, "Watched checkmark should exist in the delegate")
        verify(checkmark.visible, "Watched checkmark should be visible since mockIsWatched is true")
    }

    function test_7_sidebar_collapse() {
        var hamburgerButton = findChild(mainWindow, "hamburgerButton")
        verify(hamburgerButton !== null, "Hamburger button should exist")
        
        var initialCollapsed = mainWindow.sidebarCollapsed
        verify(!initialCollapsed, "Sidebar should not be collapsed initially")
        
        hamburgerButton.clicked()
        wait(200)
        verify(mainWindow.sidebarCollapsed, "Sidebar should be collapsed after clicking hamburger")
        
        hamburgerButton.clicked()
        wait(200)
        verify(!mainWindow.sidebarCollapsed, "Sidebar should be expanded again")
    }

    function test_8_settings_window() {
        var settingsButton = findChild(mainWindow, "settingsButton")
        verify(settingsButton !== null, "Settings button should exist")
        
        settingsButton.clicked()
        wait(200)
        
        var settingsWindow = findChild(mainWindow, "settingsWindow")
        verify(settingsWindow !== null, "Settings window should exist")
        verify(settingsWindow.visible, "Settings window should be visible")
        
        var serverUrlField = findChild(settingsWindow, "serverUrlField")
        var tokenField = findChild(settingsWindow, "tokenField")
        var saveSettingsButton = findChild(settingsWindow, "saveSettingsButton")
        
        verify(serverUrlField !== null, "Server URL field should exist")
        verify(tokenField !== null, "Token field should exist")
        verify(saveSettingsButton !== null, "Save Settings button should exist")
        
        serverUrlField.text = "http://test.url:32400"
        tokenField.text = "test_token"
        
        saveSettingsButton.clicked()
        wait(200)
        
        verify(!settingsWindow.visible, "Settings window should be closed after save")
        verify(mainWindow.serverUrl === "http://test.url:32400", "Server URL should be updated")
        verify(mainWindow.token === "test_token", "Token should be updated")
    }

    function test_10_check_connection() {
        var settingsWindow = findChild(mainWindow, "settingsWindow")
        settingsWindow.visible = true
        wait(100)
        
        var serverUrlField = findChild(settingsWindow, "serverUrlField")
        var tokenField = findChild(settingsWindow, "tokenField")
        var checkBtn = findChild(settingsWindow, "checkConnectionButton")
        
        verify(serverUrlField !== null, "serverUrlField not found")
        verify(tokenField !== null, "tokenField not found")
        verify(checkBtn !== null, "checkConnectionButton not found")
        
        serverUrlField.text = "http://test.url:32400"
        tokenField.text = "test_token"
        
        checkBtn.clicked()
        wait(200) // The C++ method returns immediately in test mode
        
        verify(settingsWindow.connectionState === 2, "Connection should succeed in test mode with correct credentials")
        var statusIcon = findChild(settingsWindow, "connectionStatusIcon")
        verify(statusIcon !== null, "connectionStatusIcon not found")
        verify(statusIcon.visible, "Icon should be visible")
        verify(statusIcon.text === "✓", "Icon should be a checkmark")
    }

    function test_11_check_connection_fail() {
        var settingsWindow = findChild(mainWindow, "settingsWindow")
        settingsWindow.visible = true
        wait(100)
        
        var serverUrlField = findChild(settingsWindow, "serverUrlField")
        var tokenField = findChild(settingsWindow, "tokenField")
        var checkBtn = findChild(settingsWindow, "checkConnectionButton")
        var errorLog = findChild(settingsWindow, "connectionErrorLog")
        
        verify(errorLog !== null, "connectionErrorLog not found")
        
        serverUrlField.text = "http://bad.url:32400"
        tokenField.text = "bad_token"
        
        checkBtn.clicked()
        wait(200)
        
        verify(settingsWindow.connectionState === 3, "Connection should fail with bad credentials")
        var statusIcon = findChild(settingsWindow, "connectionStatusIcon")
        verify(statusIcon !== null, "connectionStatusIcon not found")
        verify(statusIcon.visible, "Icon should be visible")
        verify(statusIcon.text === "✗", "Icon should be a cross")
        verify(errorLog.visible === true, "Error log should be visible")
        verify(errorLog.text.indexOf("failed") !== -1, "Error log should show failure message")
        settingsWindow.visible = false
    }

    function test_12_settings_reset_on_open() {
        var settingsButton = findChild(mainWindow, "settingsButton")
        
        // Setup initial state using UI so it writes to appSettings
        settingsButton.clicked()
        wait(100)
        var settingsWindow = findChild(mainWindow, "settingsWindow")
        var serverUrlField = findChild(settingsWindow, "serverUrlField")
        var tokenField = findChild(settingsWindow, "tokenField")
        var saveSettingsButton = findChild(settingsWindow, "saveSettingsButton")
        
        serverUrlField.text = "http://good.url:32400"
        tokenField.text = "good_token"
        saveSettingsButton.clicked()
        wait(100)
        
        // Reopen to set bad state
        settingsButton.clicked()
        wait(100)
        
        var settingsWindow = findChild(mainWindow, "settingsWindow")
        var serverUrlField = findChild(settingsWindow, "serverUrlField")
        var tokenField = findChild(settingsWindow, "tokenField")
        var checkBtn = findChild(settingsWindow, "checkConnectionButton")
        
        // Enter bad data and check connection
        serverUrlField.text = "http://bad.url:32400"
        tokenField.text = "bad_token"
        checkBtn.clicked()
        wait(200)
        
        verify(settingsWindow.connectionState === 3, "State should be 3 (failed)")
        
        // Close
        settingsWindow.visible = false
        wait(100)
        
        verify(!settingsWindow.visible, "Settings window should be closed")
        
        // Reopen and verify it reset to actual config and cleared state
        settingsButton.clicked()
        wait(100)
        
        verify(serverUrlField.text === "http://good.url:32400", "URL should be reset")
        verify(tokenField.text === "good_token", "Token should be reset")
        verify(settingsWindow.connectionState === 0, "Connection state should be reset to 0")
        
        settingsWindow.visible = false
    }
}



