import sys

def force_reset_v5(path_config, path_controller):
    # 1. Update AppConfig.qml default to 0
    with open(path_config, 'r') as f:
        config = f.read()
    config = config.replace('property int connectionVersion: 4', 'property int connectionVersion: 0')
    config = config.replace('property int connectionVersion: 3', 'property int connectionVersion: 0')
    with open(path_config, 'w') as f:
        f.write(config)

    # 2. Update GlobalController.qml to check for version 5
    with open(path_controller, 'r') as f:
        controller = f.read()
    controller = controller.replace('appSettings.connectionVersion < 4', 'appSettings.connectionVersion < 5')
    controller = controller.replace('appSettings.connectionVersion = 4', 'appSettings.connectionVersion = 5')
    with open(path_controller, 'w') as f:
        f.write(controller)

force_reset_v5('/home/geonix/Build/flex_player/src/AppConfig.qml', '/home/geonix/Build/flex_player/src/GlobalController.qml')

