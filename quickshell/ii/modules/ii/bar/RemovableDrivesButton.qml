import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// USB icon shown while a pen drive / external disk is plugged in; click for mount/open/eject (Plasma-style)
RippleButton {
    id: root
    visible: RemovableDrives.drives.length > 0
    implicitWidth: 30
    implicitHeight: 30
    buttonRadius: Appearance.rounding.full
    toggled: popup.open
    property real lastClosed: 0

    onClicked: {
        if (!popup.open && Date.now() - root.lastClosed < 300) return;
        popup.open = !popup.open;
    }

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        text: "usb"
        iconSize: Appearance.font.pixelSize.larger
        color: root.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0
    }

    StyledToolTip {
        text: "Dispositivos removíveis"
        extraVisibleCondition: !popup.open
    }

    Loader {
        id: popup
        property bool open: false
        active: open && RemovableDrives.drives.length > 0

        sourceComponent: PopupWindow {
            id: popupWindow
            visible: true
            color: "transparent"

            anchor {
                item: root
                adjustment: PopupAdjustment.SlideX | PopupAdjustment.ResizeY
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }

            implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2 + 8

            HyprlandFocusGrab {
                active: true
                windows: [popupWindow]
                onCleared: {
                    root.lastClosed = Date.now();
                    popup.open = false;
                }
            }

            StyledRectangularShadow {
                target: background
            }

            Rectangle {
                id: background
                readonly property real padding: 14
                anchors {
                    fill: parent
                    margins: Appearance.sizes.elevationMargin
                    topMargin: Appearance.sizes.elevationMargin + (Config.options.bar.bottom ? 0 : 8)
                    bottomMargin: Appearance.sizes.elevationMargin + (Config.options.bar.bottom ? 8 : 0)
                }
                implicitWidth: Math.max(320, content.implicitWidth + padding * 2)
                implicitHeight: content.implicitHeight + padding * 2
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                ColumnLayout {
                    id: content
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: background.padding
                    }
                    spacing: 10

                    StyledText {
                        text: "Dispositivos removíveis"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }

                    Repeater {
                        model: RemovableDrives.drives

                        delegate: ColumnLayout {
                            id: driveItem
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                MaterialSymbol {
                                    text: "hard_drive"
                                    iconSize: Appearance.font.pixelSize.huge
                                    color: Appearance.colors.colOnLayer1
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: driveItem.modelData.title
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledText {
                                        text: driveItem.modelData.size
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                                DialogButton {
                                    buttonText: RemovableDrives.busy ? "Ejetando…" : "Ejetar"
                                    enabled: !RemovableDrives.busy
                                    onClicked: RemovableDrives.eject(driveItem.modelData)
                                }
                            }

                            Repeater {
                                model: driveItem.modelData.partitions

                                delegate: RowLayout {
                                    id: partItem
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 30
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        StyledText {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: `${partItem.modelData.label} · ${partItem.modelData.size}`
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            elide: Text.ElideMiddle
                                            text: partItem.modelData.mountpoint || "Não montado"
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }
                                    }
                                    DialogButton {
                                        buttonText: partItem.modelData.mountpoint ? "Abrir" : "Montar"
                                        onClicked: {
                                            if (partItem.modelData.mountpoint) {
                                                RemovableDrives.open(partItem.modelData.mountpoint);
                                                popup.open = false;
                                            } else {
                                                RemovableDrives.mount(partItem.modelData.path);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
