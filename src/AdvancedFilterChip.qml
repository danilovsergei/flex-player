import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

Rectangle {
    id: chipRoot
    
    signal removeClicked()
    signal filterChanged(string fField, string fOp, string fVal, string fLabel)

    property var appCtrl: null
    property var appSet: null

    property string initialField: "title"
    property string initialOp: "="
    property string initialVal: ""
    property string initialLabel: ""

    property string currentField: initialField
    property string currentOp: initialOp
    property string currentVal: initialVal
    property string currentLabel: initialLabel
    property bool isBoolean: isBooleanField(currentField)

    height: 40
    width: rowLayout.implicitWidth + 30
    radius: 20
    color: "#444"
    border.color: "#555"
    border.width: 1

    property var stringFields: [
        { text: "Title", value: "title" },
        { text: "Genre", value: "genre" },
        { text: "Content Rating", value: "contentRating" },
        { text: "Collection", value: "collection" },
        { text: "Director", value: "director" },
        { text: "Actor", value: "actor" },
        { text: "Writer", value: "writer" },
        { text: "Producer", value: "producer" },
        { text: "Country", value: "country" },
        { text: "Studio", value: "studio" },
        { text: "Resolution", value: "resolution" },
        { text: "Video Codec", value: "videoCodec" },
        { text: "Audio Codec", value: "audioCodec" },
        { text: "Subtitle Codec", value: "subtitleCodec" },
        { text: "Audio Layout", value: "audioLayout" },
        { text: "Audio Language", value: "audioLanguage" },
        { text: "Subtitle Language", value: "subtitleLanguage" },
        { text: "Edition", value: "editionTitle" },
        { text: "Labels", value: "label" }
    ]
    
    property var numberFields: [
        { text: "Year", value: "year" },
        { text: "Decade", value: "decade" }
    ]

    property var booleanFields: [
        { text: "Unwatched", value: "unwatched" },
        { text: "In Progress", value: "inProgress" },
        { text: "HDR", value: "hdr" },
        { text: "DOVI", value: "dovi" },
        { text: "Atmos", value: "atmos" },
        { text: "Unmatched", value: "unmatched" },
        { text: "Duplicates", value: "duplicate" }
    ]

    property var stringOperators: [
        { text: "contains", value: "=" },
        { text: "does not contain", value: "!=" },
        { text: "is", value: "%3D=" },
        { text: "is not", value: "!=" },
        { text: "begins with", value: "%3C=" },
        { text: "ends with", value: "%3E=" }
    ]

    property var numberOperators: [
        { text: "is", value: "=" },
        { text: "is not", value: "!=" },
        { text: "is greater than", value: "%3E%3E=" },
        { text: "is less than", value: "%3C%3C=" }
    ]

    property var stringDropdownOperators: [
        { text: "is", value: "=" },
        { text: "is not", value: "!=" }
    ]
    property var numberDropdownOperators: [
        { text: "is", value: "=" },
        { text: "is not", value: "!=" }
    ]

    property var booleanOperators: [
        { text: "is true", value: "=1" },
        { text: "is false", value: "=0" },
        { text: "is not true", value: "!=1" },
        { text: "is not false", value: "!=0" }
    ]

    function isBooleanField(f) {
        for (var i = 0; i < booleanFields.length; i++) {
            if (booleanFields[i].value === f) return true;
        }
        return false;
    }

    function isDropdownField(f) {
        return f !== "title" && !isBooleanField(f);
    }

    function getOpModel() {
        if (isBooleanField(chipRoot.currentField)) return booleanOperators;
        if (isDropdownField(chipRoot.currentField)) {
            return isNumberField(chipRoot.currentField) ? numberDropdownOperators : stringDropdownOperators;
        } else {
            return isNumberField(chipRoot.currentField) ? numberOperators : stringOperators;
        }
    }

    PlexModel {
        id: filterOptionsModel
        connectionManager: appCtrl ? appCtrl.connectionManager : null
        onModelReset: {
            var maxVW = 60;
            for (var i = 0; i < filterOptionsModel.rowCount(); i++) {
                var item = filterOptionsModel.get(i);
                if (item) {
                    if (chipRoot.currentLabel === "" && chipRoot.currentVal !== "" && item.ratingKey === chipRoot.currentVal) {
                        chipRoot.currentLabel = item.title;
                    }
                    calcMetrics.text = item.title + " ▾";
                    if (calcMetrics.width > maxVW) {
                        maxVW = calcMetrics.width;
                    }
                }
            }
            chipRoot.maxValueFieldWidth = maxVW + 20;
        }
    }

    function isNumberField(f) {
        for (var i = 0; i < numberFields.length; i++) {
            if (numberFields[i].value === f) return true;
        }
        return false;
    }
    
    function emitChange() {
        chipRoot.filterChanged(currentField, currentOp, currentVal, currentLabel)
    }

    function getFieldText(f) {
        var allFields = stringFields.concat(numberFields).concat(booleanFields)
        for (var i = 0; i < allFields.length; i++) {
            if (allFields[i].value === f) return allFields[i].text;
        }
        return f;
    }

    function getOpText(o) {
        var activeOps = getOpModel()
        for (var i = 0; i < activeOps.length; i++) {
            if (activeOps[i].value === o) return activeOps[i].text;
        }
        return o;
    }

    property int maxFieldWidth: 100
    property int maxOpWidth: 130
    property int maxValuePopupWidth: 250
    property int maxValueFieldWidth: 100

    TextMetrics {
        id: calcMetrics
        font.pixelSize: 14
        font.bold: true
    }

    Component.onCompleted: {
        var maxFW = 0
        var allFields = stringFields.concat(numberFields).concat(booleanFields)
        for (var i = 0; i < allFields.length; i++) {
            calcMetrics.text = allFields[i].text + " ▾"
            if (calcMetrics.width > maxFW) maxFW = calcMetrics.width
        }
        maxFieldWidth = maxFW + 20

        var maxOW = 0
        var allOps = stringOperators.concat(numberOperators).concat(booleanOperators)
        for (var j = 0; j < allOps.length; j++) {
            calcMetrics.text = allOps[j].text + " ▾"
            if (calcMetrics.width > maxOW) maxOW = calcMetrics.width
        }
        maxOpWidth = maxOW + 20
        
        if (isDropdownField(chipRoot.currentField) && chipRoot.currentLabel === "" && chipRoot.currentVal !== "") {
            if (appCtrl && appCtrl.currentLibraryId !== "") {
                var endpoint = "/library/sections/" + appCtrl.currentLibraryId + "/" + chipRoot.currentField
                var params = []
                if (appCtrl.currentLibraryType === "show") {
                    params.push("type=2")
                } else {
                    params.push("type=1")
                }
                if (params.length > 0) {
                    endpoint += "?" + params.join("&")
                }
                var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : (appCtrl.connectionManager && appCtrl.connectionManager.activeUrl !== "" ? appCtrl.connectionManager.activeUrl : (appSet ? appSet.serverUrl : ""));
                if (url !== "") {
                    var token = appCtrl.currentServerToken !== "" ? appCtrl.currentServerToken : (appSet ? appSet.token : "");
                    filterOptionsModel.fetchEndpoint(url, token, endpoint)
                }
            }
        }
    }

    Row {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 2
        
        // Field Selector
        Item {
            id: fieldSelector
            objectName: "advFieldSelector"
            width: maxFieldWidth
            height: 30

            Row {
                id: fieldTextRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: getFieldText(chipRoot.currentField)
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: "▾"
                    color: "white"
                    font.pixelSize: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: fieldPopup.open()
            }

            Popup {
                id: fieldPopup
                y: fieldSelector.height
                width: Math.max(fieldSelector.width, fieldListView.contentItem.childrenRect.width + 20)
                height: Math.min(300, fieldListView.contentHeight)
                padding: 0
                background: Rectangle {
                    color: "black"
                    border.color: "#555"
                    radius: 4
                }
                
                ListView {
                    id: fieldListView
                    objectName: "advFieldListView"
                    anchors.fill: parent
                    clip: true
                    model: stringFields.concat(numberFields).concat(booleanFields)
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 10000
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    
                    delegate: ItemDelegate {
                        objectName: "advOption_" + modelData.value
                        width: implicitWidth
                        height: 35
                        padding: 0
                        contentItem: Text {
                            text: modelData.text
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                            rightPadding: 10
                        }
                        background: Rectangle {
                            width: ListView.view ? ListView.view.width : 0
                            height: 35
                            color: parent.hovered ? "#333" : "black"
                        }
                        onClicked: {
                            chipRoot.currentField = modelData.value
                            if (isBooleanField(chipRoot.currentField)) {
                                chipRoot.currentOp = "=1"
                            } else if (isDropdownField(chipRoot.currentField)) {
                                chipRoot.currentOp = "="
                            } else if (isNumberField(currentField) && !isNumberField(initialField)) {
                                chipRoot.currentOp = "=" // reset op when switching type
                            } else if (!isNumberField(currentField) && isNumberField(initialField)) {
                                chipRoot.currentOp = "="
                            }
                            chipRoot.currentVal = ""
                            chipRoot.currentLabel = ""
                            fieldPopup.close()
                            emitChange()
                        }
                    }
                }
            }
        }
        

        Rectangle {
            width: 1
            height: 20
            color: "#666"
        }
        // Operator Selector
        Item {
            id: operatorSelector
            objectName: "advOpSelector"
            width: maxOpWidth
            height: 30

            Row {
                id: opTextRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: getOpText(chipRoot.currentOp)
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: "▾"
                    color: "white"
                    font.pixelSize: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: operatorPopup.open()
            }

            Popup {
                id: operatorPopup
                y: operatorSelector.height
                width: Math.max(operatorSelector.width, operatorListView.contentItem.childrenRect.width + 20)
                height: Math.min(300, operatorListView.contentHeight)
                padding: 0
                background: Rectangle {
                    color: "black"
                    border.color: "#555"
                    radius: 4
                }
                
                ListView {
                    id: operatorListView
                    objectName: "advOpListView"
                    anchors.fill: parent
                    clip: true
                    model: getOpModel()
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 10000
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    
                    delegate: ItemDelegate {
                        objectName: "advOption_" + modelData.value
                        width: implicitWidth
                        height: 35
                        padding: 0
                        contentItem: Text {
                            text: modelData.text
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                            rightPadding: 10
                        }
                        background: Rectangle {
                            width: ListView.view ? ListView.view.width : 0
                            height: 35
                            color: parent.hovered ? "#333" : "black"
                        }
                        onClicked: {
                            chipRoot.currentOp = modelData.value
                            operatorPopup.close()
                            emitChange()
                        }
                    }
                }
            }
        }
        

        Rectangle {
            width: 1
            height: 20
            color: "#666"
            visible: !chipRoot.isBoolean
        }
        // Value Input
        TextField {
            id: valueInput
            objectName: "advValueInput"
            visible: !isDropdownField(chipRoot.currentField) && !chipRoot.isBoolean
            placeholderText: "Value..."
            placeholderTextColor: "#aaa"
            color: "white"
            font.pixelSize: 14
            font.bold: true
            background: Rectangle {
                color: "transparent"
            }
            implicitWidth: Math.max(60, contentWidth + 20)
            leftPadding: 5
            rightPadding: 5
            text: chipRoot.currentVal
            onTextChanged: {
                if (visible && chipRoot.currentVal !== text) {
                    chipRoot.currentVal = text;
                    chipRoot.currentLabel = text;
                    emitChange();
                }
            }
        }
        
        Rectangle {
            width: 1
            height: 20
            color: "#666"
            visible: isDropdownField(chipRoot.currentField)
        }

        // Value Dropdown
        Item {
            id: valueSelector
            objectName: "advValueSelector"
            visible: isDropdownField(chipRoot.currentField)
            width: Math.max(valTextRow.implicitWidth + 10, chipRoot.maxValueFieldWidth)
            height: 30

            Row {
                id: valTextRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: chipRoot.currentVal !== "" ? chipRoot.currentLabel : "Select..."
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: "▾"
                    color: "white"
                    font.pixelSize: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    valuePopup.open()
                    if (appCtrl && appCtrl.currentLibraryId !== "") {
                        var endpoint = "/library/sections/" + appCtrl.currentLibraryId + "/" + chipRoot.currentField
                        var params = []
                        if (appCtrl.currentLibraryType === "show") {
                            params.push("type=2")
                        } else {
                            params.push("type=1")
                        }
                        if (params.length > 0) {
                            endpoint += "?" + params.join("&")
                        }
                        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : (appCtrl.connectionManager.activeUrl !== "" ? appCtrl.connectionManager.activeUrl : appSet.serverUrl);
                        var token = appCtrl.currentServerToken !== "" ? appCtrl.currentServerToken : (appSet ? appSet.token : "");
                    filterOptionsModel.fetchEndpoint(url, token, endpoint)
                    }
                }
            }

            Popup {
                id: valuePopup
                y: valueSelector.height
                width: chipRoot.maxValuePopupWidth
                height: Math.min(300, valueListView.contentHeight)
                padding: 0
                background: Rectangle {
                    color: "black"
                    border.color: "#555"
                    radius: 4
                }
                
                ListView {
                    id: valueListView
                    objectName: "advValueListView"
                    anchors.fill: parent
                    clip: true
                    model: filterOptionsModel
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 100000
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    
                    delegate: ItemDelegate {
                        objectName: "advValueOption_" + index
                        width: implicitWidth
                        height: 35
                        padding: 0
                        Component.onCompleted: {
                            if (implicitWidth + 20 > chipRoot.maxValuePopupWidth) {
                                chipRoot.maxValuePopupWidth = implicitWidth + 20
                            }
                        }
                        onImplicitWidthChanged: {
                            if (implicitWidth + 20 > chipRoot.maxValuePopupWidth) {
                                chipRoot.maxValuePopupWidth = implicitWidth + 20
                            }
                        }
                        contentItem: Text {
                            text: model.title !== undefined ? model.title : ""
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                            rightPadding: 10
                        }
                        background: Rectangle {
                            width: ListView.view ? ListView.view.width : 0
                            height: 35
                            color: parent.hovered ? "#333" : "black"
                        }
                        onClicked: {
                            var val = model.ratingKey !== undefined ? model.ratingKey : ""
                            var lbl = model.title !== undefined ? model.title : ""
                            
                            chipRoot.currentVal = val
                            chipRoot.currentLabel = lbl
                            valuePopup.close()
                            emitChange()
                        }
                    }
                }
            }
        }
        
        // Remove Button
        Text {
            text: "✕"
            color: "white"
            font.pixelSize: 14
            font.bold: true
            MouseArea {
                objectName: "advRemoveArea"
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: chipRoot.removeClicked()
            }
        }
    }
}
