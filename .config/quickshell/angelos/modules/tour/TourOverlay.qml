pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Dims the screen, cuts a pixel circle around the current element and explains it. The screen
// itself comes closer: a picture of it (grim, taken once as the tips start — Quickshell's
// ScreencopyView crashes) is shown through a camera that flies to each element along a cubic
// Bézier curve, zooming in on it and a little out on the way; the key tips and the end fly back
// to the whole screen. Calm or no motion (Motion.still), or no picture: the screen as it is.
//
// Nothing but the picture moves while it flies: the circle, the ring and the card are placed
// once per tip where the camera will rest, the circle is cut when it lands.
//
// A tip shows the thing, not only tells: the desktop tip draws the right-click menu inside its
// circle; a key tip presses its keys and plays what they do on a stage above the card — the
// launcher narrowing a list as a name is typed, the clipboard, Settings, niri's overview, the
// theme flipping, a region picked and shot, a voice typing, niri's cheat sheet. Drawn small,
// not opened for real: the real ones take the keyboard and the focused screen, and the menu
// (a grabbing popup) only opens once the desktop has had input.
PanelWindow {
    id: win

    readonly property var step: Tour.current
    readonly property var tgt: step ? Tour.target(step.key) : null
    readonly property bool keyStep: !!step && (step.key === "end" || step.key.startsWith("keys:"))
    readonly property string demo: step && step.demo ? step.demo : ""
    readonly property bool stageDemo: keyStep && demo !== "" && demo !== "shot"
    readonly property real dimAlpha: 0.55
    // the tour's screen (Tour.start: the main one); its elements are the ones on it
    screen: Shell.screenByName(Tour.screen) || Shell.mainScreenFor("") || Shell.focusedScreen
    visible: Tour.running && !!step && shotSettled
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-tour"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: interface tips: a click goes on
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    // ---- the picture of the screen, taken before the overlay shows ----
    readonly property string shotPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/tour-" + Tour.screen + ".png"
    property bool shotSettled: false
    property bool shotOk: false
    readonly property bool zooming: shotOk && !Motion.still
    Process {
        id: grab
        onExited: code => {
            win.shotOk = code === 0;
            win.shotSettled = true;
        }
    }
    // no picture in time (no grim, a stand-in screen in the tests): the tips without the zoom
    Timer {
        id: grabLate
        interval: 1500
        onTriggered: win.shotSettled = true
    }
    Connections {
        target: Tour
        function onRunningChanged() {
            if (Tour.running) {
                win.shotOk = false;
                win.shotSettled = false;
                grab.command = ["sh", "-c", 'mkdir -p "${1%/*}" && command -v grim >/dev/null && exec grim -o "$2" "$1"; exit 1', "sh", win.shotPath, Tour.screen];
                grab.running = true;
                grabLate.restart();
            } else {
                win.camX = win.width / 2;
                win.camY = win.height / 2;
                win.camZ = 1;
            }
        }
    }

    // ---- what a tip shows ----
    // the keys of a key tip press one by one (pressed = how many so far); the stage is up from
    // the start, the keys only say how it was called
    property int pressed: 0
    Timer {
        id: pressT
        interval: Math.max(1, Motion.ms(170))
        repeat: true
        onTriggered: {
            win.pressed++;
            if (!win.step || !win.step.keys || win.pressed >= win.step.keys.length)
                stop();
        }
    }
    function pressKeys() {
        pressT.stop();
        pressed = 0;
        if (!visible || !step)
            return;
        if (step.keys && step.keys.length && !Motion.still)
            pressT.restart();
        else
            pressed = step.keys ? step.keys.length : 0;
    }
    onStepChanged: pressKeys()
    onVisibleChanged: if (visible) {
        keys.forceActiveFocus();
        pressKeys();
    }

    // the element's rect on the screen (unzoomed)
    readonly property rect hole: {
        Tour.revision;
        if (!Tour.running || !step || keyStep)
            return Qt.rect(width / 2, height / 2, 0, 0);
        if (step.key === "desktop")
            return Qt.rect(width / 2 - Theme.u * 60, height / 2 - Theme.u * 60, Theme.u * 120, Theme.u * 120);
        // registered items can already be gone (a reload tears the bars down first)
        if (!tgt || !tgt.item || !tgt.window || typeof tgt.item.mapToItem !== "function" || !tgt.window.contentItem)
            return Qt.rect(width / 2, height / 2, 0, 0);
        const w = tgt.window, it = tgt.item;
        const p = it.mapToItem(w.contentItem, 0, 0);
        // layer-shell doesn't tell us where the bar sits; derive it from its anchors
        const wy = w.anchors && w.anchors.bottom && !w.anchors.top ? height - w.height - (w.margins ? w.margins.bottom : 0) : (w.margins ? w.margins.top : 0);
        const wx = w.anchors && w.anchors.left && w.anchors.right ? 0 : (width - w.width) / 2;
        return Qt.rect(wx + p.x, wy + p.y, it.width, it.height);
    }

    // ---- the camera: the point of the screen in the middle of the view, and how close ----
    property real camX: width / 2
    property real camY: height / 2
    property real camZ: 1
    // where it goes for this step: close enough that the element is about a fifth of the
    // screen, in whole steps only (2×, 3×: at rest every pixel of the picture is a square of
    // pixels, as angelOS draws), never past the picture's edges (an element at the edge keeps
    // its place at the edge, its ring cut there); the key tips and the desktop stay at the
    // whole screen
    readonly property var aim: {
        if (!zooming || keyStep || step && step.key === "desktop" || hole.width <= 0)
            return Qt.vector3d(width / 2, height / 2, 1);
        const z = Math.max(1, Math.min(3, Math.round(Math.min(width / Math.max(1, hole.width * 5), height / Math.max(1, hole.height * 5)))));
        const hx = width / (2 * z), hy = height / (2 * z);
        const x = Math.max(hx, Math.min(width - hx, hole.x + hole.width / 2));
        const y = Math.max(hy, Math.min(height - hy, hole.y + hole.height / 2));
        return Qt.vector3d(x, y, z);
    }
    // the flight: from where the camera is to the aim, along a cubic Bézier (its handles bent
    // sideways, so it swoops rather than slides), zooming out a little half-way
    property var from: Qt.vector3d(width / 2, height / 2, 1)
    property var to: Qt.vector3d(width / 2, height / 2, 1)
    property real fly: 1
    onAimChanged: {
        from = Qt.vector3d(camX, camY, camZ);
        to = aim;
        if (!zooming) {
            flight.stop();
            camX = aim.x;
            camY = aim.y;
            camZ = aim.z;
            return;
        }
        flight.restart();
    }
    readonly property int flightMs: Motion.ms(700)
    NumberAnimation {
        id: flight
        target: win
        property: "fly"
        from: 0
        to: 1
        duration: win.flightMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.45, 0.0, 0.2, 1.0, 1.0, 1.0]
    }
    function bez(a, b, c, d, t) {
        const u = 1 - t;
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
    }
    onFlyChanged: {
        const t = fly, dx = to.x - from.x, dy = to.y - from.y;
        // the handles: a third of the way, pushed off the straight line by a fifth of it
        const nx = -dy * 0.2, ny = dx * 0.2;
        camX = bez(from.x, from.x + dx / 3 + nx, from.x + dx * 2 / 3 + nx, to.x, t);
        camY = bez(from.y, from.y + dy / 3 + ny, from.y + dy * 2 / 3 + ny, to.y, t);
        const pull = Math.min(0.35, Math.hypot(dx, dy) / Math.max(1, width) * 0.6);
        camZ = Math.max(1, from.z + (to.z - from.z) * t - pull * Math.sin(Math.PI * t));
    }
    readonly property bool flying: flight.running
    // the element's middle and ring where the camera comes to rest (the aim, not the camera
    // now): the circle, the ring and the card are placed once per tip and stay put; while
    // the picture flies only the dim shows, the circle is cut when it lands
    readonly property real cx: (hole.x + hole.width / 2 - aim.x) * aim.z + width / 2
    readonly property real cy: (hole.y + hole.height / 2 - aim.y) * aim.z + height / 2
    readonly property real radius: Math.max(Theme.u * 14, Math.sqrt(hole.width * hole.width + hole.height * hole.height) / 2 * aim.z + Theme.u * 6)
    // a slow beat for the stage (the cursor, the microphone's ring), not for the circle
    property real pulse: 0
    SequentialAnimation on pulse {
        running: win.visible && !Motion.still && win.stageDemo
        alwaysRunToEnd: true
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: Motion.ms(900)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: Motion.ms(900)
            easing.type: Easing.InOutSine
        }
    }

    // ---- the region shot (keys:shot): picked from one corner to the other, shot with a flash,
    // flown small to the corner where the clipboard toast lands; then again ----
    property real selT: 0
    property real selFlash: 0
    property real selFly: 0
    SequentialAnimation {
        running: win.demo === "shot" && win.visible && !Motion.still
        loops: Animation.Infinite
        onRunningChanged: if (!running) {
            win.selT = 1;
            win.selFly = 0;
            win.selFlash = 0;
        }
        ScriptAction {
            script: {
                win.selT = 0;
                win.selFly = 0;
                win.selFlash = 0;
            }
        }
        PauseAnimation {
            duration: 500
        }
        NumberAnimation {
            target: win
            property: "selT"
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: 250
        }
        NumberAnimation {
            target: win
            property: "selFlash"
            from: 0.7
            to: 0
            duration: 350
        }
        PauseAnimation {
            duration: 200
        }
        NumberAnimation {
            target: win
            property: "selFly"
            from: 0
            to: 1
            duration: 500
            easing.type: Easing.InCubic
        }
        PauseAnimation {
            duration: 900
        }
    }
    readonly property rect sel: {
        const ax = width * 0.16, ay = height * 0.2;
        const w = width * 0.62 * selT, h = height * 0.34 * selT;
        const s = Theme.u * 24;
        const tx = width - Theme.u * 10 - s, ty = height - Theme.u * 16 - s;
        const f = selFly;
        return Qt.rect(ax + (tx - ax) * f, ay + (ty - ay) * f, w + (s - w) * f, h + (s - h) * f);
    }

    onCxChanged: dim.requestPaint()
    onCyChanged: dim.requestPaint()
    onRadiusChanged: dim.requestPaint()
    onFlyingChanged: dim.requestPaint()
    onKeyStepChanged: dim.requestPaint()
    onSelChanged: dim.requestPaint()
    onDemoChanged: dim.requestPaint()

    // the picture through the camera, pixel for pixel (no smoothing: angelOS's pixels); at
    // the whole screen the live one shows instead
    Image {
        id: shotImg
        visible: win.zooming && status === Image.Ready && (win.camZ > 1 || flight.running)
        x: Math.round(win.width / 2 - win.camX * win.camZ)
        y: Math.round(win.height / 2 - win.camY * win.camZ)
        width: win.width * win.camZ
        height: win.height * win.camZ
        source: win.shotOk ? "file://" + win.shotPath + "?" + Date.now() : ""
        cache: false
        smooth: false
        mipmap: false
        asynchronous: false
        fillMode: Image.Stretch
    }

    Canvas {
        id: dim
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Qt.rgba(0, 0, 0, win.dimAlpha);
            ctx.fillRect(0, 0, width, height);
            if (!win.step)
                return;
            const b = Theme.u * 2;
            if (win.demo === "shot") {
                // the region being picked: cut out, a pixel dashed frame around it
                const r = win.sel;
                if (r.width < b || r.height < b)
                    return;
                ctx.globalCompositeOperation = "destination-out";
                ctx.fillRect(Math.round(r.x / b) * b, Math.round(r.y / b) * b, Math.round(r.width / b) * b, Math.round(r.height / b) * b);
                ctx.globalCompositeOperation = "source-over";
                ctx.fillStyle = Theme.accent;
                const x0 = Math.round(r.x / b) * b - b, y0 = Math.round(r.y / b) * b - b;
                const x1 = Math.round((r.x + r.width) / b) * b, y1 = Math.round((r.y + r.height) / b) * b;
                for (let x = x0; x <= x1; x += b * 2) {
                    ctx.fillRect(x, y0, b, b);
                    ctx.fillRect(x, y1, b, b);
                }
                for (let y = y0; y <= y1; y += b * 2) {
                    ctx.fillRect(x0, y, b, b);
                    ctx.fillRect(x1, y, b, b);
                }
                return;
            }
            if (win.keyStep || win.flying)
                return;
            // blocky circle: punch it out, then draw a pixel ring
            const r = win.radius, cx = win.cx, cy = win.cy;
            ctx.globalCompositeOperation = "destination-out";
            for (let y = -r; y <= r; y += b)
                for (let x = -r; x <= r; x += b)
                    if (x * x + y * y <= r * r)
                        ctx.fillRect(Math.round((cx + x) / b) * b, Math.round((cy + y) / b) * b, b, b);
            ctx.globalCompositeOperation = "source-over";
            const rr = r + b;
            ctx.fillStyle = Theme.accent;
            for (let a = 0; a < 360; a += 3) {
                const t = a * Math.PI / 180;
                ctx.fillRect(Math.round((cx + Math.cos(t) * rr) / b) * b, Math.round((cy + Math.sin(t) * rr) / b) * b, b, b);
            }
        }
    }
    // the shot's flash
    Rectangle {
        visible: win.demo === "shot" && win.selFlash > 0
        x: win.sel.x
        y: win.sel.y
        width: win.sel.width
        height: win.sel.height
        color: "white"
        opacity: win.selFlash
    }

    // clicks outside the card do nothing (the tour is modal), inside the hole go to "next"
    MouseArea {
        anchors.fill: parent
        onClicked: m => {
            const dx = m.x - win.cx, dy = m.y - win.cy;
            if (!win.keyStep && !win.flying && dx * dx + dy * dy <= win.radius * win.radius)
                Tour.next();
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape)
                Tour.stop();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                Tour.next();
            else if (e.key === Qt.Key_Left)
                Tour.back();
            e.accepted = true;
        }
    }

    component Keycap: PxBox {
        id: keycap
        property string label: ""
        property bool down: false
        width: cap.implicitWidth + Theme.u * 8
        height: cap.implicitHeight + Theme.u * 5
        color: down ? Theme.mix(Theme.face, Theme.accent, 0.5) : Theme.mix(Theme.face, Theme.accent, 0.2)
        sunken: down
        PxText {
            id: cap
            anchors.centerIn: parent
            font.bold: true
            text: keycap.label
        }
    }
    // a line of a small list: an icon, a name, the chosen one lit
    component MiniRow: Item {
        id: miniRow
        property string icon: ""
        property string label: ""
        property bool chosen: false
        width: parent ? parent.width : 0
        height: Theme.u * 9
        PxBox {
            anchors.fill: parent
            visible: miniRow.chosen
            color: Theme.mix(Theme.face, Theme.accent, 0.3)
            outline: false
        }
        Row {
            x: Theme.u * 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 3
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: miniRow.icon
                pixel: Theme.u * 2
                visible: miniRow.icon !== ""
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: miniRow.label
                font.bold: miniRow.chosen
            }
        }
    }

    // the desktop tip: the right-click menu as it looks, drawn in the circle
    PxBox {
        id: deskScene
        visible: win.demo === "desktop" && !win.flying
        width: Theme.u * 56
        height: deskList.height + Theme.u * 6
        x: Math.round(win.cx - width / 2)
        y: Math.round(win.cy - height / 2)
        color: Theme.face
        shadow: true
        Column {
            id: deskList
            x: Theme.u * 3
            y: Theme.u * 3
            width: parent.width - Theme.u * 6
            spacing: 0
            Repeater {
                model: [[I18n.t("Вид", "View"), true], [I18n.t("Создать", "New"), true], [I18n.t("Обои", "Wallpaper"), true], [I18n.t("Открыть", "Open"), true], [I18n.t("Персонализация", "Personalize"), false], [I18n.t("Показать больше", "Show more"), true]]
                MiniRow {
                    required property var modelData
                    required property int index
                    label: modelData[0] + (modelData[1] ? "  ▸" : "")
                    chosen: index === 0
                }
            }
        }
    }

    // ---- the stage: what a key tip plays, drawn small ----
    Item {
        id: stage
        visible: win.stageDemo
        width: Math.round(Math.min(win.width - Theme.u * 12, Theme.u * 150))
        height: stageBox.height
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height * 0.34 - height / 2)

        PxBox {
            id: stageBox
            width: parent.width
            height: stageInner.height + Theme.pad * 2
            color: Theme.face
            Item {
                id: stageInner
                x: Theme.pad
                y: Theme.pad
                width: parent.width - Theme.pad * 2
                height: {
                    for (const s of [launcherScene, clipScene, settingsScene, overviewScene, themeScene, voiceScene, keysScene])
                        if (s.visible)
                            return s.height;
                    return 0;
                }

                // the launcher: a name typed, the list narrowing to it, the first one ready
                Column {
                    id: launcherScene
                    visible: win.demo === "launcher"
                    width: parent.width
                    spacing: Theme.u * 3
                    readonly property string full: "tele"
                    property int n: 0
                    property int hold: 0
                    readonly property var apps: [["Telegram", "chat"], ["Terminal", "terminal"], [I18n.t("Текстовый редактор", "Text editor"), "window"], [I18n.t("Файлы", "Files"), "folder"], [I18n.t("Музыка", "Music"), "music"]]
                    readonly property var rows: apps.filter(a => a[0].toLowerCase().startsWith(full.slice(0, n)))
                    Timer {
                        interval: 450
                        repeat: true
                        running: launcherScene.visible && win.visible && !Motion.still
                        onRunningChanged: if (!running)
                            launcherScene.n = launcherScene.full.length
                        onTriggered: {
                            if (launcherScene.n < launcherScene.full.length)
                                launcherScene.n++;
                            else if (launcherScene.hold < 4)
                                launcherScene.hold++;
                            else {
                                launcherScene.n = 0;
                                launcherScene.hold = 0;
                            }
                        }
                    }
                    PxText {
                        text: I18n.t("Что открыть?", "What to open?")
                        kind: "title"
                        color: Theme.dark ? Theme.accent : Theme.edge
                    }
                    PxBox {
                        width: parent.width
                        height: query.implicitHeight + Theme.u * 6
                        sunken: true
                        color: Theme.mix(Theme.face, Theme.edge, 0.08)
                        PxText {
                            id: query
                            x: Theme.u * 3
                            y: Theme.u * 3
                            text: launcherScene.full.slice(0, launcherScene.n) + (win.pulse < 0.5 ? "▮" : " ")
                        }
                    }
                    Repeater {
                        model: launcherScene.rows
                        MiniRow {
                            required property var modelData
                            required property int index
                            icon: modelData[1]
                            label: modelData[0]
                            chosen: index === 0
                        }
                    }
                }

                // the clipboard: what was copied, newest first, a click puts one back
                Column {
                    id: clipScene
                    visible: win.demo === "clipboard"
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        text: I18n.t("Буфер обмена", "Clipboard")
                        kind: "title"
                        color: Theme.dark ? Theme.accent : Theme.edge
                    }
                    MiniRow {
                        icon: "image"
                        label: I18n.t("снимок экрана", "a screenshot")
                        chosen: true
                    }
                    MiniRow {
                        icon: "chat"
                        label: "https://github.com/MixaDoDs/AngelOS-Dotfiles"
                    }
                    MiniRow {
                        icon: "chat"
                        label: I18n.t("увидимся в восемь", "see you at eight")
                    }
                    MiniRow {
                        icon: "terminal"
                        label: "paru -Syu"
                    }
                }

                // Settings: the sections, a search on top, a few switches
                Row {
                    id: settingsScene
                    visible: win.demo === "settings"
                    width: parent.width
                    spacing: Theme.u * 4
                    Column {
                        width: Math.round(parent.width * 0.3)
                        spacing: Theme.u * 1
                        Repeater {
                            model: [I18n.t("Оформление", "Appearance"), I18n.t("Панель задач", "Taskbar"), I18n.t("Клавиатура", "Keyboard"), I18n.t("Мышь", "Mouse"), I18n.t("Обои", "Wallpaper"), I18n.t("Экран", "Screen")]
                            MiniRow {
                                required property string modelData
                                required property int index
                                label: modelData
                                chosen: index === 0
                            }
                        }
                    }
                    Column {
                        width: parent.width - Math.round(parent.width * 0.3) - Theme.u * 4
                        spacing: Theme.u * 3
                        PxBox {
                            width: parent.width
                            height: searchLine.implicitHeight + Theme.u * 6
                            sunken: true
                            color: Theme.mix(Theme.face, Theme.edge, 0.08)
                            Row {
                                x: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.u * 2
                                PxIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "search"
                                    pixel: Theme.u * 2
                                }
                                PxText {
                                    id: searchLine
                                    text: I18n.t("найти настройку…", "find a setting…")
                                    dim: true
                                }
                            }
                        }
                        Repeater {
                            model: [[I18n.t("Акцент из обоев", "Accent from the wallpaper"), true], [I18n.t("Живые обои", "Live wallpaper"), true], [I18n.t("Лирика на панели", "Lyrics on the bar"), false]]
                            Item {
                                id: switchRow
                                required property var modelData
                                width: parent.width
                                height: Theme.u * 9
                                PxText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: switchRow.modelData[0]
                                }
                                PxBox {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.u * 12
                                    height: Theme.u * 6
                                    sunken: true
                                    color: switchRow.modelData[1] ? Theme.accent : Theme.mix(Theme.face, Theme.edge, 0.15)
                                    Rectangle {
                                        x: switchRow.modelData[1] ? parent.width - width - Theme.u : Theme.u
                                        y: Theme.u
                                        width: Theme.u * 4
                                        height: Theme.u * 4
                                        color: Theme.face
                                    }
                                }
                            }
                        }
                    }
                }

                // niri's overview: the workspaces side by side, small, their windows in them
                Row {
                    id: overviewScene
                    visible: win.demo === "overview"
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: [[0.5, 0.45], [0.62, 0], [0.4, 0.5]]
                        Item {
                            id: ws
                            required property var modelData
                            required property int index
                            width: Math.round((overviewScene.width - Theme.u * 8) / 3)
                            height: Math.round(width * 0.6)
                            PxBox {
                                anchors.fill: parent
                                sunken: true
                                color: ws.index === 1 ? Theme.mix(Theme.face, Theme.accent, 0.25) : Theme.mix(Theme.face, Theme.edge, 0.1)
                            }
                            // the windows: two of them, the first one's width then the other's
                            Rectangle {
                                x: Theme.u * 2
                                y: Theme.u * 2
                                width: Math.round((parent.width - Theme.u * 6) * ws.modelData[0])
                                height: parent.height - Theme.u * 4
                                color: Theme.mix(Theme.face, Theme.text, 0.25)
                                Rectangle {
                                    width: parent.width
                                    height: Theme.u * 2
                                    color: Theme.accent
                                }
                            }
                            Rectangle {
                                visible: ws.modelData[1] > 0
                                x: Theme.u * 4 + Math.round((parent.width - Theme.u * 6) * ws.modelData[0])
                                y: Theme.u * 2
                                width: Math.round((parent.width - Theme.u * 6) * ws.modelData[1])
                                height: parent.height - Theme.u * 4
                                color: Theme.mix(Theme.face, Theme.text, 0.18)
                                Rectangle {
                                    width: parent.width
                                    height: Theme.u * 2
                                    color: Theme.mix(Theme.accent, Theme.face, 0.5)
                                }
                            }
                            PxText {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: Theme.u * 2
                                kind: "tiny"
                                text: ws.index + 1
                                dim: true
                            }
                        }
                    }
                }

                // the theme: a picture of the shell in the dark palette, the light one over it
                // now and then; the sun and the moon say which
                Item {
                    id: themeScene
                    visible: win.demo === "theme"
                    width: parent.width
                    height: Math.round(width * 0.5)
                    ThemePic {
                        anchors.fill: parent
                        pal: Theme.paletteFor(true)
                    }
                    ThemePic {
                        id: lightPic
                        anchors.fill: parent
                        pal: Theme.paletteFor(false)
                        opacity: 0
                        SequentialAnimation on opacity {
                            running: themeScene.visible && win.visible && !Motion.still
                            loops: Animation.Infinite
                            PauseAnimation {
                                duration: 1100
                            }
                            NumberAnimation {
                                to: 1
                                duration: 350
                            }
                            PauseAnimation {
                                duration: 1100
                            }
                            NumberAnimation {
                                to: 0
                                duration: 350
                            }
                        }
                    }
                    PxIcon {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.u * 3
                        name: lightPic.opacity > 0.5 ? "sun" : "moon"
                        pixel: Theme.u * 3
                    }
                }

                // a voice: the microphone listens, the words type themselves where the cursor is
                Row {
                    id: voiceScene
                    visible: win.demo === "voice"
                    width: parent.width
                    spacing: Theme.u * 5
                    readonly property string full: I18n.t("Привет! Этот текст напечатан голосом.", "Hi! This text was typed by voice.")
                    property int n: 0
                    property int hold: 0
                    Timer {
                        interval: 70
                        repeat: true
                        running: voiceScene.visible && win.visible && !Motion.still
                        onRunningChanged: if (!running)
                            voiceScene.n = voiceScene.full.length
                        onTriggered: {
                            if (voiceScene.n < voiceScene.full.length)
                                voiceScene.n++;
                            else if (voiceScene.hold < 22)
                                voiceScene.hold++;
                            else {
                                voiceScene.n = 0;
                                voiceScene.hold = 0;
                            }
                        }
                    }
                    Item {
                        width: Theme.u * 16
                        height: Theme.u * 16
                        anchors.verticalCenter: parent.verticalCenter
                        // the ring breathes while it listens
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * (voiceScene.n < voiceScene.full.length ? 0.8 + 0.2 * win.pulse : 0.7)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: Theme.u
                            border.color: voiceScene.n < voiceScene.full.length ? Theme.accent : Theme.edge
                        }
                        PxIcon {
                            anchors.centerIn: parent
                            name: "mic"
                            pixel: Theme.u * 3
                        }
                    }
                    PxBox {
                        width: parent.width - Theme.u * 21
                        height: typed.implicitHeight + Theme.u * 6
                        anchors.verticalCenter: parent.verticalCenter
                        sunken: true
                        color: Theme.mix(Theme.face, Theme.edge, 0.08)
                        PxText {
                            id: typed
                            x: Theme.u * 3
                            y: Theme.u * 3
                            width: parent.width - Theme.u * 6
                            wrapMode: Text.Wrap
                            text: voiceScene.full.slice(0, voiceScene.n) + (win.pulse < 0.5 || voiceScene.n < voiceScene.full.length ? "▮" : " ")
                        }
                    }
                }

                // niri's cheat sheet, the first lines of it
                Column {
                    id: keysScene
                    visible: win.demo === "keys"
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        text: I18n.t("Сочетания клавиш niri", "niri's shortcuts")
                        kind: "title"
                        color: Theme.dark ? Theme.accent : Theme.edge
                    }
                    Repeater {
                        model: [[["Mod", "Space"], I18n.t("Программы", "Apps")], [["Mod", "Tab"], I18n.t("Обзор столов и окон", "Workspaces and windows")], [["Mod", "S"], I18n.t("Настройки", "Settings")], [["Mod", "V"], I18n.t("Буфер обмена", "Clipboard")], [["Mod", "Q"], I18n.t("Закрыть окно", "Close the window")], [["Mod", "F"], I18n.t("Во весь экран", "Full screen")], [["Mod", "1…9"], I18n.t("Столы", "Workspaces")], [["Mod", "Shift", "S"], I18n.t("Скриншот области", "Region screenshot")]]
                        Row {
                            id: bind
                            required property var modelData
                            spacing: Theme.u * 3
                            Row {
                                spacing: Theme.u * 1
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: bind.modelData[0]
                                    Keycap {
                                        required property string modelData
                                        label: modelData
                                    }
                                }
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: bind.modelData[1]
                            }
                        }
                    }
                }
            }
        }
    }

    PxWindow {
        id: card
        width: Theme.u * 150
        height: titleHeight + body.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: I18n.exe("tips") + " · " + (Tour.step + 1) + "/" + Tour.active.length
        icon: "info"
        compact: true
        onCloseClicked: Tour.stop()
        // beside the circle: above it for the bottom bar, below it otherwise; a key tip under
        // its stage, under the region being shot; the end in the middle. It glides there at
        // the flight's own pace, once per tip
        x: Math.max(Theme.u * 6, Math.min(win.width - width - Theme.u * 6, win.keyStep ? (win.width - width) / 2 : win.cx - width / 2))
        y: win.keyStep ? (win.stageDemo ? stage.y + stage.height + Theme.u * 10 : win.demo === "shot" ? Math.min(win.height - height - Theme.u * 6, Math.round(win.height * 0.62)) : (win.height - height) / 2) : (win.cy > win.height / 2 ? Math.max(Theme.u * 6, win.cy - win.radius - height - Theme.u * 10) : Math.min(win.height - height - Theme.u * 6, win.cy + win.radius + Theme.u * 10))
        Behavior on x {
            NumberAnimation {
                duration: win.flightMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.45, 0.0, 0.2, 1.0, 1.0, 1.0]
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: win.flightMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.45, 0.0, 0.2, 1.0, 1.0, 1.0]
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.u * 4
            PxText {
                text: win.step ? win.step.title : ""
                kind: "title"
                color: Theme.dark ? Theme.accent : Theme.edge
            }
            // the keys of a key tip, as keycaps; they press one by one
            Row {
                visible: !!win.step && !!win.step.keys
                spacing: Theme.u * 2
                Repeater {
                    model: win.step && win.step.keys ? win.step.keys : []
                    Keycap {
                        required property int index
                        required property string modelData
                        label: modelData
                        down: index < win.pressed
                    }
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: win.step ? win.step.text : ""
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.u * 3
                PxButton {
                    compact: true
                    text: I18n.t("Пропустить", "Skip")
                    visible: Tour.step + 1 < Tour.active.length
                    onClicked: Tour.stop()
                }
                PxButton {
                    compact: true
                    text: "◂"
                    enabled: Tour.step > 0
                    onClicked: Tour.back()
                }
                PxButton {
                    compact: true
                    accent: true
                    text: Tour.step + 1 < Tour.active.length ? I18n.t("Дальше ▸", "Next ▸") : I18n.t("Готово", "Done")
                    onClicked: Tour.next()
                }
            }
        }
    }

    RightClickGuard {}
}
