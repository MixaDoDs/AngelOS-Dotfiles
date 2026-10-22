pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// (local patch 56) Heaven's Gate: the wallpaper change as a game's loading screen, over
// everything on one screen. `grim` freezes the desktop (as ScreenQuake does); the gates slam
// shut over it (21:9, Danganronpa's jolt), the chapter types in the upper one, a tip with a
// cut-out label (Persona 5) in the lower, a halo turns there. Three slabs sweep across and hold
// as a title card in the new picture's colour, the picture's name stamped on it letter by
// letter; they leave over the new picture as an old photograph developing while the camera
// drifts (RDR2's loading). The gates open like a film widening to the full screen, the words
// riding out on them, and a slanted light sweeps the live desktop back. The picture under the
// scene is swapped once the scene surely covers it (covered); no frame in time and the view
// goes another way (failed). Sounds: scripts/gate-sounds.py into …/sounds/gate. No input.
Scope {
    id: root

    required property string screenName
    signal covered(string path)
    signal failed(string path)

    property string phase: "idle"            // idle | capture | play
    property string path: ""
    property int serial: 0
    property real t: 0
    property int tick: 0
    property double startedAt: 0
    property string frameUrl: ""
    // the picture under the scene changed: only once the scene is surely drawn over it (the
    // frame image is ready a moment before the window shows it, and the swap flashed through)
    property bool swapped: false
    // the theme follows the wallpaper and changes as soon as the picture under the scene does:
    // the scene keeps the old colour until the slabs bring the new one in
    property color accentFrom: Theme.accent
    readonly property color accent: t < 2.0 ? accentFrom : Theme.accent
    property var cues: []
    property int cue: 0
    property string title: ""
    property string chapter: ""
    property var tip: ({})
    property int lastTip: -1
    readonly property real total: 5.15
    readonly property bool busy: phase !== "idle"
    readonly property string shotPath: WorkspaceAnim.runtimeDir + "/gate-" + screenName.replace(/[^A-Za-z0-9_-]/g, "_") + ".ppm"
    readonly property string soundDir: Sounds.base + "/gate"
    readonly property string soundVersion: "2"
    readonly property var sounds: ["rumble", "slam", "tick1", "tick2", "swish", "stamp", "whoosh", "choir", "bell", "shine"]

    // what the loading screen tells: the shell's keys, and now and then the angel
    readonly property var tips: [
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Space - все программы под рукой", "Mod+Space - every app at hand") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+V открывает историю буфера обмена", "Mod+V opens the clipboard history") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Shift+S - скриншот: экран замирает, выбирай окно или область", "Mod+Shift+S - a screenshot: the screen freezes, pick a window or an area") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Shift+Enter - сразу к обоям", "Mod+Shift+Enter - straight to the wallpapers") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Alt+T меняет светлую тему на тёмную и обратно", "Mod+Alt+T swaps the light and dark theme") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Alt+Y - текст песни поверх стола", "Mod+Alt+Y - the song's lyrics over the desk") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Ctrl+Shift+Esc - диспетчер задач", "Ctrl+Shift+Esc - the task manager") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Shift+Esc покажет все горячие клавиши", "Mod+Shift+Esc shows every hotkey") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+E - файлы, Mod+B - браузер", "Mod+E - files, Mod+B - the browser") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Ctrl+Alt+Del - выключение, как в старые добрые", "Ctrl+Alt+Del - shut down, like the good old days") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("Mod+Shift+X прячет приватные окна на стриме", "Mod+Shift+X hides private windows on stream") },
        { "label": I18n.t("СОВЕТ", "TIP"), "text": I18n.t("angelos wallpaper random - обои наугад", "angelos wallpaper random - a wallpaper by chance") },
        { "label": I18n.t("АНГЕЛ", "ANGEL"), "text": I18n.t("Не торопись. Я ещё рисую", "Take your time. I'm still painting") },
        { "label": I18n.t("АНГЕЛ", "ANGEL"), "text": I18n.t("Даже у врат рая есть экран загрузки", "Even heaven's gate has a loading screen") },
        { "label": I18n.t("АНГЕЛ", "ANGEL"), "text": I18n.t("Новые обои - новая глава", "A new wallpaper is a new chapter") },
        { "label": I18n.t("АНГЕЛ", "ANGEL"), "text": I18n.t("Нимб крутится - значит, всё работает", "The halo turns, so all is well") }
    ]

    function roman(n) {
        const r = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let s = "";
        for (const [v, l] of r)
            while (n >= v) {
                s += l;
                n -= v;
            }
        return s;
    }
    function textHash(s) {
        let h = 7;
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 100003;
        return h;
    }

    function start(p) {
        if (busy || !Shell.screenByName(screenName))
            return false;
        path = p;
        title = Wallpapers.nameOf(p).replace(/[-_]+/g, " ").toUpperCase();
        // the same picture is always the same chapter
        chapter = I18n.t("ГЛАВА ", "CHAPTER ") + roman(textHash(p) % 12 + 1);
        let i = Math.floor(Math.random() * tips.length);
        if (i === lastTip)
            i = (i + 1) % tips.length;
        lastTip = i;
        tip = tips[i];
        t = 0;
        tick = 0;
        swapped = false;
        accentFrom = Theme.accent;
        cues = cueList();
        cue = 0;
        phase = "capture";
        if (!gen.running)
            gen.running = true;
        grab.command = ["grim", "-o", screenName, "-t", "ppm", shotPath];
        grab.running = true;
        timeout.restart();
        return true;
    }
    // [seconds, sound], in order
    function cueList() {
        const c = [[0, "rumble"], [0.6, "slam"], [1.7, "swish"], [2.8, "whoosh"], [3.0, "choir"], [3.9, "bell"], [4.5, "shine"]];
        for (let i = 0; i < Math.min(chapter.length + title.length, 24); i++)
            c.push([0.85 + i * 0.045, i % 2 ? "tick2" : "tick1"]);
        for (let i = 0; i < tip.label.length; i++)
            c.push([1.5 + i * 0.07, i % 2 ? "tick1" : "tick2"]);
        // the card's name, a stamp a letter (the spaces quiet)
        for (let i = 0; i < Math.min(title.length, 16); i++)
            if (title.charAt(i) !== " ")
                c.push([2.12 + i * 0.05, "stamp"]);
        return c.sort((a, b) => a[0] - b[0]);
    }
    function play(name) {
        if (!Config.y2k.sounds || StreamMode.quiet || Sounds.quietNow())
            return;
        Sounds.playFile(soundDir + "/" + name + ".wav", Sounds.volumeOf("wallpaper"));
    }
    function captured() {
        if (phase !== "capture")
            return;
        serial++;
        frameUrl = "file://" + shotPath + "?" + serial;
    }
    // the frozen frame is up: the scene runs (the picture under it changes a moment later)
    function frameReady() {
        if (phase !== "capture")
            return;
        timeout.stop();
        phase = "play";
        startedAt = Date.now();
        clock.restart();
    }
    function finish() {
        clock.stop();
        timeout.stop();
        phase = "idle";
        frameUrl = "";
        remove.command = ["rm", "-f", shotPath];
        remove.running = true;
    }
    function fail() {
        const p = path;
        const was = phase;
        finish();
        if (was === "capture")
            root.failed(p);
    }

    Process {
        id: grab
        onExited: code => code === 0 ? root.captured() : root.fail()
    }
    Process {
        id: remove
    }
    // synthesised once (and again for a newer version); a volume-0 play decodes them ahead
    Process {
        id: gen
        command: ["sh", "-c", '[ "$(cat "$1/.version" 2>/dev/null)" = "$3" ] || python3 "$2" "$1" >/dev/null', "sh", root.soundDir, Quickshell.shellDir + "/scripts/gate-sounds.py", root.soundVersion]
        onExited: {
            for (const s of root.sounds)
                Sounds.playFile(root.soundDir + "/" + s + ".wav", 0);
        }
    }
    // once the settings are read (before that the transition is the default one)
    readonly property bool wanted: Config.ready && ["gate", "random"].includes(Config.wallpaper.transition)
    onWantedChanged: if (wanted && !gen.running)
        gen.running = true
    Timer {
        id: timeout
        interval: 600
        onTriggered: root.fail()
    }
    Timer {
        id: clock
        interval: 16
        repeat: true
        onTriggered: {
            root.tick++;
            root.t = (Date.now() - root.startedAt) / 1000;
            if (!root.swapped && root.t >= 0.1) {
                root.swapped = true;
                root.covered(root.path);
                // the whole shell repaints for the new colours (~0.1 s): now, under the still
                // frame, not 0.9 s on in the middle of the scene
                PaletteGenerator.settleNow();
            }
            while (root.cue < root.cues.length && root.cues[root.cue][0] <= root.t)
                root.play(root.cues[root.cue++][1]);
            if (root.t >= root.total)
                root.finish();
        }
    }

    LazyLoader {
        active: root.phase !== "idle" && !!Shell.screenByName(root.screenName)

        PanelWindow {
            id: win
            screen: Shell.screenByName(root.screenName)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-gate"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property bool playing: root.phase === "play"
            readonly property real dpr: screen && screen.devicePixelRatio > 0 ? screen.devicePixelRatio : 1
            readonly property real t: root.t
            readonly property real cs: Math.max(3, Math.floor(height / 240))
            function clamp01(x) {
                return Math.max(0, Math.min(1, x));
            }
            // the gates: in on twos with an overshoot (the slam), out smooth and wide, like a
            // film opening to the full screen; the cut slanted only while they slam. Never thinner than
            // the ornament and a line of words: a screen 21:9 or wider has next to no bars of its own
            readonly property real barFull: Math.max(0.5 * (1 - (width / Math.max(1, height)) / (21 / 9)), 0.06, 26 * cs / Math.max(1, height))
            readonly property real cIn: Math.floor(clamp01((t - 0.45) / 0.3) * 9) / 9
            readonly property real cOut: {
                const x = clamp01((t - 3.9) / 0.6);
                return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
            }
            readonly property real barNow: {
                const k1 = 1.9, k3 = 2.9, b = cIn - 1;
                return barFull * (1 + k3 * b * b * b + k1 * b * b) * (1 - cOut);
            }
            readonly property real slant: 0.05 * (1 - cIn * cIn * (3 - 2 * cIn))
            // the words' room: outside the ornament, the gates shut
            readonly property real room: Math.max(0, barFull * height - 12 * cs)
            // the blow shakes it all: hard random steps, settling
            readonly property real power: t > 0.6 && t < 0.95 ? Theme.u * 10 * Math.pow(1 - (t - 0.6) / 0.35, 1.5) : 0
            readonly property point jolt: {
                const i = root.tick;
                const r = n => {
                    const v = Math.sin(i * 12.9898 + n * 78.233) * 43758.5453;
                    return (v - Math.floor(v)) * 2 - 1;
                };
                return Qt.point(Math.round(r(1) * power / cs) * cs, Math.round(r(2) * power * 0.7 / cs) * cs);
            }
            // the first drawing of a font's glyphs stalls a frame: every word of the scene is
            // drawn all but invisible while the frame is still, before anything moves
            readonly property bool warm: playing && t < 0.4
            readonly property color glow: Theme.mix(root.accent, "#ffffff", 0.7)
            readonly property color ink: Theme.mix("#000000", root.accent, 0.12)

            Image {
                id: frame
                anchors.fill: parent
                visible: false
                source: root.frameUrl
                asynchronous: false
                cache: false
                smooth: false
                onStatusChanged: {
                    if (status === Image.Ready)
                        root.frameReady();
                    else if (status === Image.Error)
                        root.fail();
                }
            }
            Image {
                id: wall
                anchors.fill: parent
                visible: false
                source: {
                    const d = Wallpapers.display(root.path);
                    return d ? (d.startsWith("/") ? "file://" + d : d) : "";
                }
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.ceil(win.width * win.dpr), Math.ceil(win.height * win.dpr))
                asynchronous: true
                smooth: true
            }

            // what the shaking scene uncovers at its edges
            Rectangle {
                anchors.fill: parent
                visible: win.playing && win.power > 0
                color: win.ink
            }
            Item {
                id: stage
                width: parent.width
                height: parent.height
                x: win.jolt.x
                y: win.jolt.y
                visible: win.playing

                ShaderEffect {
                    anchors.fill: parent
                    property var frozenTex: frame
                    property var wallTex: wall
                    property real t: win.t
                    property real barNow: win.barNow
                    property real slant: win.slant
                    property real seed: root.serial % 17
                    property size resolution: Qt.size(width, height)
                    property color accent: root.accentFrom
                    property color accentNew: Theme.accent
                    fragmentShader: Qt.resolvedUrl("../../shaders/gate_scene.frag.qsb")
                }

                // the upper gate: the chapter, cut out, and the picture's name typed after it;
                // the words sit by the gate's cut and ride out with it
                Item {
                    width: parent.width
                    height: win.barNow * parent.height
                    clip: true
                    // shown all along, hidden by opacity: made visible again, its glyphs were set
                    // up anew and the frame stalled anyway
                    visible: win.room > 30 && win.playing
                    opacity: win.warm ? 0.004 : win.t > 0.8 ? 1 : 0
                    Column {
                        x: win.room * 0.6 + win.cs * 4
                        anchors.verticalCenter: parent.bottom
                        anchors.verticalCenterOffset: -(12 * win.cs + win.room / 2)
                        spacing: win.cs
                        Ransom {
                            text: root.chapter
                            size: win.room * 0.26
                            from: 0.85
                            step: 0.045
                        }
                        Text {
                            text: win.warm ? root.title : root.title.slice(0, Math.max(0, Math.floor((win.t - 0.85) / 0.045) - root.chapter.length))
                            color: win.glow
                            font.family: Theme.fontTitle
                            font.pixelSize: win.room * 0.36
                            font.letterSpacing: win.cs * 0.5
                        }
                    }
                }
                // the lower gate: the tip, its label cut out of magazines, the line typed fast
                Item {
                    y: parent.height - height
                    width: parent.width
                    height: win.barNow * parent.height
                    clip: true
                    visible: win.room > 30 && win.playing
                    opacity: win.warm ? 0.004 : win.t > 1.45 ? 1 : 0
                    Row {
                        x: win.room * 0.6 + win.cs * 4
                        anchors.verticalCenter: parent.top
                        anchors.verticalCenterOffset: 12 * win.cs + win.room / 2
                        spacing: win.cs * 4
                        Ransom {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.tip.label || ""
                            size: win.room * 0.32
                            from: 1.5
                            step: 0.07
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.warm ? root.tip.text || "" : (root.tip.text || "").slice(0, Math.max(0, Math.floor((win.t - 1.9) / 0.018)))
                            color: win.glow
                            font.family: Theme.fontBody
                            font.pixelSize: win.room * 0.27
                        }
                    }
                }

                // the title card: the picture's name stamped letter by letter on the slabs,
                // tilted, the chapter over it; it leaves with them
                Column {
                    id: card
                    readonly property real out: Math.pow(win.clamp01((win.t - 2.8) / 0.26), 3)
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -out * parent.width * 1.2
                    rotation: -6
                    spacing: win.cs * 3
                    visible: win.playing
                    opacity: win.warm ? 0.004 : win.t > 2.0 && win.t < 3.2 ? 1 : 0
                    Ransom {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.chapter
                        size: card.parent.height * 0.035
                        from: 2.02
                        step: 0.03
                        onField: true
                    }
                    Ransom {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.title.slice(0, 16)
                        size: card.parent.height * 0.085
                        from: 2.12
                        step: 0.05
                        onField: true
                        pop: 1.8
                    }
                }
            }

            // a word of letters cut from different papers, each tilted its own way, popping in;
            // onField: on the card's colour, so none of the papers is that colour
            component Ransom: Row {
                id: ransom
                property string text
                property real size: 20
                property real from: 0
                property real step: 0.05
                property bool onField: false
                property real pop: 1.35
                readonly property color paper: onField ? Theme.accent : root.accent
                spacing: win.cs * 0.5
                Repeater {
                    model: ransom.text.length
                    Rectangle {
                        id: chip
                        required property int index
                        readonly property real h: {
                            const v = Math.sin((index + 1) * 12.9898 + ransom.text.length * 78.233) * 43758.5453;
                            return v - Math.floor(v);
                        }
                        readonly property int look: Math.floor(h * 3)
                        readonly property real age: win.t - ransom.from - index * ransom.step
                        readonly property string ch: ransom.text.charAt(index)
                        readonly property color dark: Theme.mix("#000000", ransom.paper, 0.12)
                        readonly property color light: Theme.mix(ransom.paper, "#ffffff", 0.7)
                        opacity: age > 0 || win.warm ? 1 : 0
                        width: ch === " " ? ransom.size * 0.4 : letter.implicitWidth + win.cs * 2
                        height: ransom.size * 1.25
                        color: ch === " " ? "transparent" : look === 0 ? (ransom.onField ? "#ffffff" : ransom.paper) : look === 1 ? light : dark
                        // the dark paper needs its edge on a dark gate
                        border.width: look === 2 && ch !== " " ? Math.max(1, win.cs / 2) : 0
                        border.color: ransom.onField ? "#ffffff" : ransom.paper
                        rotation: (h - 0.5) * 16
                        y: (h - 0.5) * ransom.size * 0.25
                        scale: age < 0.06 && !win.warm ? ransom.pop : 1
                        antialiasing: false
                        Text {
                            id: letter
                            anchors.centerIn: parent
                            text: chip.ch === " " ? "" : chip.ch
                            color: chip.look === 2 ? chip.light : chip.look === 0 && ransom.onField ? ransom.paper : chip.dark
                            font.family: chip.index % 2 ? Theme.fontTitle : Theme.fontMono
                            font.pixelSize: ransom.size * (0.9 + chip.h * 0.25)
                            font.bold: true
                        }
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
