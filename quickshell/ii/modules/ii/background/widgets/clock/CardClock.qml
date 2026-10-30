pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Relógio em card: "09:04 │ OUTUBRO / 27 / Terça" (estilo "card")
Item {
    id: root
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property date now: DateTime.clock.date
    function capitalize(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        implicitWidth: row.implicitWidth + 28 * 2
        implicitHeight: row.implicitHeight + 18 * 2
        radius: Appearance.rounding.normal
        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.05)
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 18

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: Qt.locale().toString(root.now, "hh:mm")
                color: Appearance.colors.colOnLayer0
                font.family: Appearance.font.family.numbers
                font.pixelSize: 54
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                implicitWidth: 2
                radius: 1
                color: Appearance.colors.colOutlineVariant
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                StyledText {
                    text: Qt.locale().toString(root.now, "MMMM").toUpperCase()
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
                StyledText {
                    text: Qt.locale().toString(root.now, "dd")
                    color: Appearance.colors.colOnLayer0
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: root.capitalize(Qt.locale().toString(root.now, "dddd"))
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }
}
