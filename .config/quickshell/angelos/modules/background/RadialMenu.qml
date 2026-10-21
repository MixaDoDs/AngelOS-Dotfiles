pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.background.circles
import "../../services/CobwebLayout.js" as Lay

// The wallpaper's full-screen menus, popups of the wallpaper window:
//   the ring (RingLook) — the middle button: eight fixed directions around the pointer
//   (DeskMenu.ring); hold the button, flick towards one, let go: it runs. Let go where it
//   opened: it stays, a click picks.
//   the right-click menu in heaven's and hell's own looks (services/DeskMenu.overlayLook):
//   heaven's wings and harp (WingsLook, HarpLook), hell's pentagram (PentagramLook) and each
//   circle's own (modules/background/circles: QueueLook … ShardsLook, story/circles.json →
//   dress), with the desktop's entries (DeskMenu.layout).
// This host keeps what they share: the entries (slots), the keyboard selection, opening at
// the pointer, running an entry. (`fly`: the looks still draw a flyout, there are none now.)
//   mouse: hover an entry, click to run; click anywhere empty to close; a right click
//   elsewhere moves the menu there.
//   keys: arrows walk, Enter runs, Esc closes, 1–9 pick an entry.
PopupWindow {
    id: root

    required property var parentWindow
    readonly property string screenName: parentWindow && parentWindow.screen ? parentWindow.screen.name : ""
    property bool ringMode: false           // opened by the middle button: the ring
    property bool armed: false              // …and the button is still held: a flick picks
    readonly property string look: ringMode ? "ring" : DeskMenu.overlayLook
    // hell's looks open slower, over a darker veil
    readonly property bool hellLook: look === "pentagram" || HellLook.dressMenuIds.includes(look)
    // …heaven's own over a little light instead
    readonly property bool heavenLook: DeskMenu.heavenly.includes(look)

    property real cx: 0                     // where it opened (moved in near the edges)
    property real cy: 0
    property int current: -1                // selected entry
    property string fly: ""                 // the open flyout's id
    property int flyIndex: -1               // …and its entry
    property int subCurrent: -1             // selected item of the flyout
    property real reveal: 0

    readonly property real k: ({
            "compact": 0.85,
            "large": 1.25
        })[Config.desktop.menuSize] || 1
    readonly property bool labels: Config.desktop.menuLabels !== false
    // the ring's eight, or the desktop's entries: the quick ones first, then the rest (no lines)
    readonly property var slots: {
        if (ringMode)
            return DeskMenu.ring;
        const l = DeskMenu.layout("desktop");
        return l.quick.concat(l.items.filter(id => id !== "sep" && !l.quick.includes(id))).slice(0, 16);
    }
    readonly property var flyItems: []
    readonly property var hoveredEntry: current >= 0 ? DeskMenu.entry(slots[current]) : null
    // opened, or moved by a right click elsewhere (the harp runs a glissando)
    signal opened

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }
    // what the bars keep on this screen by edge (services/Zones): the menu is drawn under
    // them, so «Ещё» stays clear of it
    readonly property var zone: Lay.zoneEdges(Zones.parts, screenName)
    // the look is built when the menu opens and kept a while after it closes; with the
    // list menu chosen it is never built at all
    Linger {
        id: keep
    }
    // the middle button went down at x, y: the ring, aimed while it is held
    function openRing(x, y) {
        ringMode = true;
        place(x, y);
        armed = true;
    }
    // where the pointer is while the button is held: the direction it points to is selected
    // (a little way out from the middle; nearer, none)
    function sector(x, y) {
        const dx = x - cx, dy = y - cy;
        if (Math.hypot(dx, dy) < Theme.u * 14)
            return -1;
        const n = slots.length;
        return Math.round((Math.atan2(dy, dx) + Math.PI / 2) / (2 * Math.PI / n) + n) % n;
    }
    function aim(x, y) {
        if (armed && visible)
            current = sector(x, y);
    }
    // the button let go: towards a direction runs it, in the middle the ring stays for a click
    function release(x, y) {
        if (!armed)
            return;
        armed = false;
        const i = sector(x, y);
        if (visible && i >= 0)
            activate(i);
    }
    function openAt(x, y) {
        ringMode = false;
        place(x, y);
    }
    function place(x, y) {
        armed = false;
        keep.when = true;
        // the look says how far it reaches from its middle (the tiles place themselves); a
        // wide one (the wings, the harp) says it apart for each way: reachX, reachY
        const it = lookLoader.item;
        const mx = it ? (it.reachX !== undefined ? it.reachX : it.reach) : 0;
        const my = it ? (it.reachY !== undefined ? it.reachY : it.reach) : 0;
        cx = mx > 0 ? clamp(x, Math.min(mx, width / 2), Math.max(width - mx, width / 2)) : x;
        cy = my > 0 ? clamp(y, Math.min(my, height / 2), Math.max(height - my, height / 2)) : y;
        current = -1;
        fly = "";
        flyIndex = -1;
        subCurrent = -1;
        visible = true;
        if (Config.desktop.menuAnim !== false) {
            reveal = 0;
            revealAnim.restart();
        } else {
            reveal = 1;
        }
        opened();
        Qt.callLater(() => keys.forceActiveFocus());
    }
    function close() {
        hoverTimer.stop();
        fly = "";
        armed = false;
        visible = false;
        keep.when = false;
    }
    function openSub(name) {
        const i = slots.indexOf(name);
        if (i >= 0)
            openFly(i);
    }
    function openFly(i) {
        const id = slots[i];
        const e = DeskMenu.entry(id);
        if (!e || !e.flyout) {
            fly = "";
            flyIndex = -1;
            return;
        }
        fly = id;
        flyIndex = i;
        subCurrent = -1;
    }
    function activate(i) {
        const id = slots[i];
        const e = DeskMenu.entry(id);
        if (!e)
            return;
        if (e.flyout) {
            openFly(i);
            subCurrent = 0;
            return;
        }
        close();
        DeskMenu.run(id, screenName);
    }
    function activateSub(j) {
        const it = flyItems[j];
        if (!it || it.enabled === false)
            return;
        if (it.run)
            it.run();
        if (!it.keepOpen)
            close();
    }
    // hover: select, and open a flyout after a beat (or close the open one)
    function hoverEntry(i) {
        current = i;
        const e = DeskMenu.entry(slots[i]);
        if (e && e.flyout) {
            hoverTimer.slot = i;
            hoverTimer.restart();
        } else if (fly) {
            fly = "";
        }
    }
    // the ring's and the pentagram's keys: around in order
    function walk(e) {
        const n = slots.length;
        if (fly && subCurrent >= 0 && (e.key === Qt.Key_Up || e.key === Qt.Key_Down)) {
            subCurrent = (subCurrent + (e.key === Qt.Key_Down ? 1 : -1) + flyItems.length) % flyItems.length;
        } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
            fly = "";
            current = (current + 1 + n) % n;
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
            fly = "";
            current = current < 0 ? n - 1 : (current - 1 + n) % n;
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (fly && subCurrent >= 0)
                activateSub(subCurrent);
            else if (current >= 0)
                activate(current);
        } else {
            return false;
        }
        return true;
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: Motion.ms(root.hellLook ? 420 : 230)
        easing.type: root.hellLook ? Easing.OutCubic : Easing.OutBack
    }
    Timer {
        id: hoverTimer
        property int slot: -1
        interval: 140
        onTriggered: if (root.current === slot)
            root.openFly(slot)
    }

    anchor.window: parentWindow
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    implicitWidth: parentWindow ? parentWindow.width : 1280
    implicitHeight: parentWindow ? parentWindow.height : 720
    grabFocus: !Shell.demo
    color: "transparent"
    visible: false
    onVisibleChanged: {
        if (visible) {
            if (PopupManager.active && PopupManager.active !== root)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        } else {
            keep.when = false;
            if (PopupManager.active === root)
                PopupManager.active = null;
        }
    }
    // a look's frosted glass, if it has one
    BackgroundEffect.blurRegion: Config.appearance.blur && lookLoader.item && lookLoader.item.blurItem ? blurRegion : null
    Region {
        id: blurRegion
        item: lookLoader.item ? lookLoader.item.blurItem : null
    }

    // a light veil (hell: darker, red; heaven's own: a little light)
    Rectangle {
        anchors.fill: parent
        color: root.look === "pentagram" ? Qt.alpha("#1a0508", 0.35 * root.reveal) : root.hellLook ? Qt.alpha(Theme.hellBody, 0.4 * root.reveal) : root.heavenLook ? Qt.alpha(Theme.face, 0.16 * root.reveal) : Qt.alpha(Theme.shadow, 0.1 * root.reveal)
    }
    // empty space: left closes, right moves the menu
    // (the ring: the button still held, the pointer aims; its release may come here)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: root.armed
        onPositionChanged: m => root.aim(m.x, m.y)
        onPressed: m => {
            if (m.button === Qt.RightButton && !root.ringMode)
                root.openAt(m.x, m.y);
            else
                root.close();
        }
        onReleased: m => {
            if (m.button === Qt.MiddleButton)
                root.release(m.x, m.y);
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            const n = root.slots.length;
            if (e.key === Qt.Key_Escape) {
                if (root.fly)
                    root.fly = "";
                else
                    root.close();
            } else if (lookLoader.item && lookLoader.item.nav(e)) {
                // the look handled it
            } else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && e.key - Qt.Key_1 < n) {
                root.current = e.key - Qt.Key_1;
                root.activate(root.current);
            } else {
                return;
            }
            e.accepted = true;
        }
    }

    Loader {
        id: lookLoader
        anchors.fill: parent
        active: keep.alive
        sourceComponent: ({
                "wings": wingsLook,
                "harp": harpLook,
                "pentagram": pentagramLook,
                "queue": queueLook,
                "whirl": whirlLook,
                "plate": plateLook,
                "roulette": rouletteLook,
                "ripples": ripplesLook,
                "tombs": tombsLook,
                "blades": bladesLook,
                "masks": masksLook,
                "shards": shardsLook
            })[root.look] || ringLook
    }
    Component {
        id: ringLook
        RingLook {
            menu: root
        }
    }
    // heaven's own
    Component {
        id: wingsLook
        WingsLook {
            menu: root
        }
    }
    Component {
        id: harpLook
        HarpLook {
            menu: root
        }
    }
    Component {
        id: pentagramLook
        PentagramLook {
            menu: root
        }
    }
    // the circles' own
    Component {
        id: queueLook
        QueueLook {
            menu: root
        }
    }
    Component {
        id: whirlLook
        WhirlLook {
            menu: root
        }
    }
    Component {
        id: plateLook
        PlateLook {
            menu: root
        }
    }
    Component {
        id: rouletteLook
        RouletteLook {
            menu: root
        }
    }
    Component {
        id: ripplesLook
        RipplesLook {
            menu: root
        }
    }
    Component {
        id: tombsLook
        TombsLook {
            menu: root
        }
    }
    Component {
        id: bladesLook
        BladesLook {
            menu: root
        }
    }
    Component {
        id: masksLook
        MasksLook {
            menu: root
        }
    }
    Component {
        id: shardsLook
        ShardsLook {
            menu: root
        }
    }

    RightClickGuard {}
}
