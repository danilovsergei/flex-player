import sys

def fix_race_test2(path):
    with open(path, 'r') as f:
        content = f.read()

    # Change testAndSetBestConnection
    content = content.replace('settingsWindow.testAndSetBestConnection(mockServer);', 'rootApp.controller.connectionManager.startExhaustiveProbe(mockServer.connections, true);')

    with open(path, 'w') as f:
        f.write(content)

fix_race_test2('/home/geonix/Build/flex_player/tests/tst_connectivity_race.qml')

