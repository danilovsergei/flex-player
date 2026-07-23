import QtQuick
import QtTest
import flex.plex 1.0
import "../src"

TestCase {
    name: "BufferingUiTest"
    when: windowShown
    width: 1280
    height: 720

    Component {
        id: appComponent
        Main {
            isTestMode: true
        }
    }

    property var app

    function init() {
        app = createTemporaryObject(appComponent, null)
        verify(app)
        
        // Setup robust state to prevent migration return
        app.appSettings.connectionVersion = 5
        app.appSettings.serverList = JSON.stringify([{
            name: "omv", enabled: true, 
            connections: [{ address: "127.0.0.1", port: 32400, local: true, protocol: "https" }]
        }])
        
        var cm = findChild(app, "connectionManager")
        if (cm) {
            cm.setIsTestMode(true)
            cm.setMockResponse("https://127.0.0.1:32400", true)
        }
        
        app.startupLogic()
    }

    function test_loading_spinner_visibility_lifecycle() {
        var player = findChild(app, "playerView")
        verify(player !== null, "playerView should exist")
        player.visible = true
        
        var spinner = findChild(player, "loadingSpinner")
        verify(spinner !== null, "loadingSpinner should exist")
        
        player.mpvObject.buffering = false
        verify(!spinner.visible, "Spinner should be hidden when not buffering")
        
        console.log("TEST: Simulating NAS spin-up (buffering=true)")
        player.mpvObject.buffering = true
        
        tryCompare(spinner, "visible", true, 5000)
        verify(spinner.running, "Spinner animation should be running")
        
        console.log("TEST: Simulating playback started (buffering=false)")
        player.mpvObject.buffering = false
        
        tryCompare(spinner, "visible", false, 5000)
        verify(!spinner.running, "Spinner animation should stop")
    }

    function test_spinner_staying_centered_on_resize() {
        var player = findChild(app, "playerView")
        player.visible = true
        player.mpvObject.buffering = true
        
        var spinner = findChild(player, "loadingSpinner")
        
        tryCompare(spinner, "visible", true, 5000)

        // Use fuzzy comparison for layouts in headless
        verify(Math.abs(spinner.x - (player.width - spinner.width) / 2) < 5)
        verify(Math.abs(spinner.y - (player.height - spinner.height) / 2) < 5)
        
        app.width = 800
        app.height = 600
        wait(200)
        
        verify(Math.abs(spinner.x - (player.width - spinner.width) / 2) < 5)
        verify(Math.abs(spinner.y - (player.height - spinner.height) / 2) < 5)
    }
}

