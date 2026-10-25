pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar.parts
import qs.modules.desktop
import "HaloCat.js" as Kitty

// The Halo (Нимб) on one screen: the pixel Dynamic Island at the top centre (services/Halo).
// As on an iPhone: the main thing going on in a pill of the theme's colour (pixel-stepped round
// ends), the others as small round bubbles to its right — a click on one makes it the main one.
// Nothing going on: the closed pill at rest — the clock, the weather or the screen time each
// side and the arc or RunCat's cat between them (Settings → Halo → «At rest»), the right
// side turning through the others if asked; all off: a thin pixel halo ring. The pointer resting on the pill or the ring
// (Settings → Halo, 0.4 s) or a click opens a big card of the same shape, with a spring: the
// «Now» page (the main thing, or the clock, the weather and the screen time at rest); the
// wheel, the ‹ › or the dots turn its pages (they slide sideways). The pointer gone (a margin
// round the card still counts), it waits 0.6 s with a strip running out, then shrinks. Closed: the wheel is the
// player's volume (the pill shows it a moment), a middle click pauses, a right click opens its
// menu in place.
// It keeps a strip of its own at the top (Settings → Halo); the open card lies over the
// windows. A full-screen game or film hides it, but for a timer's end.
// The surface keeps the screen's width and a fixed height, the pill grows inside it: resizing
// the layer surface itself went in jerks (issue #14). Input only on the pill and the bubbles.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property int u: Theme.u
    // a size in art pixels, scaled by Settings → Halo → size and snapped to whole ones
    function px(n) {
        return Math.round(n * Halo.scale) * u;
    }
    readonly property bool full: Shell.fullscreenOn(modelData.name)
    // over a full-screen window only the timer's end
    // (the game's cards go to one screen only: Halo.gameScreen)
    // over a full-screen game or film: nothing (Settings → Halo), or only a timer's end
    // (the stream's chat goes over it too while on air: that is what the viewers watch)
    readonly property var baseItems: (full ? Halo.items.filter(i => Config.halo.overFullscreen === "timer" && i.kind === "ring" || i.kind === "chat" && StreamMode.onAir) : Halo.items).filter(i => !i.only || i.only === modelData.name)
    // music without synced lyrics here (a browser video, a song with none) doesn't take the pill
    // (Settings → Halo → «Music without synced lyrics»): its title peeks 5 s on a new track or
    // a pause, then its cover and bars take the resting pill's right side (`musicEar`); beside
    // another event it stays a bubble
    // while its lyrics are still being looked for it keeps the pill too: after a start the search
    // took minutes and the song sat as a cover on the side meanwhile (the owner, 25.10)
    readonly property bool musicCapsule: Config.halo.musicSmart === false || Halo.peek || Halo.pauseFresh || ((Halo.synced || Lyrics.status === "loading") && lyricsHere)
    readonly property var items: baseItems.filter(i => i.kind !== "music" || musicCapsule || baseItems.some(o => !["music", "paused", "shelf"].includes(o.kind)))
    readonly property bool musicEar: Config.halo.showMusic !== false && Halo.music && Lyrics.playing && !items.some(i => i.kind === "music")
    readonly property bool shown: (!full || items.length > 0) && (!Halo.hidden || items.some(i => i.kind === "ring")) && !(dodging && !peeking) && !mission
    // Mission Control on this screen: its desks are where the Halo sits, the Halo stepped aside
    // (it took their clicks)
    readonly property bool mission: Mission.shown && Mission.screenName === modelData.name
    // Settings → Halo → «Windows and the Halo» → hide: while a window on this screen's desk
    // touches the top, the Halo slides away; the pointer at the top edge brings it back
    readonly property bool dodging: Config.halo.windows === "hide" && !expanded && !Shell.dev && windowAtTop
    readonly property bool windowAtTop: {
        const ws = Niri.activeWorkspace(modelData.name);
        if (!ws)
            return false;
        const half = pill.width / 2 + slack;
        return Niri.windows.some(w => {
            if (w.workspace_id !== ws.id || Minimize.isAppHidden(w))
                return false;
            const l = w.layout;
            const pos = l && l.tile_pos_in_workspace_view;
            // a tiled window starts at the very top (no strip in this mode)
            if (!pos)
                return true;
            const mid = width / 2;
            return pos[1] < strip && pos[0] < mid + half && pos[0] + l.tile_size[0] > mid - half;
        });
    }
    property bool peeking: false
    Timer {
        id: peekEnd
        interval: 900
        onTriggered: win.peeking = hover.hovered
    }
    readonly property bool lyricsHere: Lyrics.placeOn(modelData.name) === "halo"

    // the main thing: a timer's end, else the one picked from the bubbles, else the most urgent.
    // Something new more urgent than the picked one takes the pill back (a picked song never
    // hides a download that started after)
    property string picked: ""
    property var seenKeys: []
    onItemsChanged: {
        const keys = items.map(i => i.key);
        const p = items.find(i => i.key === picked);
        if (picked && (!p || items.some(i => !seenKeys.includes(i.key) && Halo.rank(i) <= Halo.rank(p))))
            picked = "";
        seenKeys = keys;
    }
    // the shelf's stack and the paused song's ▶ are only bubbles: beside them the pill rests
    function mainable(i) {
        return i.kind !== "shelf" && i.kind !== "paused";
    }
    readonly property var main: items.find(i => i.kind === "ring") || items.find(i => i.key === picked && mainable(i)) || items.find(i => mainable(i)) || null
    readonly property var others: items.filter(i => i !== main)
    readonly property var bubbles: others.slice(0, 2)
    readonly property int more: others.length - bubbles.length

    // ---- at rest (nothing going on): the closed pill with a side each and the arc or the cat
    // between them; a side that has nothing to show (no weather yet, screen time not counted)
    // is left empty; both sides empty and the arc: the bare ring, as it was ----
    function restHas(k) {
        return k === "clock" || (k === "weather" && Weather.ok) || (k === "screen" && !!Config.wellbeing.track);
    }
    readonly property string restLeft: restHas(Config.halo.idleLeft) ? Config.halo.idleLeft : "none"
    // the right side turns through the ones the left doesn't show (Settings → «Change every»)
    property int restTurn: 0
    readonly property var restRights: {
        const own = Config.halo.idleRight;
        if (!restHas(own))
            return [];
        if (!(Config.halo.idleRotate > 0))
            return [own];
        return [own].concat(["clock", "weather", "screen"].filter(k => k !== own && k !== restLeft && restHas(k)));
    }
    readonly property string restRight: musicEar ? "music" : restRights.length ? restRights[restTurn % restRights.length] : "none"
    readonly property bool restCat: Config.halo.idleMiddle === "cat" || Config.halo.idleMiddle === "angel"
    readonly property bool rest: !main && !vol && !seeking && (restLeft !== "none" || restRight !== "none" || restCat)
    Timer {
        interval: Math.max(3, Config.halo.idleRotate) * 1000
        repeat: true
        running: win.shown && win.rest && !win.expanded && !win.musicEar && win.restRights.length > 1
        onTriggered: win.restTurn++
    }
    // the cat sleeps after a minute with no input (a film without touching anything too)
    // after sunset (the weather's city; Settings → Halo → «Dim at night») the resting Halo dims
    // and the cat falls asleep after 20 s instead of a minute
    readonly property bool night: Config.halo.nightDim !== false && Weather.ok && !!Weather.now && Weather.now.day === false
    IdleWatch {
        id: napWatch
        enabled: win.shown && win.restCat
        timeout: win.night ? 20 : 60
        respectInhibitors: false
    }
    // the first openings at rest tell what the wheel, a drop and a right click do (Settings →
    // Halo → hintsLeft); an opening that showed it counts down when it closes, ✕ ends them
    property bool hintShown: false
    // for the inline components (they don't see the file's ids)
    readonly property bool pointerHere: hover.hovered
    readonly property bool dozing: napWatch.isIdle
    // the processor's load 0…1 for the cat's run, read every 2 s only while it runs awake
    property real cpu: 0
    property var cpuLast: null
    FileView {
        id: cpuStat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (win.cpuLast && total > win.cpuLast.t)
                win.cpu = 1 - (idle - win.cpuLast.i) / (total - win.cpuLast.t);
            win.cpuLast = {
                "t": total,
                "i": idle
            };
        }
    }
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: win.shown && win.restCat && !win.dozing && !Motion.still && (win.rest || win.expanded)
        onTriggered: cpuStat.reload()
    }

    // Shift+wheel just moved the song: the pill shows where a moment
    property bool seeking: false
    property real seekSum: 0
    Timer {
        id: seekOff
        interval: 1200
        onTriggered: {
            win.seeking = false;
            win.seekSum = 0;
        }
    }
    // the wheel just turned the player's volume: the pill shows it a moment
    property bool vol: false
    Timer {
        id: volOff
        interval: 1200
        onTriggered: win.vol = false
    }

    // the rest's button was pressed for this ring (Halo.rang)
    property var tipDone: null
    property bool expanded: false
    readonly property bool menu: haloMenu.visible   // the right-click menu (haloMenu)
    onExpandedChanged: {
        tip = "";
        if (expanded)
            haloMenu.close();
        if (!expanded) {
            multi = [];
            closeNote();
            eventsNew = false;
            dropFocus();
            if (hintShown && Config.halo.hintsLeft > 0)
                Config.halo.hintsLeft = Config.halo.hintsLeft - 1;
            hintShown = false;
            return;
        }
        if (!main && Config.halo.hintsLeft > 0)
            hintShown = true;
        // it opens on «Now» (the shelf as the main thing: on its page; openOn: the one asked).
        // Picked here, not when it closes: the closing card fades out on the page it was on
        // the pill shows an event: open on its page (the song stays on «Now», a turn to the left)
        page = openTo >= 0 ? openTo : main && main.kind === "shelf" ? pages.indexOf("shelf") : main && events.includes(main) ? pages.indexOf("events") : 0;
        openTo = -1;
        pageScroll = 0;
    }
    property int openTo: -1
    function openOn(name) {
        const i = Math.max(0, pages.indexOf(name));
        if (expanded)
            page = i;
        else {
            openTo = i;
            expanded = true;
        }
    }
    // a quick button's field lets go of the keyboard: its page turned away, the menu over it, the
    // card closed (else the window's next focus gave it back, hidden, and the card never closed)
    signal dropFocus
    onTypingChanged: if (!typing)
        closeSoon()
    // the pointer gone from the open card: it waits a moment (a strip along its bottom runs out
    // meanwhile) and stays if the pointer comes back; never while something is dragged or typed
    readonly property int closeMs: 600
    function closeSoon() {
        if (expanded && !pointerOn() && !draggingOut && !dropping && !typing)
            closer.restart();
    }
    Timer {
        id: closer
        interval: win.closeMs
        onTriggered: if (!win.pointerOn() && !win.draggingOut && !win.dropping && !win.typing)
            win.expanded = false
    }
    // after a drag (in or out) the hover is stale: while dragging Wayland sends no pointer motion,
    // so hover.hovered keeps what it was and the card never closed. It counts again on the next
    // motion over the pill
    property bool hoverStale: false
    // a function, not a binding: called from onHoveredChanged, a binding may not have caught up
    // yet (still true) and the card never closed (16.10, after the shelf's ✕)
    function pointerOn() {
        return hover.hovered && !hoverStale;
    }
    function afterDrag(ms) {
        hoverStale = true;
        if (ms)
            linger.restart();
        else
            closeSoon();
    }
    // a drop onto the shelf: the card shows it there a moment, then closes as usual
    Timer {
        id: linger
        interval: 1500
        onTriggered: win.closeSoon()
    }
    readonly property bool closing: closer.running
    // room round the open card where the pointer still counts as on it (no slip closes it)
    readonly property int slack: expanded ? u * 10 : u * 4
    Connections {
        target: Halo
        function onOpenAsked(screen) {
            if (screen === win.modelData.name)
                win.openOn("");
        }
    }
    // a notification (any short event) stays while its card is open
    Binding {
        when: !!win.main && win.main === Halo.flash && (win.expanded || hover.hovered)
        target: Halo
        property: "flashHeld"
        value: true
        restoreMode: Binding.RestoreValue
    }
    // the notification in the pill is seen once the pointer is on it or its card opens: it may go
    readonly property bool notifLooked: !!win.main && win.main === Halo.flash && win.main.kind === "notif" && (win.expanded || hover.hovered)
    onNotifLookedChanged: if (notifLooked)
        Halo.flashSeen = true
    // the screenshot's capsule stays while the pointer is on it or its card is open
    Binding {
        when: !!win.main && win.main.kind === "shot" && (win.expanded || hover.hovered)
        target: Halo
        property: "shotHeld"
        value: true
        restoreMode: Binding.RestoreValue
    }
    function shotToShelf(path) {
        Shelf.addDrop(["file://" + encodeURI(path)], "", false);
        Sounds.play("toggle");
        Halo.flashDone();
        openOn("shelf");
    }
    // the open Halo holds the achievement's card (its timing is AchievementToast's)
    Binding {
        when: win.modelData.name === Halo.gameScreen
        target: Halo
        property: "trophyHeld"
        value: win.expanded && !!win.main && win.main.kind === "trophy"
    }
    // the open card's pages, turned by the wheel
    // «Now» is the song (or the tiles); the events (a notification, a timer, a download…) have a
    // page of their own right after it while there are any (the owner, 16.10: a notification
    // must not stand in front of the track)
    readonly property var events: items.filter(i => mainable(i) && i.kind !== "music")
    readonly property var nowMusic: items.find(i => i.kind === "music") || null
    readonly property var pages: events.length ? ["now", "events", "shelf", "buttons"] : ["now", "shelf", "buttons"]
    // the page is kept by its name when the events' page comes or goes (no jump, no slide)
    property string pageKey: "now"
    property bool noSlide: false
    onPagesChanged: {
        const i = pages.indexOf(pageKey);
        noSlide = true;
        page = i >= 0 ? i : 0;
        noSlide = false;
    }
    property int page: 0
    onPageChanged: {
        pageKey = pages[page] || "now";
        pageScroll = 0;
        dropFocus();
        if (pages[page] !== "shelf")
            closeNote();
        if (pages[page] === "events")
            eventsNew = false;
        if (pages[page] === "shelf")
            Shelf.check();
    }
    property real wheelSum: 0
    property bool wheelHeld: false
    Timer {
        id: wheelQuiet
        interval: 180
        onTriggered: {
            win.wheelSum = 0;
            win.wheelHeld = false;
        }
    }
    function turn(by) {
        page = Math.max(0, Math.min(pages.length - 1, page + by));
    }
    // the open card keeps one size whatever its page (as macOS's): a page taller than the card
    // scrolls under the wheel first, and the wheel turns the page only at its end
    // the pages keep one height; an event on «Now» (a notification, a timer) is only as tall as
    // it is, as the iPhone's island — no half-empty window
    readonly property real pageH: Math.max(u * 90, px(90))
    readonly property bool eventsPage: expanded && !dropping && pages[page] === "events"
    readonly property real cardBoxH: eventsPage ? Math.min(pageH, Math.max(px(24), pagesLoader.item ? pagesLoader.item.eventsH : 0)) : pageH
    property real pageScroll: 0
    readonly property real pageContentH: pagesLoader.item ? pagesLoader.item.contentH : 0
    // the pages exist while the pointer is on the pill or the card is open, and 45 s after
    Linger {
        id: pagesKeep
        when: win.expanded || hover.hovered || win.dropping
        ms: 45000
    }
    readonly property real pageMax: Math.max(0, pageContentH - pageView.height)
    onPageMaxChanged: pageScroll = Math.min(pageScroll, pageMax)
    // a hint under the pointer: what it is about, where (in the card's coordinates); it shows
    // after the pointer rests a moment (tipShow) and goes as it leaves
    property string tip: ""
    property real tipX: 0
    property real tipY: 0
    function hint(item, text, on) {
        if (!on) {
            if (tip === text)
                tip = "";
            return;
        }
        const p = item.mapToItem(card, item.width / 2, item.height + u * 2);
        tipX = p.x;
        tipY = p.y;
        tip = text;
        tipShow.restart();
    }
    Timer {
        id: tipShow
        interval: 450
        property bool done: false
        onRunningChanged: if (running)
            done = false
        onTriggered: done = true
    }
    // the window's title: the page as a file, as the desktop widgets have (clock.sh, music.sh)
    readonly property string headName: {
        if (dropping)
            return "drop.sh";
        const pg = pages[page];
        if (pg === "now")
            return nowMusic ? "music.sh" : "now.sh";
        if (pg !== "events")
            return pg + ".sh";
        if (events.length > 1)
            return "events.sh";
        const k = events.length ? events[0].kind : "";
        return ({
                "music": "music.sh",
                "timer": "timer.sh",
                "ring": "timer.sh",
                "rec": "rec.sh",
                "notif": "notify.sh",
                "call": "call.sh",
                "dl": "downloads.sh",
                "dlDone": "downloads.sh",
                "pick": "color.sh",
                "shot": "shot.sh",
                "osd": "volume.sh",
                "trophy": "trophy.sh",
                "chest": "chest.sh",
                "net": "net.sh",
                "power": "power.sh",
                "update": "update.sh",
                "updated": "update.sh"
            })[k] || "now.sh";
    }
    // something new took «Now» while another page is open: its dot lights up
    property bool eventsNew: false
    readonly property string mainKey: main ? main.key : ""
    onMainKeyChanged: if (expanded && pages[page] !== "events" && !!main && events.includes(main))
        eventsNew = true
    onDroppingChanged: pageScroll = 0
    // a notch (120) scrolls 16 art pixels; true if it did (the page has room that way)
    function scrollPage(d) {
        if (pageMax <= 0 || (d < 0 && pageScroll >= pageMax) || (d > 0 && pageScroll <= 0))
            return false;
        pageScroll = Math.max(0, Math.min(pageMax, pageScroll - d / 120 * u * 16));
        return true;
    }
    // the pages side by side: the strip slides to the one turned to (opening: at once)
    property real slide: page
    Behavior on slide {
        enabled: win.expanded && card.opacity > 0.99 && !win.noSlide
        NumberAnimation {
            duration: Motion.ms(320)
            easing.type: Easing.OutCubic
        }
    }
    // a file, a picture, a link or text dragged onto it: the open pill shows where to drop it
    property bool dropping: false
    // a thing of the shelf dragged out: the pill stays open until it lands
    property bool draggingOut: false
    // a quick button's field has the keyboard (own time, a note): the pill stays open
    property bool typing: false
    // the shelf's thing picked (its buttons show), by id
    property string sel: ""
    // the text open on the shelf page to be read and written (a note), by id; "" = the squares.
    // Its words are kept half a second after the last key (noteSave) and at once when it closes;
    // a note left empty goes
    property string note: ""
    function openNote(id) {
        if (note !== id)
            closeNote();
        sel = "";
        multi = [];
        note = id;
    }
    function noteFlush() {
        if (!noteSave.running)
            return;
        noteSave.stop();
        Shelf.setText(noteSave.id, noteSave.text);
    }
    function closeNote() {
        noteFlush();
        const it = note ? Shelf.find(note) : null;
        if (it && String(it.text).trim() === "")
            Shelf.remove(it.id);
        note = "";
    }
    Timer {
        id: noteSave
        property string id: ""
        property string text: ""
        interval: 500
        onTriggered: Shelf.setText(id, text)
    }
    function noteEdited(text) {
        noteSave.id = note;
        noteSave.text = text;
        noteSave.restart();
    }
    // Ctrl+click: several picked at once (two or more; one is `sel`), dragged out together
    property var multi: []
    readonly property var multiItems: Shelf.items.filter(i => multi.includes(i.id))
    function multiToggle(id) {
        const l = (multi.length ? multi : sel ? [sel] : []).filter(x => Shelf.find(x));
        const i = l.indexOf(id);
        if (i >= 0)
            l.splice(i, 1);
        else
            l.push(id);
        multi = l.length > 1 ? l : [];
        sel = l.length === 1 ? l[0] : "";
    }
    // this screen is streamed: the shelf shows no names or pictures
    // (Settings → Halo → «Hide on stream»; the owner shows everything: off by default)
    readonly property bool onAir: Config.halo.streamHide === true && StreamMode.onStream(modelData.name)

    // one tick a second while something counts or the card is open: the timers, the
    // recordings, the clock, the song's progress (the services themselves don't tick)
    property double now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: win.shown && (win.expanded || win.items.some(i => i.kind === "rec" || i.kind === "timer" || i.kind === "call") || (win.rest && (win.restLeft === "clock" || win.restRight === "clock")))
        onTriggered: {
            win.now = Date.now();
            if (win.expanded && Lyrics.player)
                Lyrics.player.positionChanged();
        }
    }

    anchors.top: true
    implicitWidth: modelData.width
    implicitHeight: Math.round(modelData.height * 0.6)
    // Settings → Halo → «A strip of its own»: windows start below the closed pill (it covered the
    // browser's tabs); hidden for a while, it keeps the strip so they don't jump; the stand
    // never pushes the real windows
    readonly property int strip: glued ? px(16) : px(18) + topGap + (skin === "float" ? u * 3 : 0)
    // Normal said outright: a 0 at start (the strip off) doesn't change the zone, so Quickshell
    // never left Auto and the strip came back after every restart (#89)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Config.halo.reserve && (Config.halo.windows || "bar") === "bar" && !Shell.dev ? strip : 0
    onStripChanged: Halo.strip = strip
    Component.onCompleted: Halo.strip = strip
    color: "transparent"
    WlrLayershell.namespace: "angelos-halo"
    // the keyboard only for the quick buttons' fields
    WlrLayershell.keyboardFocus: expanded && (pages[page] === "buttons" || pages[page] === "shelf") && !menu && !dropping ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // a full-screen window covers the Top layer: its timer's end comes over it
    // under Mission Control while it is open here: hidden, its input region still took the
    // clicks on the desks under it
    WlrLayershell.layer: Shell.bootOpen || Shell.bootCover || mission ? WlrLayer.Top : WlrLayer.Overlay
    mask: Region {
        item: win.shown ? hit : win.dodging ? peekZone : null
        Region {
            item: win.shown && !win.expanded && win.others.length ? bubbleRow : null
        }
        Region {
            item: privacy.visible ? privacy : null
        }
    }

    // the pill's size and corners, sprung on the render clock; the pill snaps to whole pixels
    // the pointer on it: the pill swells a little and its outline lights up — it is about to open
    readonly property bool lifted: hover.hovered && !expanded
    readonly property bool open: expanded || !!main || vol || seeking || rest
    // closed: the content between the round ends (a radius of room each side); open: a card at
    // least as wide as the closed pill was, so opening never makes it narrower
    readonly property real closedW: fixedWidth ? fixedW : (main || vol || seeking ? compact.implicitWidth : restRow.implicitWidth) + px(16)
    readonly property bool fixedWidth: Config.halo.fixedWidth !== false
    // the bass's «halo» style draws an arc over the pill: the pill comes down a few pixels for it
    readonly property bool bassHalo: Config.halo.bassGlow !== false && Config.halo.bassStyle === "halo" && !glued
    readonly property int topGap: bassHalo ? px(4) : 0
    readonly property real fixedW: px(176)
    // what the closed pill's content may take at most (its round ends aside)
    readonly property real innerW: fixedW - px(16)
    // open: wide and low, as the MacBook notch's apps (the owner's 16.10 answers)
    readonly property real cardW: Math.min(width - u * 8, Math.max(px(300), closedW))
    readonly property real wantW: expanded ? cardW : main || vol || seeking || rest ? Math.min(width - u * 40, closedW) + (lifted ? u * 4 : 0) : ring.width
    readonly property real wantH: expanded ? cardTop + cardBoxH + frame.chrome + u * 4 : main || vol || seeking || rest ? px(skin === "tamagotchi" ? 20 : 16) + (lifted ? u * 2 : 0) : ring.height
    // open it is a desktop widget's window (square, PxWindow); closed the look's pill
    readonly property real wantR: expanded ? 0 : px(8)
    // the open card's content starts under the window's title bar
    readonly property real cardTop: frame.chrome + frame.titleHeight + u * 4
    property real w: wantW
    // snug at rest the sides differ: the pill moves by half the difference, the middle stays put
    property real restShift: rest && !expanded && !(main || vol || seeking) && restRow.inRow ? (restRow.rightW - restRow.leftW) / 2 : 0
    Behavior on restShift {
        Spring {}
    }
    property real h: wantH
    property real r: wantR
    Behavior on w {
        Spring {}
    }
    Behavior on h {
        Spring {}
    }
    Behavior on r {
        Spring {}
    }
    component Spring: NumberAnimation {
        duration: Motion.ms(win.steps ? 300 : 420)
        easing.type: win.steps ? Easing.OutQuad : Easing.OutBack
        easing.overshoot: 1.25
    }
    // Settings → Halo → Animation «Steps»: on the way the size snaps to a coarse grid (a few
    // jumps, as an 8-bit sprite grows), the last frame lands exact
    readonly property bool steps: Config.halo.anim === "steps"
    function stepped(v, to, cell) {
        return Math.abs(v - to) < 0.5 ? Math.round(to) : Math.round(v / cell) * cell;
    }

    // the outline: a timer's end blinks the accent; the pointer's zone lights it (or the card
    // waits to close); our recording or OBS's red; the song in its cover's colour (Settings →
    // Halo → «Cover colour»); else the line
    property bool blink: false
    Timer {
        interval: 400
        repeat: true
        running: win.shown && !!win.main && win.main.kind === "ring"
        onTriggered: win.blink = !win.blink
        onRunningChanged: if (!running)
            win.blink = false
    }
    readonly property color edgeColor: {
        const k = main ? main.kind : "";
        if (k === "ring" && !expanded)
            return blink ? win.accent : line;
        if (hover.hovered || closing || dropping)
            return win.accent;
        if (expanded || vol || seeking)
            return line;
        if (k === "rec")
            return Theme.danger;
        if (k === "music" && songShown)
            return accent;
        return line;
    }
    // the Halo's accent: the theme's, and while the song shows (pill or card) half the cover's
    // colour in it — still AngelOS's palette, a shade per song (Settings → Halo → «Cover
    // colour»); pushed lighter / darker until it reads on the face (3:1). The signals keep their
    // own colours: the recording's red, the privacy dots, the rest's green, the errors
    readonly property bool songShown: !!main && main.kind === "music" && !!Halo.coverTint
    readonly property color accent: songShown ? readable(Theme.mix(Theme.accent, Halo.coverTint, 0.5)) : Theme.accent
    function lum(c) {
        const f = x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }
    function contrast(a, b) {
        const x = lum(a), y = lum(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }
    function readable(c) {
        let o = Qt.color(c);
        const up = lum(face) < 0.4;
        for (let i = 0; i < 8 && contrast(o, face) < 3; i++)
            o = up ? Qt.lighter(o, 1.15) : Qt.darker(o, 1.15);
        return o;
    }
    // ---- its look (Settings → Halo → «Look»; Halo.skin), in the desktop widgets' colours (the
    // owner's 16.10 answers «как окна-виджеты»): ears — at rest three pieces with gaps; notch —
    // black, glued to the screen's top edge like a MacBook's (square top, round bottom); float —
    // lower; tamagotchi — taller, the cat on a strip of grass. Open, every look is the widgets'
    // pixel window (PxWindow: its title bar, bevels and hard shadow) ----
    readonly property string skin: Halo.skin
    readonly property bool glued: skin === "notch"
    readonly property bool earsRest: skin === "ears" && rest && !expanded && !card.visible
    readonly property int pillY: glued ? 0 : skin === "float" ? u * 4 + topGap : u + topGap
    readonly property bool hell: Theme.hell
    // the widgets' see-through plate, a little denser: it lies over windows
    readonly property color baseFace: hell ? Theme.hellPanel : Qt.alpha(Theme.face, Math.max(0.9, Theme.panelAlpha))
    // (the notch is black on a dark theme; by day the text is dark, so the day's plate)
    readonly property color face: skin === "notch" && (Theme.dark || hell) ? "#000000" : skin === "tamagotchi" ? Qt.tint(baseFace, "#402f6f9f") : baseFace
    readonly property color line: skin === "notch" ? "transparent" : hell ? Theme.hellEdge : Theme.edge
    readonly property color inkColor: hell ? "#ff4d4d" : Theme.text
    readonly property color textInk: Theme.text
    readonly property color textInkDim: Theme.textDim

    // the top edge over the hidden pill (dodging): the pointer there brings the Halo back
    Item {
        id: peekZone
        width: hit.width
        height: win.u * 2
        x: hit.x
        HoverHandler {
            enabled: win.dodging
            onHoveredChanged: {
                if (hovered)
                    win.peeking = true;
                peekEnd.restart();
            }
        }
    }
    // where the pointer finds it: from the screen's very edge down (thrown up, the pointer stops
    // on the top row of pixels) and a little wider than the pill (or the ring at rest)
    Item {
        id: hit
        visible: win.shown
        opacity: win.night && !win.expanded && !win.main ? 0.7 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(600)
            }
        }
        width: (win.open ? pill.width : ring.width) + win.slack * 2
        height: Math.max(win.strip, (win.open ? pill.height : ring.height) + win.pillY + (win.expanded ? win.slack : win.u))
        x: Math.round((win.width - width) / 2 + win.restShift)

        HoverHandler {
            id: hover
            // a motion over it after a drag: the pointer is really here
            onPointChanged: if (win.hoverStale && hovered) {
                win.hoverStale = false;
                closer.stop();
                linger.stop();
            }
            onHoveredChanged: {
                if (!hovered && win.peeking)
                    peekEnd.restart();
                if (hovered) {
                    win.hoverStale = false;
                    linger.stop();
                    closer.stop();
                    if (!win.menu)
                        opener.restart();
                } else {
                    opener.stop();
                    win.closeSoon();
                }
            }
        }
        Timer {
            id: opener
            interval: Math.max(0, Config.halo.hoverMs)
            onTriggered: win.expanded = true
        }
        TapHandler {
            enabled: !win.expanded
            onTapped: win.expanded = true
        }
        // a middle click pauses what the pill shows: a timer, our own recording, else the music
        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: {
                const m = win.main;
                if (m && m.kind === "timer")
                    Timers.toggle(m.id);
                else if (m && m.kind === "rec") {
                    if (m.own)
                        Capture.pauseRecord();
                } else if (Lyrics.player && Lyrics.player.canTogglePlaying)
                    Lyrics.player.togglePlaying();
            }
        }
        // a right click: its menu at the pointer; a right click again closes it (the pill's own
        // clicks still come while the menu holds the grab)
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: p => {
                opener.stop();
                win.expanded = false;
                if (haloMenu.visible) {
                    haloMenu.close();
                    return;
                }
                const at = hit.mapToItem(null, p.position.x, p.position.y);
                haloMenu.popup(win.menuItems(), "", at.x, at.y);
            }
        }
        // something dragged over it: open it on the drop targets; dropped beside them: the shelf
        DropArea {
            anchors.fill: parent
            onEntered: drag => {
                win.prefetch(drag);
                dropLeave.stop();
                win.dropping = true;
                win.expanded = true;
            }
            // moving onto a target is an exit from here too: wait to see if it went elsewhere
            onExited: dropLeave.restart()
            onDropped: drop => {
                win.drop("shelf", drop, "");
            }
        }
        Timer {
            id: dropLeave
            interval: 150
            onTriggered: {
                win.dropping = false;
                win.afterDrag();
            }
        }
        // the wheel: closed, the player's volume; open, the pages
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                const d = e.angleDelta.y || e.angleDelta.x;
                if (!d)
                    return;
                // Shift: the song ±5 s a notch (a touchpad: a notch's worth), up = ahead
                if (e.modifiers & Qt.ShiftModifier) {
                    const sp = Lyrics.player;
                    if (!Halo.hasTrack || !sp || !sp.canSeek)
                        return;
                    win.seekSum += d;
                    if (Math.abs(win.seekSum) < 120)
                        return;
                    const to = sp.position + (win.seekSum > 0 ? 5 : -5);
                    win.seekSum = 0;
                    sp.position = Math.max(0, Lyrics.length > 0 ? Math.min(Lyrics.length - 1, to) : to);
                    sp.positionChanged();
                    win.seeking = true;
                    seekOff.restart();
                    return;
                }
                if (win.expanded) {
                    // the menu or the drop targets over the pages: nothing to turn
                    if (win.menu || win.dropping)
                        return;
                    // a page taller than the card scrolls first; at its end the spin stops
                    // there, the next page wants a new one (a pause)
                    if (!win.wheelHeld && win.scrollPage(d)) {
                        win.wheelSum = 0;
                        if (win.pageScroll <= 0 || win.pageScroll >= win.pageMax) {
                            win.wheelHeld = true;
                            wheelQuiet.restart();
                        }
                        return;
                    }
                    // one page a notch (120) or a gesture's worth, then quiet until the
                    // gesture (and a touchpad's glide) is over
                    wheelQuiet.restart();
                    if (win.wheelHeld || win.pages.length < 2)
                        return;
                    win.wheelSum += d;
                    if (Math.abs(win.wheelSum) >= 120) {
                        win.turn(win.wheelSum < 0 ? 1 : -1);
                        win.wheelSum = 0;
                        win.wheelHeld = true;
                    }
                } else {
                    const p = Lyrics.player;
                    if (p && p.volumeSupported && p.canControl) {
                        p.volume = Math.max(0, Math.min(1, p.volume + (d > 0 ? 0.05 : -0.05)));
                        win.vol = true;
                        volOff.restart();
                    }
                }
            }
        }

        // the halo ring at rest: a pixel ellipse's outline, column by column
        Arc {
            id: ring
            x: win.slack
            y: win.pillY
            opacity: win.open ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.ms(Theme.fast)
                }
            }
        }

        // closed: the widgets' hard pixel shadow down-right (the notch hangs from the edge: none);
        // open, the window has its own
        PxPill {
            visible: win.open && !win.glued && !win.earsRest && !win.expanded && Config.appearance.shadows
            width: pill.width
            height: pill.height
            radius: pill.radius
            x: pill.x + win.u * (win.skin === "float" ? 3 : 2)
            y: pill.y + win.u * (win.skin === "float" ? 3 : 2)
            color: Qt.alpha(Theme.shadow, Theme.shadowAlpha)
        }
        PxPill {
            id: pill
            visible: win.open
            width: win.steps ? win.stepped(win.w, win.wantW, win.px(8)) : Math.round(win.w)
            height: win.steps ? win.stepped(win.h, win.wantH, win.px(4)) : Math.round(win.h)
            radius: win.r
            x: win.slack
            y: win.pillY
            flatTop: win.glued
            // ears at rest: the pill itself is see-through, its three pieces have their own; open:
            // the window draws it
            color: win.earsRest || win.expanded ? "transparent" : win.face
            edge: win.earsRest || win.expanded ? "transparent" : win.edgeColor

            // open: a desktop widget's pixel window (as clock.sh, music.sh), the title bar ours
            PxWindow {
                id: frame
                visible: win.expanded
                anchors.fill: parent
                hell: win.hell
                compact: true
                decor: false
                closable: false
                titleRow: false
                bodyColor: Qt.alpha(Theme.face, Math.max(0.92, Theme.panelAlpha))
                active: true
                // the window's own title strip: the cat (a click — it purrs), the page's name,
                // the pages' dots on the right
                Item {
                    parent: frame.titleBar
                    anchors.fill: parent
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: win.u * 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: win.u * 3
                        RestCat {
                            id: cardCat
                            anchors.verticalCenter: parent.verticalCenter
                            pixel: Math.max(1, win.u / 2)
                            petable: true
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.headName
                            font.family: win.hell && Theme.latin(text) ? Theme.fontHell : Theme.fontBody
                            font.pixelSize: win.hell && Theme.latin(text) ? Theme.hellPx(Theme.fs) : Theme.sizeBody
                            color: win.hell ? Theme.hellText : Theme.zine ? Theme.titleText : Theme.text
                        }
                    }
                    Row {
                        id: dots
                        visible: !win.menu && !win.dropping && win.pages.length > 1
                        anchors.right: parent.right
                        anchors.rightMargin: win.u * 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: win.u
                        Repeater {
                            model: win.pages.length
                            Item {
                                id: dot
                                required property int index
                                width: win.u * 6
                                height: win.u * 6
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: dot.index === win.page ? win.u * 4 : win.u * 2
                                    height: width
                                    color: dot.index === win.page || (win.pages[dot.index] === "events" && win.eventsNew) || dotHover.hovered ? win.accent : win.hell ? Theme.hellTextDim : Theme.textDim
                                }
                                HoverHandler {
                                    id: dotHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: win.page = dot.index
                                }
                            }
                        }
                    }
                }
            }

            // the bass (services/Bass; Settings → Halo → «Glow with the bass»): shaders/halo_bass —
            // «dither»: an ordered-dither band along the inner edge, rows by the level, solid on
            // a kick; «halo»: an arc over the pill and a dotted ring walking out on a kick. Whole
            // art pixels in three colours of the cover's (or the accent); the open card too
            ShaderEffect {
                id: beat
                // the song plays in any capsule (a recording takes the pill first) or beside the rest
                // (a song without synced lyrics: its cover at the side): the bass stays
                readonly property bool here: (win.items.some(i => i.kind === "music") || win.musicEar) && !win.vol && !win.seeking && Halo.music && Lyrics.playing
                readonly property real m: win.bassHalo ? 8 : 0
                x: -m * win.u
                y: -m * win.u
                width: pill.width + 2 * m * win.u
                height: pill.height + 2 * m * win.u
                visible: here && (level > 0 || flash > 0 || wave > 0)
                readonly property real dpr: Window.window && Window.window.devicePixelRatio > 0 ? Window.window.devicePixelRatio : 1
                readonly property real artPx: Math.max(1, Math.round(win.u * dpr))
                property size cells: Qt.size(Math.max(1, Math.round(width * dpr / artPx)), Math.max(1, Math.round(height * dpr / artPx)))
                property real margin: m
                property real corner: Math.round(pill.radius / win.u)
                property real style: win.bassHalo ? 1 : 0
                property real level: here ? Bass.level : 0
                property real flash: here ? Bass.flash : 0
                property real wave: 0
                readonly property color tint: win.accent
                property color cBright: tint
                property color cMid: Qt.tint(win.face, Qt.alpha(tint, 0.55))
                property color cDim: Qt.tint(win.face, Qt.alpha(tint, 0.3))
                fragmentShader: Qt.resolvedUrl("../../shaders/halo_bass.frag.qsb")
                // the kick's ring, in four steps out (whole frames, not a smooth slide)
                NumberAnimation on wave {
                    id: waveRun
                    running: false
                    from: 0.01
                    to: 1
                    duration: Motion.ms(360)
                    easing.type: Easing.Linear
                    onFinished: beat.wave = 0
                }
                Connections {
                    target: Bass
                    enabled: beat.here && win.bassHalo
                    function onKicked() {
                        waveRun.restart();
                    }
                }
            }

            // a timer's run in the closed pill: a pixel line along its bottom fills as it goes
            Rectangle {
                id: runBar
                readonly property var t: !win.expanded && !win.vol && !win.seeking ? win.timerOf(win.main) : null
                readonly property real done: t && t.total > 0 ? Math.max(0, Math.min(1, 1 - Timers.left(t, win.now) / t.total)) : 0
                visible: !!t && t.kind !== "stopwatch" && t.total > 0
                x: Math.round(pill.radius)
                y: pill.height - win.u * 3
                width: pill.width - x * 2
                height: win.u
                color: Qt.alpha(barFill.color, 0.25)
                Rectangle {
                    id: barFill
                    height: parent.height
                    width: Math.round(parent.width * runBar.done / win.u) * win.u
                    // a pomodoro's rest: the green of «go easy»
                    color: runBar.t && runBar.t.kind === "pomodoro" && runBar.t.phase === "rest" ? Theme.ok : win.accent
                    opacity: win.running(runBar.t) ? 1 : 0.5
                }
            }


            // the content shows through the growing pill, inside its round ends
            Item {
                anchors.fill: parent
                anchors.leftMargin: win.u * 4
                anchors.rightMargin: win.u * 4
                clip: true

                // at rest: a side each, the arc or the cat between them
                Item {
                    id: restRow
                    readonly property real gap: win.earsRest ? win.u * 14 : win.u * 6
                    // fixed width: the sides share what is left; snug (fixedWidth off) the Halo grows to
                    // them, so no cap: a cap from its own width fed back through implicitWidth (a polish() loop)
                    readonly property real sideW: win.fixedWidth ? Math.max(0, (width - restMid.width) / 2 - gap) : Infinity
                    anchors.fill: parent
                    readonly property real leftW: restL.visible ? restL.implicitWidth + gap : 0
                    readonly property real rightW: restR.visible ? restR.implicitWidth + gap : 0
                    // snug, no ears: the pill hugs the three and moves over (win.restShift) so the
                    // middle stays on the screen's centre; the ears keep it on the camera, room for
                    // the wider side on both
                    readonly property bool inRow: !win.fixedWidth && !win.earsRest
                    implicitWidth: inRow ? leftW + restMid.width + rightW : restMid.width + 2 * Math.max(leftW, rightW)
                    // comes and goes in a pixel dissolve, the song's line the other way
                    readonly property bool on: win.rest && !win.expanded
                    property real vis: on ? 1 : 0
                    Behavior on vis {
                        NumberAnimation {
                            duration: Motion.ms(420)
                        }
                    }
                    visible: vis > 0
                    layer.enabled: vis > 0 && vis < 1
                    layer.effect: Dissolve {
                        vis: restRow.vis
                        incoming: restRow.on ? 1 : 0
                    }
                    // ears: a piece of its own under each of the three, gaps between them (the
                    // middle one black, the camera's)
                    Repeater {
                        model: win.earsRest ? [restL, restMid, restR] : []
                        Item {
                            required property var modelData
                            required property int index
                            visible: modelData.visible
                            x: modelData.x - win.u * 5
                            width: modelData.width + win.u * 10
                            height: restRow.height - win.u * 2
                            // the widgets' hard shadow under each piece
                            PxPill {
                                visible: Config.appearance.shadows
                                x: win.u * 2
                                y: win.u * 2
                                width: parent.width
                                height: parent.height
                                color: Qt.alpha(Theme.shadow, Theme.shadowAlpha)
                            }
                            PxPill {
                                anchors.fill: parent
                                color: parent.index === 1 ? "#000000" : win.face
                                edge: parent.index === 1 ? "transparent" : win.edgeColor
                            }
                        }
                    }
                    // tamagotchi: the cat's strip of grass along the bottom
                    Row {
                        visible: win.skin === "tamagotchi"
                        x: win.u * 2
                        y: parent.height - win.u * 3
                        spacing: win.u
                        Repeater {
                            model: Math.max(0, Math.floor((restRow.width - win.u * 4) / (win.u * 3)))
                            Rectangle {
                                required property int index
                                width: win.u * 2
                                height: index % 3 === 1 ? win.u * 2 : win.u
                                y: win.u * 2 - height
                                color: "#6fd06a"
                            }
                        }
                    }
                    RestBit {
                        id: restL
                        what: win.restLeft
                        maxW: restRow.sideW
                        anchors.verticalCenter: parent.verticalCenter
                        // steady width: by the round end; else snug to the middle
                        x: win.fixedWidth && !win.earsRest ? win.u * 2 : restMid.x - restRow.gap - width
                    }
                    Item {
                        id: restMid
                        width: win.restCat ? restSprite.width : restArc.width
                        height: win.restCat ? restSprite.height : restArc.height
                        x: restRow.inRow ? (parent.width - restRow.implicitWidth) / 2 + restRow.leftW : (parent.width - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        Arc {
                            id: restArc
                            visible: !win.restCat
                            cols: 18
                        }
                        RestCat {
                            id: restSprite
                            visible: win.restCat
                            ink: win.earsRest || String(win.face) === "#000000" ? "#efe9ff" : win.inkColor
                        }
                    }
                    RestBit {
                        id: restR
                        what: win.restRight
                        maxW: restRow.sideW
                        anchors.verticalCenter: parent.verticalCenter
                        x: win.fixedWidth && !win.earsRest ? parent.width - width - win.u * 2 : restMid.x + restMid.width + restRow.gap
                    }
                }
                Compact {
                    id: compact
                    anchors.centerIn: parent
                    readonly property var live: win.vol ? {
                        "key": "vol",
                        "kind": "vol"
                    } : win.seeking ? {
                        "key": "seek",
                        "kind": "seek"
                    } : win.main
                    // the last one stays drawn while it dissolves away
                    property var held: null
                    onLiveChanged: if (live)
                        held = live
                    item: live || held
                    readonly property bool on: !win.expanded && !!live
                    property real vis: on ? 1 : 0
                    Behavior on vis {
                        NumberAnimation {
                            duration: Motion.ms(420)
                        }
                    }
                    visible: vis > 0
                    layer.enabled: vis > 0 && vis < 1
                    layer.effect: Dissolve {
                        vis: compact.vis
                        incoming: compact.on ? 1 : 0
                    }
                }
                Item {
                    id: card
                    // the window's body: under its title bar, inside its bevels and padding
                    width: win.cardW - win.u * 14
                    x: Math.round((parent.width - width) / 2 / win.u) * win.u
                    y: win.cardTop
                    implicitHeight: win.cardBoxH
                    opacity: win.expanded ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.ms(Theme.normal)
                        }
                    }
                    // the pages' window: a taller page scrolls (win.pageScroll)
                    Item {
                        id: pageView
                        width: parent.width
                        height: card.implicitHeight
                        clip: true
                        // the pages (two thousand objects) are built while the pointer is on the
                        // pill or the card is open and kept 45 s after: closed, it holds none.
                        // Built bit by bit between frames (~0.1 s), so the opening never stalls
                        // (built at once it stopped the spring for 40–80 ms)
                        Loader {
                            id: pagesLoader
                            active: pagesKeep.alive
                            asynchronous: true
                            width: parent.width
                            y: -Math.round(win.pageScroll / win.u) * win.u
                            sourceComponent: pagesPart
                        }
                    }
                    Component {
                        id: pagesPart
                        Item {
                            // what the window's sizes ask of the pages
                            readonly property real contentH: win.dropping ? dropCard.implicitHeight : win.pages[win.page] === "shelf" ? shelfCard.implicitHeight : win.pages[win.page] === "buttons" ? buttonsCard.implicitHeight : win.pages[win.page] === "events" ? eventsCol.implicitHeight : win.nowMusic ? nowCard.implicitHeight : tilesCard.implicitHeight
                            readonly property real eventsH: eventsCol.implicitHeight
                            height: win.pageContentH
                            // «Now»: the song with its lyrics, else the tiles
                            Card {
                                id: nowCard
                                width: parent.width
                                x: win.pageX(0)
                                visible: !win.dropping && win.pageSeen(0) && !!win.nowMusic
                                item: win.expanded ? win.nowMusic : null
                            }
                            TilesCard {
                                id: tilesCard
                                width: parent.width
                                x: win.pageX(0)
                                visible: !win.dropping && win.pageSeen(0) && !win.nowMusic
                            }
                            // the events, newest first, a rule between them
                            Column {
                                id: eventsCol
                                readonly property int at: win.pages.indexOf("events")
                                width: parent.width
                                x: win.pageX(at)
                                visible: at >= 0 && !win.dropping && win.pageSeen(at)
                                spacing: win.u * 4
                                Repeater {
                                    model: win.expanded ? win.events : []
                                    Column {
                                        id: ev
                                        required property var modelData
                                        required property int index
                                        width: eventsCol.width
                                        spacing: win.u * 4
                                        Rectangle {
                                            visible: ev.index > 0
                                            width: parent.width
                                            height: win.u
                                            color: win.hell ? Theme.hellEdge : Theme.edge
                                        }
                                        Card {
                                            width: parent.width
                                            item: ev.modelData
                                        }
                                    }
                                }
                            }
                            ShelfCard {
                                id: shelfCard
                                readonly property int at: win.pages.indexOf("shelf")
                                width: parent.width
                                height: Math.max(implicitHeight, card.implicitHeight)
                                x: win.pageX(at)
                                visible: !win.dropping && win.pageSeen(at)
                            }
                            ButtonsCard {
                                id: buttonsCard
                                readonly property int at: win.pages.indexOf("buttons")
                                width: parent.width
                                x: win.pageX(at)
                                visible: !win.dropping && win.pageSeen(at)
                            }
                            DropCard {
                                id: dropCard
                                width: parent.width
                                visible: win.dropping
                            }
                        }
                    }
                    // a pixel scroll bar on the right while the page is taller than the card
                    Rectangle {
                        visible: win.pageMax > 0
                        x: parent.width + win.u
                        width: win.u
                        height: Math.max(win.u * 4, Math.round(pageView.height * pageView.height / win.pageContentH / win.u) * win.u)
                        y: Math.round((pageView.height - height) * win.pageScroll / win.pageMax / win.u) * win.u
                        color: Qt.alpha(win.accent, 0.6)
                    }
                    // a hint under the pointer (what a field takes, a file's name): the panel's
                    // little box, a moment after the pointer stops on it
                    PxBox {
                        id: tipBox
                        visible: win.tip !== "" && tipShow.done
                        z: 10
                        flat: true
                        color: Theme.menuSurface
                        width: Math.min(card.width, tipText.implicitWidth + win.u * 8)
                        height: tipText.implicitHeight + win.u * 4
                        x: Math.max(0, Math.min(card.width - width, win.tipX - width / 2))
                        y: Math.max(0, Math.min(card.implicitHeight - height, win.tipY))
                        PxText {
                            id: tipText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, card.width - win.u * 8)
                            text: win.tip
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    // «closing in a moment»: an accent strip just inside the open card's bottom edge runs out
    Rectangle {
        id: closeBar
        visible: win.closing && win.expanded
        z: 5
        x: hit.x + pill.x + win.px(10)
        y: hit.y + pill.y + pill.height - win.u * 4
        height: win.u * 2
        color: win.accent
        property real rest: 1
        width: Math.round((pill.width - win.px(20)) * rest / win.u) * win.u
        NumberAnimation on rest {
            running: win.closing
            from: 1
            to: 0
            duration: win.closeMs
        }
    }

    // the right-click menu, in the Halo's look (MenuLook); it goes with the pill
    PxMenu {
        id: haloMenu
        parentWindow: win
        kind: "halo"
    }
    onShownChanged: if (!shown)
        haloMenu.close()
    function menuItems() {
        return [
            {
                "label": I18n.t("Спрятать на час", "Hide for an hour"),
                "icon": "moon",
                "run": () => Halo.hideFor(60 * 60 * 1000)
            },
            {
                "label": I18n.t("Настройки Нимба…", "Halo settings…"),
                "icon": "gear",
                "run": () => Shell.openSettings("halo")
            }
        ];
    }

    // someone records the microphone (orange), has the camera on (green) or takes the screen
    // (purple, as the Mac's screen recording), as on the iPhone:
    // a dot left of the pill or the arc (services/Sensors; Settings → Halo → «Privacy dot»)
    Item {
        id: privacy
        visible: Config.halo.privacyDot !== false && Sensors.active && !win.full
        readonly property real at: (win.open ? pill.height : ring.height) / 2
        width: privacyDots.width + win.u * 6
        height: win.u * 9
        x: hit.x + win.slack - width - win.u
        y: win.pillY + Math.round(at - height / 2)
        Row {
            id: privacyDots
            anchors.centerIn: parent
            spacing: win.u
            Rectangle {
                visible: Sensors.mic.length > 0
                width: win.u * 3
                height: win.u * 3
                radius: win.u
                color: "#ff9f0a"
            }
            Rectangle {
                visible: Sensors.cam.length > 0
                width: win.u * 3
                height: win.u * 3
                radius: win.u
                color: "#30d158"
            }
            Rectangle {
                visible: Sensors.screen.length > 0
                width: win.u * 3
                height: win.u * 3
                radius: win.u
                color: "#bf5af2"
            }
        }
        HoverHandler {
            id: privacyHover
        }
    }
    // who it is: under the dot while the pointer is on it
    PxPill {
        visible: privacy.visible && privacyHover.hovered
        z: 6
        width: whoText.implicitWidth + win.u * 8
        height: whoText.implicitHeight + win.u * 4
        x: Math.max(win.u * 2, privacy.x + privacy.width - width)
        y: privacy.y + privacy.height + win.u
        color: win.face
        edge: win.line
        PxText {
            id: whoText
            anchors.centerIn: parent
            text: Sensors.who
            kind: "tiny"
        }
    }

    // the other things: small round bubbles to the right of the pill
    Row {
        id: bubbleRow
        x: hit.x + pill.x + pill.width + win.u * 3
        y: win.pillY
        spacing: win.u * 3
        opacity: win.shown && (win.main || win.rest) && !win.expanded ? 1 : 0
        visible: opacity > 0 && win.others.length > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(Theme.fast)
            }
        }
        Repeater {
            model: win.bubbles
            PxPill {
                id: bubble
                required property var modelData
                width: win.px(14)
                height: win.px(14)
                color: win.face
                edge: win.line
                Glyph {
                    anchors.centerIn: parent
                    item: bubble.modelData
                }
                TapHandler {
                    onTapped: {
                        const p = Lyrics.player;
                        if (bubble.modelData.kind === "shelf")
                            win.openOn("shelf");
                        else if (bubble.modelData.kind === "paused") {
                            if (p && p.canPlay)
                                p.play();
                            else if (p && p.canTogglePlaying)
                                p.togglePlaying();
                        } else
                            win.picked = bubble.modelData.key;
                    }
                }
            }
        }
        PxText {
            visible: win.more > 0
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + win.more
            dim: true
        }
    }

    // ---- what the pill, a bubble and the card say ----
    function timerOf(item) {
        return item && item.kind === "timer" ? Timers.find(item.id) : null;
    }
    function timerText(t) {
        if (!t)
            return "";
        return Timers.clock(t.kind === "stopwatch" ? Timers.elapsed(t, now) : Timers.left(t, now));
    }
    function running(t) {
        return !!t && !!(t.kind === "stopwatch" ? t.start : t.end);
    }
    function recTime(item) {
        return Timers.clock(item.own ? Capture.recElapsed(now) : Math.max(0, now - item.since));
    }
    // the open card's line under the title of a simple one
    function cardBody(item) {
        const c = Achievements.current;
        switch (item ? item.kind : "") {
        case "notif":
            return onAir ? "" : String(item.body || "").replace(/<[^>]*>/g, "");
        case "call":
            return Halo.callApp.toLowerCase().includes("discord") && DiscordVoice.state === "call" && DiscordVoice.channel ? I18n.t("Канал: ", "Channel: ") + DiscordVoice.channel : "";
        case "net":
            return Wifi.connectivityText;
        case "power":
            return Power.statusText;
        case "dlDone":
            return I18n.t("Лежит на полке.", "It is on the shelf.");
        case "update":
            return Updates._lastSay;
        case "updated":
            return item.ok ? "" : Updates.failure;
        case "trophy":
            return c ? [c.name, c.desc, c.reward ? I18n.t("Награда: ", "Reward: ") + c.reward : ""].filter(x => x).join("\n") : "";
        case "chest":
            return I18n.t("Бесплатная молитва: карточка в альбом или скин ангела.", "A free prayer: a card for the album or one of the angel's skins.");
        }
        return "";
    }
    // the achievement card's head: what it is and its tier (as AchievementToast says it)
    function trophyHead() {
        const c = Achievements.current;
        if (!c)
            return "";
        if (c.kind === "diary")
            return I18n.t("Новая запись в дневнике", "A new page in the diary");
        if (c.hell || Theme.hell)
            return c.secret ? I18n.t("Тайный грех", "A secret sin") : I18n.t("Грех засчитан", "A sin counted");
        return (c.secret ? I18n.t("Тайное достижение", "Secret achievement") : I18n.t("Достижение", "Achievement")) + " · " + (c.plugin || Achievements.tierName(c.tier));
    }
    // «Open» on the game's cards: the diary's page, the thing it gave, the list; the chest
    function openGame(kind) {
        if (kind === "chest") {
            Halo.chestWaiting = false;
            Chests.openOne();
            return;
        }
        const c = Achievements.current;
        if (!c)
            return;
        if (c.kind === "diary")
            Diary.open(c.page);
        else if (c.thing)
            Heaven.use(c.thing);
        else
            Shell.openSettings("achievements");
    }

    // the short and simple capsules: {icon, text, bad}
    function simple(item) {
        const k = item ? item.kind : "";
        const n = Downloads.active.length;
        const c = Achievements.current;
        switch (k) {
        case "net":
            return item.on ? {
                "icon": Wifi.connected ? "wifi" : "ethernet",
                "text": I18n.t("Интернет есть", "Online")
            } : {
                "icon": "wifiOff",
                "text": I18n.t("Нет интернета", "Offline"),
                "bad": true
            };
        case "power":
            return {
                "icon": "bolt",
                "text": Power.percent + "%"
            };
        case "castPause":
            return {
                "icon": "pause",
                "text": I18n.t("Зрители видят паузу", "Viewers see the pause")
            };
        case "dl": {
            // the ring beside it and the percent; the bytes of one when nobody knows the size
            const far = Downloads.overall >= 0 ? Math.floor(Downloads.overall * 100) + "%" : n === 1 ? Downloads.bytes(Downloads.active[0].size) : "";
            return {
                "icon": "download",
                "text": [n > 1 ? I18n.t("Загрузки: ", "Downloads: ") + n : n && !onAir ? Downloads.active[0].name : "", far].filter(x => x).join(" · ")
            };
        }
        case "dlDone":
            return {
                "icon": "download",
                "text": onAir ? I18n.t("Скачано", "Downloaded") : item.name
            };
        case "update":
            return {
                "icon": "refresh",
                "text": I18n.t("Обновление…", "Updating…")
            };
        case "updated":
            return item.ok ? {
                "icon": "check",
                "text": I18n.t("angelOS обновлена", "angelOS updated")
            } : {
                "icon": "warn",
                "text": I18n.t("Обновление не удалось", "The update failed"),
                "bad": true
            };
        case "trophy":
            return {
                "icon": c && c.kind === "diary" ? "document" : "star",
                "text": c ? c.name : ""
            };
        case "chest":
            return {
                "icon": "sparkleStar",
                "text": I18n.t("Сундук дня", "The day's chest")
            };
        case "place":
            return {
                "icon": "pin",
                "text": item.app + " → " + I18n.t("стол ", "desk ") + item.desk
            };
        case "notif":
            return {
                "icon": "bell",
                "text": [item.app, item.summary].filter(x => x).join(" · ")
            };
        case "osd":
            return {
                "icon": item.what === "brightness" ? "sun" : item.what === "kbd" ? "keyboard" : item.what === "mic" ? (Audio.micMuted ? "micMute" : "mic") : (Audio.muted ? "speakerMute" : "speaker"),
                "text": Math.round(Halo.osdLevel(item.what) * 100) + "%"
            };
        case "chat":
            return {
                "icon": item.amount ? "heart" : "chat",
                "text": item.author + (item.amount ? " · " + item.amount : "") + (item.text ? ": " + item.text : "")
            };
        case "call":
            return {
                "icon": Halo.callMuted ? "micMute" : "phone",
                "text": Halo.callApp + " · " + Timers.clock(Math.max(0, now - Halo.callSince))
            };
        }
        return null;
    }
    // a drop on one of the targets: shelf | share | folder (a favourite folder's id)
    // one format of a drop, read straight (Helium's drag on Wayland leaves the ready-made
    // urls/html/text empty though it offers them)
    function dragString(ev, fmt) {
        try {
            return (ev.formats || []).includes(fmt) ? String(ev.getDataAsString(fmt) || "") : "";
        } catch (e) {
            return "";
        }
    }
    // Chromium (Helium) offers a web picture as text/x-moz-url, no text/uri-list; Qt's Wayland
    // plugin renames that to text/uri-list and *accepts* the drag under the new name, which
    // the source never offered — niri (smithay) calls the drag unaccepted, cancels the source
    // at the drop and passes on no reads: every format came back empty (2026-10-16, traced on a
    // stand). While the drag is still over us the source answers: read everything once on
    // each enter, Qt keeps it for the offer, and drop() finds it there. A few ms (25 for 6 MB)
    function prefetch(ev) {
        for (const f of (ev.formats || []))
            if (/^text\/(uri-list|html|plain)$/.test(f) || /^application\/octet-stream;\s*name=/i.test(f) || /^image\//i.test(f))
                try {
                    ev.getDataAsArrayBuffer(f);
                } catch (e) {}
        if (ev.hasUrls)
            ev.urls;
    }
    function drop(target, ev, folderId) {
        const fmts = ev.formats || [];
        // moz-url is "url\ntitle": the title comes as a second "url" (a pin's name, "file:Cat.jpg")
        const absolute = u => /^[a-z][a-z0-9+.-]*:\/\//i.test(u);
        let urls = ev.hasUrls ? ev.urls.map(x => String(x)).filter(absolute) : [];
        if (!urls.length)
            urls = dragString(ev, "text/uri-list").split(/\r?\n/).map(x => x.trim()).filter(x => x && x[0] !== "#" && absolute(x));
        const html = (ev.hasHtml ? ev.html : "") || dragString(ev, "text/html");
        const text = (ev.hasText ? ev.text : "") || dragString(ev, "text/plain");
        const image = /<img/i.test(html);
        // the picture itself, as a browser hands it over (Chromium: «application/octet-stream;
        // name="x.jpg"»): the very bytes dragged, nothing to fetch
        const picFmt = fmts.find(f => /^application\/octet-stream;\s*name=/i.test(f)) || fmts.find(f => /^image\//i.test(f)) || "";
        let pic = null;
        if (picFmt && target !== "share")
            try {
                pic = ev.getDataAsArrayBuffer(picFmt);
            } catch (e) {}
        const picName = (picFmt.match(/name="?([^";]+)"?/i) || [])[1] || "";
        // what the source offered (a browser's drag varies): the journal tells when one goes wrong
        console.info("halo drop:", target, JSON.stringify(fmts), "urls " + urls.length + " " + urls.slice(0, 2).map(u => u.slice(0, 100)).join(" "), "html " + html.length, "text " + text.length, "pic " + (pic ? pic.byteLength : 0) + " " + picName, image ? "img " + Shelf.imgSrc(html).slice(0, 100) : "");
        const files = urls.filter(x => x.startsWith("file://")).map(x => decodeURIComponent(x.slice(7)));
        if (target === "share")
            QuickShare.share(files, files.length ? "" : urls[0] || text);
        else if (target === "folder")
            Shelf.intoFolder(folderId, urls);
        else {
            if (pic && pic.byteLength > 0 && !urls.some(u => u.startsWith("file://")))
                Shelf.addBytes(pic, picName, image ? Shelf.imgSrc(html) : "");
            else
                Shelf.addDrop(urls, text, image, image ? Shelf.imgSrc(html) : "");
            Sounds.play("toggle");
            page = pages.indexOf("shelf");
            ev.accept(Qt.CopyAction);
            dropLeave.stop();
            dropping = false;
            expanded = true;
            afterDrag(true);
            return;
        }
        ev.accept(Qt.CopyAction);
        dropLeave.stop();
        dropping = false;
        afterDrag();
    }
    // the song to the start of its line i (the offset of Settings → Lyrics counted back)
    function seekLine(i) {
        const p = Lyrics.player;
        const l = Lyrics.lines[i];
        if (!p || !p.canSeek || !l)
            return;
        p.position = Math.max(0, l.t - Config.lyrics.offsetMs / 1000 + 0.05);
        p.positionChanged();
        Lyrics.updateIndex();
    }
    // a player's name for the switcher: Spotify, Helium…
    function playerName(p) {
        const n = p.identity || p.desktopEntry || "";
        return n.charAt(0).toUpperCase() + n.slice(1);
    }

    component RecDot: Rectangle {
        property bool paused: false
        width: win.u * 3
        height: win.u * 3
        color: paused ? Theme.textDim : Theme.danger
        // a pixel blink with the seconds
        opacity: paused || Math.floor(win.now / 1000) % 2 ? 1 : 0.35
    }

    // the song's cover as a record in whole pixels (shaders/halo_vinyl): a rim in the Halo's
    // colour, the spindle hole, grooves (Player's «vinyl»)
    component Cover: Item {
        id: cov
        property int size: win.px(10)
        property real spin: 0
        readonly property bool small: size < win.px(20)
        width: size
        height: size
        Image {
            id: art
            anchors.fill: parent
            source: Lyrics.artUrl
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // nearest pixels: the shader takes one per art pixel, no smearing between them
            smooth: false
            // only the shader's texture (an Image is one even unseen)
            visible: false
        }
        ShaderEffect {
            anchors.fill: parent
            readonly property real dpr: Window.window && Window.window.devicePixelRatio > 0 ? Window.window.devicePixelRatio : 1
            readonly property real artPx: Math.max(1, Math.round(win.u * dpr))
            property size cells: Qt.size(Math.max(1, Math.round(width * dpr / artPx)), Math.max(1, Math.round(height * dpr / artPx)))
            property real angle: cov.spin
            property real plain: cov.small ? 1 : 0
            property real hasArt: art.status === Image.Ready ? 1 : 0
            property color cRim: win.accent
            property color cHole: Theme.dark ? "#000000" : Theme.edge
            property color cBlank: Theme.mix(win.face, win.accent, 0.35)
            property variant source: art
            fragmentShader: Qt.resolvedUrl("../../shaders/halo_vinyl.frag.qsb")
        }
    }

    // a little spectrum of pixel blocks (music.sh's, small): four columns dancing while it plays
    component EqBars: Row {
        id: eq
        spacing: Math.max(1, win.u / 2)
        // whole blocks on one shared timer, not an endless NumberAnimation per column: that one
        // kept the whole Halo window drawing at the monitor's rate for four steps (22.10)
        property int tick: 0
        Timer {
            interval: 130
            repeat: true
            running: eq.visible && Lyrics.playing && win.shown && !win.expanded && !Motion.still
            onTriggered: eq.tick++
        }
        Repeater {
            // each column's phase in the 1 → 4 → 1 swing
            model: [0, 5, 2, 4]
            Item {
                id: bar
                required property int modelData
                readonly property int blk: win.u * 2
                readonly property int gap: Math.max(1, win.u / 2)
                width: blk
                height: blk * 4 + gap * 3
                readonly property int v: 1 + [0, 1, 2, 3, 2, 1][(eq.tick + modelData) % 6]
                Column {
                    anchors.bottom: parent.bottom
                    spacing: bar.gap
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: bar.blk
                            height: bar.blk
                            visible: index >= 4 - Math.round(bar.v)
                            color: Lyrics.playing ? Theme.mix(Theme.accent2, win.accent, (4 - index) / 4) : Theme.textDim
                        }
                    }
                }
            }
        }
    }

    // the song's cover small and square, in whole art pixels (music.sh's way: a tiny source, no
    // smoothing); no cover yet: a plate of the accent
    component Art: Item {
        id: art
        property int size: win.u * 8
        width: size
        height: size
        Rectangle {
            visible: artImg.status !== Image.Ready
            anchors.fill: parent
            color: Theme.mix(win.face, win.accent, 0.35)
        }
        Image {
            id: artImg
            anchors.fill: parent
            source: Lyrics.artUrl
            sourceSize: Qt.size(Math.max(4, Math.round(art.size / win.u)), Math.max(4, Math.round(art.size / win.u)))
            fillMode: Image.PreserveAspectCrop
            smooth: false
            asynchronous: true
        }
    }

    // a clock that reads on the pill: the face the pill's colour, the rim and hands the accent
    // the halo's pixel arc: an ellipse's outline, column by column (the bare ring at rest, and
    // between the sides of the resting pill)
    component Arc: Item {
        id: arc
        property int cols: 26
        property int rows: 5
        width: cols * win.u
        height: rows * win.u
        Repeater {
            model: arc.cols
            Item {
                id: col
                required property int index
                readonly property real cx: (index + 0.5 - arc.cols / 2) / (arc.cols / 2)
                readonly property real dy: Math.sqrt(Math.max(0, 1 - cx * cx)) * (arc.rows - 1) / 2
                x: index * win.u
                Rectangle {
                    y: Math.round((arc.rows - 1) / 2 - col.dy) * win.u
                    width: win.u
                    height: win.u
                    color: win.pointerHere ? win.accent : Qt.alpha(win.accent, 0.85)
                }
                Rectangle {
                    y: Math.round((arc.rows - 1) / 2 + col.dy) * win.u
                    width: win.u
                    height: win.u
                    color: win.accent
                    opacity: 0.6
                }
            }
        }
    }

    // a side of the resting pill: the clock, the weather now, or the screen time today
    component RestBit: Row {
        id: rb
        property string what: "none"
        property real maxW: 0
        visible: what !== "none"
        spacing: win.u * 2
        // the song or video without synced lyrics: its cover and the dancing bars
        Art {
            visible: rb.what === "music"
            anchors.verticalCenter: parent.verticalCenter
        }
        EqBars {
            visible: rb.what === "music"
            anchors.verticalCenter: parent.verticalCenter
        }
        PxIcon {
            visible: rb.what !== "clock" && rb.what !== "music"
            anchors.verticalCenter: parent.verticalCenter
            name: rb.what === "weather" ? (Weather.ok ? Weather.icon(Weather.now.code, Weather.now.day) : "sun") : "monitor"
        }
        PxText {
            visible: rb.what !== "music"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(0, rb.maxW - (rb.what !== "clock" ? win.u * 12 : 0)))
            elide: Text.ElideRight
            text: rb.what === "clock" ? Qt.formatTime(new Date(win.now), "hh:mm") : rb.what === "weather" ? (Weather.ok ? Weather.deg(Weather.now.temp) : "") : rb.what === "screen" ? Wellbeing.fmt(Wellbeing.todaySeconds) : ""
        }
    }

    // RunCat's cat (modules/halo/HaloCat.js) in the text colour: a steady frame each 200 ms (it
    // used to follow win.cpu, so the shell's own load sped it up, a feedback loop); a
    // minute without input it sleeps as a loaf, breathing, a «z» rising; the pointer on the Halo
    // wakes it; in hell it turns red. One still frame when motion is reduced
    component RestCat: Item {
        id: cat
        property int pixel: win.u
        property color ink: win.inkColor
        property int tick: 0
        // a click: it purrs a moment — a pixel heart rises, «мрр»
        property bool petable: false
        property bool purring: false
        TapHandler {
            enabled: cat.petable
            onTapped: {
                cat.purring = true;
                purrOff.restart();
            }
        }
        HoverHandler {
            enabled: cat.petable
            cursorShape: Qt.PointingHandCursor
        }
        Timer {
            id: purrOff
            interval: 1600
            onTriggered: cat.purring = false
        }
        readonly property bool napping: win.dozing && !win.pointerHere
        readonly property bool moving: visible && win.shown && !Motion.still
        // bongo (Settings → Halo): at its desk while keys are pressed, a paw down for each
        // (KeyCast taps: the keyboard's side); both paws up between them, back to running after
        property string paw: ""             // "" | up | left | right | both
        Connections {
            target: KeyCast
            enabled: cat.moving
            function onTapped(side) {
                cat.paw = side === "l" ? "left" : side === "r" ? "right" : "both";
                pawUp.restart();
                pawOff.restart();
            }
        }
        Timer {
            id: pawUp
            interval: 110
            onTriggered: cat.paw = "up"
        }
        Timer {
            id: pawOff
            interval: 900
            onTriggered: cat.paw = ""
        }
        // the stream's chat capsule: cheering, a heart for a paid message
        property bool cheer: false
        property bool gift: false
        readonly property var frame: cheer ? Kitty.bongo.up : paw !== "" && moving ? Kitty.bongo[paw] : napping ? Kitty.nap[moving ? Math.floor(tick / 2) % 2 : 0] : moving ? Kitty.run[tick % 5] : Kitty.run[0]
        width: 20 * pixel
        height: 12 * pixel
        Timer {
            interval: cat.napping ? 1000 : 200
            repeat: true
            running: cat.moving
            onTriggered: cat.tick++
        }
        PxIcon {
            bitmap: cat.frame
            pixel: cat.pixel
            ink: cat.ink
        }
        PxIcon {
            visible: cat.purring || cat.gift
            name: "heart"
            pixel: cat.pixel
            x: 16 * cat.pixel
            y: -(cat.tick % 4) * cat.pixel
        }
        PxText {
            visible: cat.purring
            x: 22 * cat.pixel
            y: 0
            text: I18n.t("мрр", "purr")
            kind: "tiny"
            dim: true
        }
        // the «z» over its back, rising a step a tick, gone every fourth
        PxIcon {
            readonly property int step: cat.tick % 4
            visible: cat.napping && cat.moving && step < 3
            bitmap: Kitty.zz
            pixel: cat.pixel
            x: (8 + step) * cat.pixel
            y: (4 - step * 2) * cat.pixel
            ink: cat.ink
            opacity: 0.7
        }
    }

    // the pixel dissolve of the closed pill's content (shaders/halo_dissolve): whole art pixels
    // in an ordered-dither order, the leaving layer's cells going where the coming one's appear
    component Dissolve: ShaderEffect {
        property real vis: 1
        property real incoming: 1
        readonly property real dpr: Window.window && Window.window.devicePixelRatio > 0 ? Window.window.devicePixelRatio : 1
        readonly property real artPx: Math.max(1, Math.round(win.u * dpr))
        property size cells: Qt.size(Math.max(1, Math.round(width * dpr / artPx)), Math.max(1, Math.round(height * dpr / artPx)))
        fragmentShader: Qt.resolvedUrl("../../shaders/halo_dissolve.frag.qsb")
    }

    component Clock: PxIcon {
        name: "clock"
        ink: win.accent
        light: win.face
    }

    // the strip of pages: where page i stands now, and whether any of it is in sight
    function pageX(i) {
        const step = px(12);
        return Math.round((i - slide) * (card.width + u * 8) / step) * step;
    }
    function pageSeen(i) {
        return Math.abs(i - slide) < 0.999;
    }
    // a bubble's picture
    component Glyph: Item {
        id: gl
        property var item: null
        width: win.u * 10
        height: win.u * 10
        RecDot {
            anchors.centerIn: parent
            visible: !!gl.item && gl.item.kind === "rec"
            width: win.u * 4
            height: win.u * 4
        }
        Clock {
            anchors.centerIn: parent
            visible: !!gl.item && (gl.item.kind === "timer" || gl.item.kind === "ring")
        }
        Art {
            anchors.centerIn: parent
            visible: !!gl.item && (gl.item.kind === "music" || gl.item.kind === "paused")
            opacity: gl.item && gl.item.kind === "paused" ? 0.55 : 1
        }
        // the paused song: ▶ over its dimmed cover, a click plays it on
        PxIcon {
            anchors.centerIn: parent
            visible: !!gl.item && gl.item.kind === "paused"
            name: "play"
            ink: Theme.text
            fill: Theme.text
        }
        Stack {
            anchors.centerIn: parent
            visible: !!gl.item && gl.item.kind === "shelf"
        }
        Swatch {
            anchors.centerIn: parent
            visible: !!gl.item && gl.item.kind === "pick"
            hex: gl.item && gl.item.hex || ""
        }
        PxIcon {
            anchors.centerIn: parent
            readonly property var s: win.simple(gl.item)
            visible: !!s && gl.item.kind !== "dl"
            name: s ? s.icon : "star"
        }
        PxRing {
            anchors.centerIn: parent
            visible: !!gl.item && gl.item.kind === "dl"
            size: win.u * 9
            value: Downloads.overall
        }
    }

    // a picked colour's square
    component Swatch: Rectangle {
        property string hex: ""
        width: win.u * 8
        height: win.u * 8
        color: hex || "transparent"
        border.width: win.u
        border.color: win.line
    }

    // the shelf's stack: a pixel sheet and the number of things on it
    component Stack: Item {
        width: win.u * 10
        height: win.u * 10
        Rectangle {
            x: win.u * 2
            y: 0
            width: win.u * 7
            height: win.u * 8
            color: "transparent"
            border.width: win.u
            border.color: Theme.textDim
        }
        Rectangle {
            x: 0
            y: win.u * 2
            width: win.u * 7
            height: win.u * 8
            color: win.face
            border.width: win.u
            border.color: win.accent
        }
        PxText {
            x: 0
            y: win.u * 2
            width: win.u * 7
            height: win.u * 8
            horizontalAlignment: Text.AlignHCenter
            text: String(Math.min(99, Shelf.count))
            kind: "tiny"
        }
    }

    // the pill, closed: the thing at the left, its state at the right
    component Compact: Row {
        id: cp
        property var item: null
        readonly property string kind: item ? item.kind : ""
        readonly property var t: win.timerOf(item)
        readonly property var s: win.simple(item)
        spacing: win.u * 4

        // a timer's end
        Clock {
            visible: cp.kind === "ring"
            anchors.verticalCenter: parent.verticalCenter
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "ring"
            text: Halo.rang ? Halo.rang.head : ""
        }

        // a recording (ours paused: a still grey dot); the microphone when it records that
        RecDot {
            visible: cp.kind === "rec"
            anchors.verticalCenter: parent.verticalCenter
            paused: !!cp.item && cp.item.own !== false && Capture.recPaused
        }
        PxIcon {
            visible: cp.kind === "rec" && cp.item.own !== false && Config.capture.recordAudio === "mic"
            anchors.verticalCenter: parent.verticalCenter
            name: "mic"
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "rec"
            text: cp.item && cp.item.own === false ? "OBS" : Capture.recPaused ? I18n.t("Пауза", "Paused") : I18n.t("Запись", "Rec")
            dim: true
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "rec"
            text: cp.kind === "rec" ? win.recTime(cp.item) : ""
        }

        // a timer
        Clock {
            visible: !!cp.t
            anchors.verticalCenter: parent.verticalCenter
            name: cp.t && cp.t.kind === "pomodoro" && cp.t.phase === "rest" ? "coffee" : "clock"
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!cp.t && !!cp.t.label
            text: cp.t ? cp.t.label : ""
            dim: true
            elide: Text.ElideRight
            width: Math.min(implicitWidth, win.px(80))
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!cp.t
            text: win.timerText(cp.t)
            dim: !win.running(cp.t)
        }

        // the music: the lyric line when it lives here, else the cover and the song
        // (the lyric line brings its own cover)
        Art {
            visible: cp.kind === "music" && !lyr.visible
            anchors.verticalCenter: parent.verticalCenter
            size: win.u * 10
        }
        BarLyrics {
            id: lyr
            visible: cp.kind === "music" && win.lyricsHere && active
            anchors.verticalCenter: parent.verticalCenter
            screenName: win.modelData.name
            place: "halo"
            fixedWidth: false
            maxWidth: win.fixedWidth ? win.innerW - win.u * 12 : Math.min(win.px(160), win.width - win.u * 60)
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "music" && !lyr.visible
            text: Lyrics.title
            elide: Text.ElideRight
            width: Math.min(implicitWidth, win.fixedWidth ? win.innerW - win.px(10) - win.u * 16 : win.u * 100)
        }
        EqBars {
            visible: cp.kind === "music"
            anchors.verticalCenter: parent.verticalCenter
        }

        // a picked colour
        Swatch {
            visible: cp.kind === "pick"
            anchors.verticalCenter: parent.verticalCenter
            hex: cp.item && cp.item.hex || ""
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "pick"
            text: cp.item && cp.item.hex || ""
        }
        // the short and simple ones (win.simple): an icon and a word
        // a call: a green dot breathing
        Rectangle {
            visible: cp.kind === "call"
            anchors.verticalCenter: parent.verticalCenter
            width: win.u * 4
            height: win.u * 4
            color: Theme.ok
            opacity: (win.now / 1000) % 2 < 1 ? 1 : 0.55
        }
        // a notification: the app's own picture when it sends one
        Image {
            id: notifPic
            visible: cp.kind === "notif" && status === Image.Ready
            anchors.verticalCenter: parent.verticalCenter
            width: win.px(12)
            height: win.px(12)
            source: cp.kind === "notif" && cp.item.icon && !win.onAir ? cp.item.icon : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: false
        }
        PxIcon {
            visible: !!cp.s && !notifPic.visible && cp.kind !== "call" && cp.kind !== "chat"
            anchors.verticalCenter: parent.verticalCenter
            name: cp.s ? cp.s.icon : "star"
        }
        // a viewer wrote in the stream's chat: the Halo's cat cheers it (a heart for a paid one)
        RestCat {
            visible: cp.kind === "chat"
            anchors.verticalCenter: parent.verticalCenter
            cheer: true
            gift: cp.kind === "chat" && !!cp.item.amount
            ink: win.textInk
        }
        // volume / brightness: the bar of blocks
        BlockBar {
            visible: cp.kind === "osd"
            anchors.verticalCenter: parent.verticalCenter
            width: win.px(70)
            value: cp.kind === "osd" ? Halo.osdLevel(cp.item.what) : 0
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!cp.s && cp.s.text !== ""
            text: cp.s ? cp.s.text : ""
            color: cp.s && cp.s.bad ? Theme.danger : win.textInk
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, win.px(140))
        }
        // a download: the round progress at the right, as the iPhone's island
        PxRing {
            visible: cp.kind === "dl"
            anchors.verticalCenter: parent.verticalCenter
            cell: win.u
            size: win.px(12)
            value: Downloads.overall
        }

        // the wheel's player volume, a moment
        PxIcon {
            visible: cp.kind === "vol"
            anchors.verticalCenter: parent.verticalCenter
            name: "speaker"
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "vol"
            text: cp.kind === "vol" && Lyrics.player ? Math.round(Lyrics.player.volume * 100) + "%" : ""
        }

        // a screenshot just saved: its picture and a word
        Image {
            visible: cp.kind === "shot"
            anchors.verticalCenter: parent.verticalCenter
            height: win.px(12)
            width: Math.round(height * 16 / 9)
            source: cp.kind === "shot" ? "file://" + cp.item.path : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "shot"
            text: I18n.t("Скриншот", "Screenshot")
        }

        // Shift+wheel's seek, a moment: where the song is now
        PxIcon {
            visible: cp.kind === "seek"
            anchors.verticalCenter: parent.verticalCenter
            name: "next"
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "seek"
            text: cp.kind === "seek" && Lyrics.player ? Timers.clock((win.now, Lyrics.player.position) * 1000) + (Lyrics.length > 0 ? " / " + Timers.clock(Lyrics.length * 1000) : "") : ""
        }

        // the shelf alone
        Stack {
            visible: cp.kind === "shelf"
            anchors.verticalCenter: parent.verticalCenter
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.kind === "shelf"
            text: I18n.t("на полке", "on the shelf")
            dim: true
        }
    }

    // ---- the open card's pieces, drawn as the desktop widgets draw theirs (the owner's 16.10
    // answers «как окна-виджеты»): sunken square plates, buttons, a bar of pixel blocks, one font ----

    // a plate: a sunken square piece of the window (music.sh's cover well); a clickable one lights
    // up under the pointer
    component Well: PxBox {
        id: well
        property bool clickable: false
        property bool lit: false
        readonly property bool hovered: wellHov.hovered
        signal clicked
        hell: win.hell
        sunken: true
        readonly property color base: win.hell ? Theme.hellSunken : Theme.sunken
        color: lit || (clickable && wellHov.hovered) ? Theme.mix(base, win.accent, 0.22) : base
        edgeColor: lit ? win.accent : win.hell ? Theme.hellEdge : Theme.edge
        HoverHandler {
            id: wellHov
            cursorShape: well.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            enabled: well.clickable
            onTapped: well.clicked()
        }
    }

    // a bar of pixel blocks (████░░░, as music.sh's spectrum is built): how far a song, a timer, a
    // download is; value < 0: nobody knows, a block runs along. seekable: a click moves it there
    component BlockBar: Item {
        id: bb
        property real value: 0
        property bool paused: false
        property bool seekable: false
        signal seek(real frac)
        readonly property int cell: win.u * 3
        readonly property int gap: win.u
        readonly property int n: Math.max(1, Math.floor((width + gap) / (cell + gap)))
        readonly property int lit: value < 0 ? 0 : Math.round(Math.max(0, Math.min(1, value)) * n)
        property int runAt: 0
        implicitHeight: cell
        Timer {
            interval: 120
            repeat: true
            running: bb.value < 0 && !bb.paused && bb.visible && win.shown
            onTriggered: bb.runAt = (bb.runAt + 1) % bb.n
        }
        Row {
            spacing: bb.gap
            Repeater {
                model: bb.n
                Rectangle {
                    required property int index
                    readonly property bool on: bb.value < 0 ? Math.abs(index - bb.runAt) < 2 : index < bb.lit
                    width: bb.cell
                    height: bb.cell
                    color: on ? (bb.paused ? Theme.textDim : win.accent) : Qt.alpha(Theme.text, 0.16)
                }
            }
        }
        HoverHandler {
            enabled: bb.seekable
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            enabled: bb.seekable
            onTapped: e => bb.seek(Math.max(0, Math.min(1, e.position.x / bb.width)))
        }
    }

    // a line that doesn't fit ends in «…»; the pointer on it, it runs along to its end and back
    component RunText: Item {
        id: rt
        property string text: ""
        property bool dim: false
        property bool bold: false
        property string kind: "body"
        property color color: dim ? Theme.textDim : Theme.text
        property int align: Text.AlignLeft
        readonly property bool running: t.implicitWidth > width && rtHov.hovered
        property real off: 0
        onRunningChanged: if (!running)
            off = 0
        implicitHeight: t.implicitHeight
        clip: true
        PxText {
            id: t
            x: Math.round(rt.off / win.u) * win.u
            width: rt.running ? implicitWidth : rt.width
            text: rt.text
            kind: rt.kind
            color: rt.color
            font.bold: rt.bold
            elide: rt.running ? Text.ElideNone : Text.ElideRight
            horizontalAlignment: rt.running ? Text.AlignLeft : rt.align
        }
        SequentialAnimation on off {
            running: rt.running && !Motion.still
            loops: Animation.Infinite
            PauseAnimation {
                duration: 500
            }
            NumberAnimation {
                from: 0
                to: rt.width - t.implicitWidth
                duration: Math.max(600, (t.implicitWidth - rt.width) / (win.u * 24) * 1000)
            }
            PauseAnimation {
                duration: 900
            }
            NumberAnimation {
                to: 0
                duration: 250
            }
        }
        HoverHandler {
            id: rtHov
        }
    }

    // an event's head, one shape for every one of them: its picture in a plate on the left, the
    // title and a line, what counts on the right (a time, a percent)
    component Head: Item {
        id: hd
        property string icon: ""
        property string title: ""
        property string line: ""
        property string side: ""
        property bool sideDim: false
        property bool bad: false
        // a picture of its own instead of the icon (a cover, a dot, a colour)
        default property alias glyph: glyphBox.data
        implicitHeight: Math.max(plate.height, textCol.implicitHeight)
        Well {
            id: plate
            width: win.u * 16
            height: width
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            id: glyphBox
            anchors.fill: plate
        }
        PxIcon {
            visible: hd.icon !== ""
            anchors.centerIn: plate
            name: hd.icon || "star"
            light: plate.color
        }
        Column {
            id: textCol
            x: plate.width + win.u * 4
            width: hd.width - x - (sideText.visible ? sideText.width + win.u * 4 : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.u
            RunText {
                width: parent.width
                text: hd.title
                bold: true
                color: hd.bad ? Theme.danger : Theme.text
            }
            RunText {
                visible: hd.line !== ""
                width: parent.width
                text: hd.line
                dim: true
            }
        }
        PxText {
            id: sideText
            visible: hd.side !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: hd.side
            kind: "big"
            dim: hd.sideDim
        }
    }

    // the song as music.sh has it: the picture in its plate (Settings → Halo → «Music»: a square
    // cover, a record turning, a cassette with the cover on its label), the title and the artist,
    // the bar of blocks (a click moves the song) and the three buttons
    component Player: Item {
        id: pl
        property real art: win.px(36)
        readonly property string view: Config.halo.musicView || "cover"
        implicitHeight: Math.max(art, info.implicitHeight)
        Well {
            id: artWell
            width: pl.view === "cassette" ? Math.round(pl.art * 1.5 / win.u) * win.u : pl.art
            height: pl.art
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: sq
                visible: pl.view === "cover" && status === Image.Ready
                anchors.fill: parent
                source: Lyrics.artUrl
                // a source pixel an art pixel, no smoothing: a pixel cover, as music.sh's
                sourceSize: Qt.size(Math.max(8, Math.round(pl.art / win.u)), Math.max(8, Math.round(pl.art / win.u)))
                fillMode: Image.PreserveAspectCrop
                smooth: false
                asynchronous: true
            }
            PxIcon {
                visible: pl.view === "cover" && sq.status !== Image.Ready
                anchors.centerIn: parent
                name: "music"
                pixel: win.u * 2
            }
            Cover {
                id: disc
                visible: pl.view === "vinyl"
                anchors.centerIn: parent
                size: pl.art - win.u * 2
                NumberAnimation on spin {
                    running: disc.visible && Lyrics.playing && win.expanded && !Motion.still
                    from: 0
                    to: Math.PI * 2
                    duration: 4000
                    loops: Animation.Infinite
                }
            }
            Cassette {
                visible: pl.view === "cassette"
                anchors.fill: parent
                anchors.margins: win.u * 2
            }
        }
        Column {
            id: info
            x: artWell.width + win.u * 5
            width: pl.width - x
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.u * 2
            RunText {
                width: parent.width
                text: Lyrics.title
                bold: true
            }
            RunText {
                visible: Lyrics.artist !== ""
                width: parent.width
                text: Lyrics.artist
                dim: true
            }
            BlockBar {
                visible: Lyrics.length > 0
                width: parent.width
                value: win.now && Lyrics.player ? Lyrics.player.position / Math.max(1, Lyrics.length) : 0
                seekable: !!Lyrics.player && Lyrics.player.canSeek
                onSeek: f => {
                    Lyrics.player.position = f * Lyrics.length;
                    Lyrics.player.positionChanged();
                }
            }
            Row {
                id: transport
                spacing: win.u * 2
                PxButton {
                    id: prevBtn
                    compact: true
                    hell: win.hell
                    icon: "prev"
                    iconPixel: Math.max(1, win.u - 1)
                    enabled: !!Lyrics.player && Lyrics.player.canGoPrevious
                    onClicked: Lyrics.player.previous()
                }
                PxButton {
                    compact: true
                    hell: win.hell
                    icon: Lyrics.playing ? "pause" : "play"
                    iconPixel: Math.max(1, win.u - 1)
                    onClicked: if (Lyrics.player && Lyrics.player.canTogglePlaying)
                        Lyrics.player.togglePlaying()
                }
                PxButton {
                    compact: true
                    hell: win.hell
                    icon: "next"
                    iconPixel: Math.max(1, win.u - 1)
                    enabled: !!Lyrics.player && Lyrics.player.canGoNext
                    onClicked: Lyrics.player.next()
                }
                // osu!mini's rhythm mode on this track (plugin osu-mini, while it is on)
                // the button's width with its word, measured unseen (a Row skips what isn't
                // visible): in a narrow card the word goes and the note alone stays inside it
                PxButton {
                    id: rhythmProbe
                    visible: false
                    compact: true
                    icon: "music"
                    iconPixel: Math.max(1, win.u - 1)
                    text: rhythmBtn.word
                }
                PxButton {
                    id: rhythmBtn
                    readonly property string word: I18n.t("Ритм", "Rhythm")
                    visible: JSON.parse(Plugins.enabledIds).includes("osu-mini")
                    compact: true
                    hell: win.hell
                    icon: "music"
                    iconPixel: Math.max(1, win.u - 1)
                    text: transport.parent.width >= prevBtn.width * 3 + transport.spacing * 3 + rhythmProbe.implicitWidth + (swap.visible ? swap.width + transport.spacing : 0) ? word : ""
                    enabled: Lyrics.playing
                    onClicked: {
                        Shell.gameAsk = "rhythm";
                        Shell.gameOpen = true;
                    }
                    onHoveredChanged: win.hint(rhythmBtn, I18n.t("Ритм-игра под этот трек: D — слова, K — бит", "A rhythm game on this track: D the words, K the beat"), hovered)
                }
                // two players at once (Spotify and a video in the browser): the next one shown
                PxButton {
                    id: swap
                    readonly property var list: Lyrics.players.filter(p => !!p.trackTitle)
                    readonly property var next: list.length > 1 ? list[(list.indexOf(Lyrics.player) + 1) % list.length] : null
                    visible: !!next
                    compact: true
                    hell: win.hell
                    text: "⇄"
                    onClicked: Lyrics.pinned = next
                    onHoveredChanged: win.hint(swap, (Lyrics.player ? win.playerName(Lyrics.player) : "") + " → " + (next ? win.playerName(next) : ""), hovered)
                }
            }
        }
    }

    // a cassette: the cover on its label, two reels behind a window turning while it plays
    component Cassette: Item {
        id: cas
        property int frame: 0
        Timer {
            interval: 160
            repeat: true
            running: cas.visible && Lyrics.playing && win.expanded && !Motion.still
            onTriggered: cas.frame = (cas.frame + 1) % 2
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.mix(win.face, win.accent, 0.3)
            border.width: win.u
            border.color: win.inkColor
        }
        Image {
            x: win.u * 2
            y: win.u * 2
            width: parent.width - win.u * 4
            height: Math.round(parent.height * 0.4 / win.u) * win.u
            source: Lyrics.artUrl
            sourceSize: Qt.size(win.u * 16, win.u * 6)
            fillMode: Image.PreserveAspectCrop
            smooth: false
            asynchronous: true
        }
        Rectangle {
            x: win.u * 4
            y: Math.round(parent.height * 0.5 / win.u) * win.u
            width: parent.width - win.u * 8
            height: Math.round(parent.height * 0.35 / win.u) * win.u
            color: Qt.darker(win.face, 1.4)
            Row {
                anchors.centerIn: parent
                spacing: Math.round(parent.width * 0.25 / win.u) * win.u
                Repeater {
                    model: 2
                    PxIcon {
                        bitmap: cas.frame ? ["..###..", ".#...#.", "#.#.#.#", "#..#..#", "#.#.#.#", ".#...#.", "..###.."] : ["..###..", ".#.#.#.", "#..#..#", "####.##", "#..#..#", ".#.#.#.", "..###.."]
                        pixel: Math.max(1, win.u / 2)
                        ink: win.inkColor
                    }
                }
            }
        }
    }

    // the song's spectrum as music.sh's (its own cava, only while the card shows it)
    component Spectrum: MusicSpectrum {
        screenName: win.modelData.name
        widget: ({
                "uid": "halo-" + win.modelData.name,
                "settings": {
                    "bars": 24
                }
            })
        face: true
        rows: 4
        mac: false
    }

    // ---- the open Halo at rest: tiles (the owner's 16.10 answers): the song (or the weather) big
    // on the left, the clock with the date and the weather top right, the screen time and the
    // timer (or the pomodoro's button) under it ----
    component TilesCard: Item {
        id: tc
        readonly property real gap: win.u * 3
        readonly property real colW: Math.floor((width - 3 * gap) / 4)
        readonly property real rowH: Math.floor((win.pageH - gap) / 2)
        readonly property bool song: Halo.hasTrack && Config.halo.showMusic !== false
        readonly property var timer: Timers.items.length ? Timers.items[0] : null
        implicitHeight: rowH * 2 + gap

        Well {
            id: bigTile
            width: tc.colW * 2 + tc.gap
            height: tc.rowH * 2 + tc.gap
            Player {
                visible: tc.song
                x: win.u * 4
                y: win.u * 4
                width: parent.width - win.u * 8
                // the cassette is half as wide again as the cover: the same share of the tile
                art: Math.round(Math.min((parent.width - win.u * 8) * 0.42 / ((Config.halo.musicView || "cover") === "cassette" ? 1.5 : 1), parent.height - win.u * 10 - (tileSpec.visible ? tileSpec.height : 0)) / win.u) * win.u
            }
            Spectrum {
                id: tileSpec
                visible: tc.song && win.expanded && tc.visible && Lyrics.playing
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                fitWidth: parent.width - win.u * 8
                rows: 3
            }
            // nothing playing: the weather, big
            Column {
                visible: !tc.song
                anchors.centerIn: parent
                spacing: win.u * 2
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Weather.ok ? Weather.icon(Weather.now.code, Weather.now.day) : "sun"
                    pixel: win.u * 2
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.ok ? Weather.deg(Weather.now.temp) : "—"
                    kind: "big"
                }
                RunText {
                    width: bigTile.width - win.u * 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    align: Text.AlignHCenter
                    text: Weather.ok ? Weather.words(Weather.now.code) : I18n.t("Погода ещё не пришла", "No weather yet")
                    dim: true
                }
            }
        }
        // the clock, the date and the weather
        Well {
            x: (tc.colW + tc.gap) * 2
            width: tc.colW * 2 + tc.gap
            height: tc.rowH
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: win.u * 5
                spacing: win.u * 4
                PxText {
                    id: tileClock
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(new Date(win.now), "hh:mm")
                    kind: "big"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property real room: tc.colW * 2 + tc.gap - tileClock.width - win.u * 14
                    spacing: win.u
                    RunText {
                        width: parent.room
                        text: Qt.locale(I18n.english ? "en_US" : "ru_RU").toString(new Date(win.now), "dddd, d MMMM")
                    }
                    RunText {
                        visible: Weather.ok && tc.song
                        width: parent.room
                        text: Weather.ok ? Weather.deg(Weather.now.temp) + " " + Weather.words(Weather.now.code) : ""
                        dim: true
                    }
                }
            }
        }
        // the screen time today
        Well {
            x: (tc.colW + tc.gap) * 2
            y: tc.rowH + tc.gap
            width: tc.colW
            height: tc.rowH
            Column {
                anchors.centerIn: parent
                spacing: win.u * 2
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "monitor"
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Config.wellbeing.track ? Wellbeing.fmt(Wellbeing.todaySeconds) : "—"
                }
            }
            HoverHandler {
                onHoveredChanged: win.hint(parent, I18n.t("За экраном сегодня", "Screen time today"), hovered)
            }
        }
        // the timer that runs (a click pauses it), else the pomodoro's button
        Well {
            id: timerTile
            x: (tc.colW + tc.gap) * 3
            y: tc.rowH + tc.gap
            width: tc.colW
            height: tc.rowH
            clickable: true
            lit: !!tc.timer && win.running(tc.timer)
            onClicked: tc.timer ? Timers.toggle(tc.timer.id) : HaloButtons.run("pomodoro")
            Column {
                anchors.centerIn: parent
                spacing: win.u * 2
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: tc.timer && tc.timer.kind === "pomodoro" && tc.timer.phase === "rest" ? "coffee" : tc.timer ? "clock" : "coffee"
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tc.timer ? win.timerText(tc.timer) : I18n.t("Помодоро", "Pomodoro")
                    dim: !!tc.timer && !win.running(tc.timer)
                }
            }
            HoverHandler {
                onHoveredChanged: win.hint(timerTile, tc.timer ? (win.running(tc.timer) ? I18n.t("Клик — пауза", "Click: pause") : I18n.t("Клик — дальше", "Click: go on")) : I18n.t("Помодоро 25/5", "Pomodoro 25/5"), hovered)
            }
        }
    }

    // the pill, open: the main thing's card
    component Card: Column {
        id: card
        property var item: null
        readonly property string kind: item ? item.kind : ""
        readonly property var t: win.timerOf(item)
        readonly property var s: win.simple(item)
        spacing: win.u * 3

        // ---- a timer's end ----
        Head {
            visible: card.kind === "ring"
            width: parent.width
            title: Halo.rang ? Halo.rang.head : ""
            line: Halo.rang ? Halo.rang.body : ""
            Clock {
                anchors.centerIn: parent
            }
        }
        PxButton {
            readonly property var tip: card.kind === "ring" && Halo.rang ? Halo.rang.tip : null
            readonly property bool done: !!tip && win.tipDone === Halo.rang
            visible: !!tip
            compact: true
            hell: win.hell
            enabled: !done
            icon: done ? "check" : tip && tip.kind === "water" ? "drop" : tip && tip.kind === "eyes" ? "eye" : "heart"
            text: done ? I18n.t("Засчитано в Благополучии ♡", "Counted in Wellbeing ♡") : tip && tip.kind === "water" ? I18n.t("Стакан выпит", "Drank a glass") : tip && tip.kind === "eyes" ? I18n.t("Смотрю вдаль", "Looking away") : I18n.t("Иду размяться", "Going to stretch")
            onClicked: {
                Wellbeing.restTaken(tip.kind);
                win.tipDone = Halo.rang;
            }
        }

        // ---- a screenshot: drag the picture out (or onto the shelf's target), or the buttons ----
        Head {
            visible: card.kind === "shot"
            width: parent.width
            icon: "image"
            title: I18n.t("Скриншот сохранён", "Screenshot saved")
            line: I18n.t("Тащи картинку куда нужно", "Drag the picture where you want it")
        }
        Well {
            id: shotPic
            visible: card.kind === "shot"
            width: parent.width
            height: visible ? win.px(56) : 0
            readonly property string path: card.kind === "shot" ? card.item.path : ""
            Image {
                id: shotImg
                anchors.fill: parent
                source: shotPic.path ? "file://" + shotPic.path : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            HoverHandler {
                cursorShape: Qt.OpenHandCursor
                onHoveredChanged: if (hovered)
                    shotImg.grabToImage(r => shotPic.dragPic = r.url, Qt.size(win.px(60), win.px(34)))
            }
            property url dragPic
            DragHandler {
                id: shotDrag
                target: null
                onActiveChanged: win.draggingOut = active
            }
            Drag.active: shotDrag.active
            Drag.dragType: Drag.Automatic
            Drag.imageSource: shotPic.dragPic
            Drag.hotSpot.x: win.px(30)
            Drag.hotSpot.y: win.px(17)
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: {
                "text/uri-list": shotPic.path ? "file://" + encodeURI(shotPic.path) : ""
            }
            Drag.onDragFinished: action => {
                win.draggingOut = false;
                if (action !== Qt.IgnoreAction)
                    Halo.flashDone();
                win.afterDrag();
            }
        }
        Row {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            visible: card.kind === "shot"
            spacing: win.u * 2
            PxButton {
                compact: true
                hell: win.hell
                icon: "document"
                text: I18n.t("На полку", "To the shelf")
                onClicked: win.shotToShelf(shotPic.path)
            }
            PxButton {
                compact: true
                hell: win.hell
                text: I18n.t("Открыть", "Open")
                onClicked: {
                    Quickshell.execDetached(["xdg-open", shotPic.path]);
                    Halo.flashDone();
                }
            }
            PxButton {
                compact: true
                hell: win.hell
                icon: "folder"
                text: I18n.t("В папке", "In folder")
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", 'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "[\'$1\']" "" >/dev/null 2>&1 || xdg-open "$(dirname "$2")"', "sh", ("file://" + encodeURI(shotPic.path)).replace(/'/g, "%27"), shotPic.path]);
                    Halo.flashDone();
                }
            }
        }

        // ---- a recording ----
        Head {
            visible: card.kind === "rec"
            width: parent.width
            title: card.item && card.item.own === false ? I18n.t("Запись OBS", "OBS recording") : Capture.recPaused ? I18n.t("Запись на паузе", "Recording paused") : I18n.t("Запись экрана", "Screen recording")
            line: card.kind === "rec" && card.item.own !== false ? Capture.recFile.split("/").pop() + (Config.capture.recordAudio === "mic" ? I18n.t(" · с микрофоном", " · with the mic") : "") : ""
            side: card.kind === "rec" ? win.recTime(card.item) : ""
            RecDot {
                anchors.centerIn: parent
                width: win.u * 4
                height: win.u * 4
                paused: card.kind === "rec" && card.item.own !== false && Capture.recPaused
            }
        }
        Row {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            visible: card.kind === "rec" && card.item.own !== false
            spacing: win.u * 2
            PxButton {
                compact: true
                hell: win.hell
                icon: Capture.recPaused ? "play" : "pause"
                text: Capture.recPaused ? I18n.t("Дальше", "Go on") : I18n.t("Пауза", "Pause")
                onClicked: Capture.pauseRecord()
            }
            PxButton {
                compact: true
                hell: win.hell
                danger: true
                text: I18n.t("Стоп", "Stop")
                onClicked: Capture.stopRecord()
            }
        }

        // ---- a timer ----
        Head {
            visible: !!card.t
            width: parent.width
            icon: card.t && card.t.kind === "pomodoro" && card.t.phase === "rest" ? "coffee" : "clock"
            title: card.t ? Timers.title(card.t) : ""
            side: win.timerText(card.t)
            sideDim: !win.running(card.t)
        }
        BlockBar {
            visible: !!card.t && card.t.kind !== "stopwatch" && card.t.total > 0
            width: parent.width
            value: card.t && card.t.total > 0 ? 1 - Timers.left(card.t, win.now) / card.t.total : 0
            paused: !win.running(card.t)
        }
        Row {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            visible: !!card.t
            spacing: win.u * 2
            PxButton {
                compact: true
                hell: win.hell
                icon: win.running(card.t) ? "pause" : "play"
                text: win.running(card.t) ? I18n.t("Пауза", "Pause") : I18n.t("Дальше", "Go on")
                onClicked: Timers.toggle(card.item.id)
            }
            PxButton {
                visible: !!card.t && card.t.kind === "stopwatch" && !!card.t.start
                compact: true
                hell: win.hell
                text: I18n.t("Круг", "Lap")
                onClicked: Timers.lap(card.item.id)
            }
            PxButton {
                compact: true
                hell: win.hell
                icon: "close"
                text: I18n.t("Убрать", "Remove")
                onClicked: Timers.stop(card.item.id)
            }
        }

        // ---- the short and simple ones: the head, a bar, a button or two ----
        Head {
            visible: !!card.s
            width: parent.width
            icon: card.s && !notifPic.visible && card.kind !== "call" ? card.s.icon : ""
            bad: !!card.s && !!card.s.bad
            title: card.kind === "notif" ? (card.item.app || I18n.t("Уведомление", "Notification")) : card.kind === "trophy" ? win.trophyHead() : card.kind === "dl" ? I18n.t("Загрузки", "Downloads") : card.kind === "call" ? Halo.callApp : card.kind === "osd" ? (card.item.what === "brightness" ? I18n.t("Яркость", "Brightness") : card.item.what === "mic" ? I18n.t("Микрофон", "Microphone") : card.item.what === "kbd" ? I18n.t("Подсветка", "Backlight") : I18n.t("Громкость", "Volume")) : card.s ? card.s.text : ""
            line: card.kind === "notif" ? String(card.item.summary || "") : card.kind === "call" ? win.cardBody(card.item) : ""
            side: card.kind === "call" ? Timers.clock(Math.max(0, win.now - Halo.callSince)) : card.kind === "osd" && card.s ? card.s.text : ""
            Image {
                id: notifPic
                visible: card.kind === "notif" && status === Image.Ready
                anchors.fill: parent
                anchors.margins: win.u * 2
                source: card.kind === "notif" && card.item.icon && !win.onAir ? card.item.icon : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: false
            }
            // a call: a green dot breathing
            Rectangle {
                visible: card.kind === "call"
                anchors.centerIn: parent
                width: win.u * 4
                height: win.u * 4
                color: Halo.callMuted ? Theme.textDim : Theme.ok
                opacity: (win.now / 1000) % 2 < 1 ? 1 : 0.55
            }
        }
        PxText {
            readonly property string body: card.kind === "call" ? "" : win.cardBody(card.item)
            visible: !!card.s && body !== ""
            width: parent.width
            text: body
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            dim: true
        }
        BlockBar {
            visible: card.kind === "osd"
            width: parent.width
            value: card.kind === "osd" ? Halo.osdLevel(card.item.what) : 0
        }
        // the downloads, each: its name, the bar, how far, how fast, how long still
        Repeater {
            model: card.kind === "dl" ? Downloads.active : []
            Column {
                id: dlRow
                required property var modelData
                readonly property real f: Downloads.fraction(modelData)
                readonly property int etaS: Downloads.eta(modelData)
                width: card.width
                spacing: win.u * 2
                RunText {
                    visible: !win.onAir
                    width: parent.width
                    text: dlRow.modelData.name
                }
                BlockBar {
                    width: parent.width
                    value: dlRow.f
                    paused: dlRow.modelData.paused
                }
                PxText {
                    width: parent.width
                    elide: Text.ElideRight
                    dim: true
                    text: [dlRow.f >= 0 ? Math.floor(dlRow.f * 100) + "%" : "", Downloads.bytes(dlRow.modelData.size) + (dlRow.modelData.total > 0 ? I18n.t(" из ", " of ") + Downloads.bytes(dlRow.modelData.total) : ""), dlRow.modelData.paused ? I18n.t("пауза", "paused") : dlRow.modelData.speed > 0 ? Downloads.bytes(dlRow.modelData.speed) + I18n.t("/с", "/s") : "", dlRow.etaS > 0 ? I18n.t("ещё ", "") + Downloads.seconds(dlRow.etaS) + I18n.t("", " left") : ""].filter(x => x).join(" · ")
                }
            }
        }
        // the percent comes from the browser's extension: a browser open since before it was put
        // in reads it at its next start
        PxText {
            visible: card.kind === "dl" && Downloads.overall < 0 && Downloads.needRestart.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Проценты появятся после перезапуска: ", "The percent comes after a restart of ") + Downloads.needRestart.join(", ")
        }
        Row {
            visible: !!card.s
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            spacing: win.u * 2
            PxButton {
                visible: card.kind === "notif" && !!Halo.flashNote && Notifs.canOpen(Halo.flashNote)
                compact: true
                hell: win.hell
                text: I18n.t("Открыть", "Open")
                onClicked: {
                    Notifs.open(Halo.flashNote);
                    Halo.flashDone();
                    win.expanded = false;
                }
            }
            PxButton {
                visible: card.kind === "castPause"
                compact: true
                hell: win.hell
                icon: "play"
                text: I18n.t("Снова в эфир", "Back on air")
                onClicked: {
                    Privacy.pause("off");
                    win.expanded = false;
                }
            }
            PxButton {
                visible: card.kind === "notif"
                compact: true
                hell: win.hell
                icon: "close"
                text: I18n.t("Скрыть", "Dismiss")
                onClicked: Halo.flashDone()
            }
            PxButton {
                visible: card.kind === "call"
                compact: true
                hell: win.hell
                checkable: true
                checked: Halo.callMuted
                icon: Halo.callMuted ? "micMute" : "mic"
                text: Halo.callMuted ? I18n.t("Микрофон выключен", "Mic off") : I18n.t("Выключить микрофон", "Mute the mic")
                onClicked: Halo.callMute()
            }
            PxButton {
                visible: card.kind === "call"
                compact: true
                hell: win.hell
                text: I18n.t("Открыть ", "Open ") + Halo.callApp
                onClicked: {
                    Halo.callOpen();
                    win.expanded = false;
                }
            }
            PxButton {
                visible: card.kind === "trophy" || card.kind === "chest"
                compact: true
                hell: win.hell
                text: I18n.t("Открыть", "Open")
                onClicked: {
                    win.expanded = false;
                    win.openGame(card.kind);
                }
            }
            PxButton {
                visible: card.kind === "chest"
                compact: true
                hell: win.hell
                text: I18n.t("Потом", "Later")
                onClicked: Halo.chestWaiting = false
            }
            PxButton {
                visible: card.kind === "dlDone"
                compact: true
                hell: win.hell
                text: I18n.t("На полке", "On the shelf")
                onClicked: win.openOn("shelf")
            }
            PxButton {
                visible: card.kind === "dl"
                compact: true
                hell: win.hell
                icon: "folder"
                text: I18n.t("Папка", "Folder")
                onClicked: {
                    win.expanded = false;
                    Qt.openUrlExternally("file://" + Downloads.dir);
                }
            }
            PxButton {
                visible: card.kind === "update" || card.kind === "updated" || card.kind === "net"
                compact: true
                hell: win.hell
                icon: "gear"
                text: I18n.t("Подробнее", "Details")
                onClicked: {
                    win.expanded = false;
                    Shell.openSettings(card.kind === "net" ? "network" : "updates");
                }
            }
        }

        // ---- a picked colour: it, and the last ones (a click copies) ----
        Head {
            visible: card.kind === "pick"
            width: parent.width
            title: card.item && card.item.hex || ""
            line: I18n.t("скопировано", "copied")
            Swatch {
                anchors.fill: parent
                anchors.margins: win.u * 2
                hex: card.item && card.item.hex || ""
            }
        }
        Row {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            visible: card.kind === "pick" && ColorPicker.recent.length > 1
            spacing: win.u * 2
            Repeater {
                model: card.kind === "pick" ? ColorPicker.recent.slice(1, 6) : []
                Swatch {
                    id: older
                    required property string modelData
                    width: win.px(12)
                    height: win.px(12)
                    hex: modelData
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: win.hint(older, older.hex, hovered)
                    }
                    TapHandler {
                        onTapped: {
                            ColorPicker.copy(older.hex);
                            Halo.flashOf("pick", {
                                "hex": older.hex
                            });
                        }
                    }
                }
            }
        }

        // ---- the music: the player as music.sh, its spectrum, the lyric lines around the sung one ----
        Player {
            visible: card.kind === "music"
            width: parent.width
            art: win.px(30)
        }
        Spectrum {
            visible: card.kind === "music" && win.expanded && Lyrics.playing
            fitWidth: card.width
            rows: 3
        }
        Column {
            id: lines
            visible: card.kind === "music" && Lyrics.hasLyrics
            width: parent.width
            Repeater {
                model: [Lyrics.previous, Lyrics.current, Lyrics.next]
                RunText {
                    id: lyricLine
                    required property string modelData
                    required property int index
                    readonly property int li: Lyrics.index - 1 + index
                    readonly property bool can: Lyrics.status === "ok" && modelData !== "" && li >= 0 && li < Lyrics.lines.length && !!Lyrics.player && Lyrics.player.canSeek
                    width: lines.width
                    align: Text.AlignHCenter
                    text: modelData
                    bold: index === 1
                    color: lineHover.hovered && can ? Theme.text : index === 1 ? win.accent : Theme.textDim
                    HoverHandler {
                        id: lineHover
                        cursorShape: lyricLine.can ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    TapHandler {
                        enabled: lyricLine.can
                        onTapped: win.seekLine(lyricLine.li)
                    }
                }
            }
        }
    }

    // ---- the shelf ----
    // a thing's picture: a thumbnail for a picture, else its kind's icon
    function shelfPic(it) {
        return !!it.path && (it.kind === "image" || it.kind === "file" && /\.(png|jpe?g|gif|webp|avif|bmp|svg)$/i.test(it.path));
    }
    function shelfIcon(it) {
        return it.kind === "folder" ? "folder" : it.kind === "image" ? "image" : it.kind === "link" ? "arrowRight" : it.kind === "text" ? "note" : "document";
    }
    function shelfName(it) {
        return win.onAir ? "" : it.name || it.text || it.url || "";
    }
    // what a tile says under its icon: the file's extension, «link», «text», «folder»
    function shelfTag(it) {
        if (it.kind === "link")
            return I18n.t("ссылка", "link");
        if (it.kind === "text")
            return I18n.t("текст", "text");
        if (it.kind === "folder")
            return I18n.t("папка", "folder");
        const m = String(it.path || it.name || "").match(/\.([a-z0-9]{1,5})$/i);
        return m ? m[1].toLowerCase() : "";
    }

    // a dashed pixel frame: where a drop lands
    component Dashed: Canvas {
        id: dz
        property color ink: Theme.textDim
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.fillStyle = String(dz.ink);
            const u = win.u, d = u * 3;
            for (let x = 0; x < width; x += d * 2) {
                g.fillRect(x, 0, Math.min(d, width - x), u);
                g.fillRect(x, height - u, Math.min(d, width - x), u);
            }
            for (let y = 0; y < height; y += d * 2) {
                g.fillRect(0, y, u, Math.min(d, height - y));
                g.fillRect(width - u, y, u, Math.min(d, height - y));
            }
        }
    }

    // one thing on the shelf, a square: its picture whole (else its icon and kind), its name
    // under the pointer; a click picks it (its buttons show under), a drag takes it out.
    // A text is two squares wide with its first words on it, as a note pinned to a board; a click
    // opens it to be read and written (NoteView)
    component ShelfTile: Item {
        id: tile
        required property var modelData
        property int cell: win.px(30)
        property int gap: win.u * 3
        readonly property var it: modelData
        readonly property bool words: it.kind === "text" && !win.onAir && !it.failed
        readonly property bool picked: win.sel === it.id || win.multi.includes(it.id)
        // dragged while one of several picked: all of them go
        readonly property var batch: win.multi.includes(it.id) ? win.multiItems : [it]
        width: words ? cell * 2 + gap : cell
        height: cell
        opacity: it.missing ? 0.45 : 1

        Well {
            anchors.fill: parent
            lit: tile.picked || tileHover.hovered
        }
        Image {
            id: thumb
            visible: !win.onAir && win.shelfPic(tile.it) && status === Image.Ready
            anchors.fill: parent
            anchors.margins: win.u * 2
            source: win.shelfPic(tile.it) && !win.onAir && !tile.it.missing ? "file://" + tile.it.path : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Column {
            visible: !thumb.visible && !tile.it.pending && !tile.words
            anchors.centerIn: parent
            spacing: win.u
            PxIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: tile.it.failed ? "warn" : win.shelfIcon(tile.it)
            }
            PxText {
                visible: text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.shelfTag(tile.it)
                dim: true
            }
        }
        // a text's words, as many lines as the square holds, the last one ending in «…»
        PxText {
            visible: tile.words
            anchors.fill: parent
            anchors.margins: win.u * 3
            anchors.rightMargin: win.u * (tile.it.fav ? 9 : 3)
            readonly property string words: String(tile.it.text || "").trim()
            text: words || I18n.t("пустая записка", "an empty note")
            dim: words === ""
            kind: "tiny"
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            clip: true
        }
        // a picture still coming from the browser
        PxRing {
            visible: !!tile.it.pending
            anchors.centerIn: parent
            cell: win.u
            size: win.px(14)
            value: -1
        }
        PxIcon {
            visible: tile.it.fav
            x: parent.width - width - win.u * 2
            y: win.u * 2
            name: "star"
            pixel: Math.max(1, win.u / 2)
        }

        HoverHandler {
            id: tileHover
            // the picture that rides under the pointer while it is dragged out, taken beforehand
            onHoveredChanged: {
                if (hovered)
                    tile.grabToImage(r => tile.dragPic = r.url);
                const name = tile.words ? I18n.t("Клик — прочитать и поправить", "A click: read and edit it") : win.shelfName(tile.it);
                win.hint(tile, (name ? name + "\n" : "") + I18n.t("Ctrl+клик — выбрать несколько", "Ctrl+click picks several"), hovered);
            }
        }
        property url dragPic
        TapHandler {
            acceptedModifiers: Qt.NoModifier
            onTapped: {
                if (tile.words) {
                    win.openNote(tile.it.id);
                    return;
                }
                const was = tile.picked && !win.multi.length;
                win.multi = [];
                win.sel = was ? "" : tile.it.id;
            }
        }
        TapHandler {
            acceptedModifiers: Qt.ControlModifier
            onTapped: win.multiToggle(tile.it.id)
        }
        // out: the file (a link's address, a text) where it is dropped
        DragHandler {
            id: dragOut
            target: null
            onActiveChanged: {
                win.draggingOut = active;
                if (active)
                    win.tip = "";
            }
        }
        Drag.active: dragOut.active
        Drag.dragType: Drag.Automatic
        Drag.imageSource: tile.dragPic
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: tile.batch.length > 1 ? win.batchMime(tile.batch) : tile.it.kind === "text" ? {
            "text/plain": tile.it.text
        } : tile.it.kind === "link" ? {
            "text/uri-list": tile.it.url,
            "text/plain": tile.it.url
        } : {
            "text/uri-list": Shelf.uri(tile.it)
        }
        Drag.onDragFinished: action => {
            win.draggingOut = false;
            if (action !== Qt.IgnoreAction) {
                for (const b of tile.batch)
                    Shelf.taken(b.id);
                win.multi = [];
            }
            win.afterDrag();
        }
    }

    // several things dragged at once: their files and links as one uri list, the texts (and
    // the links) as plain text
    function batchMime(list) {
        const uris = list.map(i => Shelf.uri(i)).filter(u => u);
        const plain = list.map(i => i.kind === "text" ? i.text : i.kind === "link" ? i.url : "").filter(t => t);
        const m = {};
        if (uris.length)
            m["text/uri-list"] = uris.join("\r\n");
        if (plain.length)
            m["text/plain"] = plain.join("\n");
        return m;
    }
    // the open pill's shelf page: the favourites first, then the loose things, six squares a row;
    // what is left of the page is where a drop lands (the clipboard has its own window)
    component ShelfCard: Item {
        id: sc
        readonly property var picked: Shelf.items.find(i => i.id === win.sel) || null
        readonly property int gap: win.u * 3
        readonly property int cols: 6
        readonly property int cell: Math.floor((width - (cols - 1) * gap) / cols)
        // the squares it takes: ＋, one a thing, two a text
        readonly property int squares: Shelf.items.reduce((n, i) => n + (i.kind === "text" && !win.onAir && !i.failed ? 2 : 1), win.onAir ? 0 : 1)
        implicitHeight: win.note ? win.pageH : col.implicitHeight + (col.implicitHeight > 0 ? gap : 0) + win.px(24)

        NoteView {
            visible: !!win.note
            width: parent.width
            height: win.pageH
        }
        Column {
            id: col
            visible: !win.note
            width: parent.width
            spacing: win.u * 3
            Flow {
                visible: sc.squares > 0
                // as wide as its squares (six at most a row), in the middle
                width: Math.min(sc.cols, sc.squares) * (sc.cell + sc.gap) - sc.gap
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: sc.gap
                // a new note, written at once
                Well {
                    id: plus
                    visible: !win.onAir
                    width: sc.cell
                    height: sc.cell
                    clickable: true
                    onHoveredChanged: win.hint(plus, I18n.t("Записка на потом: что сделать, купить, ответить.\nОстаётся, пока не отметишь ✓", "A note for later: what to do, buy, answer.\nIt stays until you tick it ✓"), hovered)
                    onClicked: {
                        win.tip = "";
                        win.openNote(Shelf.newNote().id);
                        win.noteFocus();
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: win.u
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "plus"
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t("записка", "note")
                            dim: true
                        }
                    }
                }
                Repeater {
                    model: Shelf.favs.concat(Shelf.loose)
                    ShelfTile {
                        cell: sc.cell
                        gap: sc.gap
                    }
                }
            }
            // several picked: what goes for all of them
            Row {
                visible: win.multiItems.length > 1
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: win.u * 2
                PxText {
                    height: win.u * 12
                    text: I18n.t("Выбрано: ", "Picked: ") + win.multiItems.length
                    dim: true
                }
                PxButton {
                    compact: true
                    hell: win.hell
                    icon: "star"
                    checkable: true
                    checked: win.multiItems.every(i => i.fav)
                    onClicked: {
                        const on = !win.multiItems.every(i => i.fav);
                        for (const i of win.multiItems)
                            Shelf.setFav(i.id, on);
                    }
                }
                PxButton {
                    compact: true
                    hell: win.hell
                    icon: "close"
                    text: I18n.t("Убрать", "Remove")
                    onClicked: {
                        for (const i of win.multiItems)
                            Shelf.remove(i.id);
                        win.multi = [];
                    }
                }
                PxButton {
                    compact: true
                    hell: win.hell
                    text: I18n.t("Снять выбор", "Unpick")
                    onClicked: win.multi = []
                }
            }
            // the picked thing's buttons: icons in a row (music.sh's), their names under the pointer
            Row {
                id: acts
                readonly property var it: sc.picked
                visible: !!it && win.multiItems.length < 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: win.u * 2
                Repeater {
                    model: [
                        { "id": "look", "icon": "eye", "tip": I18n.t("Просмотр", "Look") },
                        { "id": "open", "icon": "arrowRight", "tip": I18n.t("Открыть", "Open") },
                        { "id": "folder", "icon": "folder", "tip": I18n.t("Показать в папке", "Show in folder") },
                        { "id": "share", "icon": "phone", "tip": "Quick Share" },
                        { "id": "copy", "icon": "document", "tip": I18n.t("В буфер", "Copy") },
                        { "id": "discord", "icon": "chat", "tip": "≤" + VideoGrab.limitMb + I18n.t(" МБ для Discord", " MB for Discord") },
                        { "id": "fav", "icon": "star", "tip": I18n.t("Оставить навсегда", "Keep for good") },
                        { "id": "remove", "icon": "close", "tip": I18n.t("Убрать с полки", "Remove") }
                    ]
                    PxButton {
                        id: actBtn
                        required property var modelData
                        readonly property var it: acts.it
                        visible: !!it && (modelData.id === "look" ? it.kind !== "link" && it.kind !== "text" : modelData.id === "folder" ? ["file", "image", "folder"].includes(it.kind) : modelData.id === "discord" ? it.kind === "file" && !it.missing && VideoGrab.isVideo(it.path) : true)
                        compact: true
                        hell: win.hell
                        icon: modelData.icon
                        iconPixel: Math.max(1, win.u - 1)
                        checkable: modelData.id === "fav"
                        checked: modelData.id === "fav" && !!it && it.fav
                        onHoveredChanged: win.hint(actBtn, modelData.tip, hovered)
                        onClicked: {
                            const i = it.id;
                            win.tip = "";
                            switch (modelData.id) {
                            case "look": Shelf.look(i); break;
                            case "open": Shelf.open(i); break;
                            case "folder": Shelf.showInFolder(i); break;
                            case "share": Shelf.share(i); break;
                            case "copy": Shelf.copy(i); break;
                            case "discord": VideoGrab.shrink(it.path, 0, 0); break;
                            case "fav": Shelf.setFav(i, !it.fav); break;
                            case "remove":
                                Shelf.remove(i);
                                win.sel = "";
                                break;
                            }
                        }
                    }
                }
            }
        }
        // the rest of the page: where a drop lands; an empty shelf says what it is for
        Item {
            visible: !win.note
            y: col.implicitHeight + (col.implicitHeight > 0 ? sc.gap : 0)
            width: parent.width
            height: Math.max(win.px(24), sc.height - y)
            Dashed {
                anchors.fill: parent
                ink: win.dropping ? win.accent : Qt.alpha(Theme.textDim, 0.7)
            }
            Column {
                visible: Shelf.items.length === 0
                anchors.centerIn: parent
                width: parent.width - win.u * 12
                spacing: win.u * 2
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: I18n.t("Карман на рабочем столе", "A pocket on the desktop")
                }
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    dim: true
                    text: I18n.t("Брось сюда файл, картинку из браузера, ссылку или текст — и вытащи в любое окно, когда понадобится: не надо искать его заново или держать открытым.\n＋ — записка на потом: что сделать, купить, ответить.", "Drop a file, a picture from the browser, a link or text here, and drag it into any window when it is needed: no looking for it again, no keeping it open.\n＋ is a note for later: what to do, buy, answer.")
                }
            }
            Row {
                visible: Shelf.items.length > 0
                anchors.centerIn: parent
                spacing: win.u * 3
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "download"
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Брось сюда ещё", "Drop more here")
                    dim: true
                }
            }
            HoverHandler {
                onHoveredChanged: win.hint(parent, I18n.t("Полежит, пока не вытащишь в нужное окно. Записки остаются, пока не отметишь ✓. ★ — оставить навсегда; папка со ★ принимает файлы", "It waits until you drag it into a window. Notes stay until you tick them ✓. ★ keeps a thing for good; a ★ folder takes files"), hovered)
            }
        }
    }

    // a text from the shelf open on its page: read, written (kept as it is typed), copied, sent,
    // starred, ticked off; ← or Esc back to the squares. Still dragged out from its square
    signal noteFocus
    component NoteView: Column {
        id: nv
        readonly property var it: Shelf.items.find(i => i.id === win.note) || null
        // the words put in from the shelf, not typed: not saved back
        property bool filling: false
        spacing: win.u * 3
        // from Shelf itself: `it` may not have caught up with the new id yet
        function fill() {
            const n = win.note ? Shelf.find(win.note) : null;
            filling = true;
            editor.text = n ? n.text : "";
            filling = false;
        }
        Connections {
            target: win
            function onNoteChanged() {
                nv.fill();
            }
            function onNoteFocus() {
                Qt.callLater(() => editor.input.forceActiveFocus());
            }
            function onDropFocus() {
                editor.input.focus = false;
            }
        }
        Connections {
            target: editor.input
            function onActiveFocusChanged() {
                win.typing = editor.input.activeFocus;
            }
        }
        Item {
            id: nvHead
            width: parent.width
            height: back.height
            PxButton {
                id: back
                compact: true
                hell: win.hell
                icon: "arrowLeft"
                iconPixel: Math.max(1, win.u - 1)
                onHoveredChanged: win.hint(back, I18n.t("К полке (Esc)", "Back to the shelf (Esc)"), hovered)
                onClicked: {
                    win.tip = "";
                    win.closeNote();
                }
            }
            RunText {
                x: back.width + win.u * 3
                width: tools.x - x - win.u * 3
                anchors.verticalCenter: parent.verticalCenter
                dim: true
                text: !nv.it ? "" : (nv.it.note ? I18n.t("записка", "note") : I18n.t("текст", "text")) + " · " + Qt.formatDateTime(new Date(nv.it.added), "dd.MM hh:mm")
            }
            Row {
                id: tools
                anchors.right: parent.right
                spacing: win.u * 2
                Repeater {
                    model: [
                        { "id": "copy", "icon": "document", "tip": I18n.t("В буфер", "Copy") },
                        { "id": "share", "icon": "phone", "tip": "Quick Share" },
                        { "id": "fav", "icon": "star", "tip": I18n.t("Оставить навсегда", "Keep for good") },
                        { "id": "done", "icon": "check", "tip": I18n.t("Сделано — убрать с полки", "Done: off the shelf") }
                    ]
                    PxButton {
                        id: toolBtn
                        required property var modelData
                        compact: true
                        hell: win.hell
                        icon: modelData.icon
                        iconPixel: Math.max(1, win.u - 1)
                        checkable: modelData.id === "fav"
                        checked: modelData.id === "fav" && !!nv.it && nv.it.fav
                        onHoveredChanged: win.hint(toolBtn, modelData.tip, hovered)
                        onClicked: {
                            if (!nv.it)
                                return;
                            const i = nv.it.id;
                            win.tip = "";
                            win.noteFlush();
                            switch (modelData.id) {
                            case "copy": Shelf.copy(i); break;
                            case "share": Shelf.share(i); break;
                            case "fav": Shelf.setFav(i, !nv.it.fav); break;
                            case "done":
                                Shelf.remove(i);
                                win.note = "";
                                break;
                            }
                        }
                    }
                }
            }
        }
        PxTextArea {
            id: editor
            width: parent.width
            height: nv.height - nvHead.height - nv.spacing
            placeholder: I18n.t("Что не забыть…", "What not to forget…")
            onEdited: if (!nv.filling && nv.it)
                win.noteEdited(text)
            // Esc, Ctrl+Enter: back to the squares
            keyFilter: e => {
                if (e.key === Qt.Key_Escape || (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) {
                    editor.input.focus = false;
                    win.closeNote();
                    return true;
                }
                return false;
            }
        }
    }

    // where a dragged thing can go: the shelf, Quick Share, a favourite folder
    component DropCard: Column {
        spacing: win.u * 3
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("Отпусти на цели", "Drop it on a target")
            dim: true
        }
        Flow {
            // as wide as its targets, in the middle
            width: Math.min(parent.width, (2 + Shelf.favs.filter(i => i.kind === "folder").length) * (win.px(44) + win.u * 3) - win.u * 3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: win.u * 3
            DropTile {
                target: "shelf"
                icon: "document"
                label: I18n.t("На полку", "To the shelf")
            }
            DropTile {
                target: "share"
                icon: "phone"
                label: "Quick Share"
            }
            Repeater {
                model: Shelf.favs.filter(i => i.kind === "folder")
                DropTile {
                    required property var modelData
                    target: "folder"
                    folderId: modelData.id
                    icon: "folder"
                    label: win.onAir ? "★" : "★ " + modelData.name
                }
            }
        }
    }
    component DropTile: Item {
        id: dt
        property string target: ""
        property string folderId: ""
        property string icon: ""
        property string label: ""
        width: win.px(44)
        height: win.px(30)
        Well {
            anchors.fill: parent
            lit: area.containsDrag
        }
        Column {
            anchors.centerIn: parent
            spacing: win.u * 2
            PxIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: dt.icon
            }
            RunText {
                width: dt.width - win.u * 6
                align: Text.AlignHCenter
                text: dt.label
            }
        }
        DropArea {
            id: area
            anchors.fill: parent
            onEntered: drag => {
                win.prefetch(drag);
                dropLeave.stop();
            }
            onExited: dropLeave.restart()
            onDropped: drop => win.drop(dt.target, drop, dt.folderId)
        }
    }

    // ---- the quick buttons (services/HaloButtons; Settings → Halo picks and orders them) ----
    // music.sh's buttons made tiles, four a row (a wide one takes two); the timer and the note
    // share one field under them
    component ButtonsCard: Column {
        id: bc
        spacing: win.u * 3
        readonly property int gap: win.u * 3
        readonly property int cell: Math.floor((width - 3 * gap) / 4)
        readonly property int tileH: win.px(26)
        // [{b, row, col}]: four cells a row, holes filled by what comes next (HaloButtons.pack)
        readonly property var packed: HaloButtons.pack(HaloButtons.list.filter(b => b.kind !== "field"), 4)
        readonly property int rows: packed.length ? Math.max(...packed.map(p => p.row)) + 1 : 0
        readonly property bool hasTimer: HaloButtons.list.some(b => b.id === "timer")
        readonly property bool hasNote: HaloButtons.list.some(b => b.id === "note")
        Item {
            width: parent.width
            height: bc.rows * bc.tileH + Math.max(0, bc.rows - 1) * bc.gap
            Repeater {
                model: bc.packed
                QuickTile {
                    cell: bc.cell
                    gap: bc.gap
                    height: bc.tileH
                    // the row centred: what its cells take, the rest split both sides
                    readonly property int used: bc.packed.filter(p => p.row === modelData.row).reduce((m, p) => Math.max(m, p.col + (p.b.wide ? 2 : 1)), 0)
                    x: Math.round((bc.width - used * bc.cell - (used - 1) * bc.gap) / 2 / win.u) * win.u + modelData.col * (bc.cell + bc.gap)
                    y: modelData.row * (bc.tileH + bc.gap)
                }
            }
        }
        // what the tiles and the field started: here always, so a press shows what it did
        // (Settings → Halo → Timers only hides them in the pill)
        Repeater {
            model: Timers.items
            TimerRow {
                width: bc.width
            }
        }
        // one field: a time starts a timer («25», «5m чай», «помодоро 50/10»), other words go onto
        // the shelf as a note; Enter does it
        PxField {
            id: field
            visible: bc.hasTimer || bc.hasNote
            width: parent.width
            property bool bad: false
            placeholder: bad ? I18n.t("Не понял — например 25 или 5m чай", "Didn't get it: try 25 or 5m tea") : bc.hasTimer && bc.hasNote ? I18n.t("таймер или заметка…", "a timer or a note…") : HaloButtons.hint(bc.hasTimer ? "timer" : "note")
            onAccepted: {
                if (text.trim() === "")
                    return;
                if ((bc.hasTimer && HaloButtons.submit("timer", text)) || (bc.hasNote && HaloButtons.submit("note", text))) {
                    bad = false;
                    text = "";
                    return;
                }
                bad = true;
                badOff.restart();
            }
            onEdited: bad = false
            Timer {
                id: badOff
                interval: 4000
                onTriggered: field.bad = false
            }
            HoverHandler {
                onHoveredChanged: win.hint(field, (bc.hasTimer ? I18n.t("Таймер: 25 — на 25 мин, 5m чай — с подписью, помодоро 50/10 — 50 работы, 10 отдыха.", "Timer: 25 is 25 min, 5m tea has a name, pomodoro 50/10 is 50 of work, 10 of rest.") : "") + (bc.hasTimer && bc.hasNote ? "\n" : "") + (bc.hasNote ? I18n.t("Другой текст — заметка на полку.", "Other words: a note on the shelf.") : ""), hovered)
            }
            Connections {
                target: field.input
                function onActiveFocusChanged() {
                    win.typing = field.input.activeFocus;
                }
            }
            Connections {
                target: win
                function onDropFocus() {
                    field.input.focus = false;
                }
            }
            Keys.onEscapePressed: {
                field.input.focus = false;
                win.expanded = false;
            }
        }
    }
    // a running timer on the buttons page: its name, the time, pause and stop
    component TimerRow: Row {
        id: tr
        required property var modelData
        readonly property var t: modelData
        spacing: win.u * 3
        PxIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: tr.t.kind === "pomodoro" && tr.t.phase === "rest" ? "coffee" : "clock"
            light: Theme.face
        }
        RunText {
            anchors.verticalCenter: parent.verticalCenter
            width: tr.width - x - tr.spacing - tail.width
            text: Timers.title(tr.t)
        }
        Row {
            id: tail
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.u * 2
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: win.timerText(tr.t)
                dim: !win.running(tr.t)
            }
            PxButton {
                compact: true
                hell: win.hell
                icon: win.running(tr.t) ? "pause" : "play"
                onClicked: Timers.toggle(tr.t.id)
            }
            PxButton {
                compact: true
                hell: win.hell
                icon: "close"
                onClicked: Timers.stop(tr.t.id)
            }
        }
    }
    // a button or a switch: music.sh's button (a raised square of the face, lit under the
    // pointer, pressed in on a click), its icon over its name
    component QuickTile: Item {
        id: qt
        required property var modelData
        property int cell
        property int gap
        readonly property var b: modelData.b
        readonly property bool on: b.kind === "toggle" && HaloButtons.on(b.id)
        width: b.wide ? cell * 2 + gap : cell

        PxBox {
            anchors.fill: parent
            hell: win.hell
            sunken: qtTap.pressed || qt.on
            color: qt.on ? win.accent : qtHover.hovered ? Theme.mix(win.hell ? Theme.hellFace : Theme.face, win.accent, 0.25) : win.hell ? Theme.hellFace : Theme.face
        }
        Column {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: qtTap.pressed ? win.u : 0
            spacing: win.u * 2
            PxIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: qt.b.icon
                ink: qt.on ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
            }
            RunText {
                width: qt.width - win.u * 6
                align: Text.AlignHCenter
                text: HaloButtons.label(qt.b)
                color: qt.on ? Theme.selectText : Theme.text
            }
        }
        HoverHandler {
            id: qtHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: qtTap
            onTapped: {
                HaloButtons.run(qt.b.id);
                // what opens on the screen (the picker, the selector) wants the pill gone
                if (qt.b.kind === "action")
                    win.expanded = false;
            }
        }
    }

    RightClickGuard {}
}
