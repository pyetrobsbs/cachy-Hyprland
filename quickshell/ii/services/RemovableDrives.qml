pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * USB/hotplug drives (pen drives, external disks) with mount/open/eject actions.
 * Refreshed on udev block events, and periodically while a drive is present
 * (mounting doesn't emit udev events).
 */
Singleton {
    id: root

    // [{ name, path, size, title, partitions: [{ path, label, size, fstype, mountpoint }] }]
    property var drives: []
    property bool busy: false

    function refresh() {
        lsblkProc.running = true;
    }

    function driveTitle(dev) {
        // "Generic" is just the USB enclosure's vendor string, not useful
        const name = [dev.vendor, dev.model].map(s => (s ?? "").trim()).filter(s => s.length > 0 && s !== "Generic").join(" ");
        return name.length > 0 ? name : dev.name;
    }

    function mount(partPath) {
        Quickshell.execDetached(["bash", "-c",
            'udisksctl mount -b "$1" >/dev/null 2>/tmp/qs-udisks-err || notify-send -a Discos "Não foi possível montar" "$(cat /tmp/qs-udisks-err)"',
            "_", partPath]);
        refreshSoon.restart();
    }

    function open(mountpoint) {
        Quickshell.execDetached(["xdg-open", mountpoint]);
    }

    function eject(drive) {
        const mounted = drive.partitions.filter(p => p.mountpoint).map(p => p.path);
        root.busy = true;
        ejectProc.command = ["bash", "-c", `
            disk="$1"; name="$2"; shift 2
            for p in "$@"; do
                if ! udisksctl unmount -b "$p" >/dev/null 2>/tmp/qs-udisks-err; then
                    notify-send -a Discos -i drive-removable-media "Não foi possível ejetar $name" "O disco está em uso. Feche os arquivos e programas que o usam e tente de novo."
                    exit 1
                fi
            done
            sync
            udisksctl power-off -b "$disk" >/dev/null 2>&1
            notify-send -a Discos -i drive-removable-media "Pode remover com segurança" "$name"
        `, "_", drive.path, drive.title, ...mounted];
        ejectProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-o", "NAME,PATH,LABEL,SIZE,FSTYPE,TYPE,HOTPLUG,TRAN,MOUNTPOINT,MODEL,VENDOR"]
        stdout: StdioCollector {
            id: lsblkCollector
            onStreamFinished: {
                let devices = [];
                try {
                    devices = JSON.parse(lsblkCollector.text).blockdevices ?? [];
                } catch (e) {
                    return;
                }
                root.drives = devices
                    .filter(d => d.type === "disk" && d.hotplug && d.tran !== "nvme")
                    .map(d => {
                        // A disk without partitions can hold the filesystem itself
                        const parts = (d.children ?? []).length > 0 ? d.children : (d.fstype ? [d] : []);
                        return {
                            name: d.name,
                            path: d.path,
                            size: d.size,
                            title: root.driveTitle(d),
                            partitions: parts.filter(p => p.fstype && p.fstype !== "swap").map(p => ({
                                path: p.path,
                                label: p.label ?? p.name,
                                size: p.size,
                                fstype: p.fstype,
                                mountpoint: p.mountpoint ?? ""
                            }))
                        };
                    });
            }
        }
    }

    Process {
        id: ejectProc
        onExited: {
            root.busy = false;
            root.refresh();
        }
    }

    // Long-running: one line per udev block event
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: refreshSoon.restart()
        }
    }

    Timer {
        id: refreshSoon
        interval: 800
        onTriggered: root.refresh()
    }

    Timer {
        running: root.drives.length > 0
        interval: 4000
        repeat: true
        onTriggered: root.refresh()
    }
}
