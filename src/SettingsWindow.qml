import flex.plex 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsWindow
    property bool isTestEnvironment: (typeof rootApp !== "undefined" && rootApp && rootApp.isTestMode)
    objectName: "settingsWindow"
    anchors.fill: parent
    color: "#1e1e1e"
    visible: false
    z: 999

    property int connectionState: 0
    property string connectionError: ""
    property PlexModel allLibrariesModel: null
    property alias librariesTabCol: librariesTabCol
    property var collectionsModel: null
    
    property var discoveredServers: []
    property var localServersList: []

    Component.onCompleted: {
        if (appSettings.token && appSettings.token !== "") {
            if (!settingsWindow.isTestEnvironment) {
                plexAuth.fetchServers(appSettings.token);
            } else {
                if (appSettings.token === "fake_test_token_for_auto_fetch") {
                    settingsWindow.connectionState = -1;
                }
            }
        }
    }

    function openTab(tabIndex, serverUrl, token) {
        if (tabIndex !== undefined) {
            settingsSidebarColumn.settingsTab = tabIndex
        } else {
            settingsSidebarColumn.settingsTab = 0
        }
        
        tokenField.text = appSettings.token
        
        try {
            settingsWindow.localServersList = JSON.parse(appSettings.serverList || "[]");
        } catch(e) {
            settingsWindow.localServersList = [];
        }

        connectionState = 0
        connectionError = ""
        visible = true
        
        if (appSettings.token && appSettings.token !== "") {
            if (!settingsWindow.isTestEnvironment) {
                plexAuth.fetchServers(appSettings.token);
            } else {
                if (appSettings.token === "fake_test_token_for_auto_fetch") {
                    settingsWindow.connectionState = -1;
                }
            }
        }
    }

    function closeSettings() {
        visible = false
    }

    function getLibraryIcon(type) {
        if (type === "movie") return "🎬"
        if (type === "show") return "📺"
        if (type === "artist") return "🎵"
        if (type === "photo") return "📷"
        return "📁"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: {}
    }

    PlexAuth {
        id: plexAuth
        objectName: "plexAuth"
        onTokenReceived: function(token) {
            tokenField.text = token
            if (!settingsWindow.isTestEnvironment) {
                appSettings.token = token
                plexAuth.fetchServers(token)
            }
        }
        onAuthError: function(errorMsg) {
            console.error("Plex Auth Error: " + errorMsg)
            settingsWindow.connectionState = -1
        }
        onPinCodeChanged: {
            if (plexAuth.pinCode !== "") {
                var authUrl = "https://app.plex.tv/auth#?clientID=" + plexAuth.clientId + "&code=" + plexAuth.pinCode + "&context[device][product]=Flex%20Player"
                Qt.openUrlExternally(authUrl)
            }
        }
        onServersReceived: function(servers) {
            console.log("[Settings] Received " + servers.length + " servers from Plex");
            if (servers.length === 0) {
                settingsWindow.connectionError = "No Plex servers found on this account."
                settingsWindow.connectionState = 3
                return
            }
            
            var currentList = []
            try { currentList = JSON.parse(appSettings.serverList || "[]") } catch(e) { currentList = [] }
            
            var updatedList = []
            for (var i = 0; i < servers.length; i++) {
                var s = servers[i]
                var existing = currentList.find(function(item) { return item.name === s.name })
                updatedList.push({
                    name: s.name,
                    product: s.product,
                    connections: s.connections,
                    accessToken: s.accessToken,
                    owned: s.owned,
                    sourceTitle: s.sourceTitle,
                    enabled: existing ? existing.enabled : true
                })
            }
            
            appSettings.serverList = JSON.stringify(updatedList)
            localServersList = updatedList
            discoveredServers = servers
            
            var enabledServers = updatedList.filter(function(s) { return s.enabled });
            if (enabledServers.length > 0) {
                testAndSetBestConnection(enabledServers[0])
            }
        }
    }

    property var currentlyTestingNode: null

    function testAndSetBestConnection(serverData) {
        settingsWindow.connectionState = 1
        discoverStatusText.text = "Testing connection to " + serverData.name + "..."
        
        var node = connectionManager.getServer(serverData.name);
        if (node) {
            currentlyTestingNode = node;
            node.forceProbe();
        } else {
            discoverStatusText.text = "Server node not found.";
            settingsWindow.connectionState = 3;
        }
    }

    Connections {
        target: currentlyTestingNode
        function onResolutionFinished(success) {
            var sName = currentlyTestingNode ? currentlyTestingNode.name : "Server";
            if (success) {
                settingsWindow.connectionState = 2
                discoverStatusText.text = sName + ": Connected to " + currentlyTestingNode.activeUrl
            } else {
                settingsWindow.connectionState = 3
                settingsWindow.connectionError = sName + ": Could not reach server."
                discoverStatusText.text = sName + ": Connection failed."
            }
            currentlyTestingNode = null;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        Rectangle {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            color: "#151515"

            ColumnLayout {
                id: settingsSidebarColumn; objectName: "settingsSidebarColumn"
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Button {
                    id: settingsBackButton
                    text: "← Back"
                    Layout.alignment: Qt.AlignLeft
                    contentItem: Text {
                        text: settingsBackButton.text
                        color: settingsBackButton.hovered ? "#E5A00D" : "white"
                        font.pixelSize: 22
                        font.bold: true
                    }
                    background: Rectangle { color: "transparent" }
                    onClicked: closeSettings()
                }

                Item { Layout.preferredHeight: 20 }

                property int settingsTab: 0

                Repeater {
                    model: ["Login Configuration", "Manage Libraries", "Hotkeys", "Playback", "Appearance"]
                    delegate: Button {
                        text: modelData
                        objectName: "settingsTab" + index
                        Layout.fillWidth: true
                        contentItem: Text {
                            text: parent.text
                            color: settingsSidebarColumn.settingsTab === index ? "#E5A00D" : "white"
                            font.pixelSize: 18
                            font.bold: settingsSidebarColumn.settingsTab === index
                        }
                        background: Rectangle { color: "transparent" }
                        onClicked: settingsSidebarColumn.settingsTab = index
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Main Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            StackLayout {
                anchors.fill: parent
                anchors.margins: 40
                currentIndex: settingsSidebarColumn.settingsTab

                // TAB 0: Login
                ColumnLayout {
                    spacing: 25
                    
                    Text {
                        text: "Login Configuration"
                        color: "white"
                        font.pixelSize: 32
                        font.bold: true
                        Layout.bottomMargin: 10
                    }

                    ColumnLayout {
                        spacing: 8
                        Text { text: "Plex API Token"; color: "gray"; font.pixelSize: 14 }
                        RowLayout {
                            spacing: 15
                            TextField {
                                id: tokenField
                                objectName: "tokenField"
                                Layout.preferredWidth: 450
                                placeholderText: "Paste your Plex token here"
                                text: appSettings.token
                                color: "white"
                                font.pixelSize: 16
                                background: Rectangle { color: "#2e2e2e"; radius: 8 }
                                leftPadding: 15
                                topPadding: 10
                                bottomPadding: 10
                                onTextEdited: settingsWindow.connectionState = 0
                            }
                            Button {
                                objectName: "getFromPlexButton"
                                text: "Login with Plex"
                                contentItem: Text { 
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter 
                                }
                                background: Rectangle { 
                                    implicitWidth: 160
                                    implicitHeight: 44
                                    color: "#E5A00D"
                                    radius: 8 
                                }
                                onClicked: plexAuth.requestPin()
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 15
                        Layout.topMargin: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Servers"; color: "white"; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
                            Button {
                                text: "🔄 Refresh"
                                visible: tokenField.text !== ""
                                onClicked: plexAuth.fetchServers(tokenField.text)
                                background: Rectangle { color: "transparent" }
                                contentItem: Text { text: parent.text; color: "#E5A00D"; font.pixelSize: 14; font.bold: true }
                            }
                        }
                        
                        ListView {
                            id: serverCheckList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(localServersList.length * 50 + 10, 300)
                            model: localServersList
                            clip: true
                            delegate: RowLayout {
                                    Component.onCompleted: console.log("[Settings] Created library delegate: " + model.title)
                                width: serverCheckList.width
                                height: 45
                                spacing: 15
                                CheckBox {
                                    checked: modelData.enabled
                                    onClicked: {
                                        var list = JSON.parse(appSettings.serverList || "[]")
                                        for (var i = 0; i < list.length; i++) {
                                            if (list[i].name === modelData.name) {
                                                list[i].enabled = checked
                                            }
                                        }
                                        appSettings.serverList = JSON.stringify(list)
                                        localServersList = list
                                    }
                                }
                                property var serverNode: typeof connectionManager !== "undefined" ? connectionManager.getServer(modelData.name) : null
                                property bool isOffline: serverNode ? !serverNode.isOnline : false
                                Text { text: "🖥️ " + modelData.name + (isOffline ? " ❌" : ""); color: isOffline ? "#888" : "white"; font.pixelSize: 18; Layout.fillWidth: true }
                                Button {
                                    text: "Test"
                                    onClicked: testAndSetBestConnection(modelData)
                                    background: Rectangle { 
                                        implicitWidth: 80
                                        implicitHeight: 32
                                        color: "#333333"
                                        radius: 6
                                        border.color: "#444444" 
                                    }
                                    contentItem: Text { 
                                        text: parent.text
                                        color: "white"
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter 
                                    }
                                }
                            }
                        }


                    }

                    Text {
                        id: discoverStatusText
                        objectName: "discoverStatusText"
                        text: ""
                        color: "#E5A00D"
                        font.pixelSize: 14
                        visible: text !== ""
                    }

                    RowLayout {
                        spacing: 10
                        visible: settingsWindow.connectionState !== 0
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: settingsWindow.connectionState === 1 ? "#E5A00D" : (settingsWindow.connectionState === 2 ? "#4CAF50" : "#FF5252")
                        }
                        Text {
                            text: settingsWindow.connectionState === 1 ? "Connecting..." : (settingsWindow.connectionState === 2 ? "Connection Successful!" : "Connection Failed: " + settingsWindow.connectionError)
                            color: "white"
                            font.pixelSize: 14
                        }
                    }

                    TextField { id: serverUrlField; objectName: "serverUrlField"; visible: false; text: appSettings.serverUrl }

                    RowLayout {
                        Layout.topMargin: 20
                        spacing: 15
                        Button {
                            text: "Cancel"
                            contentItem: Text { 
                                text: parent.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter 
                            }
                            background: Rectangle { 
                                implicitWidth: 120
                                implicitHeight: 40
                                color: "#444444"
                                radius: 8 
                            }
                            onClicked: closeSettings()
                        }
                        Button {
                            id: saveSettingsButton
                            objectName: "saveSettingsButton"
                            text: "Save & Apply"
                            contentItem: Text { 
                                text: parent.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter 
                            }
                            background: Rectangle { 
                                implicitWidth: 160
                                implicitHeight: 40
                                color: "#E5A00D"
                                radius: 8 
                            }
                            onClicked: {
                                appSettings.token = tokenField.text
                                closeSettings()
                                if (!isTestEnvironment) mainWindow.startupLogic()
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                // TAB 1: Libraries
                ColumnLayout {
                    id: librariesTabCol
                    objectName: "librariesTabCol"
                    spacing: 20
                    property var localLibrariesMap: ({})
                    
                    Component.onCompleted: {
                        try { 
                            var raw = JSON.parse(appSettings.enabledLibraries || "{}");
                            var filtered = {};
                            var keys = Object.keys(raw);
                            for (var i = 0; i < keys.length; i++) {
                                if (keys[i].indexOf("_") !== -1) filtered[keys[i]] = raw[keys[i]];
                            }
                            localLibrariesMap = filtered;
                        } catch(e) { localLibrariesMap = {} }
                    }
                    
                    onVisibleChanged: {
                        if (visible) {
                            try { 
                                var raw = JSON.parse(appSettings.enabledLibraries || "{}");
                                var filtered = {};
                                var keys = Object.keys(raw);
                                for (var i = 0; i < keys.length; i++) {
                                    if (keys[i].indexOf("_") !== -1) filtered[keys[i]] = raw[keys[i]];
                                }
                                localLibrariesMap = filtered;
                            } catch(e) { localLibrariesMap = {} }
                            if (connectionManager.activeUrl !== "" && allLibrariesModel) {
                                console.log("[Settings] Fetching libraries from active URL: " + connectionManager.activeUrl);
                                allLibrariesModel.fetchEndpoint(connectionManager.activeUrl, appSettings.token, "/library/sections");
                            } else {
                                console.log("[Settings] Cannot fetch libraries: activeUrl empty or model null");
                            }
                        }
                    }

                    Text { text: "Library Configuration"; color: "white"; font.pixelSize: 32; font.bold: true }
                    Text { text: "Select which libraries to display on the Home screen:"; color: "gray"; font.pixelSize: 16 }

                    ListView {
                        id: serverLibrariesList
                        objectName: "serverLibrariesList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: localServersList.filter(function(s) { return s.enabled })
                        clip: true
                        spacing: 30
                        delegate: ColumnLayout {
                            id: serverDelegateRoot
                            width: serverLibrariesList.width
                            spacing: 12
                            
                            property string serverUrl: ""
                            property string serverName: modelData.name
                            property string serverToken: modelData.accessToken !== undefined && modelData.accessToken !== "" ? modelData.accessToken : appSettings.token
                            property bool isOwned: modelData.owned !== undefined ? modelData.owned : true
                            property string sourceTitle: modelData.sourceTitle !== undefined ? modelData.sourceTitle : ""
                            
                            property var serverNode: typeof connectionManager !== "undefined" && connectionManager !== null ? connectionManager.getServer(serverDelegateRoot.serverName) : null
                            property bool isOffline: serverNode ? !serverNode.isOnline : false

                            Connections {
                                target: typeof connectionManager !== "undefined" ? connectionManager : null
                                function onActiveUrlChanged() {
                                    serverDelegateRoot.updateServerUrl();
                                }
                            }
                            
                            function updateServerUrl() {
                                var hasController = (typeof rootApp !== "undefined" && rootApp.controller);
                                var hasConnManager = (typeof connectionManager !== "undefined");
                                console.log("[Settings] updateServerUrl called for " + serverDelegateRoot.serverName + " activeServersList: " + (hasController && rootApp.controller.activeServersList ? rootApp.controller.activeServersList.length : "null") + " activeUrl: " + (hasConnManager ? connectionManager.activeUrl : "null"));
                                var knownUrl = "";
                                if (hasController && rootApp.controller.activeServersList) {
                                    for (var j = 0; j < rootApp.controller.activeServersList.length; j++) {
                                        if (rootApp.controller.activeServersList[j].serverName === serverDelegateRoot.serverName) {
                                            knownUrl = rootApp.controller.activeServersList[j].serverUrl;
                                            break;
                                        }
                                    }
                                }
                                if (knownUrl === "" && hasConnManager && connectionManager.activeUrl !== "") {
                                    // If activeUrl matches any connection block for this server, use it.
                                    var activeU = connectionManager.activeUrl;
                                    var isThisServer = false;
                                    if (modelData.connections) {
                                        for (var k = 0; k < modelData.connections.length; k++) {
                                            if (activeU.indexOf(modelData.connections[k].address) !== -1) {
                                                isThisServer = true;
                                                break;
                                            }
                                        }
                                    }
                                    if (isThisServer) {
                                        knownUrl = activeU;
                                    }
                                }
                                if (knownUrl !== "") {
                                    console.log("[Settings] updateServerUrl found knownUrl: " + knownUrl + " for " + serverDelegateRoot.serverName);
                                    serverUrl = knownUrl;
                                    return;
                                }

                                if (modelData.connections && modelData.connections.length > 0) {
                                    for (var i = 0; i < modelData.connections.length; i++) {
                                        var c = modelData.connections[i];
                                        var uri = c.uri;
                                        if (uri && uri.indexOf("plex.direct") !== -1) {
                                            var match = uri.match(/(\d+-\d+-\d+-\d+)/);
                                            if (match) {
                                                var ip = match[1].replace(/-/g, ".");
                                                uri = "http://" + ip + ":" + c.port;
                                            } else {
                                                uri = "http://" + c.address + ":" + c.port;
                                            }
                                        }
                                        if (c.local && c.address && (c.address.indexOf("192.168.") === 0 || c.address.indexOf("10.") === 0 || c.address.indexOf("172.") === 0)) {
                                            serverUrl = uri;
                                            return;
                                        }
                                    }
                                    var fbUri = modelData.connections[0].uri;
                                    if (fbUri && fbUri.indexOf("plex.direct") !== -1) {
                                        var fbMatch = fbUri.match(/(\d+-\d+-\d+-\d+)/);
                                        if (fbMatch) {
                                            fbUri = "http://" + fbMatch[1].replace(/-/g, ".") + ":" + modelData.connections[0].port;
                                        } else {
                                            fbUri = "http://" + modelData.connections[0].address + ":" + modelData.connections[0].port;
                                        }
                                    }
                                    serverUrl = fbUri;
                                    return;
                                }
                                serverUrl = "";
                            }
                            
                            Component.onCompleted: updateServerUrl()

                            Text { 
                                text: "📁 Server: " + serverDelegateRoot.serverName + (serverDelegateRoot.isOwned ? "" : " (Shared by " + serverDelegateRoot.sourceTitle + ")") + (serverDelegateRoot.isOffline ? " ❌" : ""); 
                                color: serverDelegateRoot.isOffline ? "#888" : "#E5A00D"; 
                                font.pixelSize: 22; 
                                font.bold: true 
                            }
                            
                            Text {
                                text: "❌ Server unreachable. Please check connection."
                                color: "#AA0000"
                                font.pixelSize: 16
                                font.italic: true
                                visible: serverDelegateRoot.isOffline
                                Layout.leftMargin: 30
                            }
                            
                            PlexModel {
                                id: serverLibrariesModel
                                // DO NOT assign connectionManager here, otherwise speculative local fetches will poison the global ConnectionManager state
                                
                                function tryFetch() {
                                    if (serverDelegateRoot.serverUrl !== "") {
                                        console.log("[Settings] serverLibrariesModel fetching for " + serverDelegateRoot.serverName + " with URL: " + serverDelegateRoot.serverUrl + " token: " + (serverDelegateRoot.serverToken !== appSettings.token ? "custom" : "global"));
                                        fetchEndpoint(serverDelegateRoot.serverUrl, serverDelegateRoot.serverToken, "/library/sections");
                                    }
                                }
                                
                                Component.onCompleted: tryFetch()
                                
                                onModelReset: {
                                    console.log("[Settings] serverLibrariesModel reset for " + serverDelegateRoot.serverName + ". Count: " + rowCount());
                                }
                            }
                            
                            Connections {
                                target: serverDelegateRoot
                                function onServerUrlChanged() {
                                    serverLibrariesModel.tryFetch();
                                }
                            }
                            
                            Repeater {
                                visible: !serverDelegateRoot.isOffline
                                model: serverLibrariesModel
                                delegate: RowLayout {
                                    Layout.leftMargin: 30
                                    spacing: 15
                                    
                                    property string uniqueKey: serverDelegateRoot.serverName + "_" + model.ratingKey
                                    
                                    CheckBox {
                                        objectName: "libraryCheckbox"
                                        enabled: model.type === "movie" || model.type === "show" || model.type === "season" || model.type === "artist"
                                        checked: !!librariesTabCol.localLibrariesMap[uniqueKey]
                                        onToggled: {
                                            var map = Object.assign({}, librariesTabCol.localLibrariesMap)
                                            if (checked) { 
                                                map[uniqueKey] = { 
                                                    "id": model.ratingKey,
                                                    "type": model.type, 
                                                    "title": model.title, 
                                                    "serverName": serverDelegateRoot.serverName,
                                                    "serverUrl": serverDelegateRoot.serverUrl,
                                                    "serverToken": serverDelegateRoot.serverToken
                                                } 
                                            }
                                            else { delete map[uniqueKey] }
                                            librariesTabCol.localLibrariesMap = map
                                        }
                                    }
                                    Text { text: getLibraryIcon(model.type) + " " + model.title; color: "white"; font.pixelSize: 18 }
                                    Text {
                                        objectName: "unsupportedWarning"
                                        text: " (Not supported yet)"
                                        color: "#AA0000"
                                        font.pixelSize: 14
                                        font.italic: true
                                        visible: model.type !== "movie" && model.type !== "show" && model.type !== "season" && model.type !== "artist"
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#333333"; Layout.topMargin: 10 }
                        }
                    }
                    RowLayout {
                        Layout.topMargin: 20
                        spacing: 15
                        Button {
                            text: "Cancel"
                            contentItem: Text { 
                                text: parent.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter 
                            }
                            background: Rectangle { 
                                implicitWidth: 120
                                implicitHeight: 40
                                color: "#444444"
                                radius: 8 
                            }
                            onClicked: closeSettings()
                        }
                        Button {
                            id: saveLibrariesButton
                            objectName: "saveLibrariesButton"
                            text: "Save & Apply"
                            contentItem: Text { 
                                text: parent.text
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter 
                            }
                            background: Rectangle { 
                                implicitWidth: 160
                                implicitHeight: 40
                                color: "#E5A00D"
                                radius: 8 
                            }
                            onClicked: {
                                appSettings.enabledLibraries = JSON.stringify(librariesTabCol.localLibrariesMap)
                                closeSettings()
                                if (!isTestEnvironment) mainWindow.startupLogic()
                            }
                        }
                    }
                }

                // TAB 2: Hotkeys
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    ColumnLayout {
                        width: parent.width
                        spacing: 20
                        Text { text: "Hotkeys"; color: "white"; font.pixelSize: 32; font.bold: true; Layout.bottomMargin: 10 }
                        
                        Text { text: "Global"; color: "#E5A00D"; font.pixelSize: 24; font.bold: true; Layout.topMargin: 10 }
                        RowLayout {
                            Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                            Text { text: "Action Name"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 200 }
                            Text { text: "Description"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Assigned Hotkey"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 150 }
                            Text { text: "Assign"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 100 }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.maximumWidth: 800; height: 1; color: "#444444" }
                        
                        RowLayout {
                            Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                            Text { text: "Refresh Page"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                            Text { text: "Reload current page data"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                            Text { 
                                id: refreshHotkeyText
                                objectName: "refreshHotkeyText"
                                text: appSettings.refreshHotkey
                                color: "#E5A00D"
                                font.pixelSize: 18
                                font.bold: true
                                Layout.preferredWidth: 150 
                            }
                            Button {
                                text: "Set"
                                objectName: "setRefreshHotkeyBtn"
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                                onClicked: { hotkeyOverlay.actionToBind = "refresh"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                            }
                        }
                        
                        Text { text: "Video Player"; color: "#E5A00D"; font.pixelSize: 24; font.bold: true; Layout.topMargin: 10 }
                        RowLayout {
                            Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                            Text { text: "Action Name"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 200 }
                            Text { text: "Description"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Assigned Hotkey"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 150 }
                            Text { text: "Assign"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 100 }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.maximumWidth: 800; height: 1; color: "#444444" }
                        
                        // Fullscreen
                        RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Toggle Full Screen"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Enter/Exit full screen video playback"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { 
                            id: fsHotkeyText
                            objectName: "fsHotkeyText"
                            text: appSettings.fullscreenHotkey
                            color: "#E5A00D"
                            font.pixelSize: 18
                            font.bold: true
                            Layout.preferredWidth: 150 
                        }
                        Button {
                            text: "Set"
                            objectName: "setFsHotkeyBtn"
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "fullscreen"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    // Play/Pause
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Toggle Play/Pause"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Play or pause the active video"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { 
                            id: ppHotkeyText
                            objectName: "ppHotkeyText"
                            text: appSettings.playPauseHotkey
                            color: "#E5A00D"
                            font.pixelSize: 18
                            font.bold: true
                            Layout.preferredWidth: 150 
                        }
                        Button {
                            text: "Set"
                            objectName: "setPpHotkeyBtn"
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "playpause"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    // Volume Up
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Increase Volume"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Increase the video playback volume"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { 
                            id: volUpHotkeyText
                            objectName: "volUpHotkeyText"
                            text: appSettings.volumeUpHotkey
                            color: "#E5A00D"
                            font.pixelSize: 18
                            font.bold: true
                            Layout.preferredWidth: 150 
                        }
                        Button {
                            text: "Set"
                            objectName: "setVolUpHotkeyBtn"
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "volup"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    // Volume Down
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Decrease Volume"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Decrease the video playback volume"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { 
                            id: volDownHotkeyText
                            objectName: "volDownHotkeyText"
                            text: appSettings.volumeDownHotkey
                            color: "#E5A00D"
                            font.pixelSize: 18
                            font.bold: true
                            Layout.preferredWidth: 150 
                        }
                        Button {
                            text: "Set"
                            objectName: "setVolDownHotkeyBtn"
                            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "voldown"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    
                    Text { text: "Music Player"; color: "#E5A00D"; font.pixelSize: 24; font.bold: true; Layout.topMargin: 20 }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Action Name"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 200 }
                        Text { text: "Description"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                        Text { text: "Assigned Hotkey"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 150 }
                        Text { text: "Assign"; color: "gray"; font.pixelSize: 16; font.bold: true; Layout.preferredWidth: 100 }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.maximumWidth: 800; height: 1; color: "#444444" }

                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Up"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Moves up in the playlist"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicUpHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mUp"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Down"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Moves down in the playlist"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicDownHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mDown"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Select All"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Selects all items"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicSelectAllHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mSelAll"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Delete"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Deletes current selection"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicDeleteHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mDel"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Select & Move Down"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Selects and moves down"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicShiftDownHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mSDown"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Select & Move Up"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Selects and moves up"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicShiftUpHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mSUp"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.maximumWidth: 800; spacing: 20
                        Text { text: "Play/Pause"; color: "white"; font.pixelSize: 16; Layout.preferredWidth: 200 }
                        Text { text: "Pauses and plays selected track"; color: "#aaaaaa"; font.pixelSize: 14; Layout.fillWidth: true }
                        Text { text: appSettings.musicPlayPauseHotkey; color: "#E5A00D"; font.pixelSize: 18; font.bold: true; Layout.preferredWidth: 150 }
                        Button {
                            text: "Set"; contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { implicitWidth: 80; implicitHeight: 32; color: "#444444"; radius: 6 }
                            onClicked: { hotkeyOverlay.actionToBind = "mPP"; hotkeyOverlay.visible = true; hotkeyOverlay.forceActiveFocus() }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    }
                }

                // TAB 3: Playback
                ColumnLayout {
                    spacing: 20
                    Text { text: "Playback Configuration"; color: "white"; font.pixelSize: 32; font.bold: true; Layout.bottomMargin: 10 }
                    
                    CheckBox {
                        id: hdrEnableCheckbox
                        objectName: "hdrEnableCheckbox"
                        text: "Automatically Toggle system HDR on HDR movie playback"
                        checked: appSettings ? appSettings.autoToggleHdr : false
                        enabled: collectionsModel && (!collectionsModel.isFlatpak || collectionsModel.hasFlatpakSpawnPermission)
                        onCheckedChanged: { appSettings.autoToggleHdr = checked }
                        contentItem: Text { 
                            text: parent.text
                            color: hdrEnableCheckbox.enabled ? "white" : "gray"
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: parent.indicator.width + parent.spacing 
                        }
                    }
                    ColumnLayout {
                        visible: collectionsModel.isFlatpak && !collectionsModel.hasFlatpakSpawnPermission
                        spacing: 5
                        Layout.fillWidth: true
                        Text { 
                            text: "Flatpak permission required to enable automatic HDR. Run this command and **restart the application**:"
                            color: "#FF5252"
                            font.pixelSize: 13
                            font.bold: true 
                        }
                        TextField {
                            text: "flatpak override --user --talk-name=org.freedesktop.Flatpak io.github.danilovsergei.flex-player"
                            readOnly: true
                            selectByMouse: true
                            Layout.fillWidth: true
                            font.family: "Monospace"
                            font.pixelSize: 12
                            background: Rectangle { 
                                color: "#000000"
                                radius: 4
                                border.color: "#FF5252"
                                border.width: 1 
                            }
                            color: "#00FF00"
                            topPadding: 8
                            bottomPadding: 8
                            leftPadding: 10
                        }
                    }
                    Text { text: "HDR Enable Command"; color: "gray"; font.pixelSize: 14; Layout.topMargin: 10 }
                    RowLayout {
                        spacing: 10
                        TextField {
                            id: hdrEnableCommand
                            objectName: "hdrEnableCommand"
                            text: appSettings.hdrEnableCommand || "kscreen-doctor output.DP-1.hdr.enable"
                            color: "white"
                            font.pixelSize: 16
                            Layout.preferredWidth: 400
                            background: Rectangle { color: "#333333"; radius: 5 }
                            onTextChanged: { appSettings.hdrEnableCommand = text }
                        }
                        Button {
                            objectName: "testHdrEnableButton"
                            text: "Test"
                            onClicked: mainWindow.runHdrCommand(hdrEnableCommand.text)
                        }
                    }
                    Text { text: "HDR Disable Command"; color: "gray"; font.pixelSize: 14; Layout.topMargin: 10 }
                    RowLayout {
                        spacing: 10
                        TextField {
                            id: hdrDisableCommand
                            objectName: "hdrDisableCommand"
                            text: appSettings.hdrDisableCommand || "kscreen-doctor output.DP-1.hdr.disable"
                            color: "white"
                            font.pixelSize: 16
                            Layout.preferredWidth: 400
                            background: Rectangle { color: "#333333"; radius: 5 }
                            onTextChanged: { appSettings.hdrDisableCommand = text }
                        }
                        Button {
                            objectName: "testHdrDisableButton"
                            text: "Test"
                            onClicked: mainWindow.runHdrCommand(hdrDisableCommand.text)
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                // TAB 4: Appearance
                ColumnLayout {
                    spacing: 20
                    Text { text: "Appearance"; color: "white"; font.pixelSize: 32; font.bold: true; Layout.bottomMargin: 10 }
                    
                    Text { text: "Music Library:"; color: "#E5A00D"; font.pixelSize: 20; font.bold: true }
                    
                    CheckBox {
                        id: minimizeSidebarCheckbox
                        objectName: "minimizeSidebarCheckbox"
                        text: "Minimize sidebar when switching to \"Music\" library"
                        checked: appSettings ? appSettings.minimizeSidebarOnMusic : false
                        onCheckedChanged: { appSettings.minimizeSidebarOnMusic = checked }
                        contentItem: Text { 
                            text: parent.text
                            color: "white"
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: parent.indicator.width + parent.spacing 
                        }
                    }

                    Text { text: "Album Details:"; color: "#E5A00D"; font.pixelSize: 20; font.bold: true; Layout.topMargin: 20 }
                    
                    RowLayout {
                        spacing: 15
                        Text {
                            text: "Keep album playlist always in:"
                            color: "white"
                            font.pixelSize: 16
                        }
                        FlexComboBox {
                            id: albumLayoutModeDropdown
                            objectName: "albumLayoutModeDropdown"
                            Layout.fillWidth: false
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 40
                            model: {
                                var v = [];
                                v.push("Auto (Responsive)");
                                v.push("Vertical");
                                v.push("Horizontal");
                                return v;
                            }
                            currentIndex: appSettings ? appSettings.albumLayoutMode : 0
                            onActivated: function(index) {
                                if (appSettings) {
                                    appSettings.albumLayoutMode = index;
                                }
                            }
                            font.pixelSize: 16
                            implicitWidth: 200
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // Overlays & Popups
    Rectangle {
        id: pinOverlay
        objectName: "pinOverlay"
        anchors.fill: parent
        color: "#E6000000"
        z: 100
        visible: plexAuth.isPolling
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent
            spacing: 30
            Text { 
                text: "Authenticating..."
                color: "white"
                font.pixelSize: 36
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter 
            }
            Text { 
                text: "A secure browser window has opened.<br>Please sign in to Plex to continue."
                color: "gray"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.RichText 
            }
            Button {
                text: "Cancel"
                anchors.horizontalCenter: parent.horizontalCenter
                contentItem: Text { 
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter 
                }
                background: Rectangle { 
                    implicitWidth: 160
                    implicitHeight: 48
                    color: "#444444"
                    radius: 8 
                }
                onClicked: plexAuth.cancelLogin()
            }
        }
    }

    Rectangle {
        id: hotkeyOverlay
        objectName: "hotkeyOverlay"
        anchors.fill: parent
        color: "#E6000000"
        visible: false
        z: 200
        property string actionToBind: ""
        focus: visible
        function bindKey(newKey) {
            if (!newKey || newKey === "") return
            if (actionToBind === "refresh") appSettings.refreshHotkey = newKey
            else if (actionToBind === "fullscreen") appSettings.fullscreenHotkey = newKey
            else if (actionToBind === "playpause") appSettings.playPauseHotkey = newKey
            else if (actionToBind === "volup") appSettings.volumeUpHotkey = newKey
            else if (actionToBind === "voldown") appSettings.volumeDownHotkey = newKey
            else if (actionToBind === "mUp") appSettings.musicUpHotkey = newKey
            else if (actionToBind === "mDown") appSettings.musicDownHotkey = newKey
            else if (actionToBind === "mSelAll") appSettings.musicSelectAllHotkey = newKey
            else if (actionToBind === "mDel") appSettings.musicDeleteHotkey = newKey
            else if (actionToBind === "mSDown") appSettings.musicShiftDownHotkey = newKey
            else if (actionToBind === "mSUp") appSettings.musicShiftUpHotkey = newKey
            else if (actionToBind === "mPP") appSettings.musicPlayPauseHotkey = newKey
            visible = false
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) return
            if (event.key === Qt.Key_Escape) { hotkeyOverlay.visible = false; event.accepted = true; return }
            var keyStr = ""
            if (event.modifiers & Qt.ControlModifier) keyStr += "Ctrl+"
            if (event.modifiers & Qt.AltModifier) keyStr += "Alt+"
            if (event.modifiers & Qt.ShiftModifier) keyStr += "Shift+"
            if (event.modifiers & Qt.MetaModifier) keyStr += "Meta+"
            var baseKey = ""
            if (event.key === Qt.Key_Space) baseKey = "Space"
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) baseKey = "Return"
            else if (event.key === Qt.Key_Tab) baseKey = "Tab"
            else if (event.key === Qt.Key_Backspace) baseKey = "Backspace"
            else if (event.key === Qt.Key_Delete) baseKey = "Delete"
            else if (event.key === Qt.Key_Up) baseKey = "Up"
            else if (event.key === Qt.Key_Down) baseKey = "Down"
            else if (event.key === Qt.Key_Left) baseKey = "Left"
            else if (event.key === Qt.Key_Right) baseKey = "Right"
            else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) baseKey = "F" + (event.key - Qt.Key_F1 + 1)
            else if (event.key >= 0x20 && event.key <= 0x0ff) baseKey = String.fromCharCode(event.key).toUpperCase()
            else if (event.text !== "") baseKey = event.text.toUpperCase()
            if (baseKey === "") return
            bindKey(keyStr + baseKey)
            event.accepted = true
        }
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent
            spacing: 20
            Text { 
                text: "Listening for key press..."
                color: "white"
                font.pixelSize: 32
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter 
            }
            Text { 
                text: "Press any key to assign it to this action.\nPress ESC to cancel."
                color: "gray"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter 
            }
            Button { 
                text: "Cancel"
                objectName: "cancelHotkeyBtn"
                anchors.horizontalCenter: parent.horizontalCenter
                contentItem: Text { 
                    text: parent.text
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter 
                }
                background: Rectangle { 
                    implicitWidth: 120
                    implicitHeight: 40
                    color: "#444444"
                    radius: 6 
                }
                onClicked: { hotkeyOverlay.visible = false } 
            }
        }
    }




}
