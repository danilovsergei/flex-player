import sys

def rewrite_test(path):
    import os
    os.system("git checkout " + path)

    with open(path, 'r') as f:
        content = f.read()

    new_content = content.replace('app.appSettings.enabledLibraries = "{}"', 'app.appSettings.enabledLibraries = "{}"\n        app.appSettings.connectionVersion = 5')

    with open(path, 'w') as f:
        f.write(new_content)

rewrite_test('/home/geonix/Build/flex_player/tests/tst_headless_ssl_libraries.qml')

