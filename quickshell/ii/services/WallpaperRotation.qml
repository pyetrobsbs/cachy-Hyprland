pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Troca o wallpaper sozinho a cada N minutos (background.autoChange no config.json).
 * Usa um "baralho": passa por todas as imagens da pasta antes de repetir alguma.
 * A troca vai pelo mesmo caminho do seletor (Wallpapers.apply), então as cores do shell acompanham.
 */
Singleton {
    id: root

    readonly property var options: Config.options.background.autoChange
    readonly property string folder: {
        const f = FileUtils.trimFileProtocol(options.folder);
        if (f.length > 0)
            return f.replace(/^~/, FileUtils.trimFileProtocol(Directories.home));
        const current = Config.options.background.wallpaperPath;
        return current.substring(0, current.lastIndexOf("/")); // Pasta do wallpaper atual
    }
    property var deck: []

    function load() {} // Força a inicialização

    function next() {
        listProc.running = false;
        listProc.running = true;
    }

    function pickFrom(files) {
        if (files.length === 0)
            return;
        const current = Config.options.background.wallpaperPath;
        // Remove do baralho o que sumiu da pasta; embaralha de novo quando acabar
        let deck = root.deck.filter(f => files.includes(f));
        if (deck.length === 0) {
            deck = files.filter(f => f !== current || files.length === 1);
            for (let i = deck.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [deck[i], deck[j]] = [deck[j], deck[i]];
            }
        }
        const chosen = deck.shift();
        root.deck = deck;
        console.log(`[WallpaperRotation] ${chosen} (${deck.length} restantes no baralho)`);
        Wallpapers.apply(chosen);
    }

    Timer {
        running: root.options.enable && Config.ready
        repeat: true
        interval: Math.max(1, root.options.intervalMinutes) * 60 * 1000
        onTriggered: {
            if (GlobalStates.screenLocked)
                return;
            root.next();
        }
    }

    Process {
        id: listProc
        command: ["find", root.folder, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.pickFrom(text.split("\n").filter(l => l.length > 0))
        }
    }

    IpcHandler {
        target: "wallpaperRotation"

        function next(): void {
            root.next();
        }
        function toggle(): void {
            Config.options.background.autoChange.enable = !Config.options.background.autoChange.enable;
        }
    }
}
