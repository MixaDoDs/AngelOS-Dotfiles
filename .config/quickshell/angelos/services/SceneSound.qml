pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// A layered scene's sounds (scene.json → "sounds", files from scripts/scene-sounds.py or the
// author's own): its air — crickets at night, birds by day, the leaves as hard as the wind
// blows — and its night's event (the meteor: the rumble for forty minutes, the whistle, the
// impact a few seconds after the flash, the fire, sirens far off, the CRT's static). All through
// sfx-player's one stream (Sounds.channel / playFile): a new stream per sound crashes Discord.
//
// The air gives way (Settings → Wallpaper → Sounds; the owner's table, 28.10):
//                 desktop seen   a window over it
//   silence         100 %          100 %
//   music            duckDesk       duckWindow       (65 % / 25 %: Spotify and other players)
//   a video          0              0                (a browser or a video player playing)
//   a game, fullscreen, locked, the idle screen: 0
// The event plays over all of that at its own level; only screens gone dark stop it.
Singleton {
    id: root

    readonly property bool live: Quickshell.env("ANGELOS_TEST") !== "1" && !Shell.dev

    // the scene to be heard: the focused screen's, else the first screen showing one
    function sceneOn(name) {
        const ws = Niri.activeWorkspace(name);
        const path = Wallpapers.origin(Wallpapers.resolve(name, ws ? ws.idx : 1));
        const dir = Wallpapers.sceneOf(path);
        return dir ? {
            "screen": name,
            "path": path,
            "dir": dir,
            "ws": ws
        } : null;
    }
    readonly property var shown: {
        if (!live || Wallpapers.hellOn)
            return null;
        const f = sceneOn(Niri.focusedOutput);
        if (f)
            return f;
        for (const s of Shell.screens) {
            const x = sceneOn(s.name);
            if (x)
                return x;
        }
        return null;
    }
    readonly property string dir: shown ? shown.dir : ""
    // every screen showing it: someone may look at one of them
    readonly property var screens: shown ? Shell.screens.map(s => sceneOn(s.name)).filter(x => x && x.dir === dir) : []
    readonly property bool seen: screens.some(x => !Shell.gaming && !Shell.hiddenScreen(x.screen))
    readonly property bool desktop: Niri.overviewOpen || screens.some(x => x.ws && Niri.windowsOn(x.ws.id).length === 0)

    // what plays (MPRIS): a browser or a video player is a video, a messenger is nothing, the rest
    // is music. A browser playing a song is music: an album (YouTube Music, Spotify's web player)
    // or YouTube's own music channels ("Artist - Topic") — the owner listens there
    function kindOf(p) {
        const id = (p.identity || "") + " " + (p.desktopEntry || "");
        if (/discord|vesktop|telegram|signal|element|slack/i.test(id))
            return "";
        if (!/firefox|chrom|brave|vivaldi|helium|zen|edge|opera|librewolf|browser|yandex|mpv|vlc|celluloid|totem|haruna|smplayer|kodi|jellyfin|plex/i.test(id))
            return "music";
        return p.trackAlbum || / - Topic$/.test(p.trackArtist || "") ? "music" : "video";
    }
    readonly property var playing: (Lyrics.players || []).filter(p => p.isPlaying).map(p => kindOf(p))
    readonly property bool video: playing.includes("video")
    readonly property bool music: playing.includes("music")
    // the air's share now (0..1) and why, for the debug page
    readonly property real airDuck: !seen || video ? 0 : music ? (desktop ? Config.wallpaper.sceneDuckDesk : Config.wallpaper.sceneDuckWindow) / 100 : 1
    readonly property string why: !shown ? "no scene" : !seen ? "not seen" : video ? "video" : music ? (desktop ? "music, desktop" : "music, window") : desktop ? "desktop" : "window"

    readonly property bool on: !!shown && Config.y2k.sounds && Wallpapers.own(shown.path, "sceneSounds") !== false
    readonly property real airVol: on ? Wallpapers.own(shown.path, "sceneSoundAir") / 100 : 0
    readonly property real eventVol: on && !Power.screensOff ? Wallpapers.own(shown.path, "sceneSoundEvent") / 100 : 0

    // the scene's list
    property var sounds: null
    FileView {
        path: root.dir ? root.dir + "/scene.json" : ""
        printErrors: false
        onLoaded: {
            try {
                root.sounds = JSON.parse(text()).sounds || null;
            } catch (e) {
                root.sounds = null;
            }
        }
        onLoadFailed: root.sounds = null
    }
    onDirChanged: sounds = null

    function smooth(x) {
        x = Math.max(0, Math.min(1, x));
        return x * x * (3 - 2 * x);
    }
    // the event's loops by its age (seconds from the impact): the rumble barely there for half
    // an hour, growing in the last ten minutes, gone into the impact; the fire after it
    function eventLoop(name, a) {
        if (!isFinite(a))
            return 0;
        if (name === "rumble")
            return a < 0 ? 0.12 * smooth((a + 2400) / 300) + 0.88 * Math.pow(smooth((a + 600) / 600), 2) : 1 - smooth(a / 40);
        if (name === "crackle")
            return a < 5 || a > 3600 ? 0 : smooth((a - 5) / 20) * (a < 460 ? 1 : Math.exp(-(a - 460) / 600));
        return 0;
    }
    // the one-shots: [name, at (s from the impact), volume]. The whistle ends as the meteor goes
    // behind the house; the impact is heard three seconds after its flash (it is far)
    readonly property var cues: [["whistle", -48, 0.9], ["impact", 3, 1], ["static", 5, 0.5], ["siren", 100, 0.6], ["siren", 330, 0.4]]

    property real lastAge: NaN
    property var sent: ({})          // channel -> [path, volume] last written
    property int beat: 0

    function send(name, path, vol) {
        const v = Math.round(vol * 100) / 100;
        const was = sent[name];
        if (was && was[0] === path && was[1] === v && beat % 20 !== 0)
            return;
        if (!was && v === 0)
            return;
        Sounds.channel(name, path, v);
        const s = Object.assign({}, sent);
        if (v === 0)
            delete s[name];
        else
            s[name] = [path, v];
        sent = s;
    }
    function silence() {
        for (const name of Object.keys(sent))
            Sounds.channel(name, "", 0);
        sent = {};
    }

    function tick() {
        beat++;
        const snd = sounds;
        if (!snd || !shown) {
            silence();
            lastAge = NaN;
            return;
        }
        const now = new Date();
        const night = Wallpapers.nightMix(shown.path, now);
        const wind = Math.max(0.15, Math.min(1, SceneWind.strength * 1.3 + SceneWind.pulse * 0.5));
        const want = {};
        for (const t of snd.ambient || []) {
            const when = t.when === "night" ? night : t.when === "day" ? 1 - night : 1;
            want["wall-" + t.file] = [root.dir + "/" + t.file, airVol * airDuck * (t.vol ?? 1) * when * (t.wind ? wind : 1)];
        }
        const ev = snd.event || null;
        const age = ev ? Wallpapers.nightEvent(now) : NaN;
        for (const name of ["rumble", "crackle"])
            if (ev && ev[name])
                want["wall-" + name] = [root.dir + "/" + ev[name], eventVol * eventLoop(name, age)];
        for (const name of Object.keys(sent))
            if (!(name in want))
                send(name, "", 0);
        for (const name in want)
            send(name, want[name][0], want[name][1]);
        // seen it fall (Achievements: the secret "A falling star"), the clock running past, not the debug page's
        if (ev && isFinite(age) && isFinite(lastAge) && lastAge < 0 && age >= 0 && age - lastAge < 30 && !SceneDebug.eventOn)
            Achievements.note("explore", "meteor");
        // a cue plays when the clock (or the debug timeline) runs past it, not when it jumps there
        if (ev && isFinite(age) && isFinite(lastAge) && age > lastAge && age - lastAge < 30)
            for (const c of cues)
                if (ev[c[0]] && lastAge < c[1] && age >= c[1] && eventVol > 0)
                    Sounds.playFile(root.dir + "/" + ev[c[0]], eventVol * c[2]);
        lastAge = age;
    }
    // the debug page plays a cue at once
    function cue(name) {
        const ev = sounds && sounds.event;
        if (ev && ev[name])
            Sounds.playFile(root.dir + "/" + ev[name], Math.max(0.3, eventVol));
    }

    Timer {
        running: root.live && (root.sounds !== null || Object.keys(root.sent).length > 0)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
}
