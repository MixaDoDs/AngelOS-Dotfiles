pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// angelOS sounds, Settings → Y2K → Sounds. Two packs:
//   y2k       synthesised by scripts/y2k-sounds.py into ~/.local/share/angelos/sounds/y2k
//   overdose  NEEDY GIRL OVERDOSE (Windose) sounds, fetched on first use by
//             scripts/sound-pack.py into …/sounds/overdose
// Events: startup notify error click shutdown angel wallpaper, a USB device plugged in
// or out (usbIn usbOut: scripts/usb-watch.py, a hub's burst plays once), the "cute" ones
// (open toggle screenshot volume windowClose — Config.y2k.cuteSounds), the
// demon's voice, and the effects crack/choir/rocks/shatter (always synthesised;
// rocks: the demon's 8-bit rockfall, shatter: the screen breaking when the
// angel and the demon swap; circle: the low hit in the dark between hell's circles,
// circleSoft its calm version; circleSin: the sin of the circle coming up, one of its two sounds by
// chance over the blow — coins in Greed, a punch in Wrath, a snicker in Fraud (CC0 recordings
// put on a stage with reverb and a path across the stereo field by scripts/hell-sounds.py,
// shipped in data/sounds/hell, not synthesised); harp: the harp menu's strings, HarpLook;
// webSnap/webSwipe/webClear:
// the cobwebs' thread snapping, a swipe of their quick-time event, the web gone). Quiet in stream
// mode (StreamMode.quiet).
// The Golden Gate skin has a pack of its own (macEvents, below): original Mac-like sounds in
// data/sounds/macos (scripts/mac-sounds.py), yours of the same name in
// ~/.local/share/angelos/sounds/macos first; its own switch, volume and volume "pop" switch
// (Config.mac.sounds / soundVolume / volumeSound, Settings → Sound in Golden Gate).
// Settings → System sounds (SfxPage) tunes each one (Config.y2k.soundTweaks,
// {event: {on, vol, sound, vary}}): on/off, its own volume, another event's sound
// ("notify") or a file ("file:/path", e.g. from sounds/custom), and for the input
// sounds which buttons click, a release tick and typing with three variants. The
// newer events (opt-in) stay quiet until switched on there.
Singleton {
    id: root

    readonly property var events: ["startup", "notify", "error", "click", "shutdown", "angel", "wallpaper", "open", "toggle", "screenshot", "volume", "windowClose", "demon", "crack", "choir", "rocks", "shatter", "voice", "clickRight", "key", "windowOpen", "workspace", "lock", "unlock", "usbIn", "usbOut", "bark", "circle", "circleSoft", "circleSin", "harp", "achievement", "stars", "chestOpen", "chestTick", "chestPrize", "chestLegend", "webSnap", "webSwipe", "webClear"]
    // off until switched on in System sounds (typing and such would surprise)
    readonly property var optIn: ["clickRight", "key", "windowOpen", "workspace", "lock", "unlock"]
    // the input ones: quiet over a fullscreen window (games) when asked
    readonly property var input: ["click", "clickRight", "key"]
    // the helper's Undertale "pips", one per letter (AngelHelper plays them as
    // SoundEffect, so they stay .wav); "voice" above is their switch and preview;
    // key2 key3: the typing variants; voiceFallen1…5: her broken voice's syllables (the story's);
    // harp1…16: the harp menu's strings, low to high (HarpLook plays them as SoundEffect too;
    // "harp" above is their switch, volume and preview, a glissando)
    readonly property var fallenVoice: ["voiceFallen1", "voiceFallen2", "voiceFallen3", "voiceFallen4", "voiceFallen5"]
    readonly property var harpStrings: Array.from({
            "length": 16
        }, (_, i) => "harp" + (i + 1))
    readonly property var extra: ["voiceAngel", "voiceDemon", "key2", "key3"].concat(fallenVoice).concat(harpStrings)
    readonly property string customDir: base + "/custom"
    readonly property var cute: ["open", "toggle", "screenshot", "volume", "windowClose"]
    readonly property var effects: ["crack", "choir", "rocks", "shatter", "voice", "bark", "circle", "circleSoft", "circleSin", "harp", "webSnap", "webSwipe", "webClear"]
    // heaven ⇄ hell's sounds: never piled up (story/game.json → pace.soundGap)
    readonly property var transitions: ["crack", "choir", "rocks", "shatter", "circle", "circleSoft", "circleSin"]
    // ones shipped with the shell rather than synthesised into the pack (the pack check skips them)
    readonly property var shipped: ["circleSin"]
    // the helper's own sounds follow "Her voice" (Config.y2k.helperVolume) on top of the volume
    readonly property var helperSounds: ["angel", "demon", "crack", "choir", "rocks", "shatter", "voice", "voiceAngel", "voiceDemon", "bark"].concat(fallenVoice)
    function volumeOf(name) {
        const v = Math.max(0, Math.min(1, Config.y2k.soundVolume));
        const own = Math.max(0, Math.min(1.5, Number(tweak(name).vol === undefined ? 1 : tweak(name).vol)));
        return Math.min(1, (helperSounds.includes(name) ? v * Math.max(0, Math.min(1, Config.y2k.helperVolume)) : v) * own);
    }
    // ---- per-event tuning (System sounds) ----
    function tweak(name) {
        return (Config.y2k.soundTweaks || {})[name] || {};
    }
    function setTweak(name, key, value) {
        const all = Object.assign({}, Config.y2k.soundTweaks || {});
        const t = Object.assign({}, all[name] || {});
        if (value === undefined || value === null)
            delete t[key];
        else
            t[key] = value;
        if (Object.keys(t).length)
            all[name] = t;
        else
            delete all[name];
        Config.y2k.soundTweaks = all;
    }
    // the switch of one event (the old "soundOff" list follows along)
    function isOn(name) {
        const t = tweak(name);
        if (t.on !== undefined)
            return !!t.on;
        return optIn.includes(name) ? false : !(Config.y2k.soundOff || []).includes(name);
    }
    function setOn(name, on) {
        setTweak(name, "on", !!on);
        const off = (Config.y2k.soundOff || []).filter(x => x !== name);
        Config.y2k.soundOff = on ? off : off.concat([name]);
    }
    // what an event plays: "" its own, another event's id, or "file:/path"
    function soundOf(name) {
        return String(tweak(name).sound || "");
    }
    // quiet hours (y2k.quietHours, from → to, whole hours, may wrap past midnight)
    function quietNow() {
        if (!Config.y2k.quietHours)
            return false;
        const h = new Date().getHours(), a = Config.y2k.quietFrom, b = Config.y2k.quietTo;
        return a === b ? false : a < b ? (h >= a && h < b) : (h >= a || h < b);
    }
    function fullscreenNow() {
        return !!Niri.focusedOutput && Shell.fullscreenOn(Niri.focusedOutput);
    }
    // the files in sounds/custom (System sounds lists them)
    property var customFiles: []
    function rescanCustom() {
        customScan.running = false;
        customScan.running = true;
    }
    Process {
        id: customScan
        command: ["sh", "-c", 'mkdir -p "$1"; cd "$1" && for f in *.ogg *.oga *.wav *.mp3 *.flac *.opus; do [ -f "$f" ] && echo "$f"; done', "sh", root.customDir]
        stdout: StdioCollector {
            onStreamFinished: root.customFiles = text.split("\n").filter(s => s !== "")
        }
    }
    signal picked(string path)
    // a file from anywhere (zenity); the caller decides what to do with it
    function pickFile() {
        picker.running = true;
    }
    Process {
        id: picker
        command: ["zenity", "--file-selection", "--title=angelOS", "--file-filter=Sounds | *.ogg *.oga *.wav *.mp3 *.flac *.opus"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f)
                    root.picked(f);
            }
        }
    }
    // scripts/y2k-sounds.py PACK_VERSION: an older pack is synthesised again
    readonly property string packVersion: "12"
    readonly property string base: Config.home + "/.local/share/angelos/sounds"
    readonly property string dir: base + "/y2k"
    readonly property string pack: Config.y2k.soundPack === "overdose" ? "overdose" : "y2k"
    property bool ready: false               // the synthesised pack is complete
    property bool overdoseReady: false
    property string overdoseError: ""
    readonly property bool downloading: fetch.running
    property var pending: []
    property var lastAt: ({})

    // ---- the Golden Gate pack: event -> file name (unlock and the session's start both "log in") ----
    readonly property bool mac: GoldenGate.on
    readonly property var macEvents: ({
            "notify": "notify",
            "error": "error",
            "volume": "volume",
            "screenshot": "screenshot",
            "trash": "trash",
            "usbIn": "usbIn",
            "usbOut": "usbOut",
            "achievement": "notify",
            "power": "power",
            "lock": "lock",
            "unlock": "login",
            "startup": "login",
            "login": "login"
        })
    readonly property string macDir: Quickshell.shellDir + "/data/sounds/macos"
    readonly property string macUserDir: base + "/macos"
    function macOwn(name) {
        return mac && macEvents[name] !== undefined;
    }
    function macEnabled(name) {
        return Config.mac.sounds && (name !== "volume" || Config.mac.volumeSound);
    }
    // ---- Output: scripts/sfx-player.py, one long-lived stream for every sound. A pw-play per
    // sound made a new stream each click, and Discord sharing the screen with sound opened and
    // dropped a capture for each one: the share froze and Discord grew to 13 GB (2026-10-07).
    // pw-play stays as the fallback while the player isn't up.
    Process {
        id: sfx
        running: Config.ready
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/sfx-player.py"]
        onExited: if (Config.ready && !sfxRestart.running)
            sfxRestart.start()
    }
    Timer {
        id: sfxRestart
        interval: 3000
        onTriggered: if (Config.ready)
            sfx.running = true
    }
    // the first of `paths` that exists plays
    function _out(vol, paths) {
        if (!sfx.running)
            return false;
        sfx.write(vol + "\t" + paths.join("\t") + "\n");
        return true;
    }

    // yours first, then the skin's (pw-play, or paplay without it, if the player is down)
    function _playMac(name, vol) {
        const file = macEvents[name];
        if (_out(vol, [macUserDir, macDir].reduce((all, d) => all.concat(["ogg", "oga", "opus", "wav", "flac", "aiff", "aif", "caf", "mp3"].map(e => d + "/" + file + "." + e)), [])))
            return;
        Quickshell.execDetached(["sh", "-c", 'for d in "$1" "$2"; do for e in ogg oga opus wav flac aiff aif caf mp3; do f="$d/$3.$e"; [ -f "$f" ] || continue; command -v pw-play >/dev/null && exec pw-play --volume "$4" "$f"; exec paplay --volume "$5" "$f"; done; done', "sh", macUserDir, macDir, file, String(vol), String(Math.round(vol * 65536))]);
    }

    function enabled(name) {
        if (macOwn(name))
            return macEnabled(name);
        if (!Config.y2k.sounds || !isOn(name))
            return false;
        return !cute.includes(name) || Config.y2k.cuteSounds;
    }
    // play even when switched off (the settings page "listen" buttons)
    function preview(name) {
        if (name === "circleSin")
            sinCircle = HellLook.circle;
        _play(name, true, 1);
    }
    function play(name) {
        playSoft(name, 1);
    }
    // `soft`: a share of the volume (the click's release tick)
    function playSoft(name, soft) {
        if (!enabled(name) || StreamMode.quiet || quietNow())
            return;
        if (input.includes(name) && Config.y2k.quietFullscreen && fullscreenNow())
            return;
        _play(name, false, soft);
    }
    // ---- hell's circles: the sin of the one coming up (CircleFx, at the blow). Two each in
    // data/sounds/hell/<circle>-1|2.ogg; one by chance, never the same twice running.
    readonly property string hellDir: Quickshell.shellDir + "/data/sounds/hell"
    property string sinCircle: ""
    property string _lastSin: ""
    function playSin(circle, soft) {
        sinCircle = circle || "";
        playSoft("circleSin", soft);
    }
    // decoded ahead and the stream opened (volume 0 plays nothing): CircleFx asks a second before
    // the blow, so the sounds come exactly on it
    function warm(name) {
        if (!ready || macOwn(name) || !enabled(name) || StreamMode.quiet || quietNow())
            return;
        const chosen = soundOf(name);
        _out(0, chosen.startsWith("file:") ? [chosen.slice(5)] : _packPaths(chosen && events.concat(extra).includes(chosen) ? chosen : name));
    }
    function warmSin(circle) {
        if (!enabled("circleSin") || StreamMode.quiet || quietNow() || soundOf("circleSin"))
            return warm("circleSin");
        if (circle && circle !== "base")
            for (const i of [1, 2])
                _out(0, [hellDir + "/" + circle + "-" + i + ".ogg"]);
    }
    function _sinPaths() {
        const ids = sinCircle && sinCircle !== "base" ? [sinCircle] : ["greed", "wrath", "fraud", "treachery"];
        const all = ids.reduce((a, c) => a.concat([c + "-1", c + "-2"]), []).filter(f => f !== _lastSin);
        const pick = all[Math.floor(Math.random() * all.length)];
        _lastSin = pick;
        return [hellDir + "/" + pick + ".ogg"];
    }

    // ---- the boot screen's chime (BootScreen), once a show. The screen on view is the user's own
    // choice, so quiet mode and quiet hours don't silence it (they do when it shows on no screen:
    // all of them streamed). In Golden Gate it is the login chime: the session's own one just
    // before counts as it, and the session's after it stays quiet (the 8 s in _play).
    // It used to go missing now and then (2026-10-08): asked for while the shell was still
    // starting, it waited for the pack check (start-up held its answer back ~0.7 s) and then
    // for a needless re-synthesis of the whole pack, or the Windose pack was not checked yet
    // and the chime was dropped for a download.
    property double loginChimeAt: 0
    Connections {
        target: Shell
        function onBootOpenChanged() {
            if (Shell.bootOpen)
                root.playBoot(Shell.bootScreens.length > 0);
        }
        // the black second before it: the player decodes the chime meanwhile (volume 0 plays
        // nothing), so it comes with the first picture of the show
        function onBootCoverShownChanged() {
            if (Shell.bootCover && root.ready && !root.macOwn("startup") && root.enabled("startup") && !root.soundOf("startup"))
                root._out(0, root._packPaths("startup"));
        }
    }
    function playBoot(onScreen) {
        if (!enabled("startup") || (!onScreen && (StreamMode.quiet || quietNow())))
            return;
        if (macOwn("startup") && Date.now() - loginChimeAt < 8000)
            return;
        _play("startup", true, 1);
    }
    // a sound goes out to the player (the UI test counts the boot screen's)
    signal sounded(string name)
    function _play(name, force, soft) {
        const now = Date.now(), key = soft < 1 ? name + "-soft" : name;
        if (macOwn(name)) {
            // the volume pop as fast as the keys repeat; logging in once (the boot screen and the
            // session's start may both ask)
            const file = macEvents[name];
            if (!force && now - (lastAt["mac:" + file] || 0) < (file === "volume" ? 80 : file === "login" ? 8000 : 90))
                return;
            lastAt["mac:" + file] = now;
            sounded(name);
            _playMac(name, Math.max(0, Math.min(1, Config.mac.soundVolume * (soft || 1))));
            return;
        }
        if (!events.includes(name))
            return;
        // a burst of the same event (volume wheel, many toggles) plays once
        if (!force && now - (lastAt[key] || 0) < (name === "volume" ? 140 : name === "click" || name === "clickRight" ? 45 : name === "key" ? 25 : transitions.includes(name) ? Story.soundGapMs : 90))
            return;
        lastAt[key] = now;
        const vol = String(Math.max(0, Math.min(1, volumeOf(name) * (soft || 1))));
        const chosen = soundOf(name);
        if (chosen.startsWith("file:")) {
            sounded(name);
            if (!_out(vol, [chosen.slice(5)]))
                Quickshell.execDetached(["pw-play", "--volume", vol, chosen.slice(5)]);
            return;
        }
        // another event's sound, or its own; typing picks one of three
        let id = chosen && events.concat(extra).includes(chosen) ? chosen : name;
        if (id === "key" && tweak("key").vary !== false)
            id = ["key", "key2", "key3"][Math.floor(Math.random() * 3)];
        if (id === "circleSin") {
            sounded(name);
            const f = _sinPaths();
            if (!_out(vol, f))
                Quickshell.execDetached(["pw-play", "--volume", vol, f[0]]);
            return;
        }
        // the pack isn't there (or not checked yet): it plays once the check or the synthesis is done
        if (!ready) {
            pending = pending.concat([name]);
            if (!check.running)
                make.running = true;
            return;
        }
        // the Windose pack not downloaded (or not checked) yet: the synthesised sound stands in
        // (the first file of the list below that exists plays)
        const overdose = pack === "overdose" && !effects.includes(id);
        if (overdose && !overdoseReady && !fetch.running && !checkOverdose.running)
            fetch.running = true;
        const first = overdose ? base + "/overdose" : dir;
        sounded(name);
        if (_out(vol, _packPaths(id)))
            return;
        Quickshell.execDetached(["sh", "-c", 'f="$1/$3.ogg"; [ -f "$f" ] || f="$2/$3.ogg"; [ -f "$f" ] || f="$2/$3.wav"; exec pw-play --volume "$4" "$f"', "sh", first, dir, id, vol]);
    }

    // where a pack sound may be: the Windose file first when that pack is picked, the synthesised one
    function _packPaths(id) {
        const own = [dir + "/" + id + ".ogg", dir + "/" + id + ".wav"];
        return pack === "overdose" && !effects.includes(id) ? [base + "/overdose/" + id + ".ogg"].concat(own) : own;
    }

    // the pack must be there before something plays it without _play() (the pips)
    function ensure() {
        if (!ready && !make.running)
            make.running = true;
    }

    // ---- "Click" and typing: every click / key press on the desktop (issue #10).
    // The shell only sees clicks on its own windows, so scripts/click-watch.py
    // reports them from the mice and keyboards; it runs only while one is on.
    // Which buttons click: y2k.clickButtons; the right one has its own sound when
    // "clickRight" is on; y2k.clickRelease: a softer tick on release.
    readonly property bool clicksWanted: Config.ready && !Shell.dev && (enabled("click") || enabled("clickRight"))
    readonly property bool keysWanted: Config.ready && !Shell.dev && enabled("key")
    readonly property var watchArgs: (clicksWanted ? ["--mouse"] : []).concat(keysWanted ? ["--keys"] : [])
    property string clickStatus: ""          // "" | noperm
    function onPress(button) {
        if (button === "right" && enabled("clickRight"))
            play("clickRight");
        else if ((Config.y2k.clickButtons || ["left", "right"]).includes(button))
            play("click");
    }
    function onRelease(button) {
        if (!Config.y2k.clickRelease)
            return;
        if (button === "right" && enabled("clickRight"))
            playSoft("clickRight", 0.45);
        else if ((Config.y2k.clickButtons || ["left", "right"]).includes(button))
            playSoft("click", 0.45);
    }
    Process {
        id: clicks
        running: root.watchArgs.length > 0
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/click-watch.py"].concat(root.watchArgs)
        stdout: SplitParser {
            onRead: line => {
                const [what, button] = line.split(" ");
                if (what === "click")
                    root.onPress(button || "left");
                else if (what === "release")
                    root.onRelease(button || "left");
                else if (what === "key")
                    root.play("key");
                else if (what === "noperm")
                    root.clickStatus = "noperm";
            }
        }
        onExited: if (root.watchArgs.length > 0 && !clickRestart.running)
            clickRestart.start()
    }
    // mouse / keys switched: the watcher starts again with the new flags (or stops)
    onWatchArgsChanged: {
        clicks.running = false;
        if (watchArgs.length > 0) {
            clickRestart.interval = 50;
            clickRestart.start();
        }
    }
    Timer {
        id: clickRestart
        interval: 5000
        onTriggered: {
            interval = 5000;
            if (root.watchArgs.length > 0)
                clicks.running = true;
        }
    }

    // ---- USB devices plugged in / out (scripts/usb-watch.py reads udev, no root);
    // runs only while one of the two sounds is on
    readonly property bool usbWanted: Config.ready && !Shell.dev && (enabled("usbIn") || enabled("usbOut"))
    Process {
        id: usb
        running: root.usbWanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/usb-watch.py"]
        stdout: SplitParser {
            onRead: line => {
                const what = line.split(" ")[0];
                if (what === "add")
                    root.play("usbIn");
                else if (what === "remove")
                    root.play("usbOut");
            }
        }
        onExited: if (root.usbWanted && !usbRestart.running)
            usbRestart.start()
    }
    Timer {
        id: usbRestart
        interval: 5000
        onTriggered: if (root.usbWanted)
            usb.running = true
    }

    // ---- Golden Gate: logged in (once a session: a marker in $XDG_RUNTIME_DIR, so `angelos
    // restart` and crash restarts stay quiet, and a skin switched on later doesn't chime) ----
    readonly property bool loginWanted: Config.ready && !Shell.dev && mac && Config.mac.sounds
    property bool loginAsked: false
    onLoginWantedChanged: if (loginWanted && !loginAsked && Date.now() - startedAt < 60000) {
        loginAsked = true;
        loginMark.running = true;
    }
    Process {
        id: loginMark
        command: ["sh", "-c", 'm="${XDG_RUNTIME_DIR:-/tmp}/angelos-login-sound"; [ -e "$m" ] && exit 1; : > "$m"']
        onExited: code => {
            if (code === 0)
                loginDelay.start();
        }
    }
    Timer {
        id: loginDelay
        interval: 1500                       // PipeWire is up by then
        onTriggered: {
            root.loginChimeAt = Date.now();
            root.play("login");
        }
    }
    // a charger plugged in (UPower; asked only while the sound can play — no battery: never changes)
    readonly property bool powerWanted: Config.ready && !Shell.dev && mac && Config.mac.sounds
    Connections {
        target: root.powerWanted ? UPower : null
        function onOnBatteryChanged() {
            if (!UPower.onBattery && root.settled())
                root.play("power");
        }
    }
    // screenshot tools (mac-screenshot.sh, niri-screenshot-region) skip their own "pling" while
    // the shutter plays here (its notification brings it): a marker in $XDG_RUNTIME_DIR/angelos
    readonly property bool shutterHere: Config.ready && !Shell.dev && mac && macEnabled("screenshot")
    onShutterHereChanged: markShutter()
    Component.onCompleted: {
        markShutter();
        // a complete pack: its version is written last (scripts/y2k-sounds.py), so what is asked
        // for at once (the boot screen) plays without waiting for the file check
        if (String(packStamp.text()).trim() === packVersion)
            ready = true;
    }
    FileView {
        id: packStamp
        path: root.dir + "/.version"
        blockLoading: true
        printErrors: false
    }
    function markShutter() {
        shutterMark.running = false;
        shutterMark.command = ["sh", "-c", 'd="${XDG_RUNTIME_DIR:-/tmp}/angelos"; mkdir -p "$d"; if [ "$1" = 1 ]; then : > "$d/shutter"; else rm -f "$d/shutter"; fi', "sh", shutterHere ? "1" : "0"];
        shutterMark.running = true;
    }
    Process {
        id: shutterMark
    }

    // ---- the shell's own moments ----
    readonly property double startedAt: Date.now()
    function settled() {
        return Config.ready && Date.now() - startedAt > 5000;
    }
    // (Start opens silently)
    Connections {
        target: Shell
        function onLauncherOpenChanged() {
            if (Shell.launcherOpen)
                root.play("open");
        }
        function onSettingsOpenChanged() {
            if (Shell.settingsOpen)
                root.play("open");
        }
    }
    Connections {
        target: Niri
        function onWindowClosed(id) {
            root.play("windowClose");
        }
        function onWindowOpened(id) {
            root.play("windowOpen");
        }
        function onWorkspaceActivated(ws, focused) {
            if (focused && root.settled())
                root.play("workspace");
        }
    }
    Connections {
        target: Shell
        function onLockedChanged() {
            if (root.settled())
                root.play(Shell.locked ? "lock" : "unlock");
        }
    }
    Connections {
        target: Audio
        function onVolumeChanged() {
            if (root.settled())
                root.play("volume");
        }
    }
    // every wallpaper change, not only the first (the angel only comments now and then)
    property double wallpaperQuietUntil: 0
    function quietWallpaper(ms) {
        wallpaperQuietUntil = Date.now() + ms;
    }
    readonly property string wallpaperKey: Wallpapers.stateKey
    onWallpaperKeyChanged: if (settled() && Date.now() > wallpaperQuietUntil)
        wallpaperDebounce.restart()
    Timer {
        id: wallpaperDebounce
        interval: 200
        onTriggered: root.play("wallpaper")
    }

    // synthesise once if the pack is missing (or older than the event list)
    Process {
        id: check
        running: true
        command: ["sh", "-c", 'd="$1"; [ "$(cat "$d/.version" 2>/dev/null)" = "$2" ] || exit 1; shift 2; for n in "$@"; do [ -f "$d/$n.ogg" ] || [ -f "$d/$n.wav" ] || exit 1; done', "sh", root.dir, root.packVersion].concat(root.events.filter(e => !root.shipped.includes(e))).concat(root.extra)
        onExited: code => {
            if (code === 0) {
                root.ready = true;
                root.playPending();
            } else {
                root.ready = false;
                if ((Config.y2k.sounds || root.pending.length) && !make.running)
                    make.running = true;    // missing or older (louder) pack: made again right away
            }
        }
    }
    Process {
        id: make
        command: ["python3", Quickshell.shellDir + "/scripts/y2k-sounds.py", root.dir]
        onExited: code => {
            if (code !== 0)
                return;
            root.ready = true;
            root.playPending();
        }
    }
    // what was asked for while the pack wasn't there: the last of it
    function playPending() {
        const p = pending;
        pending = [];
        for (const n of p.slice(-1))
            _play(n, true);
    }

    // the Windose pack: present already, or downloaded when picked
    Process {
        id: checkOverdose
        running: root.pack === "overdose"
        command: ["sh", "-c", '[ -f "$1/notify.ogg" ] && [ -f "$1/startup.ogg" ]', "sh", root.base + "/overdose"]
        onExited: code => {
            root.overdoseReady = code === 0;
            if (code !== 0 && root.pack === "overdose" && !fetch.running)
                fetch.running = true;
        }
    }
    Process {
        id: fetch
        command: ["python3", Quickshell.shellDir + "/scripts/sound-pack.py", "overdose", root.base + "/overdose"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.overdoseError = Object.keys(r.failed || {}).length ? I18n.t("не скачались: ", "failed: ") + Object.keys(r.failed).join(", ") : "";
                } catch (e) {
                    root.overdoseError = I18n.t("нет сети или GitHub недоступен", "no network or GitHub is down");
                }
            }
        }
        onExited: code => {
            root.overdoseReady = code === 0;
            if (code === 0)
                root.play("angel");
        }
    }
}
