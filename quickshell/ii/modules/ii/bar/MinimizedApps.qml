import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Icons of windows minimized with Super+H; click one to restore it
RowLayout {
    id: root
    spacing: 2
    visible: MinimizedWindows.windows.length > 0

    Repeater {
        model: MinimizedWindows.windows

        delegate: RippleButton {
            id: button
            required property var modelData
            implicitWidth: 26
            implicitHeight: 26
            buttonRadius: Appearance.rounding.full
            onClicked: MinimizedWindows.restore(button.modelData.address)

            contentItem: AppIcon {
                anchors.centerIn: parent
                implicitSize: 18
                opacity: 0.6
                source: Quickshell.iconPath(AppSearch.guessIcon(button.modelData.class), "application-x-executable")
            }

            StyledToolTip {
                text: button.modelData.title
            }
        }
    }
}
