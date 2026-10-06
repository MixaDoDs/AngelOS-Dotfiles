pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The lock screen's NGO "stream" (modules/lock/StreamOverlay): how long it has been
// going and what the chat may talk about.
//   days     the stream day: day 1 is the day angelOS came, every later day it runs
//            adds one (~/.local/state/angelos/lock-stream.json)
//   viewers  grow with the days: nobody on day 1 (a 1 or a 2 now and then), about
//            1000–1500 by day 30, slower after that
//   seen     what was on screen when it locked — the program's NAME only (never a
//            window title: that holds the page you read and who you write to), the
//            song, how many windows, the hour; and which programs sent notifications
//            while it was locked (names only, never their text)
//   wish     heaven's prayer at the unlock (gacha): 3★/4★/5★ with a pity counter
//   claim    heaven's daily login reward in stars ✦ (HeavenStars): one a day, a 7-day cycle
// Nothing here leaves the computer.
Singleton {
    id: root

    property int days: 1
    property string lastDay: ""
    property bool loaded: false
    readonly property string file: Config.stateDir + "/lock-stream.json"

    // heaven: the prayer's pity, the login rewards
    property int pity4: 0
    property int pity5: 0
    property int wishes: 0
    property int fives: 0
    property string lastClaim: ""
    property int streak: 0
    property int claims: 0

    function save() {
        store.setText(JSON.stringify({
            "days": days,
            "lastDay": lastDay,
            "pity4": pity4,
            "pity5": pity5,
            "wishes": wishes,
            "fives": fives,
            "lastClaim": lastClaim,
            "streak": streak,
            "claims": claims
        }));
    }
    function dayKey(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }
    // a new day of angelOS counts once, whenever the shell first sees it
    function touch() {
        if (!loaded)
            return;
        const today = dayKey(new Date());
        if (today === lastDay)
            return;
        if (lastDay !== "")
            days++;
        lastDay = today;
        save();
    }
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text()) || {};
                root.days = Math.max(1, Math.floor(Number(s.days) || 1));
                root.lastDay = String(s.lastDay || "");
                root.pity4 = Math.max(0, Number(s.pity4) || 0);
                root.pity5 = Math.max(0, Number(s.pity5) || 0);
                root.wishes = Math.max(0, Number(s.wishes) || 0);
                root.fives = Math.max(0, Number(s.fives) || 0);
                root.lastClaim = String(s.lastClaim || "");
                root.streak = Math.max(0, Number(s.streak) || 0);
                root.claims = Math.max(0, Number(s.claims) || 0);
            } catch (e) {}
            root.loaded = true;
            root.touch();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                firstSeen.running = true;
        }
    }
    // no file yet: day 1 is the day the angelOS config appeared (an old install is not a newcomer)
    Process {
        id: firstSeen
        command: ["sh", "-c", 'stat -c "%W %Y" "$1" 2>/dev/null', "sh", Config.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const [born, changed] = String(text).trim().split(" ").map(Number);
                const t = (born > 0 ? born : changed || 0) * 1000;
                root.days = t > 0 ? Math.max(1, Math.floor((Date.now() - t) / 86400000) + 1) : 1;
                root.lastDay = "";
                root.loaded = true;
                root.touch();
            }
        }
    }
    Timer {
        interval: 600000
        repeat: true
        running: root.loaded
        onTriggered: root.touch()
    }

    // the audience of a stream day: 0 on day 1, ~1250 on day 30 (×0.8…1.2 per lock)
    function baseViewers(d) {
        if (d <= 1)
            return 0;
        if (d <= 30)
            return 1250 * Math.pow((d - 1) / 29, 1.6);
        return 1250 * (1 + 0.6 * Math.log2(d / 30));
    }
    // one look at the counter: day 1 is mostly 0, a 1 or a 2 slips in
    function rollViewers(d) {
        const base = baseViewers(d);
        if (base < 1) {
            const r = Math.random();
            return r < 0.7 ? 0 : r < 0.9 ? 1 : 2;
        }
        return Math.max(0, Math.round(base * (0.8 + Math.random() * 0.4) + (base < 8 ? Math.floor(Math.random() * 3) - 1 : 0)));
    }

    // followers: everyone who ever stayed, more with every day
    readonly property int followers: Math.round(baseViewers(days) * 2.4 + (days - 1) * 3)

    // ---- heaven's prayer (Genshin's rates): 5★ 0.6 %, soft pity from 74, sure at 90;
    // 4★ 5.1 %, sure every 10th ----
    // dry: the preview's wish — the same odds, nothing counted
    function wish(dry) {
        if (dry) {
            const p5 = pity5 + 1 >= 90 ? 1 : pity5 + 1 >= 74 ? 0.006 + (pity5 - 72) * 0.06 : 0.006;
            return Math.random() < p5 ? 5 : pity4 + 1 >= 10 || Math.random() < 0.051 ? 4 : 3;
        }
        pity4++;
        pity5++;
        wishes++;
        const p5 = pity5 >= 90 ? 1 : pity5 >= 74 ? 0.006 + (pity5 - 73) * 0.06 : 0.006;
        let stars = 3;
        if (Math.random() < p5) {
            stars = 5;
            pity5 = 0;
            pity4 = 0;
            fives++;
        } else if (pity4 >= 10 || Math.random() < 0.051) {
            stars = 4;
            pity4 = 0;
        }
        save();
        return stars;
    }

    // ---- heaven's daily login reward: a 7-day cycle, claimed by the first unlock of a day ----
    readonly property var rewards: [20, 30, 40, 50, 60, 80, 160].map((n, i) => ({
                "icon": i === 6 ? "sparkleStar" : "sparkle",
                "n": n
            }))
    property string today: dayKey(new Date())
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.today = root.dayKey(new Date())
    }
    readonly property bool claimable: today !== lastClaim
    // where in the cycle today's reward is (claimed today: the one just taken)
    readonly property int cycleDay: claimable ? claims % 7 : (claims + 6) % 7
    function claim() {
        if (!claimable)
            return null;
        const y = new Date();
        y.setDate(y.getDate() - 1);
        streak = lastClaim === dayKey(y) ? streak + 1 : 1;
        const r = rewards[claims % 7];
        lastClaim = today;
        claims++;
        save();
        HeavenStars.earn(r.n, I18n.t("награда за вход, день %1", "login reward, day %1").arg(claims % 7 || 7));
        return r;
    }

    // ---- what the chat knows ----
    property var seen: ({})
    property var notified: []        // program names that sent a notification while locked
    readonly property bool watching: Shell.locked || Shell.lockPreview

    function appName(w) {
        const id = String(w && w.app_id || "");
        if (!id)
            return "";
        const e = DesktopEntries.heuristicLookup(id);
        return e && e.name ? e.name : id.replace(/^.*\./, "");
    }
    // a rough kind of program, for the chat's jokes
    function kindOf(appId, name) {
        const s = (String(appId) + " " + String(name)).toLowerCase();
        if (/steam_app|cs2|counter-strike|osu|minecraft|gamescope|lutris|heroic|dota|genshin|zenless|hoyo|wine|game/.test(s))
            return "game";
        if (/obs/.test(s))
            return "obs";
        if (/telegram|discord|vesktop|signal|element|whatsapp|vk/.test(s))
            return "chat";
        if (/code|zed|neovim|nvim|idea|kate|helix|pycharm|clion|jetbrains/.test(s))
            return "code";
        if (/kitty|alacritty|foot|wezterm|ghostty|konsole|terminal/.test(s))
            return "terminal";
        if (/helium|firefox|chrom|brave|zen|librewolf|vivaldi|browser/.test(s))
            return "browser";
        if (/spotify|music|yandex|deezer|tidal|rhythmbox|strawberry|mpv|vlc|celluloid/.test(s))
            return "media";
        if (/nautilus|thunar|dolphin|files/.test(s))
            return "files";
        if (/blender|krita|gimp|aseprite|inkscape|resolve|kdenlive/.test(s))
            return "art";
        return name ? "app" : "";
    }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
    }
    function snapshot() {
        const w = Niri.focusedWindow;
        uptimeFile.reload();
        const up = parseFloat(String(uptimeFile.text() || "0").split(" ")[0]) || 0;
        const app = appName(w);
        seen = {
            "app": app,
            "kind": kindOf(w ? w.app_id : "", app),
            "windows": Niri.windows.length,
            "song": Lyrics.title || "",
            "artist": Lyrics.artist || "",
            "playing": Lyrics.playing,
            "hour": new Date().getHours(),
            "uptimeMin": Math.floor(up / 60),
            "layout": Niri.layoutShort || ""
        };
        notified = [];
    }
    onWatchingChanged: if (watching) {
        touch();
        snapshot();
    }
    Connections {
        target: Notifs
        function onArrived(info) {
            if (!root.watching || !info)
                return;
            const name = String(info.appName || "").trim();
            if (name && !/screenshot|скриншот|angelos/i.test(name))
                root.notified = root.notified.concat([name]).slice(-12);
        }
    }
}
