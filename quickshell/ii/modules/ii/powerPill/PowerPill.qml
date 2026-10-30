pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Menu de energia em pílula que desce de baixo da barra (Super+Esc).
 * Setas/1-5 escolhem, Enter confirma, Esc fecha.
 * Sair/Reiniciar/Desligar pedem um segundo clique para confirmar.
 */
Scope {
    id: root

    readonly property var actions: [
        { icon: "lock", label: "Bloquear", confirm: false, run: () => Session.lock() },
        { icon: "dark_mode", label: "Suspender", confirm: false, run: () => Session.suspend() },
        { icon: "logout", label: "Sair", confirm: true, run: () => Session.logout() },
        { icon: "restart_alt", label: "Reiniciar", confirm: true, run: () => Session.reboot() },
        { icon: "power_settings_new", label: "Desligar", confirm: true, run: () => Session.poweroff() },
    ]
    property int selected: 0
    property int armed: -1 // ação esperando o clique de confirmação
    property var targetScreen: null

    function trigger(index) {
        const action = root.actions[index];
        root.selected = index;
        if (action.confirm && root.armed !== index) {
            root.armed = index;
            return;
        }
        GlobalStates.powerPillOpen = false;
        action.run();
    }

    Connections {
        target: GlobalStates
        function onPowerPillOpenChanged() {
            if (!GlobalStates.powerPillOpen)
                return;
            const name = Hyprland.focusedMonitor?.name;
            root.targetScreen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
            root.selected = 0;
            root.armed = -1;
        }
    }

    Loader {
        active: GlobalStates.powerPillOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            screen: root.targetScreen
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:powerPill"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            margins.top: Appearance.sizes.barHeight + 4
            implicitWidth: pill.implicitWidth + 40
            implicitHeight: pill.implicitHeight + 40

            Component.onCompleted: GlobalFocusGrab.addDismissable(panelWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.powerPillOpen = false;
                }
            }

            StyledRectangularShadow {
                target: pill
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                implicitWidth: content.implicitWidth + 28
                implicitHeight: content.implicitHeight + 24
                radius: 26
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                focus: true

                // Desce de baixo da barra
                opacity: 0
                transform: Translate {
                    id: slide
                    y: -24
                }
                Component.onCompleted: appear.start()
                ParallelAnimation {
                    id: appear
                    NumberAnimation {
                        target: pill
                        property: "opacity"
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: slide
                        property: "y"
                        to: 0
                        duration: 260
                        easing.type: Easing.OutBack
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.powerPillOpen = false;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                        root.selected = (root.selected + root.actions.length - 1) % root.actions.length;
                        root.armed = -1;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.selected = (root.selected + 1) % root.actions.length;
                        root.armed = -1;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.trigger(root.selected);
                    } else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.actions.length) {
                        root.trigger(event.key - Qt.Key_1);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                ColumnLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 8

                    RowLayout { // Cabeçalho
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Rectangle {
                            implicitWidth: 7
                            implicitHeight: 7
                            radius: 4
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.armed >= 0 ? `CLIQUE DE NOVO PARA ${root.actions[root.armed].label.toUpperCase()}` : "SESSÃO // ENERGIA"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: root.armed >= 0 ? Appearance.colors.colError : Appearance.colors.colPrimary
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: root.actions.length
                            RippleButton {
                                id: actionButton
                                required property int index
                                readonly property var act: root.actions[index]
                                readonly property bool isSelected: root.selected === index
                                readonly property bool isArmed: root.armed === index
                                implicitWidth: 118
                                implicitHeight: 52
                                buttonRadius: 16
                                colBackground: isArmed ? Appearance.colors.colErrorContainer : isSelected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer1
                                colBackgroundHover: isArmed ? Appearance.colors.colErrorContainerHover : Appearance.colors.colSecondaryContainerHover
                                colRipple: isArmed ? Appearance.colors.colErrorContainerActive : Appearance.colors.colSecondaryContainerActive
                                onHoveredChanged: if (hovered && root.armed !== index) root.selected = index
                                onClicked: root.trigger(index)

                                Rectangle { // Contorno da opção selecionada
                                    anchors.fill: parent
                                    radius: actionButton.buttonRadius
                                    color: "transparent"
                                    border.width: actionButton.isSelected ? 2 : 0
                                    border.color: actionButton.isArmed ? Appearance.colors.colError : Appearance.colors.colPrimary
                                }

                                contentItem: RowLayout {
                                    spacing: 8
                                    readonly property color colFg: actionButton.isArmed ? Appearance.colors.colOnErrorContainer : actionButton.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    MaterialSymbol {
                                        Layout.leftMargin: 4
                                        text: actionButton.act.icon
                                        iconSize: Appearance.font.pixelSize.huge
                                        fill: actionButton.isSelected ? 1 : 0
                                        color: parent.colFg
                                    }
                                    ColumnLayout {
                                        spacing: -2
                                        StyledText {
                                            text: actionButton.act.label
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.DemiBold
                                            color: parent.parent.colFg
                                        }
                                        StyledText {
                                            text: `[${actionButton.index + 1}]`
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "powerPill"

        function toggle(): void {
            GlobalStates.powerPillOpen = !GlobalStates.powerPillOpen;
        }
        function open(): void {
            GlobalStates.powerPillOpen = true;
        }
        function close(): void {
            GlobalStates.powerPillOpen = false;
        }
    }

    GlobalShortcut {
        name: "powerPillToggle"
        description: "Abre/fecha o menu de energia em pílula"
        onPressed: GlobalStates.powerPillOpen = !GlobalStates.powerPillOpen
    }
}
