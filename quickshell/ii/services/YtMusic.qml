pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * Player de música próprio: busca no YouTube (yt-dlp) e toca no mpv em segundo plano.
 * O mpv aparece no MPRIS (pacote mpv-mpris), então play/pause/posição vêm do MprisController.
 * Aqui ficam a busca, a fila e os favoritos.
 * Track: { id, title, artist, duration (s), url, thumb }
 */
Singleton {
    id: root

    readonly property string script: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/music/ytmusic.sh`
    readonly property string favoritesPath: FileUtils.trimFileProtocol(`${Directories.state}/user/music_favorites.json`)

    property var results: []
    property var queue: []
    property var favorites: []
    property int queueIndex: -1
    property bool searching: false
    property string searchError: ""
    property string lastQuery: ""
    property real lastCommandTime: 0 // o download + o mpv levam alguns segundos
    property string loadingId: "" // música pedida que ainda está sendo baixada
    readonly property bool loading: loadingId !== ""
    readonly property var currentTrack: (queueIndex >= 0 && queueIndex < queue.length) ? queue[queueIndex] : null

    function makeTrack(id, title, artist, duration) {
        return {
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            url: `https://www.youtube.com/watch?v=${id}`,
            thumb: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
        };
    }

    // O mpv deste player (e não outro mpv qualquer) é o player MPRIS ativo
    function isMine(player) {
        return (player?.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.mpv") && root.currentTrack !== null;
    }

    function search(query) {
        query = query.trim();
        if (query.length === 0)
            return;
        root.lastQuery = query;
        root.searchError = "";
        root.searching = true;
        searchProc.running = false;
        searchProc.command = ["bash", root.script, "search", query];
        searchProc.running = true;
    }

    function playList(list, index) {
        if (!list || list.length === 0)
            return;
        // A fila começa na música escolhida; as seguintes são baixadas em segundo plano
        root.queue = list.slice(index);
        root.queueIndex = 0;
        root.loadingId = root.queue[0].id;
        root.lastCommandTime = Date.now();
        Quickshell.execDetached(["bash", root.script, "playlist"].concat(root.queue.map(t => t.url)));
    }

    function play(track) {
        playList([track], 0);
    }

    function enqueue(track) {
        root.queue = root.queue.concat([track]);
        if (root.queueIndex < 0) {
            root.queueIndex = root.queue.length - 1;
            root.loadingId = track.id;
        }
        root.lastCommandTime = Date.now();
        Quickshell.execDetached(["bash", root.script, "add", track.url]);
    }

    function playIndex(index) {
        root.queueIndex = index;
        Quickshell.execDetached(["bash", root.script, "playindex", `${index}`]);
    }

    function removeFromQueue(index) {
        const q = root.queue.slice(0);
        q.splice(index, 1);
        root.queue = q;
        if (index < root.queueIndex)
            root.queueIndex -= 1;
        Quickshell.execDetached(["bash", root.script, "remove", `${index}`]);
    }

    function isFavorite(id) {
        return root.favorites.some(t => t.id === id);
    }

    function toggleFavorite(track) {
        if (!track)
            return;
        if (isFavorite(track.id))
            root.favorites = root.favorites.filter(t => t.id !== track.id);
        else
            root.favorites = [track].concat(root.favorites);
        favoritesFile.setText(JSON.stringify(root.favorites, null, 2));
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 4 || f[0].length === 0)
                        continue;
                    list.push(root.makeTrack(f[0], f[1], f[2], parseInt(f[3]) || 0));
                }
                root.results = list;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.searching = false;
            if (exitCode === 127)
                root.searchError = "yt-dlp não está instalado (sudo pacman -S yt-dlp)";
            else if (exitCode !== 0)
                root.searchError = "A busca falhou (sem internet?)";
        }
    }

    // Acompanha qual item da fila do mpv está tocando
    Timer {
        interval: 1500
        repeat: true
        running: root.queue.length > 0
        onTriggered: statusProc.running = true
    }
    Process {
        id: statusProc
        command: ["bash", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const path = JSON.parse(text).data;
                    const sinceCommand = Date.now() - root.lastCommandTime;
                    if (path === -2) { // mpv fechado
                        if (sinceCommand < 30000)
                            return;
                        root.loadingId = "";
                        root.queueIndex = -1;
                        root.queue = [];
                        return;
                    }
                    if (root.loadingId !== "" && sinceCommand > 90000)
                        root.loadingId = ""; // desiste do "carregando" se o download travar
                    if (typeof path !== "string")
                        return; // mpv parado
                    const id = path.split("/").pop().replace(/\.[^.]+$/, "");
                    if (root.loadingId !== "" && id !== root.loadingId)
                        return; // ainda tocando a música anterior
                    root.loadingId = "";
                    const index = root.queue.findIndex(t => t.id === id);
                    if (index >= 0)
                        root.queueIndex = index;
                } catch (e) {}
            }
        }
    }

    FileView {
        id: favoritesFile
        path: Qt.resolvedUrl(root.favoritesPath)
        onLoaded: {
            try {
                root.favorites = JSON.parse(favoritesFile.text());
            } catch (e) {
                root.favorites = [];
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                root.favorites = [];
                favoritesFile.setText("[]");
            }
        }
    }

    IpcHandler {
        target: "music"

        function search(query: string): void {
            root.search(query);
        }
        function playResult(index: int): void {
            if (index >= 0 && index < root.results.length)
                root.play(root.results[index]);
        }
        function enqueueResult(index: int): void {
            if (index >= 0 && index < root.results.length)
                root.enqueue(root.results[index]);
        }
        function quit(): void {
            Quickshell.execDetached(["bash", root.script, "quit"]);
        }
    }
}
