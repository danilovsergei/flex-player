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
        

        tryCompare(spinner, "visible", true)
        verify(spinner.running, "Spinner animation should be running")
        

        console.log("TEST: Simulating playback started (buffering=false)")
        player.mpvObject.buffering = false
        

        tryCompare(spinner, "visible", false)
        verify(!spinner.running, "Spinner animation should stop")
    }

    function test_spinner_staying_centered_on_resize() {
        var player = findChild(app, "playerView")
        player.visible = true
        player.mpvObject.buffering = true
        
        var spinner = findChild(player, "loadingSpinner")
        

        compare(spinner.x, (player.width - spinner.width) / 2)
        compare(spinner.y, (player.height - spinner.height) / 2)
        

        app.width = 800
        app.height = 600
        wait(50)
        

        compare(spinner.x, (player.width - spinner.width) / 2)
        compare(spinner.y, (player.height - spinner.height) / 2)
    }
}

