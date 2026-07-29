import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import flex.plex 1.0

ColumnLayout {
    id: root
    objectName: "libraryBrowserView"


    
    property var appCtrl: typeof mainWindow !== "undefined" ? mainWindow.controller : (typeof rootApp !== "undefined" ? appCtrl : null)
    property var appSet: typeof mainWindow !== "undefined" ? mainWindow.appSettings : (typeof rootApp !== "undefined" ? appSet : null)

    property bool unwatchedFilterActive: false
    property bool hdrFilterActive: false
    property bool doviFilterActive: false
    property bool atmosFilterActive: false
    property bool inProgressFilterActive: false
    property bool unmatchedFilterActive: false
    property bool duplicatesFilterActive: false

    property string genreFilterValue: ""
    property string yearFilterValue: ""
    property string decadeFilterValue: ""
    property string contentRatingFilterValue: ""
    property string collectionFilterValue: ""
    property string directorFilterValue: ""
    property string actorFilterValue: ""
    property string writerFilterValue: ""
    property string producerFilterValue: ""
    property string countryFilterValue: ""
    property string studioFilterValue: ""
    property string resolutionFilterValue: ""
    property string videoCodecFilterValue: ""
    property string audioCodecFilterValue: ""
    property string subtitleCodecFilterValue: ""
    property string audioLayoutFilterValue: ""
    property string audioLanguageFilterValue: ""
    property string subtitleLanguageFilterValue: ""
    property string editionTitleFilterValue: ""
    property string labelFilterValue: ""

    property bool genreFilterAdded: false
    property bool yearFilterAdded: false
    property bool decadeFilterAdded: false
    property bool contentRatingFilterAdded: false
    property bool collectionFilterAdded: false
    property bool directorFilterAdded: false
    property bool actorFilterAdded: false
    property bool writerFilterAdded: false
    property bool producerFilterAdded: false
    property bool countryFilterAdded: false
    property bool studioFilterAdded: false
    property bool resolutionFilterAdded: false
    property bool videoCodecFilterAdded: false
    property bool audioCodecFilterAdded: false
    property bool subtitleCodecFilterAdded: false
    property bool audioLayoutFilterAdded: false
    property bool audioLanguageFilterAdded: false
    property bool subtitleLanguageFilterAdded: false
    property bool editionTitleFilterAdded: false
    property bool labelFilterAdded: false

    ListModel {
        id: advancedFiltersModel
    }
    
    Item {
        id: internalState
        function doApply() { applyFilters() }
    }

    Connections {
        target: appCtrl
        function onCurrentLibraryIdChanged() {
            if (root.visible) {
                applyFilters()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            applyFilters()
        }
    }

    spacing: 15

    // Top Filter Bar
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: filterColumn.implicitHeight
        Layout.margins: 20
        color: "transparent"
        clip: true

        Column {
            id: filterColumn
            width: parent.width
            spacing: 15

            Flow {
                id: fixedFilterRow
                width: parent.width
                spacing: 10

                FixedFilterChip {
                    objectName: "unwatchedFilterChip"
                    text: "Unwatched"
                    active: root.unwatchedFilterActive
                    onClicked: { root.unwatchedFilterActive = !root.unwatchedFilterActive; applyFilters() }
                }
                FixedFilterChip {
                    objectName: "inProgressFilterChip"
                    text: "In Progress"
                    active: root.inProgressFilterActive
                    onClicked: { root.inProgressFilterActive = !root.inProgressFilterActive; applyFilters() }
                }
                FixedFilterChip {
                    objectName: "hdrFilterChip"
                    text: "HDR"
                    active: root.hdrFilterActive
                    onClicked: { root.hdrFilterActive = !root.hdrFilterActive; applyFilters() }
                }
                FixedFilterChip {
                    objectName: "doviFilterChip"
                    text: "DOVI"
                    active: root.doviFilterActive
                    onClicked: { root.doviFilterActive = !root.doviFilterActive; applyFilters() }
                }
                FixedFilterChip {
                    objectName: "atmosFilterChip"
                    text: "Atmos"
                    active: root.atmosFilterActive
                    onClicked: { root.atmosFilterActive = !root.atmosFilterActive; applyFilters() }
                }
                FixedFilterChip {
                    objectName: "unmatchedFilterChip"
                    text: "Unmatched"
                    active: root.unmatchedFilterActive
                    onClicked: { root.unmatchedFilterActive = !root.unmatchedFilterActive; applyFilters() }
                }
                FixedFilterChip {
                    objectName: "duplicatesFilterChip"
                    text: "Duplicates"
                    active: root.duplicatesFilterActive
                    onClicked: { root.duplicatesFilterActive = !root.duplicatesFilterActive; applyFilters() }
                }

                Rectangle {
                    id: addFilterBtn
                    objectName: "addFilterBtn"
                    height: 32
                    width: addFilterRow.width + 30
                    radius: 16
                    color: "transparent"
                    border.color: "#555"
                    border.width: 1
                    
                    RowLayout {
                        id: addFilterRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "Add Filter"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: "➕"
                            color: "white"
                            font.pixelSize: 14
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addFilterPopup.open()
                    }
                    
                    Popup {
                        id: addFilterPopup
                        y: addFilterBtn.height + 5
                        width: Math.max(200, availableFiltersList.contentItem.childrenRect.width + 20)
                        height: Math.min(420, addFilterContentLayout.implicitHeight + 20)
                        padding: 0
                        background: Rectangle {
                            color: "#222"
                            border.color: "#555"
                            radius: 8
                        }
                        
                        ColumnLayout {
                            id: addFilterContentLayout
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 0
                            
                            ListView {
                                id: availableFiltersList
                                Layout.fillWidth: true
                                Layout.preferredHeight: contentHeight > 0 ? Math.min(contentHeight, 400) : 0
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar {
                                    active: parent.hovered || parent.moving
                                    policy: ScrollBar.AsNeeded
                                }
                                    model: ListModel {
                                        id: availableFiltersModel
                                        ListElement { name: "Genre"; propKey: "genre" }
                                        ListElement { name: "Year"; propKey: "year" }
                                        ListElement { name: "Decade"; propKey: "decade" }
                                        ListElement { name: "Content Rating"; propKey: "contentRating" }
                                        ListElement { name: "Collection"; propKey: "collection" }
                                        ListElement { name: "Director"; propKey: "director" }
                                        ListElement { name: "Actor"; propKey: "actor" }
                                        ListElement { name: "Writer"; propKey: "writer" }
                                        ListElement { name: "Producer"; propKey: "producer" }
                                        ListElement { name: "Country"; propKey: "country" }
                                        ListElement { name: "Studio"; propKey: "studio" }
                                        ListElement { name: "Resolution"; propKey: "resolution" }
                                        ListElement { name: "Video Codec"; propKey: "videoCodec" }
                                        ListElement { name: "Audio Codec"; propKey: "audioCodec" }
                                        ListElement { name: "Subtitle Codec"; propKey: "subtitleCodec" }
                                        ListElement { name: "Audio Layout"; propKey: "audioLayout" }
                                        ListElement { name: "Audio Language"; propKey: "audioLanguage" }
                                        ListElement { name: "Subtitle Language"; propKey: "subtitleLanguage" }
                                        ListElement { name: "Edition"; propKey: "editionTitle" }
                                        ListElement { name: "Labels"; propKey: "label" }
                                    }
                                    
                                    delegate: ItemDelegate {
                                        width: implicitWidth
                                        height: visible ? 40 : 0
                                        visible: !root[model.propKey + "FilterAdded"]
                                        text: model.name
                                        
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            verticalAlignment: Text.AlignVCenter
                                            rightPadding: 10
                                        }
                                        background: Rectangle {
                                            width: ListView.view ? ListView.view.width : 0
                                            height: visible ? 40 : 0
                                            color: parent.hovered ? "#444" : "transparent"
                                        }
                                        onClicked: {
                                            root[model.propKey + "FilterAdded"] = true;
                                            addFilterPopup.close();
                                        }
                                    }
                                }
                        }
                    }
                }
                Rectangle {
                    id: addAdvancedFilterBtn
                    objectName: "addAdvancedFilterBtn"
                    height: 32
                    width: addAdvancedFilterRow.implicitWidth + 30
                    radius: 16
                    color: "transparent"
                    border.color: "#555"
                    border.width: 1
                    
                    RowLayout {
                        id: addAdvancedFilterRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "Advanced"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: "➕"
                            color: "white"
                            font.pixelSize: 14
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: advancedFiltersModel.append({fieldKey: "title", operatorModifier: "=", filterValue: ""})
                    }
                }
                
            } // End fixedFilterRow

            Flow {
                id: valueFilterRow
                width: parent.width
                spacing: 10
                visible: childrenRect.height > 0

                ValueFilterChip { objectName: "genreFilterChip"; text: "Genre"; filterType: "genre"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.genreFilterAdded; selectedValue: root.genreFilterValue; onValueSelected: function(val) { root.genreFilterValue = val; applyFilters() }; onRemoveClicked: { root.genreFilterAdded = false; root.genreFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "yearFilterChip"; text: "Year"; filterType: "year"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.yearFilterAdded; selectedValue: root.yearFilterValue; onValueSelected: function(val) { root.yearFilterValue = val; applyFilters() }; onRemoveClicked: { root.yearFilterAdded = false; root.yearFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "decadeFilterChip"; text: "Decade"; filterType: "decade"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.decadeFilterAdded; selectedValue: root.decadeFilterValue; onValueSelected: function(val) { root.decadeFilterValue = val; applyFilters() }; onRemoveClicked: { root.decadeFilterAdded = false; root.decadeFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "contentRatingFilterChip"; text: "Content Rating"; filterType: "contentRating"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.contentRatingFilterAdded; selectedValue: root.contentRatingFilterValue; onValueSelected: function(val) { root.contentRatingFilterValue = val; applyFilters() }; onRemoveClicked: { root.contentRatingFilterAdded = false; root.contentRatingFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "collectionFilterChip"; text: "Collection"; filterType: "collection"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.collectionFilterAdded; selectedValue: root.collectionFilterValue; onValueSelected: function(val) { root.collectionFilterValue = val; applyFilters() }; onRemoveClicked: { root.collectionFilterAdded = false; root.collectionFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "directorFilterChip"; text: "Director"; filterType: "director"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.directorFilterAdded; selectedValue: root.directorFilterValue; onValueSelected: function(val) { root.directorFilterValue = val; applyFilters() }; onRemoveClicked: { root.directorFilterAdded = false; root.directorFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "actorFilterChip"; text: "Actor"; filterType: "actor"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.actorFilterAdded; selectedValue: root.actorFilterValue; onValueSelected: function(val) { root.actorFilterValue = val; applyFilters() }; onRemoveClicked: { root.actorFilterAdded = false; root.actorFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "writerFilterChip"; text: "Writer"; filterType: "writer"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.writerFilterAdded; selectedValue: root.writerFilterValue; onValueSelected: function(val) { root.writerFilterValue = val; applyFilters() }; onRemoveClicked: { root.writerFilterAdded = false; root.writerFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "producerFilterChip"; text: "Producer"; filterType: "producer"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.producerFilterAdded; selectedValue: root.producerFilterValue; onValueSelected: function(val) { root.producerFilterValue = val; applyFilters() }; onRemoveClicked: { root.producerFilterAdded = false; root.producerFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "countryFilterChip"; text: "Country"; filterType: "country"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.countryFilterAdded; selectedValue: root.countryFilterValue; onValueSelected: function(val) { root.countryFilterValue = val; applyFilters() }; onRemoveClicked: { root.countryFilterAdded = false; root.countryFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "studioFilterChip"; text: "Studio"; filterType: "studio"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.studioFilterAdded; selectedValue: root.studioFilterValue; onValueSelected: function(val) { root.studioFilterValue = val; applyFilters() }; onRemoveClicked: { root.studioFilterAdded = false; root.studioFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "resolutionFilterChip"; text: "Resolution"; filterType: "resolution"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.resolutionFilterAdded; selectedValue: root.resolutionFilterValue; onValueSelected: function(val) { root.resolutionFilterValue = val; applyFilters() }; onRemoveClicked: { root.resolutionFilterAdded = false; root.resolutionFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "videoCodecFilterChip"; text: "Video Codec"; filterType: "videoCodec"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.videoCodecFilterAdded; selectedValue: root.videoCodecFilterValue; onValueSelected: function(val) { root.videoCodecFilterValue = val; applyFilters() }; onRemoveClicked: { root.videoCodecFilterAdded = false; root.videoCodecFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "audioCodecFilterChip"; text: "Audio Codec"; filterType: "audioCodec"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.audioCodecFilterAdded; selectedValue: root.audioCodecFilterValue; onValueSelected: function(val) { root.audioCodecFilterValue = val; applyFilters() }; onRemoveClicked: { root.audioCodecFilterAdded = false; root.audioCodecFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "subtitleCodecFilterChip"; text: "Subtitle Codec"; filterType: "subtitleCodec"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.subtitleCodecFilterAdded; selectedValue: root.subtitleCodecFilterValue; onValueSelected: function(val) { root.subtitleCodecFilterValue = val; applyFilters() }; onRemoveClicked: { root.subtitleCodecFilterAdded = false; root.subtitleCodecFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "audioLayoutFilterChip"; text: "Audio Layout"; filterType: "audioLayout"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.audioLayoutFilterAdded; selectedValue: root.audioLayoutFilterValue; onValueSelected: function(val) { root.audioLayoutFilterValue = val; applyFilters() }; onRemoveClicked: { root.audioLayoutFilterAdded = false; root.audioLayoutFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "audioLanguageFilterChip"; text: "Audio Language"; filterType: "audioLanguage"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.audioLanguageFilterAdded; selectedValue: root.audioLanguageFilterValue; onValueSelected: function(val) { root.audioLanguageFilterValue = val; applyFilters() }; onRemoveClicked: { root.audioLanguageFilterAdded = false; root.audioLanguageFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "subtitleLanguageFilterChip"; text: "Subtitle Language"; filterType: "subtitleLanguage"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.subtitleLanguageFilterAdded; selectedValue: root.subtitleLanguageFilterValue; onValueSelected: function(val) { root.subtitleLanguageFilterValue = val; applyFilters() }; onRemoveClicked: { root.subtitleLanguageFilterAdded = false; root.subtitleLanguageFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "editionTitleFilterChip"; text: "Edition"; filterType: "editionTitle"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.editionTitleFilterAdded; selectedValue: root.editionTitleFilterValue; onValueSelected: function(val) { root.editionTitleFilterValue = val; applyFilters() }; onRemoveClicked: { root.editionTitleFilterAdded = false; root.editionTitleFilterValue = ""; applyFilters() } }
                ValueFilterChip { objectName: "labelFilterChip"; text: "Labels"; filterType: "label"; appCtrl: root.appCtrl; appSet: root.appSet; isAdded: root.labelFilterAdded; selectedValue: root.labelFilterValue; onValueSelected: function(val) { root.labelFilterValue = val; applyFilters() }; onRemoveClicked: { root.labelFilterAdded = false; root.labelFilterValue = ""; applyFilters() } }

            } // End valueFilterRow



            Flow {
                id: advancedFilterRow
                width: parent.width
                function requestApply() { root.applyFilters() }
                spacing: 10
                visible: advancedFiltersModel.count > 0

                Repeater {
                    id: advancedFilterRepeater
                    model: advancedFiltersModel
                    delegate: AdvancedFilterChip {
                        appCtrl: root.appCtrl
                        appSet: root.appSet
                        initialField: model.fieldKey !== undefined ? model.fieldKey : "title"
                        initialOp: model.operatorModifier !== undefined ? model.operatorModifier : "="
                        initialVal: model.filterValue !== undefined ? model.filterValue : ""
                        onFilterChanged: function(fField, fOp, fVal, fLabel) {
                            parent.requestApply()
                        }
                        onRemoveClicked: {
                            var p = parent
                            advancedFiltersModel.remove(index)
                            p.requestApply()
                        }
                    }
                }
            } // End advancedFilterRow
        } // End filterColumn
    }

    // Grid View
    GridView {
        id: browserGrid
        objectName: "browserGrid"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 20
        cellWidth: 220
        cellHeight: 330
        clip: true
        
        model: appCtrl ? appCtrl.libraryAllModel : null
        
        delegate: MoviePosterDelegate {
            width: 200
            height: 300
            onPosterClicked: {
                if (appCtrl.currentLibraryType === "movie") {
                    typeof mainWindow !== 'undefined' ? mainWindow.openDetails(model.ratingKey) : rootApp.openDetails(model.ratingKey)
                } else if (appCtrl.currentLibraryType === "show") {
                    typeof mainWindow !== 'undefined' ? mainWindow.openShow(model.ratingKey) : rootApp.openShow(model.ratingKey)
                }
            }
        }
        
        ScrollBar.vertical: ScrollBar {
            active: hovered || browserGrid.moving
            policy: ScrollBar.AsNeeded
            background: Rectangle { color: "transparent" }
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: parent.active ? "#80ffffff" : "#40ffffff"
            }
        }
    }

    function applyFilters() {
        if (!appCtrl || !appCtrl.libraryAllModel) return;

        var fullEndpoint = "/library/sections/" + appCtrl.currentLibraryId + "/all"
        var params = []
        
        if (appCtrl.currentLibraryType === "show") {
            params.push("type=2")
        } else {
            params.push("type=1")
        }
        
        params.push("sort=addedAt:desc")
        
        if (root.unwatchedFilterActive) params.push("unwatched=1")
        if (root.hdrFilterActive) params.push("hdr=1")
        if (root.doviFilterActive) params.push("dovi=1")
        if (root.atmosFilterActive) params.push("atmos=1")
        if (root.inProgressFilterActive) params.push("inProgress=1")
        if (root.unmatchedFilterActive) params.push("unmatched=1")
        if (root.duplicatesFilterActive) params.push("duplicate=1")
        
        if (root.genreFilterValue !== "") params.push("genre=" + encodeURIComponent(root.genreFilterValue))
        if (root.yearFilterValue !== "") params.push("year=" + encodeURIComponent(root.yearFilterValue))
        if (root.decadeFilterValue !== "") params.push("decade=" + encodeURIComponent(root.decadeFilterValue))
        if (root.contentRatingFilterValue !== "") params.push("contentRating=" + encodeURIComponent(root.contentRatingFilterValue))
        if (root.collectionFilterValue !== "") params.push("collection=" + encodeURIComponent(root.collectionFilterValue))
        if (root.directorFilterValue !== "") params.push("director=" + encodeURIComponent(root.directorFilterValue))
        if (root.actorFilterValue !== "") params.push("actor=" + encodeURIComponent(root.actorFilterValue))
        if (root.writerFilterValue !== "") params.push("writer=" + encodeURIComponent(root.writerFilterValue))
        if (root.producerFilterValue !== "") params.push("producer=" + encodeURIComponent(root.producerFilterValue))
        if (root.countryFilterValue !== "") params.push("country=" + encodeURIComponent(root.countryFilterValue))
        if (root.studioFilterValue !== "") params.push("studio=" + encodeURIComponent(root.studioFilterValue))
        if (root.resolutionFilterValue !== "") params.push("resolution=" + encodeURIComponent(root.resolutionFilterValue))
        if (root.videoCodecFilterValue !== "") params.push("videoCodec=" + encodeURIComponent(root.videoCodecFilterValue))
        if (root.audioCodecFilterValue !== "") params.push("audioCodec=" + encodeURIComponent(root.audioCodecFilterValue))
        if (root.subtitleCodecFilterValue !== "") params.push("subtitleCodec=" + encodeURIComponent(root.subtitleCodecFilterValue))
        if (root.audioLayoutFilterValue !== "") params.push("audioLayout=" + encodeURIComponent(root.audioLayoutFilterValue))
        if (root.audioLanguageFilterValue !== "") params.push("audioLanguage=" + encodeURIComponent(root.audioLanguageFilterValue))
        if (root.subtitleLanguageFilterValue !== "") params.push("subtitleLanguage=" + encodeURIComponent(root.subtitleLanguageFilterValue))
        if (root.editionTitleFilterValue !== "") params.push("editionTitle=" + encodeURIComponent(root.editionTitleFilterValue))
        if (root.labelFilterValue !== "") params.push("label=" + encodeURIComponent(root.labelFilterValue))

        for (var i = 0; i < advancedFilterRepeater.count; i++) {
            var chip = advancedFilterRepeater.itemAt(i)
            if (chip && (chip.currentVal !== "" || chip.isBoolean)) {
                var valPart = chip.isBoolean ? "" : encodeURIComponent(chip.currentVal)
                var p = encodeURIComponent(chip.currentField) + chip.currentOp + valPart
                console.log("ADVANCED FILTER PUSHING: " + p)
                params.push(p)
            }
        }
        console.log("FULL PARAMS: " + params.join("&"))

        if (params.length > 0) {
            fullEndpoint += "?" + params.join("&")
        }

        var url = appCtrl.currentServerUrl !== "" ? appCtrl.currentServerUrl : (appCtrl.connectionManager.activeUrl !== "" ? appCtrl.connectionManager.activeUrl : appSet.serverUrl);
        
        if (appCtrl.libraryAllModel) {
            appCtrl.libraryAllModel.fetchEndpoint(url, appSet.token, fullEndpoint)
        }
    }
}
