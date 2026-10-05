pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Widgets on the wallpaper: which, where, with what settings. Dragged by their title bar.
Singleton {
    id: root

    property bool editMode: false

    // ---- the look: angelOS's pixel windows or macOS Golden Gate cards ----
    // Config.desktop.widgetStyle: "auto" follows the skin (Golden Gate → cards), "pixel", "mac".
    // In hell (Theme.realm) the circle's look stays whatever the style: the built-in widgets
    // and the plugins that know it ("macLook") draw a card face of their own, the host draws
    // the card (widgets/MacWidgetCard) and drags it by the whole card in edit mode.
    readonly property string style: ["auto", "pixel", "mac"].includes(Config.desktop.widgetStyle) ? Config.desktop.widgetStyle : "auto"
    readonly property bool macStyle: Config.ready && (style === "mac" || (style === "auto" && GoldenGate.on))
    readonly property bool macLook: macStyle && !Theme.hell
    // macOS widget measures (points, grown with the font scale): 16 pt inside, 22 pt corners
    function mpx(v) {
        return Math.round(v * Theme.fs);
    }
    readonly property int macPad: mpx(16)
    readonly property int macRadius: mpx(22)
    // SF Pro when it is installed (Display from 20 pt up, as Apple sets it), else the skin's
    // font (Inter); Config.mac.font wins when it is set
    readonly property bool sfPro: Theme.macFamilies.includes("SF Pro Text")
    function macFamily(px) {
        if (Config.mac.font && Theme.macFamilies.includes(Config.mac.font))
            return Config.mac.font;
        if (sfPro)
            return px >= 20 && Theme.macFamilies.includes("SF Pro Display") ? "SF Pro Display" : "SF Pro Text";
        return Theme.macFont;
    }
    // colours from the theme in use (its flavour, light or dark): the Golden Gate skin's Mac
    // palette while it is on, the wallpaper's or a flavour's otherwise
    readonly property color macLabel: Qt.alpha(Theme.text, 0.95)
    readonly property color macSecondary: Theme.mix(Theme.textDim, Theme.text, Theme.dark ? 0.15 : 0.4)
    readonly property color macTertiary: Theme.dark ? Qt.alpha(Theme.textDim, 0.8) : Theme.mix(Theme.textDim, Theme.text, 0.15)
    readonly property color macSeparator: Qt.alpha(Theme.text, Theme.dark ? 0.12 : 0.1)
    // the glass: a tint of the theme's surface over the blurred wallpaper (no blur: nearly
    // opaque, as macOS's Reduce Transparency); Golden Gate's clear … tinted slider moves it
    readonly property real macTintAlpha: Config.appearance.blur ? 0.46 + Math.max(0, Math.min(1, Config.mac.glass)) * 0.38 : 0.92
    readonly property color macFill: Qt.alpha(Theme.mix(Theme.face, Theme.dark ? "#000000" : "#ffffff", 0.12), macTintAlpha)
    readonly property color macEdge: Theme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.1)
    readonly property color macRim: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.7)
    readonly property color macShadow: Qt.rgba(0, 0, 0, Theme.dark ? 0.42 : 0.18)
    // a theme colour as ink on the glass: a flavour's dark accent (a wallpaper's) lifted on dark
    // glass, a pale one deepened on light glass — the hue stays
    function macInk(c) {
        const l = c.hslLightness;
        if (Theme.dark && l < 0.6)
            return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.45), 0.62, 1);
        if (!Theme.dark && l > 0.4)
            return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.45), 0.38, 1);
        return c;
    }
    // a set of distinct tints from the theme's accents (a flavour may repeat one: then the next)
    function macTints(n) {
        const pool = [Theme.accent, Theme.accent2, Theme.accent4, Theme.accent3, Theme.ok, Theme.danger, Theme.title2].map(macInk);
        const out = [];
        const far = (a, b) => Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b) > 0.3;
        for (const c of pool)
            if (out.length < n && out.every(o => far(o, c)))
                out.push(c);
        while (out.length < n)
            out.push(pool[out.length % pool.length]);
        return out;
    }
    readonly property var macColors: macTints(4)

    // Every widget lives twice (DesktopWidgetHost): its face in the backdrop,
    // which niri never slides — so it stays put however a workspace switch
    // starts, and shows in the overview — and an input copy at opacity 0 on
    // angelos-desktop, which slides with the workspaces. The input copy only
    // shows over the face while a button in it is hovered or pressed, or in a
    // drag / edit mode; then it steps aside for a switch:
    //   a switch the shell starts (workspace keys via `angelos ws`, the bar):
    //   prepareSwitch() hides it and waits for that frame before niri moves;
    //   a switch niri starts by itself: onWorkspaceActivated, a few frames late —
    //   only ever with the pointer on a widget's button.
    property var asideUntil: ({})            // screen -> ms: input copies hidden until
    property double asideClock: 0
    function steppedAside(screen) {
        return Niri.overviewOpen || (asideUntil[screen] || 0) > asideClock;
    }
    // how long niri's slide takes (cfg/animation.kdl: preset × slowdown) and a margin
    readonly property int switchMs: Math.round(WorkspaceAnim.slideMs * WorkspaceAnim.slowdown) + 80
    function stepAside(screen, ms) {
        const now = Date.now();
        const u = Object.assign({}, asideUntil);
        u[screen] = Math.max(u[screen] || 0, now + (ms || switchMs));
        asideUntil = u;
        asideClock = now;
        // one clock for every screen: wake up when the last of them is done, or
        // an earlier screen's end would leave a later one stepped aside for good
        let last = now;
        for (const k in u)
            last = Math.max(last, u[k]);
        settle.interval = Math.max(1, last - now + 20);
        settle.restart();
    }
    Timer {
        id: settle
        onTriggered: root.asideClock = Date.now()
    }
    Connections {
        target: Niri
        function onWorkspaceActivated(ws, focused) {
            if (ws && !Niri.overviewOpen && !WorkspaceAnim.captured && WorkspaceAnim.current.id !== "instant")
                root.stepAside(ws.output);
        }
    }

    // ---- a switch the shell starts: an input copy on show hides first ----
    property var job: null                   // {screen, go, frames}
    readonly property bool preparing: job !== null
    function shownOn(screen) {
        for (const uid of uidsFor(screen)) {
            const h = hosts[uid];
            if (h && h.visible && h.shown)
                return true;
        }
        return false;
    }
    function prepareSwitch(screen, go) {
        if (job)
            advance();                       // another key before the last one got through
        if (!screen || !shownOn(screen)) {
            go();
            return;
        }
        stepAside(screen, switchMs + 200);   // niri's own event makes it exact
        job = {
            "screen": screen,
            "go": go,
            "frames": 0
        };
        jobGuard.restart();
    }
    // Background: a frame of the desktop surface reached the screen. Two frames
    // after the change, or one and then quiet, and the copy is gone from it.
    function framePresented(screen) {
        const j = job;
        if (!j || j.screen !== screen)
            return;
        j.frames++;
        if (j.frames >= 2)
            advance();
        else
            jobQuiet.restart();
    }
    function advance() {
        const j = job;
        if (!j)
            return;
        job = null;
        jobQuiet.stop();
        jobGuard.stop();
        j.go();
    }
    Timer {
        id: jobQuiet
        interval: 14
        onTriggered: root.advance()
    }
    // no frame at all (a stalled window): go on anyway
    Timer {
        id: jobGuard
        interval: 70
        onTriggered: root.advance()
    }

    // ---- heaven ⇄ hell: the widgets burn over (DesktopWidgetHost draws it) ----
    // While the demon rules (and Y2K → Widgets in hell is on) the widgets live in
    // hell. A swap holds them until the glass breaks (Angel.holdWidgets); then they
    // burn over in burnMs — the old look goes, Theme.realm flips at the middle and
    // the new one shows. At start-up they are simply where they belong.
    readonly property bool hellWanted: Config.ready && Angel.demon && Config.y2k.hellWidgets
    property real burn: 1                    // 0 → 1 through a burn-over; 1 = settled
    property string burnTo: ""               // "hell" | "heaven" while burning
    readonly property bool burning: burnTo !== ""
    readonly property int burnMs: 1500
    property bool _realmSet: false
    onHellWantedChanged: Qt.callLater(settleRealm)
    Component.onCompleted: Qt.callLater(settleRealm)
    Connections {
        target: Config
        function onReadyChanged() {
            Qt.callLater(root.settleRealm);
        }
    }
    Connections {
        target: Angel
        function onHoldWidgetsChanged() {
            if (!Angel.holdWidgets)
                Qt.callLater(root.settleRealm);
        }
    }
    function settleRealm() {
        if (!Config.ready || Angel.holdWidgets)
            return;
        const want = hellWanted ? "hell" : "heaven";
        if (!_realmSet) {
            _realmSet = true;
            Theme.realm = want;
            return;
        }
        if (want === (burning ? burnTo : Theme.realm))
            return;
        // the quiet switch (Angel.instant, C1): straight over, no burn
        if (Angel.instant || Motion.still) {
            burnAnim.stop();
            burnTo = "";
            burn = 1;
            Theme.realm = want;
            return;
        }
        burnTo = want;
        burnAnim.restart();
    }
    // dev/owner (`angelos helper realm`): burn over to the other side and back, for a look
    function burnPreview(to) {
        burnTo = to === "hell" || to === "heaven" ? to : (Theme.hell ? "heaven" : "hell");
        burnAnim.restart();
        return burnTo;
    }
    NumberAnimation {
        id: burnAnim
        target: root
        property: "burn"
        from: 0
        to: 1
        duration: root.burnMs
        onFinished: {
            Theme.realm = root.burnTo || Theme.realm;
            root.burnTo = "";
            // the wish may have changed while it burned (a quick toggle)
            Qt.callLater(root.settleRealm);
        }
    }
    onBurnChanged: if (burnTo && burn >= 0.5 && Theme.realm !== burnTo)
        Theme.realm = burnTo

    property var hosts: ({})                 // uid -> DesktopWidgetHost, the input copy
    property var faces: ({})                 // uid -> DesktopWidgetHost, the face
    function registerFace(uid, item) {
        const m = Object.assign({}, faces);
        m[uid] = item;
        faces = m;
    }
    function unregisterFace(uid, item) {
        if (faces[uid] !== item)
            return;
        const m = Object.assign({}, faces);
        delete m[uid];
        faces = m;
    }
    property var drag: ({
            "uid": "",
            "x": 0,
            "y": 0
        })
    function registerHost(uid, item) {
        const m = Object.assign({}, hosts);
        m[uid] = item;
        hosts = m;
    }
    function unregisterHost(uid, item) {
        if (hosts[uid] !== item)
            return;
        const m = Object.assign({}, hosts);
        delete m[uid];
        hosts = m;
    }

    readonly property var builtin: [
        {
            "type": "clock",
            "label": I18n.t("Часы", "Clock"),
            "icon": "calendar",
            "title": "clock"
        },
        {
            "type": "sysmon",
            "label": I18n.t("Системный монитор", "System monitor"),
            "icon": "chip",
            "title": "sysmon"
        },
        {
            "type": "cava",
            "label": I18n.t("Визуализатор cava", "cava visualizer"),
            "icon": "music",
            "title": "cava"
        },
        {
            "type": "nowplaying",
            "label": I18n.t("Сейчас играет", "Now playing"),
            "icon": "play",
            "title": "music"
        },
        {
            // hell's own: offered, shown and spun only while the demon rules
            "type": "hellwheel",
            "label": I18n.t("Колесо Ада", "Wheel of Hell"),
            "icon": "pentagram",
            "title": "wheel666",
            "hell": true
        }
    ]
    readonly property var pluginTypes: Plugins.desktopWidgets.map(p => ({
                "type": "plugin:" + p.id,
                "label": p.name,
                "icon": p.icon || "plug",
                "title": p.desktopTitle || p.id,
                "plugin": p
            }))
    // the demon's widgets (the Wheel of Hell) don't exist in heaven: not offered, not shown
    // (they stay in the settings and come back with her)
    readonly property var types: builtin.filter(t => !t.hell || Angel.hellShown).concat(pluginTypes)
    readonly property var widgets: (Config.desktop.widgets || []).filter(w => !!typeInfo(w.type))

    // "clock.exe" → "clock.sh": the ending picked in Settings → Appearance (I18n.exe)
    readonly property var suffixes: I18n.suffixes
    function titleOf(info) {
        if (!info)
            return "";
        return I18n.exe(I18n.label(info.title));
    }
    // widget size: 70–130 % of its natural size
    readonly property real minScale: 0.7
    readonly property real maxScale: 1.3
    function scaleOf(w) {
        return w && w.scale ? Math.max(minScale, Math.min(maxScale, w.scale)) : 1;
    }
    function setScale(uid, s) {
        const v = Math.round(Math.max(minScale, Math.min(maxScale, s)) * 100) / 100;
        _save((Config.desktop.widgets || []).map(w => w.uid === uid ? Object.assign({}, w, {
                    "scale": v
                }) : w));
    }

    function typeInfo(t) {
        return types.find(x => x.type === t) || null;
    }
    function byUid(uid) {
        return widgets.find(w => w.uid === uid) || null;
    }
    // a widget whose monitor isn't connected (unplugged, renamed) shows on the main screen
    function screenOf(w) {
        return !w || Quickshell.screens.some(s => s.name === w.screen) ? (w ? w.screen : "") : Shell.primaryName;
    }
    function uidsFor(screen) {
        return widgets.filter(w => screenOf(w) === screen).map(w => w.uid);
    }
    // Widgets never cover each other (translucent, one's text would show through the other's).
    // Their places are kept in pixels while their sizes follow the art pixel and the fonts, and
    // the screen may be smaller than the one they were placed on (a 2× monitor): a widget that
    // would land on one placed before it on its screen (the list's order) goes to the nearest
    // free place next to one of them (below, above, beside), inside the screen. The saved place
    // stays as it is, so the old sizes bring the old layout back. No free place at all (more
    // widgets than screen): it stays where it was put.
    function settledPlace(uid, screen, x, y, w, h, aw, ah) {
        const gap = Theme.u * 2;
        const before = [];
        for (const o of widgets) {
            if (o.uid === uid)
                break;
            if (screenOf(o) !== screen)
                continue;
            const f = faces[o.uid];
            if (f && f.visible && f.width > 0)
                before.push([f.x, f.y, f.width, f.height]);
        }
        const free = (px, py) => !before.some(r => px < r[0] + r[2] + gap && px + w + gap > r[0] && py < r[1] + r[3] + gap && py + h + gap > r[1]);
        if (free(x, y))
            return Qt.point(x, y);
        const cx = v => Math.max(0, Math.min(aw - w, v)), cy = v => Math.max(0, Math.min(ah - h, v));
        // the edges of the others (and of the screen) are where a free place can start
        const xs = [x, 0, aw - w], ys = [y, 0, ah - h];
        for (const r of before) {
            xs.push(r[0], r[0] + r[2] + gap, r[0] - gap - w);
            ys.push(r[1], r[1] + r[3] + gap, r[1] - gap - h);
        }
        let best = null, bestD = Infinity;
        for (const px0 of xs)
            for (const py0 of ys) {
                const px = cx(px0), py = cy(py0);
                const d = (px - x) * (px - x) + (py - y) * (py - y);
                if (d < bestD && free(px, py)) {
                    best = Qt.point(px, py);
                    bestD = d;
                }
            }
        return best || Qt.point(x, y);
    }
    // Settings → Monitor → "Move every widget here": all of them onto one screen, as they are
    function moveAllTo(screen) {
        if (!screen)
            return 0;
        const moved = (Config.desktop.widgets || []).filter(w => w.screen !== screen).length;
        _save((Config.desktop.widgets || []).map(w => w.screen === screen ? w : Object.assign({}, w, {
                    "screen": screen
                })));
        return moved;
    }
    function has(type, screen) {
        return widgets.some(w => w.type === type && w.screen === screen);
    }

    function _save(list) {
        Config.desktop.widgets = list;
    }
    function add(type, screen, x, y) {
        screen = screen || Shell.primaryName;
        const n = widgets.filter(w => w.screen === screen).length;
        _save((Config.desktop.widgets || []).concat([{
                    "uid": type.replace(/[^\w-]/g, "_") + "-" + Date.now().toString(36),
                    "type": type,
                    "screen": screen,
                    // new widgets fill a loose grid instead of piling up
                    "x": x !== undefined ? x : Theme.u * (20 + (n % 3) * 170),
                    "y": y !== undefined ? y : Theme.u * (20 + Math.floor(n / 3) * 95),
                    "settings": ({})
                }]));
    }
    function remove(uid) {
        _save((Config.desktop.widgets || []).filter(w => w.uid !== uid));
    }
    function toggle(type, screen) {
        const w = widgets.find(w => w.type === type && w.screen === screen);
        if (w)
            remove(w.uid);
        else
            add(type, screen);
    }
    function move(uid, x, y) {
        const g = Config.desktop.snap ? Theme.u * 4 : 1;
        _save((Config.desktop.widgets || []).map(w => w.uid === uid ? Object.assign({}, w, {
                    "x": Math.round(x / g) * g,
                    "y": Math.round(y / g) * g
                }) : w));
    }
    function setScreen(uid, screen) {
        _save((Config.desktop.widgets || []).map(w => w.uid === uid ? Object.assign({}, w, {
                    "screen": screen
                }) : w));
    }
    function resetPosition(uid) {
        const w = byUid(uid);
        if (!w)
            return;
        const n = widgets.filter(x => x.screen === w.screen && x.uid !== uid).length;
        move(uid, Theme.u * (20 + (n % 3) * 170), Theme.u * (20 + Math.floor(n / 3) * 95));
    }
    function removeAll(screen) {
        _save((Config.desktop.widgets || []).filter(w => screen && w.screen !== screen));
    }
    function setSetting(uid, key, value) {
        _save((Config.desktop.widgets || []).map(w => {
            if (w.uid !== uid)
                return w;
            const s = Object.assign({}, w.settings || {});
            s[key] = value;
            return Object.assign({}, w, {
                "settings": s
            });
        }));
    }

    // first run: bring over the plugin widgets that used to place themselves
    Timer {
        running: Config.ready && !Config.desktop.initialized && Plugins.plugins.length > 0
        interval: 1500
        onTriggered: {
            const first = Shell.primaryName || (Quickshell.screens[0] || {}).name || "DP-1";
            const list = (Config.desktop.widgets || []).slice();
            for (const p of Plugins.desktopWidgets) {
                if (list.some(w => w.type === "plugin:" + p.id))
                    continue;
                const pref = (Config.plugins.data[p.id] || {});
                list.push({
                    "uid": "plugin_" + p.id + "-init",
                    "type": "plugin:" + p.id,
                    "screen": pref.orbScreen || pref.screen || first,
                    "x": p.id === "claude-companion" ? Theme.u * 20 : -Theme.u * 20,
                    "y": p.id === "claude-companion" ? -Theme.u * 40 : Theme.u * 30,
                    "settings": ({})
                });
            }
            Config.desktop.widgets = list;
            Config.desktop.initialized = true;
        }
    }
}
