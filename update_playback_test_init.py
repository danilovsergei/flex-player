import sys

def update_playback_test_init(path):
    with open(path, 'r') as f:
        content = f.read()
    
    old_init = r"""            console.log("Setting app settings...")
            mainWindow.testAppSettings.enabledLibraries = JSON.stringify({
                "1": { "title": "Test Movies", "type": "movie" },
                "2": { "title": "Test Series", "type": "show" }
            })
            mainWindow.testAppSettings.serverUrl = "http://test.url:32400"
            mainWindow.testAppSettings.token = "test_token"
            
            console.log("Calling startupLogic...")
            mainWindow.startupLogic()"""

    new_init = r"""            console.log("Setting app settings...")
            mainWindow.testAppSettings.connectionVersion = 5
            mainWindow.testAppSettings.enabledLibraries = JSON.stringify({
                "1": { "title": "Test Movies", "type": "movie" },
                "2": { "title": "Test Series", "type": "show" }
            })
            
            var mockConnections = [
                { address: "192.168.31.2", port: 32400, local: true, protocol: "https" }
            ]
            mainWindow.testAppSettings.serverList = JSON.stringify([
                { name: "omv", enabled: true, connections: mockConnections }
            ])
            mainWindow.testAppSettings.serverUrl = "https://192.168.31.2:32400"
            mainWindow.testAppSettings.token = "test_token"
            
            // Setup ConnectionManager for the race win
            var cm = findChild(mainWindow, "connectionManager")
            if (cm) {
                cm.setIsTestMode(true)
                cm.setMockResponse("https://192.168.31.2:32400", true)
            }

            console.log("Calling startupLogic...")
            mainWindow.startupLogic()"""

    content = content.replace(old_init, new_init)
    with open(path, 'w') as f:
        f.write(content)

update_playback_test_init('/home/geonix/Build/flex_player/tests/tst_playback.qml')

