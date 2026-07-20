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
        try {
            console.log("Creating main window...")
            mainWindow = mainComponent.createObject(container, {isTestMode: true})
            verify(mainWindow !== null, "Main window should be created")
            
            console.log("Loading mock data...")
            mainWindow.testGlobalRecentModel.loadMockData([
                "/home/geonix/Build/flex_player/tests/dummy1.mkv"
            ], "movie", 0, 0, false);

            mainWindow.testGlobalDeckModel.loadMockData([
                "/home/geonix/Build/flex_player/tests/dummy2.mkv"
            ], "movie", 30000, 60000, false);

            mainWindow.testCollectionsModel.loadMockData([
                "/home/geonix/Build/flex_player/tests/dummy3.mkv"
            ], "collection", 0, 0, false);
            
            mainWindow.testCollectionMoviesModel.loadMockData([
                "/home/geonix/Build/flex_player/tests/dummy1.mkv"
            ], "movie", 0, 0, true);
            
            mainWindow.testAllLibrariesModel.loadMockData([
                "/home/geonix/Build/flex_player/tests/dummy1.mkv"
            ], "movie", 0, 0, false);
            
            console.log("Setting app settings...")
            mainWindow.testAppSettings.enabledLibraries = JSON.stringify({
                "1": { "title": "Test Movies", "type": "movie" },
                "2": { "title": "Test Series", "type": "show" }
            })
            mainWindow.testAppSettings.serverUrl = "http://test.url:32400"
            mainWindow.testAppSettings.token = "test_token"
            
            console.log("Calling startupLogic...")
            mainWindow.startupLogic()
            console.log("initTestCase completed successfully")
        } catch(e) {
            console.log("EXCEPTION in initTestCase:", e)
            verify(false, "Exception caught")
        }
    }
    
    function test_66_home_recently_added_visibility() {
        var mockRecent = [
            "/home/geonix/Build/flex_player/tests/recent1.mkv",
            "/home/geonix/Build/flex_player/tests/recent2.mkv"
        ];
        mainWindow.currentTab = 0;
        wait(50);
        mainWindow.testGlobalRecentModel.loadMockData(mockRecent, "movie", 0, 0, false);
        wait(100);
        var recentList = findChild(mainWindow, "globalRecentlyAddedList");
        verify(recentList !== null, "Recently Added list should exist");
        verify(recentList.visible === true, "Recently Added list should be visible");
        verify(recentList.count === 2, "Recently Added list should show 2 items");
    }

    function test_67_multi_library_home_rails() {
        mainWindow.currentTab = 0;
        wait(100);
        var homeView = findChild(mainWindow, "homeView");
        verify(homeView !== null, "Home view should exist");
        verify(homeView.homeLibrariesList.length >= 2, "Home page should have 2 libraries");
        
        var movieRail = findChild(homeView, "libraryRail_1"); 
        verify(movieRail !== null, "Movie LibraryRail should be found");
        var movieList = findChild(movieRail, "delegateRecentList");
        verify(movieList.count > 0, "Movie rail should not be empty");
        
        var seriesRail = findChild(homeView, "libraryRail_2"); 
        verify(seriesRail !== null, "Series LibraryRail should be found");
        var seriesList = findChild(seriesRail, "delegateRecentList");
        verify(seriesList.count > 0, "Series rail should not be empty");
    }

    function cleanupTestCase() {
        if (mainWindow) {
            mainWindow.destroy()
        }
    }
