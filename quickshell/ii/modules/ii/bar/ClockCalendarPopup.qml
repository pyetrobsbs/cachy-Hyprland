import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.calendar
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Calendar popup opened by clicking the bar clock (Windows/Plasma style)
Loader {
    id: root

    property Item anchorItem: parent
    property bool open: false
    property real visualMargin: 8
    // Timestamp of the last focus-loss close, so the same click on the clock doesn't reopen it
    property real lastClosed: 0

    function toggle() {
        if (!root.open && Date.now() - root.lastClosed < 300) return;
        root.open = !root.open;
    }

    active: root.open

    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true
        color: "transparent"

        anchor {
            item: root.anchorItem
            adjustment: PopupAdjustment.SlideX | PopupAdjustment.ResizeY
            edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
        }

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.visualMargin

        HyprlandFocusGrab {
            active: true
            windows: [popupWindow]
            onCleared: {
                root.lastClosed = Date.now();
                root.open = false;
            }
        }

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real padding: 14
            anchors {
                fill: parent
                margins: Appearance.sizes.elevationMargin
                topMargin: Appearance.sizes.elevationMargin + (Config.options.bar.bottom ? 0 : root.visualMargin)
                bottomMargin: Appearance.sizes.elevationMargin + (Config.options.bar.bottom ? root.visualMargin : 0)
            }
            implicitWidth: contentColumn.implicitWidth + padding * 2
            implicitHeight: contentColumn.implicitHeight + padding * 2
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: contentColumn
                anchors.centerIn: parent
                spacing: 2

                StyledText {
                    Layout.leftMargin: 6
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.5
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                    text: DateTime.time
                }

                StyledText {
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 4
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                    text: DateTime.clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                CalendarWidget {
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
