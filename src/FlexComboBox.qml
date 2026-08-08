/*
 * FlexComboBox.qml
 *
 * CRITICAL ARCHITECTURE NOTE (August 2026):
 * This component MUST inherit from `QtQuick.Controls.Basic` (specifically `Basic.ComboBox`, 
 * `Basic.Popup`, and `Basic.ItemDelegate`). 
 *
 * DO NOT use the standard `import QtQuick.Controls` for this custom component.
 *
 * History & Rationale:
 * We encountered a severe "black text on black background" rendering bug when running 
 * Flex Player on Linux desktop environments (specifically KDE Plasma). When using the standard 
 * `QtQuick.Controls`, KDE injects its own heavily customized, OS-themed QML files 
 * (e.g., `org.kde.desktop/ComboBox.qml`) in place of the base Qt components.
 *
 * This caused several cascading failures when trying to build a custom-themed UI:
 * 1. The KDE theme engine forcefully overrides the `palette` properties of `Popup` and 
 *    `ItemDelegate`, turning our custom yellow text into dark gray or black.
 * 2. Attempting to bypass the KDE `ItemDelegate` by replacing it with a pure QML `Rectangle` 
 *    resulted in a bizarre bug where the internal Javascript array bindings (`modelData`) 
 *    would silently evaluate to an empty string `""` for all unhighlighted items.
 * 3. The `Popup` component is actually a top-level OS window in Qt 6. If the ComboBox was 
 *    opened from a detached component (like `SettingsWindow`), it failed to inherit the 
 *    ApplicationWindow's global dark theme and fell back to the KDE System Theme.
 *
 * The Solution:
 * By explicitly importing `QtQuick.Controls.Basic`, we force Qt to use the pure, native, 
 * unstyled C++ implementation of the controls. This completely physically bypasses the 
 * operating system's theme engine (like KDE's `org.kde.desktop` hooks). 
 * 
 * As a result:
 * - JS string bindings (`modelData`) work flawlessly for all items.
 * - Backgrounds and text colors obey our exact QML bindings.
 * - We do not need ugly `palette.text` overrides or `Item` shielding wrappers.
 * - The component looks 100% identical on Windows, macOS, and all Linux distros.
 */
import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    background: Rectangle { color: "#222222"; radius: 4 }
    
    contentItem: Text { 
        text: control.currentText; color: "#E5A00D"; font.pixelSize: 16; 
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; leftPadding: 10; rightPadding: 30 
    }
    
    indicator: Canvas {
        x: control.width - width - 10
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 12; height: 8; contextType: "2d"
        Connections {
            target: control
            function onPressedChanged() { control.indicator.requestPaint() }
        }
        onPaint: {
            var context = getContext("2d");
            context.reset(); context.moveTo(0, 0); context.lineTo(width, 0); context.lineTo(width / 2, height); context.closePath();
            context.fillStyle = control.pressed ? "#aaaaaa" : "#E5A00D"; context.fill();
        }
    }
    
    popup: Popup {
        y: control.height - 1; width: control.width; implicitHeight: contentItem.implicitHeight; padding: 1
        contentItem: ListView {
            clip: true; implicitHeight: contentHeight; model: control.delegateModel
            currentIndex: control.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle { color: "#111111"; border.color: "#444444"; radius: 4 }
    }
    
    delegate: ItemDelegate {
        id: delegateItem
        width: ListView.view.width
        implicitHeight: 40
        highlighted: control.highlightedIndex === index
        
        onClicked: {
            control.currentIndex = index;
            if (control.activated) control.activated(index);
            control.popup.close();
        }
        
        contentItem: Text { 
            text: typeof modelData !== "undefined" ? modelData : control.textAt(index)
            color: delegateItem.highlighted ? "black" : "#E5A00D"
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter 
            leftPadding: 10
        }
        
        background: Rectangle { 
            color: delegateItem.highlighted ? "#E5A00D" : "transparent" 
        }
    }
}
