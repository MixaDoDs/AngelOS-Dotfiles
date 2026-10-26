pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The Halo (Нимб): what the pixel Dynamic Island at the top centre shows (modules/halo), as
// capsules: our own screen recording and OBS's, every timer, the music, an angelOS update and
// browser downloads in progress, the day's chest; for a moment: a picked colour, the network
// gone or back, the charger plugged in, a download or an update done, an achievement. A timer's
// end is `rang` for a few seconds, the only thing shown over a full-screen game. Settings → Halo.
Singleton {
    id: root

    // the 16.10 redesign (the owner's answers): an install moves once to the notch look growing
    // in steps; what it picks after stays
    Timer {
        interval: 600
        running: true
        onTriggered: {
            if (!Config.ready) {
                restart();
                return;
            }
            if (Config.halo.redesignOnce)
                return;
            Config.halo.skin = "notch";
            Config.halo.anim = "steps";
            Config.halo.redesignOnce = true;
        }
    }

    // the look: ears | notch | float | tamagotchi; the dropped ones (classic, win98, neon, lcd,
    // ticker; 16.10 «как виджеты») fall back to the notch
    readonly property string skin: ["ears", "notch", "float", "tamagotchi"].includes(Config.halo.skin) ? Config.halo.skin : "notch"

    // the Halo is on this screen (Settings → Halo: on, which screens; empty list = every one)
    function on(name) {
        const l = Config.halo.screens || [];
        return !!Config.halo.enabled && (!l.length || l.includes(name));
    }

    // Settings → Halo → size: s | m | l, a factor on the pixel step
    readonly property real scale: ({
            "s": 0.85,
            "l": 1.25
        })[Config.halo.size] || 1

    // the height of the Halo's strip at the top (HaloWindow): the room niri keeps for snapped and
    // maximized windows in Settings → Halo → «Windows and the Halo» → maximized (WindowConfig)
    property int strip: 0

    // the right-click menu's «hide for an hour»: the pill and the ring go, the strip stays (the
    // windows don't jump)
    property double hiddenUntil: 0
    readonly property bool hidden: hiddenUntil > clock
    property double clock: Date.now()
    function hideFor(ms) {
        hiddenUntil = Date.now() + ms;
        clock = Date.now();
        unhide.interval = ms;
        unhide.restart();
        hiddenKept.setText(String(hiddenUntil));
    }
    function show() {
        hiddenUntil = 0;
        clock = Date.now();
        hiddenKept.setText("0");
    }
    // the card opened on a screen (the wallpaper's ring): the Halo there takes it (HaloWindow)
    signal openAsked(string screen)
    function openOn(screen) {
        show();
        openAsked(screen);
    }
    // through a restart of the shell (it came back at once after each, 16.10), not a reboot
    FileView {
        id: hiddenKept
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/halo-hidden"
        blockLoading: true
        printErrors: false
    }
    function restoreHidden() {
        const until = Number(String(hiddenKept.text() || "").trim()) || 0;
        if (until > Date.now())
            hideFor(until - Date.now());
    }
    Timer {
        id: unhide
        // a coarse timer may fire a little early: then it waits for the rest
        onTriggered: {
            root.clock = Date.now();
            if (root.hiddenUntil > root.clock) {
                interval = root.hiddenUntil - root.clock + 20;
                restart();
            }
        }
    }

    // the clocks of the desktop and the Halo's resting card keep the weather coming
    readonly property bool weatherWanted: !!Config.halo.enabled

    // a timer just ended: {head, body}, null after a few seconds
    property var rang: null
    Connections {
        target: Timers
        function onRang(head, body) {
            root.rang = {
                "head": head,
                "body": body,
                "tip": Timers.restTip
            };
            ringOff.restart();
        }
    }
    Timer {
        id: ringOff
        interval: 8000
        onTriggered: root.rang = null
    }

    // ---- notifications, the volume, calls (the owner's 16.10 answers) ----
    // a notification: in the pill until it is seen — the pointer on the pill or its card open
    // (#106: 3.5 s and gone, missed by anyone away from the screen); the bell counts the unread
    // (modules/bar/parts/Bell). Not over a hidden or
    // full-screen-hidden Halo (then the corner popup comes as before)
    readonly property bool takesNotifications: Config.ready && !!Config.halo.enabled && Config.halo.notify !== false && !hidden && !(gameOn && Config.halo.overFullscreen !== "timer")
    // somewhere a full-screen window (the Halo's screens): it hides there
    readonly property bool gameOn: Shell.screens.some(s => on(s.name) && Shell.fullscreenOn(s.name))
    Connections {
        target: Notifs
        function onArrived(info) {
            if (!root.takesNotifications || info.quiet || info.critical)
                return;
            root.flashOf("notif", {
                "app": info.appName || "",
                "summary": info.summary || "",
                "body": info.body || "",
                "icon": info.icon || ""
            }, 3500);
            // the notification itself (for «Open») apart: a QObject inside the flash's object
            // made the property drop it at once
            root.flashNote = info.n || null;
        }
    }
    // volume / mic / brightness / the keyboard's light: a bar a moment
    function takesOsd(kind, screen) {
        return Config.ready && !!Config.halo.enabled && Config.halo.osd !== false && ["volume", "mic", "brightness", "kbd"].includes(kind) && on(screen) && !hidden && !Shell.fullscreenOn(screen);
    }
    Connections {
        target: Audio
        enabled: Config.halo.osd !== false
        function onChanged(what) {
            if (what === "volume" || what === "mic")
                root.flashOf("osd", {
                    "what": what
                }, 1500);
        }
    }
    Connections {
        target: Backlight
        enabled: Config.halo.osd !== false
        function onChanged(what) {
            if (what === "brightness" || what === "kbd")
                root.flashOf("osd", {
                    "what": what
                }, 1500);
        }
    }
    // the volume as it is, past 100 % too (#120: the keys go to 150 %, the pill said 100 %); the bar
    // of blocks stops at full by itself
    function osdLevel(what) {
        return what === "brightness" ? Backlight.level : what === "kbd" ? (Backlight.kbdMax > 0 ? Backlight.kbd / Backlight.kbdMax : 0) : what === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : (Audio.muted ? 0 : Audio.volume);
    }
    // a call: a program from the list taking the microphone (PipeWire, services/Sensors). Its
    // capture may not say who it is: Discord's is «WEBRTC VoiceEngine», the program only in
    // application.process.binary and the portal's app id (16.10: the call never showed) — those
    // count too and name the call; Discord's own word (DiscordVoice) when it has one
    readonly property var callNames: ["discord", "vesktop", "webcord", "legcord", "telegram", "64gram", "ayugram", "freshgram", "kotatogram", "zoom", "skype", "slack", "teams", "element", "signal", "whatsapp", "mumble", "teamspeak"].concat((Config.halo.callApps || []).map(x => String(x).toLowerCase()))
    function callLabel(n) {
        const p = n.properties || {};
        if (String(p["media.class"] || "") !== "Stream/Input/Audio" || !Sensors.app(n))
            return "";
        const keys = [Sensors.app(n), p["application.process.binary"], p["pipewire.access.portal.app_id"], p["application.id"]].map(x => String(x || ""));
        const i = keys.findIndex(k => k && callNames.some(c => k.toLowerCase().includes(c)));
        // an app id: its last part ("com.discordapp.Discord" → "Discord")
        return i < 0 ? "" : i >= 2 ? keys[i].split(".").pop() : keys[i];
    }
    readonly property string callApp: {
        if (Config.halo.calls === false)
            return "";
        for (const n of Sensors.mic.length ? Sensors.captures : []) {
            const l = callLabel(n);
            if (l)
                return l;
        }
        return DiscordVoice.state === "call" ? "Discord" : "";
    }
    property double callSince: 0
    onCallAppChanged: callSince = callApp ? Date.now() : 0
    function callNodes() {
        return Sensors.captures.filter(n => callLabel(n) === callApp);
    }
    // muting is that program's capture only: the mixer, the stream and the other programs hear on
    readonly property bool callMuted: callApp !== "" && callNodes().some(n => n.audio && n.audio.muted)
    function callMute() {
        const m = !callMuted;
        for (const n of callNodes())
            if (n.audio)
                n.audio.muted = m;
    }
    function callOpen() {
        const k = callApp.toLowerCase().split(/\s+/)[0];
        const w = Niri.windows.find(w => String(w.app_id || "").toLowerCase().includes(k) || String(w.title || "").toLowerCase().includes(k));
        if (w)
            Niri.focusWindow(w.id);
    }

    // ---- a short event: its capsule a few seconds, the newest wins ----
    // the stream's chat (services/StreamChat): the latest message a moment, its own capsule
    property var chat: null
    Connections {
        target: StreamChat
        enabled: Config.stream.chatHalo !== false
        function onMessage(m) {
            root.chat = Object.assign({
                "id": Date.now()
            }, m);
            chatOff.interval = Math.min(9000, 4000 + 40 * String(m.text || "").length);
            chatOff.restart();
        }
    }
    Timer {
        id: chatOff
        onTriggered: root.chat = null
    }
    property var flash: null
    // its card is open: it stays
    property bool flashHeld: false
    property var flashNote: null
    function flashOf(kind, data, ms) {
        flash = Object.assign({
            "key": "f" + kind,
            "kind": kind
        }, data || {});
        flashOff.interval = ms || 3500;
        flashOff.restart();
    }
    Timer {
        id: flashOff
        onTriggered: {
            if (root.flash && ((root.flash.kind === "shot" && root.shotHeld) || root.flashHeld))
                restart();
            else
                root.flash = null;
        }
    }
    function flashDone() {
        flashOff.stop();
        flash = null;
    }

    // ---- the song's cover colour: the pill's outline and the dancing bars (Settings → Halo →
    // «Cover colour»). A file is read as it is, a web cover (Spotify's) fetched once into the
    // runtime dir; ColorQuantizer finds the colours, PaletteGenerator.accentOf the lively one
    readonly property string coverUrl: Config.halo.coverTint !== false && music ? Lyrics.artUrl : ""
    property string coverFile: ""
    property int coverTurn: 0
    onCoverUrlChanged: coverFetch()
    function coverFetch() {
        const u = coverUrl;
        if (!u) {
            coverFile = "";
            return;
        }
        if (u.startsWith("file://")) {
            coverFile = u;
            return;
        }
        if (!/^https?:\/\//.test(u)) {
            coverFile = "";
            return;
        }
        // two names in turn: the next cover is a new source for the quantizer
        coverTurn = 1 - coverTurn;
        const path = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/halo-cover-" + coverTurn;
        coverGet.want = u;
        coverGet.path = path;
        coverGet.running = false;
        coverGet.command = ["curl", "-sfL", "--create-dirs", "--max-time", "8", "-o", path, u];
        coverGet.running = true;
    }
    Process {
        id: coverGet
        property string want: ""
        property string path: ""
        onExited: code => {
            if (code === 0 && want === root.coverUrl)
                root.coverFile = "file://" + path;
        }
    }
    ColorQuantizer {
        id: coverColors
        depth: 3
        rescaleSize: 64
        source: root.coverFile
    }
    // "" while there is none
    readonly property string coverTint: coverFile && coverColors.colors.length ? PaletteGenerator.accentOf(coverColors.colors) : ""
    // a screenshot just saved: its picture a few seconds (Settings → Halo → «Screenshot
    // thumbnail»); held while the pointer is on it or the card is open (shotHeld)
    property bool shotHeld: false
    Connections {
        target: Capture
        function onShotSaved(path) {
            // not while privacy on stream hides apps: the picture may have them in it
            // (the corner's own thumbnail, services/ShotEdit, takes its place when it is on)
            if (Config.halo.shotThumb !== false && !ShotEdit.wanted && !Privacy.hiddenNow.length)
                root.flashOf("shot", {
                    "path": path
                }, 4000);
        }
    }
    // a pinned program opened on its place (Settings → Windows → Program places): a moment
    Connections {
        target: Niri
        function onWindowOpened(id) {
            const w = Niri.windows.find(x => x.id === id);
            const pin = w && WindowConfig.remember ? WindowConfig.placeFor(w.app_id) : null;
            const now = pin ? WindowConfig.placeOf(w) : null;
            if (!now || now.output !== pin.output || now.idx !== pin.idx || Niri.windows.filter(x => x.app_id === w.app_id).length > 1)
                return;
            const e = DesktopEntries.heuristicLookup(w.app_id);
            root.flashOf("place", {
                "app": e ? e.name : w.app_id,
                "desk": pin.idx
            }, 2500);
        }
    }
    Connections {
        target: ColorPicker
        function onPicked(hex) {
            root.flashOf("pick", {
                "hex": hex
            });
        }
    }
    // the network gone (only once it was there) or back (only after it was told gone); a flap
    // of a few seconds says nothing
    property bool netSeen: false
    property bool netDown: false
    Connections {
        target: Wifi
        function onOnlineChanged() {
            netWait.restart();
        }
    }
    Timer {
        id: netWait
        interval: 5000
        onTriggered: {
            if (Wifi.online) {
                root.netSeen = true;
                if (root.netDown)
                    root.flashOf("net", {
                        "on": true
                    }, 3000);
                root.netDown = false;
            } else if (root.netSeen && !root.netDown) {
                root.netDown = true;
                root.flashOf("net", {
                    "on": false
                }, 4500);
            }
        }
    }
    Component.onCompleted: {
        netSeen = Wifi.online;
        shelfSeen = Shelf.count;
        restoreHidden();
    }
    // the charger plugged in (a laptop): «⚡ 64%»
    Connections {
        target: Power
        function onPluggedChanged() {
            if (Power.hasBattery && Power.plugged)
                root.flashOf("power", {}, 3000);
        }
    }
    // a download done: its name (services/Downloads put it on the shelf)
    Connections {
        target: Downloads
        function onFinishedChanged() {
            if (Downloads.finished)
                root.flashOf("dlDone", {
                    "name": Downloads.finished
                }, 3500);
        }
    }
    // an angelOS update (Settings → Updates) ran: done or not, a moment; the restart question
    // stays the UpdatePrompt's
    readonly property bool updating: Updates.state === "updating" || Updates.state === "restoring" || Updates.state === "cloning"
    onUpdatingChanged: if (!updating && Updates.state !== "idle")
        flashOf("updated", {
            "ok": Updates.state !== "failed"
        }, 5000)

    // ---- the game: an achievement's or a diary page's card, the day's chest ----
    // in the Halo when it is on the screen the card would go to (the main one, or the first the
    // stream doesn't show; modules/y2k/AchievementToast): that card steps aside
    readonly property string gameScreen: {
        const all = [Shell.primaryScreen].concat(Quickshell.screens.filter(s => s !== Shell.primaryScreen));
        const s = all.find(x => x && StreamMode.effectsOn(x.name));
        return s && on(s.name) ? s.name : "";
    }
    // the open Halo holds the card, as the pointer on the toast does
    property bool trophyHeld: false
    // the day's chest: services/Chests asks here instead of its notification
    property bool chestWaiting: false

    // paused music keeps its capsule a while (Settings → Halo → «In a pause», 30 s), then the
    // pill rests and a ▶ bubble with its cover stays beside it for an hour (`pausedResume`)
    readonly property int pauseKeepMs: Math.max(0, Config.halo.pauseKeep === undefined ? 30 : Config.halo.pauseKeep) * 1000
    property double pausedAt: 0
    property bool pauseFresh: false
    property bool pausedResume: false
    Connections {
        target: Lyrics
        function onPlayingChanged() {
            if (Lyrics.playing) {
                root.pauseFresh = false;
                root.pausedResume = false;
                pauseOff.stop();
                resumeOff.stop();
                root.peekNow();
            } else {
                root.pausedAt = Date.now();
                root.pauseFresh = root.pauseKeepMs > 0;
                root.pausedResume = root.pauseKeepMs === 0;
                if (root.pauseFresh)
                    pauseOff.restart();
                else
                    resumeOff.restart();
            }
        }
        // a new song or video: its title peeks in the pill a moment (Settings → «Music without
        // synced lyrics»)
        function onTitleChanged() {
            if (Lyrics.playing)
                root.peekNow();
        }
    }
    Timer {
        id: pauseOff
        interval: Math.max(1, root.pauseKeepMs)
        onTriggered: {
            root.pauseFresh = false;
            root.pausedResume = true;
            resumeOff.restart();
        }
    }
    Timer {
        id: resumeOff
        interval: 60 * 60 * 1000
        onTriggered: root.pausedResume = false
    }
    // the title in the pill for 5 s
    property bool peek: false
    function peekNow() {
        peek = true;
        peekOff.restart();
    }
    Timer {
        id: peekOff
        interval: 5000
        onTriggered: root.peek = false
    }
    // something just landed on the shelf: its bubble shows a minute
    property bool shelfFresh: false
    property int shelfSeen: -1
    Connections {
        target: Shelf
        function onCountChanged() {
            // the state file read at start is no landing
            if (shelfArm.running === false && root.shelfSeen >= 0 && Shelf.count > root.shelfSeen) {
                root.shelfFresh = true;
                shelfOff.restart();
            }
            root.shelfSeen = Shelf.count;
        }
    }
    Timer {
        id: shelfArm
        interval: 5000
        running: true
    }
    Timer {
        id: shelfOff
        interval: 60 * 1000
        onTriggered: root.shelfFresh = false
    }
        // the song's lyrics follow it in time (not plain text, not missing)
    readonly property bool synced: Lyrics.status === "ok" && Lyrics.lines.length > 0
    readonly property bool hasTrack: !!Lyrics.player && Lyrics.title !== ""
    readonly property bool music: hasTrack && (Lyrics.playing || pauseFresh)

    // the capsules, most urgent first: [{key, kind, …}]. The order is the rank (rank below):
    // a timer's end, an achievement, a moment's event, a recording, an update, downloads,
    // timers, the chest; the music (with its lyrics) is the least — in the pill only when nothing
    // else goes on; the shelf's stack is no event, it stays a bubble
    readonly property var order: ["ring", "call", "trophy", "flash", "castPause", "rec", "update", "dl", "chat", "timer", "chest", "music", "paused", "shelf"]
    function rank(item) {
        const i = order.indexOf(["pick", "net", "power", "dlDone", "updated", "notif", "osd"].includes(item.kind) ? "flash" : item.kind);
        return i < 0 ? order.indexOf("flash") : i;
    }
    readonly property var items: {
        const l = [];
        const H = Config.halo;
        if (rang)
            l.push({
                "key": "ring",
                "kind": "ring"
            });
        if (gameScreen && Achievements.current)
            l.push({
                "key": "trophy:" + Achievements.current.id,
                "kind": "trophy",
                "only": gameScreen
            });
        if (callApp)
            l.push({
                "key": "call",
                "kind": "call"
            });
        if (flash)
            l.push(flash);
        // the pause for viewers (Privacy.pause): on until switched off, so it can't be forgotten
        if (Privacy.paused)
            l.push({
                "key": "castPause",
                "kind": "castPause"
            });
        if (H.showRec && Capture.recording)
            l.push({
                "key": "rec",
                "kind": "rec",
                "own": true,
                "since": Capture.recSince
            });
        if (H.showRec && StreamMode.obsRec)
            l.push({
                "key": "obs",
                "kind": "rec",
                "own": false,
                "since": StreamMode.recSince
            });
        if (updating)
            l.push({
                "key": "update",
                "kind": "update"
            });
        if (Downloads.active.length)
            l.push({
                "key": "dl",
                "kind": "dl"
            });
        if (chat)
            l.push({
                "key": "chat" + chat.id,
                "kind": "chat",
                "author": chat.author,
                "text": chat.text,
                "amount": chat.amount,
                "regular": chat.regular
            });
        if (H.showTimers)
            for (const t of Timers.items)
                l.push({
                    "key": "t" + t.id,
                    "kind": "timer",
                    "id": t.id
                });
        if (H.showMusic && music)
            l.push({
                "key": "music",
                "kind": "music"
            });
        if (gameScreen && chestWaiting && Chests.freeReady && !Chests.open)
            l.push({
                "key": "chest",
                "kind": "chest",
                "only": gameScreen
            });
        // paused a while ago: a ▶ bubble with the cover, never the pill (HaloWindow)
        if (H.showMusic && pausedResume && hasTrack && !Lyrics.playing)
            l.push({
                "key": "paused",
                "kind": "paused"
            });
        // the shelf's loose things (services/Shelf): a stack with their number, last — only a
        // minute after something landed there (the shelf itself is a page of the open Halo)
        if (Shelf.count > 0 && shelfFresh)
            l.push({
                "key": "shelf",
                "kind": "shelf"
            });
        // stable: within a rank, the order they came in
        return l.map((x, i) => [x, i]).sort((a, b) => rank(a[0]) - rank(b[0]) || a[1] - b[1]).map(p => p[0]);
    }
}
