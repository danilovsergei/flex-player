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

    function test_hdr_cycle() {
        app.appSettings.autoToggleHdr = true
        app.appSettings.hdrEnableCommand = "MOCK_HDR_ON"
        app.appSettings.hdrDisableCommand = "MOCK_HDR_OFF"

        verify(app.controller)
        
        var spy = createTemporaryObject(spyComponent, null, {
            target: app.controller,
            signalName: "hdrCommandExecuted"
        })
        verify(spy)

        var player = findChild(app, "playerView")
        player.visible = true
        
        wait(200)
        
        console.log("TEST: Setting videoIsHdr to true")
        player.mpvObject.videoIsHdr = true
        
        tryCompare(spy, "count", 1, 5000)
        compare(spy.signalArguments[0][0], "MOCK_HDR_ON")

        console.log("TEST: Clicking back button")
        player.mpvObject.paused = true
        wait(200)
        var backBtn = findChild(player, "backButton")
        if (backBtn !== null) {
            backBtn.clicked() // Explicitly trigger signal
        } else {
            player.visible = false;
        }
        
        tryCompare(spy, "count", 2, 5000)
        compare(spy.signalArguments[1][0], "MOCK_HDR_OFF")
        
        console.log("TEST: Starting second playback")
        player.visible = true
        player.mpvObject.videoIsHdr = false
        player.mpvObject.videoIsHdr = true
        
        tryCompare(spy, "count", 3, 5000)
        compare(spy.signalArguments[2][0], "MOCK_HDR_ON")
        
        player.mpvObject.paused = true
        wait(200)
        if (backBtn !== null) { backBtn.clicked() }
        tryCompare(spy, "count", 4, 5000)
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
        
        tryCompare(spy, "count", 1, 5000)
        compare(spy.signalArguments[0][0], "CLOSE_HDR_ON")
        
        console.log("TEST: Simulating app closing...")
        app.closing({accepted: true}) 
        
        tryCompare(spy, "count", 2, 5000)
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
        
        wait(500)
        compare(spy.count, 0, "No HDR command should be called when setting is off")
    }

    Component {
        id: spyComponent
        SignalSpy {}
    }
}

