pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Fake "minimize": windows sent to special:minimized (Super+H) are listed here
 * and can be restored to the workspace they came from.
 * Super+H toggles: minimizes the focused window, or restores the last minimized
 * one when nothing is focused. Super+Shift+H always restores the last one.
 */
Singleton {
    id: root

    readonly property string specialName: "special:minimized"
    // address -> workspace id the window was on before minimizing
    property var origins: ({})
    // addresses in the order they were minimized (last = most recent)
    property var order: []
    property string activeAddress: ""
    readonly property var windows: HyprlandData.windowList.filter(w => w.workspace?.name === root.specialName)

    function minimize(address) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${root.specialName}", follow = false, window = "address:${address}" })`);
    }

    function restore(address) {
        const target = root.origins[address] ?? HyprlandData.activeWorkspace?.id ?? 1;
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${target}, follow = true, window = "address:${address}" })`);
        Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`);
        delete root.origins[address];
        root.order = root.order.filter(a => a !== address);
    }

    function restoreLast() {
        const minimized = root.windows.map(w => w.address);
        // Most recently minimized first, then anything we lost track of (e.g. after a reload)
        const last = root.order.slice().reverse().find(a => minimized.includes(a)) ?? minimized[minimized.length - 1];
        if (last) root.restore(last);
    }

    function toggle() {
        const win = HyprlandData.windowByAddress[root.activeAddress];
        if (win?.workspace?.name === root.specialName) root.restore(win.address);
        else if (win && win.workspace?.id > 0) root.minimize(win.address);
        else root.restoreLast();
    }

    GlobalShortcut {
        name: "minimizeToggle"
        description: "Minimize focused window, or restore the last minimized one"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        name: "minimizeRestoreLast"
        description: "Restore the last minimized window"
        onPressed: root.restoreLast()
    }

    Process {
        running: true
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: activeCollector
            onStreamFinished: {
                try {
                    root.activeAddress = JSON.parse(activeCollector.text).address ?? "";
                } catch (e) {
                    root.activeAddress = "";
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // activewindowv2>>ADDRESS (address without 0x, empty when nothing is focused)
            if (event.name === "activewindowv2") {
                root.activeAddress = event.data ? `0x${event.data}` : "";
                return;
            }
            // movewindowv2>>ADDRESS,WORKSPACEID,WORKSPACENAME
            if (event.name !== "movewindowv2") return;
            const parts = event.data.split(",");
            if (parts.slice(2).join(",") !== root.specialName) return;
            const address = `0x${parts[0]}`;
            // HyprlandData hasn't refreshed yet, so this is still the old workspace
            const oldWorkspace = HyprlandData.windowByAddress[address]?.workspace;
            if (oldWorkspace && oldWorkspace.id > 0) root.origins[address] = oldWorkspace.id;
            root.order = root.order.filter(a => a !== address).concat([address]);
        }
    }
}
