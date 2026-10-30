pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Um único processo cava para o player de música e para as barras da área de trabalho.
 * Só roda quando alguém está mostrando as barras.
 * points: 64 valores de 0 a 1000
 */
Singleton {
    id: root

    readonly property bool desktopActive: Config.options.background.widgets.visualizer.enable
        && MprisController.isPlaying && !GlobalStates.screenLocked
    readonly property bool active: desktopActive || GlobalStates.musicPlayerOpen
    property list<real> points: []

    Process {
        running: root.active
        onRunningChanged: if (!running) root.points = []
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/shared_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
            }
        }
    }
}
