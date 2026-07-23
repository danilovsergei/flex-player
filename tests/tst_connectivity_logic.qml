import QtQuick
import QtTest
import flex.plex 1.0

TestCase {
    name: "ConnectivityLogicTest"
    when: windowShown

    PlexConnectionManager {
        id: cm
    }

    function test_102_multi_ip_resolution() {
        var mockConns = [
            { address: "172.17.0.1", port: 32400, local: true, protocol: "https" },
            { address: "192.168.31.2", port: 32400, local: true, protocol: "https" }
        ]
        
        cm.token = "test"
        cm.setIsTestMode(true)
        
        // Mock success for the real IP only
        cm.setMockResponse("https://192.168.31.2:32400", true)
        cm.setMockResponse("https://172.17.0.1:32400", false)
        
        cm.startExhaustiveProbe(mockConns)
        tryCompare(cm, "activeUrl", "https://192.168.31.2:32400", 5000)
    }

    function test_104_locality_priority() {
        var mockConns = [
            { address: "99.31.213.169", port: 22469, local: false, protocol: "https" },
            { address: "192.168.31.2", port: 32400, local: true, protocol: "https" }
        ]
        
        cm.token = "test"
        cm.setIsTestMode(true)
        
        // Both succeed, but 192.168 must win
        cm.setMockResponse("https://99.31.213.169:22469", true)
        cm.setMockResponse("https://192.168.31.2:32400", true)
        
        cm.startExhaustiveProbe(mockConns)
        tryCompare(cm, "activeUrl", "https://192.168.31.2:32400", 5000)
    }
}

