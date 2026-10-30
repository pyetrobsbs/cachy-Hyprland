pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Player de música em dois cards (capa + vinil + cava | busca/fila/favoritos).
 * Toca do YouTube via YtMusic e também controla qualquer player MPRIS (Spotify, navegador...).
 * Abrir/fechar: Super+M ou clique na música da barra.
 */
Scope {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool mine: YtMusic.isMine(player) || (YtMusic.loading && YtMusic.currentTrack !== null)
    readonly property string title: mine ? YtMusic.currentTrack.title : (StringUtils.cleanMusicTitle(player?.trackTitle) || "Nada tocando")
    readonly property string artist: mine ? YtMusic.currentTrack.artist : (player?.trackArtist ?? "Busque uma música →")
    readonly property string artUrl: mine ? YtMusic.currentTrack.thumb : (player?.trackArtUrl ?? "")
    readonly property list<real> visualizerPoints: Cava.points
    property string tab: "results" // favorites | queue | results

    readonly property color colCard: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.06)
    readonly property real cardRadius: Appearance.rounding.large

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "--:--";
        return StringUtils.friendlyTimeForSeconds(seconds);
    }

    Timer { // Atualiza a posição da música
        running: GlobalStates.musicPlayerOpen && (root.player?.isPlaying ?? false)
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    component IconButton: RippleButton {
        id: iconButton
        property string iconName
        property real size: 36
        property real iconSize: Appearance.font.pixelSize.larger
        property bool filled: false
        property color colIcon: Appearance.colors.colOnLayer1
        implicitWidth: size
        implicitHeight: size
        buttonRadius: size / 2
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: iconButton.iconName
            iconSize: iconButton.iconSize
            fill: iconButton.filled ? 1 : 0
            color: iconButton.colIcon
        }
    }

    component Card: Item {
        default property alias content: cardBody.data
        StyledRectangularShadow {
            target: cardBg
        }
        Rectangle {
            id: cardBg
            anchors.fill: parent
            color: root.colCard
            radius: root.cardRadius
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
        Item {
            id: cardBody
            anchors.fill: parent
            anchors.margins: 18
        }
    }

    component TabPill: RippleButton {
        id: tabPill
        property string key
        property string iconName
        property string label
        implicitHeight: 30
        implicitWidth: tabRow.implicitWidth + 24
        buttonRadius: height / 2
        toggled: root.tab === key
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4)
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        onClicked: root.tab = key
        contentItem: Item {
            RowLayout {
                id: tabRow
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: tabPill.iconName
                    iconSize: Appearance.font.pixelSize.normal
                    fill: tabPill.toggled ? 1 : 0
                    color: tabPill.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: tabPill.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: tabPill.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }
            }
        }
    }

    Loader {
        id: playerLoader
        active: GlobalStates.musicPlayerOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:musicPlayer"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            implicitWidth: cardsRow.implicitWidth + 40
            implicitHeight: cardsRow.implicitHeight + 40

            Component.onCompleted: GlobalFocusGrab.addDismissable(panelWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.musicPlayerOpen = false;
                }
            }

            RowLayout {
                id: cardsRow
                anchors.centerIn: parent
                spacing: 16
                focus: true
                Keys.onEscapePressed: GlobalStates.musicPlayerOpen = false

                // ───────────── Card esquerdo: tocando agora ─────────────
                Card {
                    implicitWidth: 380
                    implicitHeight: 540

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        Item { // Capa + disco de vinil
                            Layout.fillWidth: true
                            implicitHeight: 210

                            Item {
                                id: vinyl
                                width: 180
                                height: 180
                                anchors.verticalCenter: parent.verticalCenter
                                x: cover.x + cover.width - width / 2 - (root.player?.isPlaying ? 0 : 50)
                                Behavior on x {
                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#111014"
                                    border.width: 1
                                    border.color: "#2a2830"
                                }
                                Repeater { // Sulcos
                                    model: 6
                                    Rectangle {
                                        required property int index
                                        anchors.centerIn: parent
                                        width: vinyl.width - 18 - index * 16
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: "#25232b"
                                    }
                                }
                                Item { // Rótulo central com a capa
                                    id: vinylLabel
                                    anchors.centerIn: parent
                                    width: 56
                                    height: 56
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: vinylLabel.width
                                            height: vinylLabel.height
                                            radius: width / 2
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Appearance.colors.colPrimary
                                    }
                                    Image {
                                        anchors.fill: parent
                                        source: root.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: "#111014"
                                }
                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 6000
                                    loops: Animation.Infinite
                                    running: root.player?.isPlaying ?? false
                                }
                            }

                            Rectangle { // Capa
                                id: cover
                                width: 180
                                height: 180
                                x: (parent.width - width - vinyl.width / 2) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colLayer2
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: cover.width
                                        height: cover.height
                                        radius: cover.radius
                                    }
                                }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    iconSize: 64
                                    color: Appearance.colors.colSubtext
                                    visible: coverImage.status !== Image.Ready
                                }
                                Image {
                                    id: coverImage
                                    anchors.fill: parent
                                    source: root.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Rectangle { // Baixando a música
                                    anchors.fill: parent
                                    visible: YtMusic.loading
                                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.35)
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MaterialLoadingIndicator {
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitSize: 48
                                            loading: YtMusic.loading
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Carregando…"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer0
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout { // Título + favorito
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.title
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    animateChange: true
                                    animationDistanceX: 6
                                    animationDistanceY: 0
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.artist
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                            }
                            IconButton {
                                visible: root.mine
                                size: 44
                                iconName: "favorite"
                                filled: YtMusic.isFavorite(YtMusic.currentTrack?.id)
                                colIcon: filled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                onClicked: YtMusic.toggleFavorite(YtMusic.currentTrack)
                            }
                        }

                        Item { // Visualizador (cava)
                            id: visualizer
                            Layout.fillWidth: true
                            implicitHeight: 44
                            readonly property int barCount: root.visualizerPoints.length
                            Row {
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: visualizer.barCount
                                    Rectangle {
                                        required property int index
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(2, (visualizer.width - visualizer.barCount * 2) / Math.max(1, visualizer.barCount))
                                        height: Math.max(3, Math.min(1, (root.visualizerPoints[index] ?? 0) / 1000) * visualizer.height)
                                        radius: width / 2
                                        color: Appearance.colors.colPrimary
                                        opacity: 0.85
                                    }
                                }
                            }
                        }

                        ColumnLayout { // Progresso
                            Layout.fillWidth: true
                            spacing: 0
                            StyledSlider {
                                Layout.fillWidth: true
                                enabled: root.player?.canSeek ?? false
                                configuration: StyledSlider.Configuration.Wavy
                                usePercentTooltip: false
                                value: (root.player?.length ?? 0) > 0 ? root.player.position / root.player.length : 0
                                onMoved: root.player.position = value * root.player.length
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: root.formatTime(root.player?.position)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: root.formatTime(root.player?.length)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout { // Controles
                            Layout.fillWidth: true
                            spacing: 6
                            IconButton {
                                iconName: MprisController.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                                enabled: MprisController.loopSupported
                                colIcon: MprisController.loopState !== MprisLoopState.None ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                onClicked: MprisController.setLoopState(MprisController.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisController.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
                            }
                            Item { Layout.fillWidth: true }
                            IconButton {
                                iconName: "skip_previous"
                                filled: true
                                iconSize: Appearance.font.pixelSize.huge
                                enabled: MprisController.canGoPrevious
                                onClicked: MprisController.previous()
                            }
                            RippleButton {
                                implicitWidth: 56
                                implicitHeight: 56
                                buttonRadius: root.player?.isPlaying ? Appearance.rounding.normal : 28
                                enabled: MprisController.canTogglePlaying
                                colBackground: Appearance.colors.colPrimary
                                colBackgroundHover: Appearance.colors.colPrimaryHover
                                colRipple: Appearance.colors.colPrimaryActive
                                onClicked: MprisController.togglePlaying()
                                Behavior on buttonRadius {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                                contentItem: MaterialSymbol {
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: root.player?.isPlaying ? "pause" : "play_arrow"
                                    iconSize: Appearance.font.pixelSize.huge
                                    fill: 1
                                    color: Appearance.colors.colOnPrimary
                                }
                            }
                            IconButton {
                                iconName: "skip_next"
                                filled: true
                                iconSize: Appearance.font.pixelSize.huge
                                enabled: MprisController.canGoNext
                                onClicked: MprisController.next()
                            }
                            Item { Layout.fillWidth: true }
                            IconButton {
                                iconName: "close"
                                onClicked: GlobalStates.musicPlayerOpen = false
                            }
                        }

                        RowLayout { // Volume
                            Layout.fillWidth: true
                            visible: MprisController.canChangeVolume
                            spacing: 8
                            MaterialSymbol {
                                text: "volume_up"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colSubtext
                            }
                            StyledSlider {
                                Layout.fillWidth: true
                                configuration: StyledSlider.Configuration.XS
                                value: root.player?.volume ?? 0
                                onMoved: root.player.volume = value
                            }
                        }
                    }
                }

                // ───────────── Card direito: busca / fila / favoritos ─────────────
                Card {
                    implicitWidth: 470
                    implicitHeight: 540

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        RowLayout { // Cabeçalho + busca
                            Layout.fillWidth: true
                            spacing: 10
                            MaterialSymbol {
                                text: "graphic_eq"
                                iconSize: Appearance.font.pixelSize.huge
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: "MÚSICA"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                                color: Appearance.colors.colOnLayer0
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                radius: height / 2
                                color: Appearance.colors.colLayer2
                                border.width: searchInput.activeFocus ? 2 : 1
                                border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 6
                                    MaterialSymbol {
                                        text: "search"
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: Appearance.colors.colSubtext
                                    }
                                    TextInput {
                                        id: searchInput
                                        Layout.fillWidth: true
                                        clip: true
                                        focus: true
                                        color: Appearance.colors.colOnLayer1
                                        selectionColor: Appearance.colors.colSecondaryContainer
                                        selectedTextColor: Appearance.colors.colOnSecondaryContainer
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        Keys.onEscapePressed: GlobalStates.musicPlayerOpen = false
                                        onAccepted: {
                                            YtMusic.search(text);
                                            root.tab = "results";
                                        }
                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: searchInput.text.length === 0
                                            text: "Buscar no YouTube…"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                    MaterialLoadingIndicator {
                                        visible: YtMusic.searching
                                        implicitSize: 22
                                        loading: YtMusic.searching
                                    }
                                }
                            }
                        }

                        RowLayout { // Abas
                            spacing: 8
                            TabPill {
                                key: "favorites"
                                iconName: "favorite"
                                label: `Favoritos (${YtMusic.favorites.length})`
                            }
                            TabPill {
                                key: "queue"
                                iconName: "queue_music"
                                label: `Fila (${YtMusic.queue.length})`
                            }
                            TabPill {
                                key: "results"
                                iconName: "search"
                                label: "Resultados"
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property var model: root.tab === "favorites" ? YtMusic.favorites : root.tab === "queue" ? YtMusic.queue : YtMusic.results

                            StyledText {
                                anchors.centerIn: parent
                                visible: parent.model.length === 0
                                horizontalAlignment: Text.AlignHCenter
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: {
                                    if (root.tab === "results") {
                                        if (YtMusic.searchError.length > 0) return YtMusic.searchError;
                                        if (YtMusic.searching) return "Buscando…";
                                        return "Digite uma música e aperte Enter";
                                    }
                                    if (root.tab === "queue") return "A fila está vazia";
                                    return "Toque o ♥ numa música para salvar aqui";
                                }
                            }

                            ListView {
                                id: trackList
                                anchors.fill: parent
                                clip: true
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds
                                model: parent.model

                                delegate: RippleButton {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    readonly property bool current: root.tab === "queue" ? index === YtMusic.queueIndex : modelData.id === YtMusic.currentTrack?.id
                                    width: trackList.width
                                    implicitHeight: 54
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: current ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                    colBackgroundHover: current ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                                    onClicked: {
                                        if (root.tab === "queue") YtMusic.playIndex(index);
                                        else if (root.tab === "favorites") YtMusic.playList(YtMusic.favorites, index);
                                        else YtMusic.play(modelData);
                                    }

                                    contentItem: RowLayout {
                                        spacing: 10
                                        StyledText {
                                            Layout.preferredWidth: 22
                                            horizontalAlignment: Text.AlignRight
                                            text: String(row.index + 1).padStart(2, "0")
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        Item {
                                            id: thumb
                                            implicitWidth: 40
                                            implicitHeight: 40
                                            layer.enabled: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: thumb.width
                                                    height: thumb.height
                                                    radius: Appearance.rounding.verysmall
                                                }
                                            }
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Appearance.colors.colLayer2
                                            }
                                            Image {
                                                anchors.fill: parent
                                                source: row.modelData.thumb
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                sourceSize.width: 80
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: row.modelData.title
                                                elide: Text.ElideRight
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: row.current ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: row.modelData.artist
                                                elide: Text.ElideRight
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                            }
                                        }
                                        StyledText {
                                            text: root.formatTime(row.modelData.duration)
                                            font.family: Appearance.font.family.monospace
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        IconButton {
                                            size: 30
                                            visible: root.tab !== "queue"
                                            iconName: "playlist_add"
                                            onClicked: YtMusic.enqueue(row.modelData)
                                        }
                                        IconButton {
                                            size: 30
                                            visible: root.tab === "queue"
                                            iconName: "remove"
                                            onClicked: YtMusic.removeFromQueue(row.index)
                                        }
                                        IconButton {
                                            size: 30
                                            iconName: "favorite"
                                            filled: YtMusic.isFavorite(row.modelData.id)
                                            colIcon: filled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                            onClicked: YtMusic.toggleFavorite(row.modelData)
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

    IpcHandler {
        target: "musicPlayer"

        function toggle(): void {
            GlobalStates.musicPlayerOpen = !GlobalStates.musicPlayerOpen;
        }
        function open(): void {
            GlobalStates.musicPlayerOpen = true;
        }
        function close(): void {
            GlobalStates.musicPlayerOpen = false;
        }
    }

    GlobalShortcut {
        name: "musicPlayerToggle"
        description: "Abre/fecha o player de música"
        onPressed: GlobalStates.musicPlayerOpen = !GlobalStates.musicPlayerOpen
    }
}
