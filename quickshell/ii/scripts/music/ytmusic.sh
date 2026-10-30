#!/usr/bin/env bash
# Backend do player de música (services/YtMusic.qml)
# O YouTube recusa (403) o download direto do stream pelo mpv/ffmpeg, então o yt-dlp
# baixa o áudio para um cache e o mpv toca o arquivo local. O mpv roda em segundo plano
# (sobrevive a reloads do Quickshell) e é controlado via socket IPC.
# Uso:
#   ytmusic.sh search "<busca>" [n]  -> id<TAB>título<TAB>canal<TAB>duração (uma por linha)
#   ytmusic.sh playlist <url>...     -> substitui a fila do mpv; toca a 1ª assim que baixar, baixa as outras em seguida
#   ytmusic.sh add <url>             -> baixa e adiciona ao fim da fila (toca se estiver parado)
#   ytmusic.sh playindex <n> | remove <n> | status | quit

SOCK="${XDG_RUNTIME_DIR:-/tmp}/ii-music-mpv.sock"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ii-music"
GEN_FILE="$CACHE/.generation"
mkdir -p "$CACHE"

alive() {
    [ -S "$SOCK" ] && printf '%s\n' '{"command":["get_property","pid"]}' \
        | socat -t 1 - "UNIX-CONNECT:$SOCK" 2>/dev/null | grep -q '"error":"success"'
}

start() {
    alive && return 0
    rm -f "$SOCK"
    # Limpa músicas não tocadas há mais de 30 dias
    find "$CACHE" -type f -name '*.*' ! -name '.*' -atime +30 -delete 2>/dev/null
    setsid -f mpv --idle=yes --no-video --force-window=no --no-terminal \
        --input-ipc-server="$SOCK" --volume=80 --title=ii-music >/dev/null 2>&1
    for _ in $(seq 50); do
        alive && return 0
        sleep 0.1
    done
    echo "mpv não iniciou" >&2
    return 1
}

send() {
    printf '%s\n' "$1" | socat -t 1 - "UNIX-CONNECT:$SOCK"
}

json_str() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

# Baixa (se ainda não estiver no cache) e imprime o caminho do arquivo
fetch() {
    local url="$1" id cached
    id="${url##*v=}"
    id="${id%%&*}"
    cached=$(find "$CACHE" -maxdepth 1 -type f -name "$id.*" ! -name '*.part' ! -name '*.ytdl' | head -1)
    if [ -n "$cached" ]; then
        touch -a "$cached"
        echo "$cached"
        return 0
    fi
    yt-dlp -q --no-warnings --no-progress --ignore-config -f 'bestaudio/best' --embed-metadata \
        -o "$CACHE/%(id)s.%(ext)s" --print after_move:filepath -- "$url" 2>/dev/null | tail -1
}

# Só continua se nenhum "playlist" mais novo tiver começado
current() {
    [ "$(cat "$GEN_FILE" 2>/dev/null)" = "$1" ]
}

case "$1" in
    search)
        command -v yt-dlp >/dev/null || { echo "NO_YTDLP" >&2; exit 127; }
        yt-dlp --flat-playlist --no-warnings --ignore-config \
            --print $'%(id)s\t%(title)s\t%(channel,uploader|)s\t%(duration|0)s' \
            "ytsearch${3:-25}:$2"
        ;;
    playlist)
        shift
        gen="$(date +%s%N)"
        echo "$gen" > "$GEN_FILE"
        start || exit 1
        first=1
        for url in "$@"; do
            file=$(fetch "$url")
            current "$gen" || exit 0
            [ -n "$file" ] || continue
            if [ "$first" = 1 ]; then
                send "{\"command\":[\"loadfile\",$(json_str "$file"),\"replace\"]}" >/dev/null
                send '{"command":["set_property","pause",false]}' >/dev/null
                first=0
            else
                send "{\"command\":[\"loadfile\",$(json_str "$file"),\"append\"]}" >/dev/null
            fi
        done
        ;;
    add)
        start || exit 1
        file=$(fetch "$2")
        [ -n "$file" ] && send "{\"command\":[\"loadfile\",$(json_str "$file"),\"append-play\"]}" >/dev/null
        ;;
    playindex)
        alive && send "{\"command\":[\"playlist-play-index\",$2]}" >/dev/null
        ;;
    remove)
        alive && send "{\"command\":[\"playlist-remove\",$2]}" >/dev/null
        ;;
    status)
        # Arquivo tocando agora (o nome é o id do vídeo); -2 = mpv fechado
        if alive; then send '{"command":["get_property","path"]}'; else echo '{"data":-2}'; fi
        ;;
    quit)
        alive && send '{"command":["quit"]}' >/dev/null
        ;;
    *)
        echo "uso: $0 search|playlist|add|playindex|remove|status|quit" >&2
        exit 2
        ;;
esac
