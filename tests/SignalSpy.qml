import QtQuick
import QtTest

Item {
    property var target: null
    property string signalName: ""
    property int count: 0
    property var signalArguments: []

    onTargetChanged: updateConnection()
    onSignalNameChanged: updateConnection()

    function updateConnection() {
        if (target && signalName) {
            var signal = target[signalName]
            if (signal) {
                signal.connect(function() {
                    count++
                    signalArguments.push(Array.prototype.slice.call(arguments))
                })
            }
        }
    }
}

