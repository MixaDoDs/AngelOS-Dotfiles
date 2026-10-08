import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Current lyric line on the bar: typewriter reveal, old line slides away.
// The box is as wide as the song's longest line (up to maxWidth), so it stays
// put during a song; a line that still doesn't fit glides sideways instead of
// being cut. Left click: Lyrics settings, right click: pause / play.
// In hell (the demon rules, Y2K → Lyrics in hell): hell's blackletter (Theme.fontHell,
// crisp at 21 px), no typewriter, no slide — the next line is simply there, the way
// things are in hell; the bar's ink gives it the circle's text colour. The salute when a
// song ends is gone with the old loud hell (HellFx.fireworks stays for the button).
Item {
    id: root

    required property string screenName
    property real maxWidth: Theme.u * 250
    property bool fixedWidth: false        // keep one width per song so the bar doesn't jump
    readonly property bool onThisScreen: !Config.lyrics.screens || Config.lyrics.screens.length === 0 || Config.lyrics.screens.includes(screenName)
    readonly property bool active: Config.lyrics.enabled && Lyrics.visibleToggle && Lyrics.hasLyrics && onThisScreen
    readonly property string line: Lyrics.current !== "" ? Lyrics.current : "♪ ~ ♪"
    readonly property real chrome: note.width + Theme.u * 6
    readonly property bool hell: Angel.demon && Config.y2k.hellLyrics
    // the hell bar (BarItem): the circle's text colours even when the lyrics keep their own font
    property bool barInk: false
    readonly property string fontFamily: hell ? Theme.fontHell : Theme.fontBody
    readonly property int fontPx: hell ? Theme.hellPx(Theme.fs) : Theme.sizeBody

    // widest line of the current song, measured once per song
    property real songText: 0
    function measureSong() {
        let w = fm.advanceWidth("♪ ~ ♪");
        for (const l of Lyrics.lines)
            w = Math.max(w, fm.advanceWidth(l.text || ""));
        songText = Math.ceil(w);
    }
    Connections {
        target: Lyrics
        function onLinesChanged() {
            root.measureSong();
        }
    }
    FontMetrics {
        id: fm
        font.family: root.fontFamily
        font.pixelSize: root.fontPx
        font.hintingPreference: Font.PreferFullHinting
        onFontChanged: root.measureSong()
    }

    visible: active && maxWidth >= Theme.u * 50
    // brightness follows the volume (services/LyricsGlow): a RØDECaster's fader, or how
    // loud the player really plays; never under 30 %
    opacity: LyricsGlow.opacity
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.ms(260)
            easing.type: Easing.OutCubic
        }
    }
    implicitWidth: Math.min(maxWidth, (fixedWidth ? songText : fullW) + chrome)
    implicitHeight: Theme.u * 13
    clip: true

    readonly property bool coverReady: cover.status === Image.Ready
    property string shown: ""
    property string previous: ""
    property int typed: 0
    readonly property real fullW: fm.advanceWidth(shown)
    readonly property real typedW: typed >= shown.length ? fullW : fm.advanceWidth(shown.slice(0, typed))
    readonly property real overflowW: Math.max(0, fullW - textBox.width)
    property real scrollX: 0

    onLineChanged: {
        previous = shown;
        shown = line;
        glide.stop();
        scrollX = 0;
        if (hell) {
            // no typewriter and no slide in hell: the line is just there
            typer.stop();
            typed = shown.length;
            burnIn = 1;
            burnOut = 1;
            old.opacity = 0;
            startGlide();
            return;
        }
        if (!Config.lyrics.typewriter) {
            typed = shown.length;
            startGlide();
        } else {
            typed = 0;
            const dur = Math.max(0.3, Lyrics.lineEnd - Lyrics.lineStart);
            typer.interval = Math.max(12, Math.min(38, dur * 1000 * 0.45 / Math.max(1, shown.length)));
            typer.restart();
        }
        slide.restart();
    }
    Component.onCompleted: {
        shown = line;
        typed = shown.length;
        lastKey = Lyrics.trackKey;
        measureSong();
    }
    // long line: read the start, then glide to the end within the line's time
    function startGlide() {
        if (overflowW <= 0)
            return;
        const dur = Math.max(1.2, Lyrics.lineEnd - Lyrics.lineStart);
        glideMove.to = overflowW;
        glideMove.duration = Math.max(900, Math.min(8000, dur * 1000 * 0.55));
        glide.restart();
    }

    // ---- hell: the burning ----
    property real burnIn: 1                  // 0 → 1: the new line climbs out of the flames
    property real burnOut: 1                 // 0 → 1: the old one chars and crumbles
    property real fxTime: 0
    readonly property bool burning: burnIn < 1 || burnOut < 1
    Timer {
        // only while something burns (nothing does in today's hell: the lines just change)
        interval: 42
        repeat: true
        running: root.hell && root.visible && root.burning
        onTriggered: root.fxTime += interval / 1000
    }
    ParallelAnimation {
        id: hellSlide
        NumberAnimation {
            target: root
            property: "burnIn"
            from: 0
            to: 1
            duration: Motion.ms(640)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "burnOut"
            from: 0
            to: 1
            duration: Motion.ms(760)
        }
        NumberAnimation {
            target: old
            property: "anchors.verticalCenterOffset"
            from: 0
            to: -Theme.u * 5
            duration: Motion.ms(760)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: old
            property: "opacity"
            from: 1
            to: 1
            duration: Motion.ms(760)
        }
        NumberAnimation {
            target: cur
            property: "anchors.verticalCenterOffset"
            from: Theme.u * 3
            to: 0
            duration: Motion.ms(520)
            easing.type: Easing.OutQuad
        }
    }
    onHellChanged: {
        burnIn = 1;
        burnOut = 1;
        hellSlide.stop();
        old.opacity = 0;
        measureSong();
    }

    // ---- the salute when a song ends (only in hell, only if the lyrics were up) ----
    // where this box is on its screen: its window's place from the layer-shell anchors
    function screenPoint() {
        const w = root.QsWindow.window;
        if (!w || !w.screen)
            return null;
        const p = root.mapToItem(null, root.width / 2, root.height / 2);
        const a = w.anchors || {}, m = w.margins || {};
        const sw = w.screen.width, sh = w.screen.height;
        const wx = a.left ? (m.left || 0) : a.right ? sw - w.width - (m.right || 0) : (sw - w.width) / 2;
        const wy = a.top ? (m.top || 0) : a.bottom ? sh - w.height - (m.bottom || 0) : (sh - w.height) / 2;
        return {
            "x": wx + p.x,
            "y": wy + p.y,
            "fromTop": !!a.top && !a.bottom
        };
    }
    // the next song's lyrics may already have taken the box down: the last place it stood
    property var lastPoint: null
    property double hiddenAt: 0
    onVisibleChanged: if (!visible)
        hiddenAt = Date.now()
    function notePoint() {
        if (hell && visible) {
            const p = screenPoint();
            if (p)
                lastPoint = p;
        }
    }
    property bool saluteOnEnd: false        // the old loud hell fired a salute at a song's end
    function salute() {
        if (!saluteOnEnd || !hell || !(visible || Date.now() - hiddenAt < 2500))
            return;
        const pt = (visible ? screenPoint() : null) || lastPoint;
        if (pt)
            HellFx.fireworks(screenName, pt.x, pt.y, pt.fromTop);
    }
    property string lastKey: ""
    Connections {
        target: Lyrics
        function onTrackKeyChanged() {
            // a song ended into the next one (the box is still up with the old song's line)
            if (root.lastKey !== "" && root.lastKey !== Lyrics.trackKey)
                root.salute();
            root.lastKey = Lyrics.trackKey;
        }
        function onPlayingChanged() {
            if (!Lyrics.playing)
                stopped.restart();
            else
                stopped.stop();
        }
    }
    Component.onDestruction: stopped.stop()
    // stopped for good (not a seek or a short pause between tracks)
    Timer {
        id: stopped
        interval: 1500
        onTriggered: if (!Lyrics.playing && root.lastKey === Lyrics.trackKey && Lyrics.length > 0 && Lyrics.position >= Lyrics.length - 3)
            root.salute()
    }

    Timer {
        id: typer
        repeat: true
        onTriggered: {
            root.typed = Math.min(root.shown.length, root.typed + 1);
            if (root.typed >= root.shown.length) {
                stop();
                // the caret already pulled the text to its end
                root.scrollX = root.overflowW;
            }
        }
    }
    SequentialAnimation {
        id: glide
        PauseAnimation {
            duration: Motion.ms(700)
        }
        NumberAnimation {
            id: glideMove
            target: root
            property: "scrollX"
            easing.type: Easing.InOutSine
        }
    }

    Item {
        id: note
        width: Config.lyrics.artwork === "cover" ? Theme.u * 12 : Theme.u * 8
        height: Theme.u * 12
        anchors.verticalCenter: parent.verticalCenter
        // note + text centred as one piece
        x: Math.max(0, Math.round((root.width - root.chrome - Math.min(root.fullW, root.width - root.chrome)) / 2))
        Behavior on x {
            NumberAnimation {
                duration: Motion.ms(160)
                easing.type: Easing.OutCubic
            }
        }
        opacity: Lyrics.playing ? 1 : 0.6
        Image {
            id: cover
            anchors.fill: parent
            source: Config.lyrics.artwork === "cover" ? Lyrics.artUrl : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            clip: true
        }
        PxIcon {
            anchors.centerIn: parent
            name: Lyrics.playing ? "music" : "pause"
            visible: cover.status !== Image.Ready || !Lyrics.playing
            pixel: Math.max(1, Theme.u - 1)
        }
    }

    Item {
        id: textBox
        anchors.left: note.right
        anchors.leftMargin: Theme.u * 4
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 2
        height: parent.height
        clip: true

        // previous line sliding up and out (in hell: charring, crumbling to ash)
        PxText {
            id: old
            width: parent.width
            height: root.hell ? parent.height : implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            text: root.previous
            elide: Text.ElideRight
            visible: !root.hell || root.burnOut < 1
            // the burn (lyrics_burn.frag) takes the text in white; standing still, the circle's dim text
            color: root.hell ? (root.burning ? "white" : Theme.hellTextDim) : root.barInk ? Theme.hellTextDim : Theme.textDim
            font.family: root.fontFamily
            font.pixelSize: root.fontPx
            renderType: Text.NativeRendering
            opacity: 0
            layer.enabled: root.hell && root.burnOut < 1
            layer.effect: ShaderEffect {
                property real progress: root.burnOut
                property real time: root.fxTime
                property real mode: 1
                property real seed: 3
                property size cells: Qt.size(Math.max(1, old.width / Theme.u), Math.max(1, old.height / Theme.u))
                property size texel: Qt.size(1 / Math.max(1, old.width), 1 / Math.max(1, old.height))
                fragmentShader: Qt.resolvedUrl("../../../shaders/lyrics_burn.frag.qsb")
            }
        }
        PxText {
            id: cur
            width: Math.max(parent.width, root.fullW + Theme.u * 4)
            height: root.hell ? parent.height : implicitHeight
            font.family: root.fontFamily
            font.pixelSize: root.fontPx
            renderType: Text.NativeRendering
            layer.enabled: root.hell && root.burnIn < 1
            layer.effect: ShaderEffect {
                property real progress: root.burnIn
                property real time: root.fxTime
                property real mode: 0
                property real seed: 1
                property size cells: Qt.size(Math.max(1, cur.width / Theme.u), Math.max(1, cur.height / Theme.u))
                property size texel: Qt.size(1 / Math.max(1, cur.width), 1 / Math.max(1, cur.height))
                fragmentShader: Qt.resolvedUrl("../../../shaders/lyrics_burn.frag.qsb")
            }
            // while typing, the caret pulls a long line along; afterwards scrollX holds / glides
            x: typer.running ? -Math.max(0, root.typedW + Theme.u * 3 - textBox.width) : -Math.min(root.scrollX, root.overflowW)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            color: root.hell ? (Lyrics.current === "" || !Lyrics.playing ? (root.burning ? "#b0b0b0" : Theme.hellTextDim) : (root.burning ? "white" : Theme.hellText)) : root.barInk ? (Lyrics.current === "" || !Lyrics.playing ? Theme.hellTextDim : Theme.hellText) : Lyrics.current === "" || !Lyrics.playing ? Theme.textDim : Theme.text
            text: {
                const esc = s => Qt.escapeHtml(s);
                const t = root.shown;
                return esc(t.slice(0, root.typed)) + (root.typed < t.length ? "<font color='" + Theme.hex(Theme.accent) + "'>▌</font>" : "");
            }
        }

        ParallelAnimation {
            id: slide
            NumberAnimation {
                target: old
                property: "anchors.verticalCenterOffset"
                from: 0
                to: -Theme.u * 8
                duration: Motion.ms(220)
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: old
                property: "opacity"
                from: 0.8
                to: 0
                duration: Motion.ms(220)
            }
            NumberAnimation {
                target: cur
                property: "anchors.verticalCenterOffset"
                from: Theme.u * 6
                to: 0
                duration: Motion.ms(180)
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (m.button === Qt.RightButton) {
                if (Lyrics.player && Lyrics.player.canTogglePlaying)
                    Lyrics.player.togglePlaying();
            } else
                Shell.openSettings("lyrics");
        }
    }
}
