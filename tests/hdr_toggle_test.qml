import QtQuick
import QtTest
import flex.plex 1.0
import "../src"

TestCase {
    name: "HdrToggleTest"
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

    function test_hdr_cycle() {
        // 0. Enable HDR toggle in settings
        app.appSettings.autoToggleHdr = true
        app.appSettings.hdrEnableCommand = "MOCK_HDR_ON"
        app.appSettings.hdrDisableCommand = "MOCK_HDR_OFF"

        verify(app.controller)
        
        var spy = createTemporaryObject(spyComponent, null, {
            target: app.controller,
            signalName: "hdrCommandExecuted"
        })
        verify(spy)

        // 1. Simulate starting an HDR video
        var player = findChild(app, "playerView")
        player.visible = true
        
        // Ensure player is ready
        wait(100)
        
        // Simulate libmpv detecting HDR
        console.log("TEST: Setting videoIsHdr to true")
        player.mpvObject.videoIsHdr = true
        
        // 3. Check that enable command was called
        tryCompare(spy, "count", 1)
        compare(spy.signalArguments[0][0], "MOCK_HDR_ON")

        // 4. Press back and check disable command
        console.log("TEST: Clicking back button")
        player.mpvObject.paused = true // Ensure controls are visible for click
        wait(100)
        var backBtn = findChild(player, "backButton")
        mouseClick(backBtn)
        
        tryCompare(spy, "count", 2)
        compare(spy.signalArguments[1][0], "MOCK_HDR_OFF")
        
        // Test 2: Toggle second time
        console.log("TEST: Starting second playback")
        player.visible = true
        player.mpvObject.videoIsHdr = false
        player.mpvObject.videoIsHdr = true
        
        tryCompare(spy, "count", 3)
        compare(spy.signalArguments[2][0], "MOCK_HDR_ON")
        
        player.mpvObject.paused = true // Ensure controls are visible
        wait(100)
        mouseClick(backBtn)
        tryCompare(spy, "count", 4)
        compare(spy.signalArguments[3][0], "MOCK_HDR_OFF")
    }

    function test_hdr_app_close() {
        app.appSettings.autoToggleHdr = true
        app.appSettings.hdrEnableCommand = "CLOSE_HDR_ON"
        app.appSettings.hdrDisableCommand = "CLOSE_HDR_OFF"
        
        var spy = createTemporaryObject(spyComponent, null, {
            target: app.controller,
            signalName: "hdrCommandExecuted"
        })

        var player = findChild(app, "playerView")
        player.visible = true
        player.mpvObject.videoIsHdr = true
        
        tryCompare(spy, "count", 1)
        compare(spy.signalArguments[0][0], "CLOSE_HDR_ON")
        
        // Simulate app closing
        console.log("TEST: Simulating app closing...")
        app.closing({accepted: true}) // Manually trigger the handler
        
        tryCompare(spy, "count", 2)
        compare(spy.signalArguments[1][0], "CLOSE_HDR_OFF")
    }

    function test_hdr_disabled_settings() {
        app.appSettings.autoToggleHdr = false
        var spy = createTemporaryObject(spyComponent, null, {
            target: app.controller,
            signalName: "hdrCommandExecuted"
        })

        var player = findChild(app, "playerView")
        player.visible = true
        player.mpvObject.videoIsHdr = true
        
        wait(200)
        compare(spy.count, 0, "No HDR command should be called when setting is off")
    }

    Component {
        id: spyComponent
        SignalSpy {}
    }
}

