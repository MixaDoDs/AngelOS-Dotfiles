pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// serp-skin: Serpantinum's top bar — floating islands over the wallpaper. Leading: the angel
// (Start), the desks as pills, now playing. Centre: angelOS's Halo when it is on, else the clock
// island (hours big, minutes over seconds, the weather). Trailing: tray, input, network, sound,
// battery, notifications, quick actions. The islands open the skin's panels (Serp.panel).
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name

    readonly property int gap: Serp.barGap
    readonly property int pillH: Serp.barPill
    readonly property real h: Serp.barHeight
    readonly property string haloZoneMode: Config.halo.windows === "maximized" && !WindowConfig.floatAll ? "bar" : Config.halo.windows || "bar"
    readonly property int haloZone: Halo.on(screenName) && Config.halo.reserve && haloZoneMode === "bar" ? Halo.strip : 0
    readonly property bool haloHere: Halo.on(screenName)

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: h
    // at the very top edge whatever else keeps a zone there (the Halo's strip); the room for
    // windows is kept by SerpZone (the part of the bar the Halo's strip doesn't cover already)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-serpbar"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        Region {
            item: leftIsland
        }
        Region {
            item: centerIsland.visible ? centerIsland : null
        }
        Region {
            item: rightIsland
        }
    }
    BackgroundEffect.blurRegion: Serp.blurOn ? blurRegion : null
    Region {
        id: blurRegion
        Region {
            item: leftIsland
            radius: Serp.radius
        }
        Region {
            item: centerIsland.visible ? centerIsland : null
            radius: Serp.radius
        }
        Region {
            item: rightIsland
            radius: Serp.radius
        }
    }

    // the wallpaper in screen space, for the liquid glass (Serp.glassOn)
    SerpBackdrop {
        id: glassBack
        screenName: win.screenName
    }
    // an island: Serpantinum's liquid glass, or the flat plate with the glass off (SGlass)
    component Island: SGlass {
        id: isl
        backdrop: glassBack
        y: win.gap
        height: win.pillH
        radius: Serp.radius
        hover: islHover.hovered ? 1 : 0
        Behavior on hover {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
        HoverHandler {
            id: islHover
            onPointChanged: isl.cursor = point.position
        }
        Behavior on width {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
    }
    component Sep: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: Serp.px(14)
        color: Serp.line
    }

    // ---- leading ----
    Island {
        id: leftIsland
        x: win.gap * 2
        width: leftRow.implicitWidth + Serp.px(8)

        Row {
            id: leftRow
            x: Serp.px(4)
            height: win.pillH
            spacing: Serp.px(2)

            SButton {
                id: startBtn
                anchors.verticalCenter: parent.verticalCenter
                active: Shell.startScreen === win.screenName
                SIcon {
                    name: Angel.demon || Story.marked ? "angel-horns" : "angel"
                    size: Serp.px(17)
                    color: Serp.accent
                }
                onClicked: Shell.toggleStart(win.screenName)
                Component.onCompleted: Shell.registerStartButton(win.screenName, startBtn, win)
            }

            // angelOS's clean desk 0 (angel-niri, Niri.zeroDesk): a faint "+" before the pills, lit
            // while it is the one shown; a window put there makes it desk 1
            SButton {
                id: zeroBtn
                readonly property var desk: Niri.zeroDesk(win.screenName)
                readonly property bool lit: !!desk && desk.is_active
                visible: !!desk
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Serp.px(22)
                implicitHeight: Serp.px(22)
                active: lit
                SIcon {
                    name: "plus"
                    size: Serp.px(13)
                    stroke: 2.4
                    color: zeroBtn.lit ? Serp.accent : Serp.subtext0
                    opacity: zeroBtn.lit || zeroBtn.hovered ? 1 : 0.6
                }
                onClicked: zeroBtn.desk.output === Niri.focusedOutput ? WorkspaceAnim.go("0") : Niri.focusWorkspace(zeroBtn.desk.id)
            }

            Item {
                id: desks
                readonly property var list: Niri.workspacesOn(win.screenName)
                readonly property bool numbers: Serp.cfg.deskStyle === "numbers"
                readonly property int dot: Serp.px(numbers ? 18 : 9)
                readonly property int wide: Serp.px(numbers ? 26 : 24)
                readonly property int sp: Serp.px(numbers ? 4 : 7)
                readonly property int active: list.findIndex(w => w.is_active)
                readonly property real rowW: list.length ? list.length * dot + (active >= 0 ? wide - dot : 0) + sp * (list.length - 1) : 0
                width: list.length ? rowW + Serp.px(12) : 0
                height: win.pillH
                // where slot i stands once the layout settles (the active one is wide)
                function slotX(i) {
                    return (width - rowW) / 2 + i * (dot + sp) + (active >= 0 && i > active ? wide - dot : 0);
                }
                function slotW(i) {
                    return i === active ? wide : dot;
                }

                Row {
                    id: slots
                    anchors.centerIn: parent
                    spacing: desks.sp
                    Repeater {
                        model: desks.list
                        Rectangle {
                            id: pill
                            required property var modelData
                            readonly property bool used: Niri.windowsOn(modelData.id).length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.is_active ? desks.wide : desks.dot
                            height: desks.numbers ? Serp.px(18) : desks.dot
                            radius: desks.numbers ? Serp.px(6) : height / 2
                            // the active one's ground is the indicator over it
                            color: modelData.is_urgent ? Serp.red : desks.numbers ? (used ? Serp.surface2 : Serp.surface0) : used ? Qt.alpha(Serp.text, 0.4) : Qt.alpha(Serp.text, 0.16)
                            opacity: modelData.is_active ? 0 : 1
                            scale: deskMa.containsMouse && !modelData.is_active ? 1.2 : deskMa.pressed ? 0.88 : 1
                            Behavior on width {
                                NumberAnimation {
                                    duration: 380
                                    easing.type: Easing.OutQuint
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Serp.quick
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Serp.normal
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Serp.normal
                                    easing.type: Easing.OutQuint
                                }
                            }
                            SText {
                                visible: desks.numbers && !pill.modelData.is_active
                                anchors.centerIn: parent
                                text: pill.modelData.idx
                                size: Serp.px(10)
                                bold: true
                                color: Serp.subtext
                            }
                            MouseArea {
                                id: deskMa
                                anchors.fill: parent
                                anchors.margins: -Serp.px(4)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pill.modelData.output === Niri.focusedOutput ? WorkspaceAnim.go(String(pill.modelData.idx)) : Niri.focusWorkspace(pill.modelData.id)
                            }
                        }
                    }
                }

                // ---- the indicator: to the next desk it flows (the leading edge first, the
                // trailing one after, so it stretches like Serpantinum's); further, it teleports
                // the angelOS way: pulled into a point where it was, out of a flash where it goes
                Rectangle {
                    id: ind
                    // the desk it stands on: the active one at once for a step, after the shrink for a jump
                    property int at: desks.active
                    // where that is — a binding, so it follows the layout as it settles (at the shell's
                    // start the island's width arrives after the desks: it stayed a dot off its place)
                    property real l: desks.slotX(Math.max(0, at))
                    property real r: l + desks.slotW(Math.max(0, at))
                    visible: desks.active >= 0
                    x: l
                    width: Math.max(desks.dot, r - l)
                    height: desks.numbers ? Serp.px(18) : desks.dot
                    anchors.verticalCenter: parent.verticalCenter
                    radius: desks.numbers ? Serp.px(6) : height / 2
                    color: Serp.accent
                    SText {
                        visible: desks.numbers && desks.active >= 0
                        anchors.centerIn: parent
                        text: desks.active >= 0 ? desks.list[desks.active].idx : ""
                        size: Serp.px(10)
                        bold: true
                        color: Serp.onAccent
                    }
                    property bool glide: false
                    Behavior on l {
                        enabled: ind.glide
                        NumberAnimation {
                            id: lAnim
                            duration: 380
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on r {
                        enabled: ind.glide
                        NumberAnimation {
                            id: rAnim
                            duration: 380
                            easing.type: Easing.OutQuint
                        }
                    }
                    function go(to) {
                        const from = at;
                        if (from < 0 || to < 0 || Math.abs(to - from) <= 1) {
                            // a step: the leading edge first (200 ms), the trailing one after (420 ms)
                            const right = to > from;
                            lAnim.duration = right ? 420 : 200;
                            rAnim.duration = right ? 200 : 420;
                            glide = from >= 0 && to >= 0;
                            at = to;
                        } else {
                            jump.to = to;
                            jump.restart();
                        }
                    }
                    SequentialAnimation {
                        id: jump
                        property int to: 0
                        ParallelAnimation {
                            NumberAnimation {
                                target: ind
                                property: "scale"
                                to: 0.2
                                duration: 130
                                easing.type: Easing.InCubic
                            }
                            NumberAnimation {
                                target: ind
                                property: "opacity"
                                to: 0
                                duration: 130
                            }
                        }
                        ScriptAction {
                            script: {
                                ind.glide = false;
                                ind.at = jump.to;
                                flash.restart();
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: ind
                                property: "scale"
                                from: 0.3
                                to: 1
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.2
                            }
                            NumberAnimation {
                                target: ind
                                property: "opacity"
                                to: 1
                                duration: 160
                            }
                        }
                    }
                }
                // the teleport's flash: a ring of the accent opening where it lands
                Rectangle {
                    id: ring
                    x: ind.x + ind.width / 2 - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: desks.dot * 2.6
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Serp.px(1.5)
                    border.color: Serp.accent
                    opacity: 0
                    scale: 0.3
                    ParallelAnimation {
                        id: flash
                        NumberAnimation {
                            target: ring
                            property: "scale"
                            from: 0.3
                            to: 1.25
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: ring
                            property: "opacity"
                            from: 0.9
                            to: 0
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                onActiveChanged: ind.go(active)
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    // as the classic bar: up from desk 1 is the clean desk 0 (WorkspaceAnim knows it)
                    onWheel: e => {
                        if (Niri.focusedOutput === win.screenName)
                            WorkspaceAnim.go(e.angleDelta.y > 0 ? "up" : "down");
                    }
                }
            }

            // the weather and the clock live here while the Halo holds the centre; with the Halo
            // off both go back to the centre island (no doubles)
            SButton {
                id: wxBtn
                visible: win.haloHere && Serp.cfg.barWeather && Weather.ok
                anchors.verticalCenter: parent.verticalCenter
                active: Serp.isOpen("weather", win.screenName)
                Row {
                    spacing: Serp.px(5)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: SerpIcons.weather(Weather.now)
                        size: Serp.px(15)
                        color: Serp.accent
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.now ? Weather.deg(Weather.now.temp) : ""
                        size: Serp.px(11.5)
                        bold: true
                    }
                }
                onClicked: Serp.togglePanel("weather", win.screenName)
            }

            // the clock with seconds (tabular digits: the island doesn't twitch every second);
            // the calendar on click
            SButton {
                id: clockBtn
                visible: win.haloHere
                anchors.verticalCenter: parent.verticalCenter
                active: Serp.isOpen("calendar", win.screenName)
                property date now: new Date()
                Timer {
                    interval: 1000
                    running: clockBtn.visible && !Shell.hiddenScreen(win.screenName)
                    repeat: true
                    triggeredOnStart: true
                    // on the second's edge, not 1 s after whenever the timer started
                    onTriggered: {
                        clockBtn.now = new Date();
                        interval = 1000 - clockBtn.now.getMilliseconds() + 5;
                    }
                }
                Row {
                    spacing: 0
                    SText {
                        text: Qt.formatTime(clockBtn.now, "HH:mm")
                        size: Serp.px(12)
                        bold: true
                        font.features: { "tnum": 1 }
                    }
                    SText {
                        text: Qt.formatTime(clockBtn.now, ":ss")
                        size: Serp.px(12)
                        dim: true
                        font.features: { "tnum": 1 }
                    }
                }
                onClicked: Serp.togglePanel("calendar", win.screenName)
            }

            // now playing: the cover, the title, play/pause; the media panel on click
            Item {
                id: media
                readonly property bool has: Serp.cfg.barMedia && !!Lyrics.player && Lyrics.title !== ""
                visible: has
                width: has ? mediaRow.implicitWidth + Serp.px(10) : 0
                height: win.pillH
                Sep {
                    x: 0
                }
                Row {
                    id: mediaRow
                    x: Serp.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(7)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Serp.px(20)
                        height: width
                        radius: Serp.px(5)
                        color: Serp.surface1
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: Lyrics.artUrl || ""
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, Serp.px(170))
                        text: Lyrics.title + (Lyrics.artist ? "  ·  " + Lyrics.artist : "")
                        size: Serp.px(11)
                    }
                    SButton {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: Serp.px(22)
                        SIcon {
                            name: Lyrics.playing ? "pause" : "play"
                            size: Serp.px(13)
                            color: Serp.accent
                            filled: true
                        }
                        onClicked: if (Lyrics.player)
                            Lyrics.player.togglePlaying()
                    }
                }
                MouseArea {
                    anchors.fill: mediaRow
                    anchors.rightMargin: Serp.px(26)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Serp.togglePanel("media", win.screenName)
                    onWheel: w => {
                        if (!Lyrics.player)
                            return;
                        if (w.angleDelta.y > 0)
                            Lyrics.player.previous();
                        else
                            Lyrics.player.next();
                    }
                }
            }
        }
    }

    // ---- centre: the clock when the Halo isn't there ----
    Island {
        id: centerIsland
        visible: !win.haloHere
        x: Math.round((win.width - width) / 2)
        width: centerRow.implicitWidth + Serp.px(24)

        property date now: new Date()
        Timer {
            interval: 1000
            running: centerIsland.visible && !Shell.hiddenScreen(win.screenName)
            repeat: true
            triggeredOnStart: true
            onTriggered: centerIsland.now = new Date()
        }
        Row {
            id: centerRow
            anchors.centerIn: parent
            spacing: Serp.px(10)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(3)
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(centerIsland.now, "HH")
                    size: Serp.px(17)
                    black: true
                    color: Serp.accent
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -Serp.px(3)
                    SText {
                        text: Qt.formatTime(centerIsland.now, "mm")
                        size: Serp.px(Serp.cfg.barSeconds ? 10 : 15)
                        bold: true
                    }
                    SText {
                        visible: Serp.cfg.barSeconds
                        text: Qt.formatTime(centerIsland.now, "ss")
                        size: Serp.px(10)
                        dim: true
                    }
                }
            }
            Sep {
                visible: wx.visible
            }
            Row {
                id: wx
                visible: Serp.cfg.barWeather && Weather.ok
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(6)
                SIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: SerpIcons.weather(Weather.now)
                    size: Serp.px(15)
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.now ? Weather.deg(Weather.now.temp) : ""
                    size: Serp.px(12)
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Serp.togglePanel("calendar", win.screenName)
        }
    }

    // ---- trailing ----
    Island {
        id: rightIsland
        x: win.width - width - win.gap * 2
        width: status.implicitWidth + Serp.px(8)

        Row {
            id: status
            x: Serp.px(4)
            height: win.pillH
            spacing: Serp.px(1)

            // the plugins' bar widgets (Селестия, the CPU cat, the privacy eye…), in the bar layout's
            // order, drawn the way the classic bar draws them (angelOS's pixel look); not mac-eq —
            // the equalizer has its own button here
            Repeater {
                model: BarLayout.all.filter(id => id.startsWith("plugin:") && id !== "plugin:mac-eq")
                Item {
                    id: plugCell
                    required property string modelData
                    readonly property var p: Plugins.barWidgets.find(x => x.id === modelData.slice(7)) || null
                    // what the shared controls inside read (Theme.settingsSkinFor): the modern look, not
                    // the classic pixel frames (the typer's pressed button had one)
                    readonly property string settingsSkin: Skin.settingsSkin
                    readonly property real fit: plug.item && plug.item.implicitHeight > win.pillH - Serp.px(4) ? (win.pillH - Serp.px(4)) / plug.item.implicitHeight : 1
                    visible: !!plug.item && plug.item.implicitWidth > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? Math.round(plug.item.implicitWidth * fit) + Serp.px(8) : 0
                    height: win.pillH
                    Loader {
                        id: plug
                        anchors.centerIn: parent
                        scale: plugCell.fit
                        readonly property string src: plugCell.p && plugCell.p.barWidget ? Plugins.url(plugCell.p, plugCell.p.barWidget) : ""
                        function load() {
                            if (plugCell.p && src && !item)
                                setSource(src, {
                                    "plugin": Plugins.context(plugCell.p),
                                    "screenName": win.screenName,
                                    "barWindow": win
                                });
                        }
                        onSrcChanged: if (item) {
                            source = "";
                            load();
                        }
                        Component.onCompleted: load()
                    }
                }
            }
            // the tray, as angelOS's: the icons pinned to the bar stand right here (right click →
            // «На панель» / «Убрать с панели»: tray-pin's BarLayout, shared with the classic bar),
            // the rest live in the orb next to them
            Repeater {
                model: SystemTray.items
                SButton {
                    id: extra
                    required property var modelData
                    visible: {
                        BarLayout.all;
                        return BarLayout.pinned(extra.modelData);
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        width: Serp.px(16)
                        height: width
                        sourceSize: Qt.size(width * 2, height * 2)
                        source: StdIcon.safe(extra.modelData.icon, "application-x-executable")
                        smooth: true
                        mipmap: true
                    }
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton)
                            extra.modelData.secondaryActivate();
                        else if ((m.button === Qt.RightButton || extra.modelData.onlyMenu) && extra.modelData.hasMenu) {
                            trayMenu.anchorItem = extra;
                            trayMenu.handle = extra.modelData.menu;
                            trayMenu.tray = extra.modelData;
                            trayMenu.toggle();
                        } else
                            extra.modelData.activate();
                    }
                    onWheel: w => extra.modelData.scroll(w.angleDelta.y, false)
                }
            }
            // the rest of the tray: an orb. Hovered it swells; pressed it bursts — a few sparks, and
            // one dot per app flies out to its place on the island (the nearest first, a little
            // past it and back) and turns into its icon on the way; the island opens under them.
            // The orb stays as a hollow ring: pressed again, or 3 s after the pointer left, or an
            // app started, the icons shrink to dots and fly back into it (the farthest first)
            Item {
                id: trayGroup
                readonly property var loose: {
                    BarLayout.all;
                    return SystemTray.items.values.filter(t => !BarLayout.pinned(t));
                }
                readonly property int n: loose.length
                readonly property int cellW: Serp.px(28)
                readonly property int orbW: Serp.px(24)
                property bool expanded: false
                property real open: expanded ? 1 : 0
                Behavior on open {
                    NumberAnimation {
                        duration: 560
                        easing.type: Easing.Linear   // each icon eases on its own (local)
                    }
                }
                function outCubic(t) {
                    return 1 - Math.pow(1 - t, 3);
                }
                function outBack(t) {
                    const c1 = 1.45, c3 = c1 + 1;
                    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
                }
                function smooth(a, b, x) {
                    const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
                    return t * t * (3 - 2 * t);
                }
                // icon i's own 0..1: the one next to the orb leaves first and comes back last
                function local(i) {
                    const st = 0.13;
                    return Math.max(0, Math.min(1, open * (1 + st * (n - 1)) - st * (n - 1 - i)));
                }
                visible: n > 0
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? orbW + Math.round(n * cellW * outCubic(open)) : 0
                height: win.pillH

                // gather back a while after the pointer left (not with a tray menu open)
                HoverHandler {
                    id: trayHover
                    onHoveredChanged: {
                        if (hovered)
                            gather.stop();
                        else if (trayGroup.expanded)
                            gather.restart();
                    }
                }
                Timer {
                    id: gather
                    interval: 3000
                    onTriggered: {
                        if (trayMenu.visible)
                            restart();
                        else
                            trayGroup.expanded = false;
                    }
                }
                onNChanged: if (n === 0)
                    expanded = false
                function toggle() {
                    expanded = !expanded;
                    if (expanded) {
                        burstAnim.restart();
                        if (!trayHover.hovered)
                            gather.restart();
                    }
                }
                Connections {
                    target: Serp
                    function onTrayToggled(screen) {
                        if (screen === win.screenName && trayGroup.n > 0)
                            trayGroup.toggle();
                    }
                }

                Repeater {
                    model: trayGroup.loose
                    Item {
                        id: ti
                        required property var modelData
                        required property int index
                        readonly property real t: trayGroup.local(index)
                        readonly property real e: trayGroup.outBack(t)
                        // where it flies from (the orb) and to (its slot), from the group's right edge
                        readonly property real fromR: trayGroup.orbW / 2 + trayGroup.cellW / 2
                        readonly property real toR: trayGroup.orbW + (trayGroup.n - index) * trayGroup.cellW
                        x: trayGroup.width - fromR - (toR - fromR) * e
                        width: trayGroup.cellW
                        height: win.pillH
                        visible: t > 0
                        z: 1
                        // the dot it is on its way
                        Rectangle {
                            anchors.centerIn: parent
                            width: Serp.px(7)
                            height: width
                            radius: width / 2
                            color: Serp.accent
                            opacity: 1 - trayGroup.smooth(0.35, 0.75, ti.t)
                            scale: 0.6 + 0.8 * Math.min(1, ti.t * 1.6)
                        }
                        SButton {
                            id: cell
                            anchors.centerIn: parent
                            opacity: trayGroup.smooth(0.4, 0.85, ti.t)
                            scale: 0.35 + 0.65 * Math.min(1.08, ti.e)
                            Image {
                                width: Serp.px(16)
                                height: width
                                sourceSize: Qt.size(width * 2, height * 2)
                                source: StdIcon.safe(ti.modelData.icon, "application-x-executable")
                                smooth: true
                                mipmap: true
                            }
                            onClicked: m => {
                                if (m.button === Qt.MiddleButton)
                                    ti.modelData.secondaryActivate();
                                else if ((m.button === Qt.RightButton || ti.modelData.onlyMenu) && ti.modelData.hasMenu) {
                                    trayMenu.anchorItem = cell;
                                    trayMenu.handle = ti.modelData.menu;
                                    trayMenu.tray = ti.modelData;
                                    trayMenu.toggle();
                                } else {
                                    ti.modelData.activate();
                                    trayGroup.expanded = false;
                                }
                            }
                            onWheel: w => ti.modelData.scroll(w.angleDelta.y, false)
                        }
                    }
                }

                Item {
                    id: orb
                    anchors.right: parent.right
                    width: trayGroup.orbW
                    height: win.pillH
                    // the hover swell on its own item, the open shrink on the ball: a Behavior
                    // must not chase a value that moves every frame
                    Item {
                        id: swell
                        anchors.centerIn: parent
                        width: Serp.px(12)
                        height: width
                        scale: orbHover.hovered ? 1.4 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: 280
                                easing.type: Easing.OutBack
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 2.2
                            height: width
                            radius: width / 2
                            color: Serp.accent
                            opacity: orbHover.hovered ? 0.2 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 220
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.alpha(Serp.accent, 1 - 0.9 * trayGroup.open)
                            border.width: Math.max(1, Serp.px(1.5))
                            border.color: Serp.accent
                            scale: 1 - 0.3 * trayGroup.smooth(0, 0.5, trayGroup.open)
                        }
                    }
                    // the burst: sparks fly off the orb as it opens
                    property real burst: 1
                    NumberAnimation {
                        id: burstAnim
                        target: orb
                        property: "burst"
                        from: 0
                        to: 1
                        duration: 420
                        easing.type: Easing.OutCubic
                    }
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            readonly property real a: index / 7 * Math.PI * 2 + 0.4
                            width: Serp.px(3)
                            height: width
                            radius: width / 2
                            color: Serp.accent
                            visible: orb.burst < 1
                            opacity: 1 - orb.burst
                            x: orb.width / 2 - width / 2 + Math.cos(a) * Serp.px(15) * orb.burst
                            y: orb.height / 2 - height / 2 + Math.sin(a) * Serp.px(11) * orb.burst
                        }
                    }
                    HoverHandler {
                        id: orbHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: trayGroup.toggle()
                    }
                }
            }
            // the charge of the things on the desk (services/Peripherals, Settings → Devices → Device
            // charge, as the classic bar's ampoules): a capsule a device, its icon beside it, the number
            // as the settings say; the panel names them all. A right click asks the devices now
            SButton {
                id: devBtn
                readonly property var devs: Config.ready && Config.peripherals.show ? Peripherals.onBar : []
                visible: devs.length > 0
                anchors.verticalCenter: parent.verticalCenter
                active: devPop.visible
                Row {
                    spacing: Serp.px(8)
                    Repeater {
                        model: devBtn.devs
                        Row {
                            id: dev
                            required property var modelData
                            readonly property string pc: Config.peripherals.percent
                            readonly property bool number: pc === "always" || (pc === "low" && (dev.modelData.level !== "ok" || dev.modelData.charging))
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Serp.px(4)
                            SerpDeviceGlyph {
                                visible: Config.peripherals.glyphs
                                anchors.verticalCenter: parent.verticalCenter
                                kind: dev.modelData.kind
                                size: Serp.px(14)
                                color: Qt.alpha(Serp.text, dev.modelData.asleep ? 0.5 : 0.9)
                            }
                            SerpCharge {
                                anchors.verticalCenter: parent.verticalCenter
                                percent: dev.modelData.percent
                                level: dev.modelData.level
                                charging: dev.modelData.charging
                                asleep: dev.modelData.asleep
                            }
                            SText {
                                visible: dev.number
                                anchors.verticalCenter: parent.verticalCenter
                                text: dev.modelData.percent + "%"
                                size: Serp.px(11)
                                bold: true
                                color: dev.modelData.level === "veryLow" && !dev.modelData.charging ? Serp.red : Serp.text
                            }
                        }
                    }
                }
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Peripherals.refresh();
                    else
                        devPop.toggle();
                }
            }
            Connections {
                target: Serp
                function onDevicesToggled(screen) {
                    if (screen === win.screenName && devBtn.visible)
                        devPop.toggle();
                }
            }
            Sep {
                visible: SystemTray.items.values.length > 0
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Niri.keyboardLayouts.length > 1
                SText {
                    text: Niri.layoutShort.toUpperCase()
                    size: Serp.px(11)
                    bold: true
                }
                onClicked: Niri.switchLayout(true)
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wifi.hasWifi || !!Wifi.wiredDevice
                active: Serp.isOpen("net", win.screenName) && Serp.panelTab !== "bt"
                SIcon {
                    name: SerpIcons.net()
                }
                onClicked: Serp.togglePanel("net", win.screenName, "wifi")
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Bt.available
                active: Serp.isOpen("net", win.screenName) && Serp.panelTab === "bt"
                SIcon {
                    name: "bluetooth"
                    color: Bt.enabled ? Serp.text : Qt.alpha(Serp.text, 0.4)
                }
                onClicked: Serp.togglePanel("net", win.screenName, "bt")
            }
            // angelOS's two window modes: the Strip (columns) and Desktop (stacking, title bars) —
            // the classic bar's «winmode» button; stack-memory keeps each side as it was
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                active: WindowConfig.floatAll
                SIcon {
                    name: WindowConfig.floatAll ? "app-window" : "panel-left"
                    color: WindowConfig.floatAll ? Serp.accent : Serp.text
                }
                onClicked: WindowConfig.setFloatAll(!Config.windows.floatAll)
            }
            // angelOS's equalizer (EasyEffects): its panel; the accent while it is on
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Eq.offered
                active: Serp.isOpen("eq", win.screenName)
                SIcon {
                    name: "activity"
                    color: Eq.ready && Eq.active ? Serp.accent : Serp.text
                }
                onClicked: m => {
                    if (m.button === Qt.RightButton && Eq.ready)
                        Eq.send("toggle");
                    else
                        Serp.togglePanel("eq", win.screenName);
                }
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Audio.ready
                active: Serp.isOpen("sound", win.screenName)
                Row {
                    spacing: Serp.px(5)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: SerpIcons.volume()
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Audio.volume * 100) + "%"
                        size: Serp.px(11)
                    }
                }
                onClicked: m => {
                    if (m.button === Qt.MiddleButton)
                        Audio.toggleMute();
                    else
                        Serp.togglePanel("sound", win.screenName);
                }
                onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Power.hasBattery && Config.power.showBattery
                SText {
                    text: Power.percent + "%"
                    size: Serp.px(11)
                    bold: true
                    color: Power.discharging && Power.percent <= Config.power.lowAt ? Serp.red : Power.charging ? Serp.green : Serp.text
                }
                onClicked: Serp.togglePanel("quick", win.screenName)
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                active: Serp.isOpen("notifs", win.screenName)
                SIcon {
                    name: Config.notifications.dnd ? "bell-off" : "bell"
                }
                Rectangle {
                    visible: Notifs.unread > 0 && !Config.notifications.dnd
                    x: Serp.px(10)
                    y: -Serp.px(2)
                    width: Serp.px(6)
                    height: width
                    radius: width / 2
                    color: Serp.red
                }
                onClicked: Serp.togglePanel("notifs", win.screenName)
            }
            SButton {
                anchors.verticalCenter: parent.verticalCenter
                active: Serp.isOpen("quick", win.screenName)
                SIcon {
                    name: "sliders-horizontal"
                    color: Serp.accent
                }
                onClicked: Serp.togglePanel("quick", win.screenName)
            }
        }
    }

    TrayMenu {
        id: trayMenu
        anchorItem: rightIsland
        above: false
    }

    // the devices' panel: every one with its name, the charge large, how it stands
    BarPopup {
        id: devPop
        panelId: "peripherals"
        anchorItem: devBtn
        above: false
        title: I18n.t("Заряд устройств", "Device charge")
        icon: "battery"
        contentWidth: Serp.px(330)
        contentHeight: devList.implicitHeight + Serp.px(8)
        Column {
            id: devList
            width: parent.width
            spacing: Serp.px(10)
            Repeater {
                model: Peripherals.shown
                Row {
                    id: drow
                    required property var modelData
                    width: devList.width
                    spacing: Serp.px(12)
                    Rectangle {
                        width: Serp.px(40)
                        height: width
                        radius: width / 2
                        color: Qt.alpha(Serp.text, 0.07)
                        SerpDeviceGlyph {
                            anchors.centerIn: parent
                            kind: drow.modelData.kind
                            size: Serp.px(20)
                            color: Serp.text
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: drow.width - Serp.px(52)
                        spacing: Serp.px(5)
                        Item {
                            width: parent.width
                            height: nameText.implicitHeight
                            SText {
                                id: nameText
                                width: parent.width - pctText.implicitWidth - Serp.px(8)
                                text: drow.modelData.name
                                size: Serp.px(12.5)
                                bold: true
                            }
                            SText {
                                id: pctText
                                anchors.right: parent.right
                                text: drow.modelData.percent + "%"
                                size: Serp.px(12.5)
                                bold: true
                                color: drow.modelData.level === "veryLow" && !drow.modelData.charging ? Serp.red : Serp.text
                            }
                        }
                        SerpCharge {
                            w: parent.width - Serp.px(4)
                            h: Serp.px(9)
                            percent: drow.modelData.percent
                            level: drow.modelData.level
                            charging: drow.modelData.charging
                            asleep: drow.modelData.asleep
                        }
                        SText {
                            text: Peripherals.kindLabel(drow.modelData.kind) + (drow.modelData.charging ? I18n.t(" · заряжается", " · charging") : drow.modelData.asleep ? I18n.t(" · спит, последний заряд", " · asleep, last charge") : "")
                            size: Serp.px(10.5)
                            color: Serp.subtext
                        }
                    }
                }
            }
            SButton {
                anchors.right: parent.right
                Row {
                    spacing: Serp.px(5)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "refresh-cw"
                        size: Serp.px(12)
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("Спросить устройства", "Ask the devices")
                        size: Serp.px(11)
                    }
                }
                onClicked: Peripherals.refresh()
            }
        }
    }

    // a press on the bar closes the classic popups (tray menus) the way the classic bar does
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: PopupManager.barPressed()
    }

    RightClickGuard {}
}
