import qs
import qs.services
import qs.modules.common
import QtQuick

// Barras do cava na base da tela (atrás das janelas). Some quando nada está tocando.
Item {
    id: root

    readonly property var points: Cava.points
    readonly property int barCount: points.length
    readonly property real gap: 6
    readonly property real barWidth: barCount > 0 ? (width - gap * (barCount + 1)) / barCount : 0

    opacity: Cava.desktopActive && barCount > 0 ? Config.options.background.widgets.visualizer.opacity : 0
    visible: opacity > 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Repeater {
        model: root.barCount
        Rectangle {
            required property int index
            readonly property real value: Math.min(1, (root.points[index] ?? 0) / 1000)
            x: root.gap + index * (root.barWidth + root.gap)
            y: root.height - height
            width: root.barWidth
            height: Math.max(4, value * root.height)
            topLeftRadius: Math.min(width / 2, 6)
            topRightRadius: Math.min(width / 2, 6)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Appearance.colors.colTertiary
                }
                GradientStop {
                    position: 1
                    color: Appearance.colors.colPrimary
                }
            }
        }
    }
}
