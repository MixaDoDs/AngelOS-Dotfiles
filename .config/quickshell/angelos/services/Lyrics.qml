pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// Synced lyrics for the current MPRIS track, fetched from lrclib.net and cached on disk.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    // the player whose song this is: playing beats paused, the preferred one beats the rest,
    // a music player beats a browser, and a messenger's voice message or a call never takes
    // the song from a music player (Telegram publishes them over MPRIS too); the one already
    // followed keeps it on a tie, so two playing players don't make the lyrics jump
    readonly property var player: {
        const pref = (Config.lyrics.preferPlayer || "").toLowerCase();
        let best = null, top = -1e9;
        for (const p of players) {
            const s = playerScore(p, pref);
            if (s > top) {
                best = p;
                top = s;
            }
        }
        return best;
    }
    // the one followed, kept outside the binding (a plain object's field notifies nobody)
    readonly property var _followed: ({
            "player": null
        })
    onPlayerChanged: _followed.player = player
    readonly property var musicApps: /spotify|yandex|vk ?music|vkmusic|deezer|tidal|apple ?music|cider|amberol|rhythmbox|elisa|strawberry|clementine|audacious|lollypop|quodlibet|cmus|mpd|ncspot|spotube|feishin|sonixd|supersonic|youtube.?music|ytmusic|soundcloud|nuclear|harmonoid|tauon|g4music|gapless|euphonica|musikcube|deadbeef|foobar|museeks|kew|termusic|plexamp|jellyfin|navidrome|psst|sayonara|mpv|vlc|celluloid|haruna/i
    readonly property var notMusic: /telegram|discord|zoom|skype|teams|whatsapp|signal|slack|element|obs|kdeconnect|gsconnect|steam|nautilus|gwenview|loupe/i
    function playerScore(p, pref) {
        const id = (p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || "");
        let s = 0;
        if (p.isPlaying)
            s += 100;
        if (pref && id.toLowerCase().includes(pref))
            s += 40;
        if (notMusic.test(id))
            s -= 70;
        else if (musicApps.test(id))
            s += 20;
        s += p.trackTitle ? 5 : -30;
        if (p.trackArtist)
            s += 3;
        if (p === _followed.player)
            s += 15;
        return s;
    }
    readonly property bool playing: !!player && player.isPlaying
    readonly property string title: player ? player.trackTitle || "" : ""
    readonly property string artist: player ? player.trackArtist || "" : ""
    readonly property string artUrl: player ? player.trackArtUrl || "" : ""
    readonly property string album: player ? player.trackAlbum || "" : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property string trackKey: artist + "\u0001" + title

    property string plainText: ""
    property var lines: []          // [{t, text}] sorted
    property string status: "idle"  // idle | loading | ok | plain | instrumental | notfound | error
    property int index: -1
    property real position: 0
    // Plain lyrics have no timing: display a first-line preview in the bar
    // and the complete text on the Lyrics settings page.
    readonly property bool hasLyrics: (status === "ok" || status === "plain") && lines.length > 0
    readonly property string current: index >= 0 && index < lines.length ? lines[index].text : ""
    readonly property string previous: index > 0 && index <= lines.length ? lines[index - 1].text : ""
    readonly property string next: index >= -1 && index + 1 < lines.length ? lines[index + 1].text : ""
    readonly property real lineStart: index >= 0 && index < lines.length ? lines[index].t : 0
    readonly property real lineEnd: index + 1 < lines.length ? lines[index + 1].t : length
    property bool visibleToggle: true

    property var _mem: ({})
    property string _pendingKey: ""

    onTrackKeyChanged: fetchTimer.restart()
    readonly property bool unseen: Shell.locked || (Shell.screens.length > 0 && Shell.screens.every(s => Shell.fullscreenOn(s.name)))

    // track metadata often arrives in pieces; wait for it to settle
    Timer {
        id: fetchTimer
        interval: 350
        onTriggered: root.fetch()
    }

    // Wakes up right before the next line is due instead of polling at a fixed
    // 80 ms; the 250 ms ceiling still picks up seeks quickly.
    Timer {
        interval: 80
        repeat: true
        // nobody reads the bar while the screen is locked or every screen shows a
        // fullscreen game or video: the position is picked up again afterwards
        running: root.playing && root.status === "ok" && root.lines.length > 0 && !root.unseen

        onTriggered: {
            root.player.positionChanged();
            root.updateIndex();
            const next = root.index + 1 < root.lines.length ? root.lines[root.index + 1].t : -1;
            interval = next > root.position ? Math.max(30, Math.min(250, Math.round((next - root.position) * 1000))) : 250;
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() {
            root.index = -1;
        }
        function onPlaybackStateChanged() {
            if (root.player) {
                root.player.positionChanged();
                root.updateIndex();
            }
        }
    }

    function updateIndex() {
        if (!player || lines.length === 0)
            return;
        position = player.position + Config.lyrics.offsetMs / 1000;
        let i = index;
        if (i < 0 || i >= lines.length || lines[i].t > position)
            i = -1;
        while (i + 1 < lines.length && lines[i + 1].t <= position)
            i++;
        if (i !== index)
            index = i;
    }

    function cacheFile(key) {
        let h = 0;
        for (let i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) | 0;
        const safe = key.replace(/[\/\\:*?"<>|\s\u0001.]+/g, "_").slice(0, 60);
        return Config.cacheDir + "/lyrics/" + safe + "_" + (h >>> 0).toString(16) + ".json";
    }

    function parseLrc(text) {
        const out = [];
        for (const raw of (text || "").split("\n")) {
            const stamps = [];
            let rest = raw;
            let m;
            const re = /^\s*\[(\d+):(\d+(?:[.:]\d+)?)\]/;
            while ((m = rest.match(re))) {
                stamps.push(parseInt(m[1]) * 60 + parseFloat(m[2].replace(":", ".")));
                rest = rest.slice(m[0].length);
            }
            for (const t of stamps)
                out.push({
                    "t": t,
                    "text": rest.trim()
                });
        }
        return out.sort((a, b) => a.t - b.t);
    }

    property string source: ""          // lrclib | NetEase | lyrics.ovh
    function apply(data) {
        source = data && data.source ? data.source : "";
        plainText = data && data.plainLyrics ? String(data.plainLyrics) : "";
        if (!data) {
            lines = [];
            status = _offline ? "error" : "notfound";
        } else if (data.instrumental) {
            lines = [];
            status = "instrumental";
        } else if (data.syncedLyrics) {
            const k = data.scale > 0.5 && data.scale < 2 ? data.scale : 1;
            lines = parseLrc(data.syncedLyrics).map(l => k === 1 ? l : {
                    "t": l.t * k,
                    "text": l.text
                });
            status = lines.length ? "ok" : "notfound";
        } else if (data.plainLyrics) {
            lines = [
                {
                    "t": 0,
                    "text": (plainText.split("\n").find(l => l.trim() !== "") || "").trim()
                }
            ];
            status = "plain";
        } else {
            lines = [];
            status = _offline ? "error" : "notfound";
        }
        index = -1;
        if (player)
            updateIndex();
    }

    // bypass caches (memory + disk) for the current track
    function refetch() {
        if (!title)
            return;
        delete _mem[trackKey];
        lines = [];
        index = -1;
        status = "loading";
        _pendingKey = trackKey;
        fetchNet(trackKey);
    }

    function fetch() {
        plainText = "";
        lines = [];
        index = -1;
        if (!title) {
            status = "idle";
            return;
        }
        const key = trackKey;
        _pendingKey = key;
        if (_mem[key] !== undefined) {
            apply(_mem[key]);
            return;
        }
        status = "loading";
        diskReader.key = key;
        diskReader.path = cacheFile(key);
        diskReader.reload();
    }

    FileView {
        id: diskReader
        property string key: ""
        printErrors: false
        onLoaded: {
            if (key !== root._pendingKey)
                return;
            try {
                const data = JSON.parse(text());
                root._mem[key] = data;
                root.apply(data);
            } catch (e) {
                root.fetchNet(key);
            }
        }
        onLoadFailed: if (key === root._pendingKey)
            root.fetchNet(key)
    }

    // one writer for every cache file: a new path is set only once the last write is
    // done (changing the path of a FileView that is still writing waits for the disk)
    AsyncFile {
        id: diskWriter
        preload: false
        atomicWrites: true
        printErrors: false
        onSaved: Qt.callLater(root._diskNext)
        onSaveFailed: Qt.callLater(root._diskNext)
    }
    property var _diskQueue: []
    function _diskNext() {
        // the same text to the same file is no write at all: on to the next one
        while (!diskWriter.writing && _diskQueue.length) {
            const job = _diskQueue.shift();
            diskWriter.path = job.path;
            diskWriter.write(job.text);
        }
    }

    function store(key, data) {
        _mem[key] = data;
        _diskQueue.push({
            "path": cacheFile(key),
            "text": JSON.stringify(data)
        });
        _diskNext();
    }

    function query(params) {
        return Object.keys(params).filter(k => params[k] !== "" && params[k] !== undefined).map(k => k + "=" + encodeURIComponent(params[k])).join("&");
    }

    function httpText(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                cb(xhr.status, xhr.status === 200 ? xhr.responseText : "");
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("User-Agent", "angelOS-quickshell (https://github.com/MixaDoDs)");
        xhr.send();
    }
    function http(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            cb(xhr.status, body);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("User-Agent", "angelOS-quickshell (https://github.com/MixaDoDs)");
        xhr.send();
    }

    // ---- what to search for ----
    readonly property bool fromBrowser: !!player && /firefox|chrom|brave|vivaldi|helium|zen|edge|opera|librewolf|browser|yandex/i.test((player.identity || "") + " " + (player.desktopEntry || ""))
    readonly property var cleaned: clean(title, artist)
    readonly property var allSources: ["local", "player", "lrclib", "amll", "netease", "kugou", "qq", "lrccx", "musixmatch", "ovh"]
    readonly property var sources: Config.lyrics.sources && Config.lyrics.sources.length ? Config.lyrics.sources : allSources
    // settings from before Kugou / QQ / local files: add the new sources once, keep the user's order
    // once the settings are read (whenever this service starts, before or after that)
    readonly property bool _needsMigration: Config.ready && (Config.lyrics.sourcesVersion || 0) < 3
    on_NeedsMigrationChanged: if (_needsMigration)
        Qt.callLater(migrateSources)
    Component.onCompleted: if (_needsMigration)
        Qt.callLater(migrateSources)
    function migrateSources() {
        if (!Config.ready || Config.lyrics.sourcesVersion >= 3)
            return;
        if (Config.lyrics.sourcesVersion === 2) {
            // v3: AMLL after lrclib, lrc.cx and Musixmatch before lyrics.ovh — the user's order kept
            let out = (Config.lyrics.sources || []).filter(x => !["amll", "lrccx", "musixmatch"].includes(x));
            const at = out.indexOf("lrclib");
            out.splice(at >= 0 ? at + 1 : out.length, 0, "amll");
            const ovh = out.indexOf("ovh");
            out.splice(ovh >= 0 ? ovh : out.length, 0, "lrccx", "musixmatch");
            Config.lyrics.sources = out;
            Config.lyrics.sourcesVersion = 3;
            return;
        }
        const cur = (Config.lyrics.sources || []).slice();
        const fresh = ["local", "player"].filter(s => !cur.includes(s));
        const net = ["kugou", "qq"].filter(s => !cur.includes(s));
        let out = fresh.concat(cur);
        const ovh = out.indexOf("ovh");
        if (ovh >= 0)
            out.splice(ovh, 0, ...net);
        else
            out = out.concat(net);
        Config.lyrics.sources = out;
        Config.lyrics.sourcesVersion = 2;
        migrateSources();
    }

    // "Artist - Song (Official Video) [4K]" from a browser or YouTube → {artist, title}
    function clean(t, a) {
        t = String(t || "");
        a = String(a || "");
        // what a video adds to the song's name: (Official Music Video), [Lyric Video], 【MV】,
        // (премьера клипа, 2024), (текст песни), (prod. by …), #shorts, emoji, a year
        const noise = /\s*[\(\[【〔]\s*(?:official\s*)?(?:hd\s*|hq\s*|4k\s*)?(?:music\s*|lyrics?\s*|lyric\s*|audio\s*)?(?:video|audio|lyrics?(?:\s*video)?|visuali[sz]er|mv|m\/v|hd|hq|4k|8k|60\s?fps|live|clip(?:\s*officiel)?|videoclip|video\s*clip|премьера[^\)\]】]*|клип[^\)\]】]*|official|текст(?:\s*песни)?|lyrics?\s*\/\s*текст|караоке|karaoke|with\s+lyrics|letra|legendado|tradução|перевод|subtitulado|eng\s*sub|bass\s*boosted|explicit|clean|(?:19|20)\d\d|prod(?:\.|uced)?(?:\s*by)?\s[^\)\]】]*)\s*[\)\]】〕]/gi;
        t = t.replace(noise, "").replace(noise, "");
        t = t.replace(/\s*#\S+/g, "").replace(/[\uD83C-\uDBFF][\uDC00-\uDFFF]|[☀-➿️]/g, "");
        t = t.replace(/\s*[|｜•].*$/, "").replace(/\s+(?:4k|hd|hq|mv|m\/v|official\s+video)\s*$/i, "").replace(/\s{2,}/g, " ").trim();
        a = a.replace(/\s*-\s*Topic$/i, "").replace(/VEVO$/i, "").replace(/\s+(?:official|официальный|music|records|tv)$/i, "").replace(/\s*[\(\[]official[\)\]]$/i, "").trim();
        // Artist「Song」 / Artist «Song» / Artist "Song"
        let q = t.match(/^(.+?)\s*[「『«“"]\s*(.+?)\s*[」』»”"]\s*$/);
        if (q && (!a || fromBrowser)) {
            a = q[1].replace(/\s*[-–—:]\s*$/, "").trim();
            t = q[2].trim();
        }
        const m = t.match(/^(.+?)\s+[-–—]\s+(.+)$/) || (fromBrowser ? t.match(/^(.+?)\s*[–—]\s*(.+)$/) : null);
        if (m) {
            const left = m[1].trim(), right = m[2].trim();
            if (/\b(?:remaster(?:ed)?|remix|version|edit|mix|live|mono|stereo|acoustic|instrumental|sped up|slowed|nightcore|reverb)\b/i.test(right) && a && !fromBrowser)
                t = left;          // "Song - Remastered 2011"
            else if (!a || fromBrowser || left.toLowerCase().includes(a.toLowerCase()) || a.toLowerCase().includes(left.toLowerCase())) {
                a = left;          // "Artist - Song" (channel name as the artist)
                t = right;
            }
        } else if (fromBrowser) {
            // SoundCloud and the like: "Song by Artist"
            const by = t.match(/^(.+?)\s+by\s+(.+)$/i);
            if (by && (!a || similar(by[2], a))) {
                t = by[1].trim();
                a = by[2].trim();
            }
        }
        t = t.replace(/\s*[\(\[](?:feat|ft|featuring|при уч\.?)\.?\s[^\)\]]*[\)\]]/gi, "").replace(/\s+(?:feat|ft|featuring)\.?\s.*$/i, "").replace(/^["'«“]+|["'»”]+$/g, "").trim();
        return {
            "title": t || String(title || ""),
            "artist": a
        };
    }
    function similar(x, y) {
        const n = s => String(s || "").toLowerCase().replace(/[\s.,'"’`!?¿¡()\[\]{}\-–—:;&/\\*+~_«»]+/g, "");
        const a = n(x), b = n(y);
        return !!a && !!b && (a === b || a.includes(b) || b.includes(a));
    }

    // ---- is this the song? ----
    // Every source answers a search with *something*: a cover, a remix, a song of the same
    // name by someone else — Musixmatch even sends made-up words when it doesn't know the
    // caller. So a found song must have the title (fuzzy, Cyrillic ⇄ Latin), one of the
    // artists when both sides name them, the length within a few seconds when both know
    // it, and the same version (a remix, live, sped up, slowed…) unless the length agrees.
    readonly property var versionWords: /\b(?:remix|rmx|live|acoustic|sped\s*up|speed\s*up|slowed|nightcore|reverb|instrumental|karaoke|cover|edit|mashup|8d)\b|ремикс|кавер|минус/i
    function translit(x) {
        const map = {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya", "і": "i", "ї": "yi", "є": "ye", "ґ": "g"};
        return String(x || "").replace(/[а-яёіїєґ]/g, ch => map[ch] ?? ch);
    }
    // letters and digits only, lower case, Latin; Latin spellings of Russian folded together
    // (y/i, ks/x, j/y, ph/f, w/v, doubled letters) so "Skryptonite" meets "Скриптонит"
    function key(x) {
        let s = translit(String(x || "").toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "").replace(/ё/g, "е"));
        s = s.replace(/&/g, "and").replace(/[^a-z0-9À-ɏͰ-ϿЀ-ӿ぀-ヿ㐀-鿿가-힯]+/g, "");
        return s.replace(/ph/g, "f").replace(/ks/g, "x").replace(/[jy]/g, "i").replace(/w/g, "v").replace(/kh/g, "h").replace(/(.)\1+/g, "$1");
    }
    // a song's name without the parts that differ between releases: (feat. …), - Remastered, (From "…")
    function titleKey(x) {
        return key(String(x || "").replace(/\s*[\(\[][^\)\]]*[\)\]]/g, " ").replace(/\s+[-–—]\s+.*$/, "").replace(/\s+(?:feat|ft)\.?\s.*$/i, "")) || key(x);
    }
    function ratio(a, b) {
        if (!a || !b)
            return 0;
        if (a === b)
            return 1;
        const m = a.length, n = b.length;
        if (Math.abs(m - n) > Math.max(m, n) * 0.5)
            return 0;
        let prev = [];
        for (let j = 0; j <= n; j++)
            prev[j] = j;
        for (let i = 1; i <= m; i++) {
            const cur = [i];
            for (let j = 1; j <= n; j++)
                cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
            prev = cur;
        }
        return 1 - prev[n] / Math.max(m, n);
    }
    function sameName(x, y, need) {
        const a = titleKey(x), b = titleKey(y);
        if (!a || !b)
            return false;
        if (ratio(a, b) >= need)
            return true;
        // one holds the other, nearly all of it (brackets are already gone): "Love" is not "Lovely"
        const short = a.length < b.length ? a : b, long = a.length < b.length ? b : a;
        return short.length >= 6 && long.includes(short) && short.length / long.length >= 0.8;
    }
    function artistsOf(x) {
        return String(x || "").split(/\s*(?:,|;|&|\/|\bx\b|×|\+|\bfeat\.?|\bft\.?|\bfeaturing\b|\band\b|\bи\b)\s*/i).map(key).filter(k => k.length > 0);
    }
    function sameArtist(x, y) {
        const a = artistsOf(x), b = artistsOf(y);
        const whole = key(x), whole2 = key(y);
        if (whole && whole2 && (ratio(whole, whole2) >= 0.75 || whole.includes(whole2) || whole2.includes(whole)))
            return true;
        return a.some(p => b.some(q => ratio(p, q) >= 0.75 || (Math.min(p.length, q.length) >= 4 && (p.includes(q) || q.includes(p)))));
    }
    // cand: {title, artist, duration (s)}; c: what is playing (cleaned); d: its length (s)
    readonly property var tempoWords: /sped\s*up|speed\s*up|slowed|nightcore|daycore|ускор|замедл/i
    // a sped up / slowed version: the original's lyrics fit once their times are stretched
    readonly property bool tempoVersion: tempoWords.test(String(title))
    function matches(cand, c, d) {
        if (!cand || !sameName(cand.title, c.title, 0.8))
            return false;
        const dur = Number(cand.duration) || 0;
        const timed = d > 0 && dur > 0;
        const wantVersion = versionWords.test(String(c.title) + " " + String(title));
        const candVersion = versionWords.test(String(cand.title));
        const stretch = tempoVersion && !candVersion && timed && d / dur > 0.6 && d / dur < 1.5;
        if (timed && Math.abs(dur - d) > 8 && !stretch)
            return false;
        const close = timed && Math.abs(dur - d) <= 3;
        if (c.artist && cand.artist && !sameArtist(cand.artist, c.artist) && !(close && key(cand.title) === key(c.title)))
            return false;
        // the remix is not the original (and back), unless they are the same length
        if (wantVersion !== candVersion && !close && !stretch)
            return false;
        return true;
    }
    // the plain name to try when the first round found nothing: no version, the first artist only
    readonly property var fallback: {
        const c = cleaned;
        const t = String(c.title).replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "").replace(/\s+[-–—]\s+.*$/, "").trim() || c.title;
        const parts = String(c.artist).split(/\s*(?:,|;|&|\/|\sx\s|×|\sfeat\.?\s|\sft\.?\s)\s*/i).filter(x => x);
        const a = parts.length ? parts[0].trim() : c.artist;
        return t === c.title && a === c.artist ? null : {
            "title": t,
            "artist": a
        };
    }

    // NetEase LRC starts with credit lines ("作词 : …"); drop them
    function stripCredits(lrc) {
        return String(lrc || "").split(/\r?\n/).filter(l => {
            if (/^\s*\[\d+:\d+(?:[.:]\d+)?\]\s*[^\[\]]{1,24}\s?[:：]\s?/.test(l) && /作|曲|词|编|制作|混音|录音|Producer|Lyricist|Composer|Written|Composed|Arranged|Lyrics by|Music by/i.test(l))
                return false;
            // Kugou / QQ put "Artist - Title" and "Written by：…" on the first seconds
            if (/^\s*\[00:(?:0\d|1[0-5])[.:]\d+\]\s*(?:.{1,80}\s[-–]\s.{1,80}|(?:written|composed|produced|arranged|lyrics|music)\s+by\s*[:：].*|词\s*[:：].*|曲\s*[:：].*)$/i.test(l))
                return false;
            return true;
        }).join("\n");
    }
    // Kugou sends base64 of UTF-8 bytes. Qt.atob may hand back text already decoded
    // (then it has characters above 0xFF or is not valid UTF-8 as bytes) or one
    // character per byte; only the latter is decoded here.
    function utf8(bin) {
        bin = String(bin || "").replace(/^\ufeff/, "");
        let valid = true;
        for (let k = 0; k < bin.length && valid; k++) {
            const c = bin.charCodeAt(k);
            if (c > 0xff)
                valid = false;
            else if (c >= 0x80) {
                const n = c >= 0xf0 ? 3 : c >= 0xe0 ? 2 : c >= 0xc0 ? 1 : -1;
                if (n < 0)
                    valid = false;
                for (let j = 1; valid && j <= n; j++) {
                    const cc = bin.charCodeAt(k + j);
                    if (!(cc >= 0x80 && cc < 0xc0))
                        valid = false;
                }
                k += Math.max(0, n);
            }
        }
        if (!valid)
            return bin;
        let out = "", i = 0;
        if (bin.charCodeAt(0) === 0xef && bin.charCodeAt(1) === 0xbb && bin.charCodeAt(2) === 0xbf)
            i = 3;
        while (i < bin.length) {
            const c = bin.charCodeAt(i++);
            if (c < 0x80)
                out += String.fromCharCode(c);
            else if (c >= 0xc0 && c < 0xe0)
                out += String.fromCharCode(((c & 0x1f) << 6) | (bin.charCodeAt(i++) & 0x3f));
            else if (c >= 0xe0 && c < 0xf0) {
                const c2 = bin.charCodeAt(i++), c3 = bin.charCodeAt(i++);
                out += String.fromCharCode(((c & 0x0f) << 12) | ((c2 & 0x3f) << 6) | (c3 & 0x3f));
            } else if (c >= 0xf0) {
                const c2 = bin.charCodeAt(i++), c3 = bin.charCodeAt(i++), c4 = bin.charCodeAt(i++);
                const cp = ((c & 0x07) << 18) | ((c2 & 0x3f) << 12) | ((c3 & 0x3f) << 6) | (c4 & 0x3f);
                out += String.fromCodePoint(cp);
            }
        }
        return out;
    }
    function entities(t) {
        return String(t || "").replace(/&#(\d+);/g, (m, n) => String.fromCodePoint(parseInt(n))).replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
    }
    // synced lyrics worth showing: three timed lines with words at least (not a lone
    // "[00:00.00] instrumental, enjoy" or the credits alone)
    function goodLrc(lrc) {
        return /\[\d+:\d+/.test(lrc || "") && parseLrc(stripCredits(lrc)).filter(l => l.text).length >= 3;
    }
    function lrcData(source, lrc, extra) {
        lrc = stripCredits(lrc);
        return Object.assign({
            "source": source
        }, /\[\d+:\d+/.test(lrc) ? {
            "syncedLyrics": lrc
        } : {
            "plainLyrics": lrc
        }, extra || {});
    }

    // ---- local files and the player's own lyrics ----
    readonly property string trackUrl: player && player.metadata ? String(player.metadata["xesam:url"] || "") : ""
    function localCandidates(c) {
        const out = [];
        if (trackUrl.startsWith("file://")) {
            const path = decodeURIComponent(trackUrl.slice(7));
            out.push(path.replace(/\.[^./]+$/, "") + ".lrc");
        }
        const name = (c.artist ? c.artist + " - " : "") + c.title;
        for (const dir of [Config.home + "/.lyrics", Config.home + "/Music/Lyrics", Config.home + "/Music/lyrics"])
            out.push(dir + "/" + name.replace(/[\/]/g, "_") + ".lrc");
        return out;
    }
    FileView {
        id: localReader
        property var cb: null
        printErrors: false
        // callbacks run on the next turn: they may point this reader at the next file
        onLoaded: {
            const f = cb, t = text();
            cb = null;
            if (f)
                Qt.callLater(() => f(t));
        }
        onLoadFailed: {
            const f = cb;
            cb = null;
            if (f)
                Qt.callLater(() => f(null));
        }
    }
    // setting the path loads the file (loaded / loadFailed call cb back)
    function readLocal(path, cb) {
        localReader.cb = cb;
        localReader.path = "";
        localReader.path = path;
    }
    // QQ Music wants a Referer, which XMLHttpRequest may not set: curl does it
    Process {
        id: curl
        property var cb: null
        property bool raw: false
        stdout: StdioCollector {
            onStreamFinished: {
                const f = curl.cb;
                curl.cb = null;
                if (curl.raw)
                    return f ? f(text) : null;
                let body = null;
                try {
                    body = JSON.parse(text);
                } catch (e) {}
                if (f)
                    f(body);
            }
        }
    }
    function curlJson(url, referer, cb) {
        curl.running = false;
        curl.raw = false;
        curl.cb = cb;
        curl.command = ["curl", "-s", "-m", "8", "-A", "Mozilla/5.0", "-e", referer, url];
        curl.running = true;
    }
    // curl with its own headers (Musixmatch wants a cookie); the answer as text
    function curlRaw(args, cb) {
        curl.running = false;
        curl.raw = true;
        curl.cb = cb;
        curl.command = ["curl", "-s", "-m", "8"].concat(args);
        curl.running = true;
    }
    // Kugou: song search → lyric candidates for its hash → base64 LRC
    function kugouLyrics(hash, durMs, cb) {
        http("https://krcs.kugou.com/search?" + query({
            "ver": 1,
            "man": "yes",
            "client": "mobi",
            "keyword": "",
            "duration": durMs || "",
            "hash": hash
        }), (code, body) => {
            const cand = body && body.candidates && body.candidates[0];
            if (!cand)
                return cb(null);
            http("https://lyrics.kugou.com/download?" + query({
                "ver": 1,
                "client": "pc",
                "id": cand.id,
                "accesskey": cand.accesskey,
                "fmt": "lrc",
                "charset": "utf8"
            }), (code2, dl) => cb(dl && dl.content ? root.utf8(Qt.atob(dl.content)) : null));
        });
    }
    function qqLyrics(mid, cb) {
        curlJson("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?" + query({
            "songmid": mid,
            "format": "json",
            "nobase64": 1,
            "g_tk": 5381
        }), "https://y.qq.com/", body => cb(body && body.lyric ? root.entities(body.lyric) : null));
    }

    // ---- source chain, in the order chosen in Settings → Lyrics; then once more with the
    // plain name (no version, the first artist) for the open databases ----
    // A step gets its own `next`/`finish`: a source that never answers is skipped after
    // 10 s (stepWatch), and its late answer is ignored.
    Timer {
        id: stepWatch
        property var fire: null
        interval: 10000
        onTriggered: if (fire)
            fire()
    }
    function fetchNet(key) {
        const d = length;
        const steps = [];
        let plain = null;       // best unsynced text of the right song met on the way
        let stepId = 0;
        const finish = data => {
            if (key !== _pendingKey)
                return;
            stepWatch.stop();
            // the original's lyrics on a sped up / slowed version: their times stretched to it
            if (data && data.syncedLyrics && tempoVersion && data.duration > 0 && d > 0 && Math.abs(data.duration - d) > 3)
                data = Object.assign({}, data, {
                    "scale": d / data.duration
                });
            if (data) {
                store(key, data);
                apply(data);
            } else if (plain) {
                store(key, plain);
                apply(plain);
            } else {
                root._mem[key] = null;   // not found: remember for this session only
                apply(null);
            }
        };
        const run = () => {
            if (key !== _pendingKey)
                return;
            const step = steps.shift();
            if (!step)
                return finish(null);
            const my = ++stepId;
            const next = () => {
                if (my === stepId)
                    run();
            };
            const done = data => {
                if (my === stepId)
                    finish(data);
            };
            stepWatch.fire = next;
            stepWatch.restart();
            step(next, done);
        };
        const keepPlain = data => {
            if (!plain && data && data.plainLyrics && String(data.plainLyrics).trim())
                plain = data;
        };
        const base = "https://lrclib.net/api/";
        // the steps of one source for one name; c = {title, artist}
        const build = (c, again) => {
            const pickLrclib = list => {
                if (!Array.isArray(list))
                    return null;
                const ok = list.filter(r => root.matches({
                        "title": r.trackName || r.name,
                        "artist": r.artistName,
                        "duration": r.duration
                    }, c, d));
                const synced = ok.filter(r => r.syncedLyrics).sort((x, y) => Math.abs((x.duration || 0) - d) - Math.abs((y.duration || 0) - d));
                keepPlain(ok.find(r => r.plainLyrics) ? Object.assign({
                    "source": "lrclib"
                }, ok.find(r => r.plainLyrics)) : null);
                return synced[0] || null;
            };
            const steps = {};
            // .lrc next to the track, or ~/.lyrics/Artist - Title.lrc
            steps.local = (next, done) => {
                const paths = localCandidates(c);
                const tryNext = () => {
                    const path = paths.shift();
                    if (!path)
                        return next();
                    root.readLocal(path, text => {
                        if (text && text.trim()) {
                            const data = root.lrcData("local", text);
                            if (data.syncedLyrics)
                                return done(data);
                            keepPlain(data);
                        }
                        tryNext();
                    });
                };
                tryNext();
            };
            // players that publish lyrics themselves (xesam:asText)
            steps.player = (next, done) => {
                const t = player && player.metadata ? String(player.metadata["xesam:asText"] || "") : "";
                if (t.trim()) {
                    const data = root.lrcData("player", t);
                    if (data.syncedLyrics)
                        return done(data);
                    keepPlain(data);
                }
                next();
            };
            steps.lrclib = [(next, done) => http(base + "get?" + query({
                        "track_name": c.title,
                        "artist_name": c.artist,
                        "album_name": fromBrowser || again ? "" : album,
                        "duration": d > 0 ? Math.round(d) : ""
                    }), (code, body) => {
                    if (code === 0)
                        root._offline = true;
                    // lrclib's own match is by name and length (±2 s); the name is checked again
                    const ok = body && root.matches({
                        "title": body.trackName,
                        "artist": body.artistName,
                        "duration": body.duration
                    }, c, d);
                    if (ok && (body.syncedLyrics || body.instrumental))
                        return done(Object.assign({
                            "source": "lrclib"
                        }, body));
                    if (ok)
                        keepPlain(Object.assign({
                            "source": "lrclib"
                        }, body));
                    next();
                }), (next, done) => http(base + "search?" + query({
                        "track_name": c.title,
                        "artist_name": c.artist
                    }), (code, list) => {
                    const best = pickLrclib(list);
                    best ? done(Object.assign({
                        "source": "lrclib"
                    }, best)) : next();
                }), (next, done) => http(base + "search?" + query({
                        "q": (c.artist + " " + c.title).trim()
                    }), (code, list) => {
                    const best = pickLrclib(list);
                    best ? done(Object.assign({
                        "source": "lrclib"
                    }, best)) : next();
                })];
            // AMLL TTML DB: hand-timed lyrics, found by the Spotify / NetEase track id or the name
            steps.amll = (next, done) => root.amllFind(c, d, (lrc, hit) => {
                    if (root.goodLrc(lrc))
                        done(root.lrcData("AMLL", lrc, {
                            "trackName": hit ? hit.title : ""
                        }));
                    else
                        next();
                });
            steps.netease = (next, done) => http("https://music.163.com/api/cloudsearch/pc?" + query({
                        "s": (c.title + " " + c.artist).trim(),
                        "type": 1,
                        "limit": 10
                    }), (code, body) => {
                    const songs = body && body.result && body.result.songs ? body.result.songs : [];
                    const match = songs.find(x => root.matches({
                            "title": x.name,
                            "artist": (x.ar || []).map(a => a.name).join(", "),
                            "duration": (x.dt || 0) / 1000
                        }, c, d));
                    if (!match)
                        return next();
                    http("https://music.163.com/api/song/lyric?id=" + match.id + "&lv=1", (code2, lyr) => {
                        const lrc = lyr && lyr.lrc ? root.stripCredits(lyr.lrc.lyric) : "";
                        if (root.goodLrc(lrc))
                            done({
                                "source": "NetEase",
                                "syncedLyrics": lrc,
                                "trackName": match.name,
                                "duration": (match.dt || 0) / 1000
                            });
                        else
                            next();
                    });
                });
            steps.kugou = (next, done) => http("http://mobilecdn.kugou.com/api/v3/search/song?" + query({
                        "format": "json",
                        "keyword": (c.artist + " " + c.title).trim(),
                        "page": 1,
                        "pagesize": 10
                    }), (code, body) => {
                    const list = body && body.data && body.data.info ? body.data.info : [];
                    const match = list.find(x => root.matches({
                            "title": x.songname,
                            "artist": x.singername,
                            "duration": x.duration
                        }, c, d));
                    if (!match)
                        return next();
                    root.kugouLyrics(match.hash, d ? Math.round(d * 1000) : (match.duration || 0) * 1000, lrc => {
                        if (root.goodLrc(lrc))
                            done(root.lrcData("Kugou", lrc, {
                                "trackName": match.songname,
                                "duration": match.duration || 0
                            }));
                        else
                            next();
                    });
                });
            steps.qq = (next, done) => http("https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?" + query({
                        "key": (c.artist + " " + c.title).trim(),
                        "format": "json"
                    }), (code, body) => {
                    const list = body && body.data && body.data.song ? body.data.song.itemlist || [] : [];
                    // no length in QQ's quick search: the name and the artist must both agree
                    const match = list.find(x => root.matches({
                            "title": x.name,
                            "artist": x.singer || "?"
                        }, c, d));
                    if (!match)
                        return next();
                    root.qqLyrics(match.mid, lrc => {
                        if (root.goodLrc(lrc))
                            done(root.lrcData("QQ Music", lrc, {
                                "trackName": match.name
                            }));
                        else
                            next();
                    });
                });
            // lrc.cx (LrcApi): a large mirror of the Chinese stores plus Apple Music
            steps.lrccx = (next, done) => http("https://api.lrc.cx/jsonapi?" + query({
                        "title": c.title,
                        "artist": c.artist,
                        "album": fromBrowser || again ? "" : album
                    }), (code, list) => {
                    const match = (Array.isArray(list) ? list : []).find(r => root.goodLrc(r.lrc) && root.matches({
                            "title": r.title,
                            "artist": r.artist || "?",
                            "duration": r.duration || 0
                        }, c, d));
                    match ? done(root.lrcData("lrc.cx", match.lrc, {
                        "trackName": match.title
                    })) : next();
                });
            // Musixmatch: the biggest catalogue; its anonymous token is refused in some
            // countries (the answer then is made-up words — matches() throws them out)
            steps.musixmatch = (next, done) => root.mxmFind(c, d, data => {
                    if (data && data.syncedLyrics)
                        done(data);
                    else {
                        keepPlain(data);
                        next();
                    }
                });
            // lyrics.ovh: plain text only, so it is skipped once some text was met
            steps.ovh = (next, done) => {
                if (plain || !c.artist)
                    return next();
                http("https://api.lyrics.ovh/v1/" + encodeURIComponent(c.artist) + "/" + encodeURIComponent(c.title), (code, body) => {
                    if (body && body.lyrics && body.lyrics.trim())
                        plain = {
                            "source": "lyrics.ovh",
                            "plainLyrics": body.lyrics.trim()
                        };
                    next();
                });
            };
            return steps;
        };
        const first = build(cleaned, false);
        for (const src of sources)
            if (first[src])
                steps.push(...[].concat(first[src]));
        const alt = fallback;
        if (alt) {
            const second = build(alt, true);
            for (const src of sources)
                if (["lrclib", "netease", "lrccx", "kugou"].includes(src))
                    steps.push(...[].concat(second[src]));
        }
        _offline = false;
        run();
    }
    property bool _offline: false

    // ---- Musixmatch (desktop app API) ----
    property string _mxmToken: ""        // "" not asked yet | "none" refused (asked again after 10 min)
    property double _mxmAsked: 0
    function mxmToken(cb) {
        if (_mxmToken && _mxmToken !== "none")
            return cb(_mxmToken);
        if (_mxmToken === "none" && Date.now() - _mxmAsked < 600000)
            return cb("");
        _mxmAsked = Date.now();
        curlRaw(["-H", "cookie: AWSELBCORS=0; AWSELB=0", "https://apic-desktop.musixmatch.com/ws/1.1/token.get?app_id=web-desktop-app-v1.0"], text => {
            let tok = "";
            try {
                tok = JSON.parse(text).message.body.user_token || "";
            } catch (e) {}
            // all zeros: the decoy token — every answer would be made up
            root._mxmToken = tok && !/^0+$/.test(tok) && !/UpgradeOnlyUpgradeOnly/.test(tok) ? tok : "none";
            cb(root._mxmToken === "none" ? "" : root._mxmToken);
        });
    }
    function mxmFind(c, d, cb) {
        mxmToken(tok => {
            if (!tok)
                return cb(null);
            curlRaw(["-H", "cookie: AWSELBCORS=0; AWSELB=0", "https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get?" + query({
                    "format": "json",
                    "namespace": "lyrics_richsynched",
                    "subtitle_format": "lrc",
                    "app_id": "web-desktop-app-v1.0",
                    "q_artist": c.artist,
                    "q_track": c.title,
                    "q_duration": d > 0 ? Math.round(d) : "",
                    "f_subtitle_length": d > 0 ? Math.round(d) : "",
                    "usertoken": tok
                })], text => {
                let calls = null;
                try {
                    calls = JSON.parse(text).message.body.macro_calls;
                } catch (e) {}
                const get = (k, f) => {
                    try {
                        return f(calls[k].message.body);
                    } catch (e) {
                        return null;
                    }
                };
                const track = get("matcher.track.get", b => b.track);
                if (!track || !root.matches({
                        "title": track.track_name,
                        "artist": track.artist_name,
                        "duration": track.track_length
                    }, c, d))
                    return cb(null);
                if (track.instrumental)
                    return cb({
                        "source": "Musixmatch",
                        "instrumental": true
                    });
                const lrc = get("track.subtitles.get", b => b.subtitle_list[0].subtitle.subtitle_body) || "";
                if (root.goodLrc(lrc))
                    return cb(root.lrcData("Musixmatch", lrc, {
                        "trackName": track.track_name,
                        "duration": track.track_length || 0
                    }));
                const txt = get("track.lyrics.get", b => b.lyrics.lyrics_body) || "";
                cb(txt.trim() ? {
                    "source": "Musixmatch",
                    "plainLyrics": txt.replace(/\n*\*{7}[\s\S]*$/, "").trim()
                } : null);
            });
        });
    }

    // ---- AMLL TTML DB (github.com/Steve-xmh/amll-ttml-db) ----
    // its index (~1.6 MB, refreshed weekly into the cache) maps track ids and names to TTML files
    readonly property string amllIndexFile: Config.cacheDir + "/lyrics/amll-index.jsonl"
    property var _amll: null              // [{t: [names], a: [artists], sp: [ids], ncm: [ids], f}]
    property var _amllWait: []
    property bool _amllLoading: false
    readonly property string spotifyId: {
        const u = trackUrl + " " + (player && player.metadata ? String(player.metadata["mpris:trackid"] || "") : "");
        const m = u.match(/(?:open\.spotify\.com\/track\/|spotify[:\/]track[:\/])([A-Za-z0-9]{22})/);
        return m ? m[1] : "";
    }
    FileView {
        id: amllReader
        printErrors: false
        blockLoading: false
        onLoaded: root.amllParsed(text())
        onLoadFailed: root.amllParsed("")
    }
    Process {
        id: amllFetch
        // -z: only when the file there is newer than ours; older than a week → asked again
        command: ["sh", "-c", 'f="$1"; if [ ! -s "$f" ] || [ -n "$(find "$f" -mtime +7 2>/dev/null)" ]; then curl -sf -m 25 -z "$f" -o "$f.part" "$2" && [ -s "$f.part" ] && mv "$f.part" "$f"; rm -f "$f.part"; touch "$f" 2>/dev/null; fi; true', "sh", root.amllIndexFile, "https://raw.githubusercontent.com/Steve-xmh/amll-ttml-db/main/metadata/raw-lyrics-index.jsonl"]
        onExited: {
            amllReader.path = "";
            amllReader.path = root.amllIndexFile;
        }
    }
    function amllParsed(text) {
        const out = [];
        for (const line of String(text || "").split("\n")) {
            if (!line.trim())
                continue;
            try {
                const r = JSON.parse(line), m = {};
                for (const kv of r.metadata || [])
                    m[kv[0]] = kv[1] || [];
                out.push({
                    "t": m.musicName || [],
                    "a": m.artists || [],
                    "sp": m.spotifyId || [],
                    "ncm": m.ncmMusicId || [],
                    "f": r.rawLyricFile
                });
            } catch (e) {}
        }
        _amll = out;
        _amllLoading = false;
        const wait = _amllWait;
        _amllWait = [];
        for (const f of wait)
            f();
    }
    function amllFind(c, d, cb) {
        if (_amll === null) {
            _amllWait.push(() => amllFind(c, d, cb));
            if (!_amllLoading) {
                _amllLoading = true;
                amllFetch.running = true;
            }
            return;
        }
        const sp = spotifyId;
        let hit = sp ? _amll.find(r => r.sp.includes(sp)) : null;
        if (!hit)
            hit = _amll.find(r => r.t.some(t => sameName(t, c.title, 0.9)) && (!c.artist || r.a.some(a => sameArtist(a, c.artist))));
        if (!hit || !hit.f)
            return cb(null, null);
        httpText("https://raw.githubusercontent.com/Steve-xmh/amll-ttml-db/main/raw-lyrics/" + hit.f, (code, text) => cb(code === 200 ? root.ttmlToLrc(text) : null, {
                "title": hit.t[0] || ""
            }));
    }
    // TTML → LRC lines: each <p begin=…> is a line; its words are the spans' text; background
    // vocals, translations and romanisations (ttm:role x-bg / x-translation / x-roman) left out
    function ttmlTime(v) {
        const p = String(v || "").split(":").map(Number);
        return p.length === 3 ? p[0] * 3600 + p[1] * 60 + p[2] : p.length === 2 ? p[0] * 60 + p[1] : p[0] || 0;
    }
    function lrcStamp(t) {
        const m = Math.floor(t / 60), s = t - m * 60;
        return "[" + String(m).padStart(2, "0") + ":" + s.toFixed(2).padStart(5, "0") + "]";
    }
    function dropRoles(xml) {
        let out = "", i = 0;
        const open = /<span\b[^>]*ttm:role="x-(?:bg|translation|roman)"[^>]*>/g;
        let m;
        while ((m = open.exec(xml))) {
            out += xml.slice(i, m.index);
            // skip to the span's own end, nested spans counted
            let depth = 1, j = open.lastIndex;
            const tag = /<\/?span\b[^>]*?(\/?)>/g;
            tag.lastIndex = j;
            let t;
            while (depth > 0 && (t = tag.exec(xml))) {
                if (t[0].startsWith("</"))
                    depth--;
                else if (!t[1])
                    depth++;
                j = tag.lastIndex;
            }
            i = j;
            open.lastIndex = j;
        }
        return out + xml.slice(i);
    }
    function ttmlToLrc(xml) {
        const lines = [];
        const re = /<p\b[^>]*\bbegin="([^"]+)"[^>]*>([\s\S]*?)<\/p>/g;
        let m;
        while ((m = re.exec(String(xml || "")))) {
            const text = entities(dropRoles(m[2]).replace(/<[^>]+>/g, "")).replace(/\s+/g, " ").trim();
            if (text)
                lines.push(lrcStamp(ttmlTime(m[1])) + text);
        }
        return lines.join("\n");
    }

    // ---- manual search from Settings → Lyrics ----
    // Every result says what happened when it is picked (#34): its lyrics are fetched
    // (`picking` = its uid), or it has none (`pickFailed[uid]`) — a click is never silent.
    // A source that never answers no longer holds the list back: what came in 10 s is shown.
    property var results: []
    property bool searching: false
    property int searchGen: 0
    property string picking: ""
    property var pickFailed: ({})
    Timer {
        id: searchWatch
        property var finish: null
        interval: 10000
        onTriggered: if (finish)
            finish()
    }
    Timer {
        id: pickWatch
        property string uid: ""
        interval: 12000
        onTriggered: root.pickDone(uid, false)
    }
    function pickDone(uid, ok) {
        if (!uid || picking !== uid)
            return;
        picking = "";
        pickWatch.stop();
        if (!ok) {
            const f = Object.assign({}, pickFailed);
            f[uid] = true;
            pickFailed = f;
        }
    }
    function search(text) {
        text = String(text || "").trim();
        if (!text)
            return;
        const gen = ++searchGen;
        searching = true;
        results = [];
        picking = "";
        pickFailed = ({});
        let pending = 5;
        const out = [];
        const finish = () => {
            if (gen !== searchGen || !searching)
                return;
            searching = false;
            searchWatch.stop();
            results = out.map((r, i) => Object.assign({
                    "uid": gen + ":" + i
                }, r));
        };
        const done = () => {
            if (--pending === 0)
                finish();
        };
        searchWatch.finish = finish;
        searchWatch.restart();
        http("https://lrclib.net/api/search?" + query({
            "q": text
        }), (code, list) => {
            for (const r of (Array.isArray(list) ? list : []).slice(0, 12))
                out.push({
                    "source": "lrclib",
                    "title": r.trackName,
                    "artist": r.artistName,
                    "duration": r.duration || 0,
                    "synced": !!r.syncedLyrics,
                    "data": r
                });
            done();
        });
        http("https://api.lrc.cx/jsonapi?" + query({
            "title": text
        }), (code, list) => {
            for (const r of (Array.isArray(list) ? list : []).filter(r => r.lrc).slice(0, 6))
                out.push({
                    "source": "lrc.cx",
                    "title": r.title,
                    "artist": r.artist,
                    "duration": r.duration || 0,
                    "synced": /\[\d+:\d+/.test(r.lrc),
                    "data": root.lrcData("lrc.cx", r.lrc)
                });
            done();
        });
        http("http://mobilecdn.kugou.com/api/v3/search/song?" + query({
            "format": "json",
            "keyword": text,
            "page": 1,
            "pagesize": 8
        }), (code, body) => {
            for (const x of (body && body.data && body.data.info ? body.data.info : []))
                out.push({
                    "source": "Kugou",
                    "title": x.songname,
                    "artist": x.singername,
                    "duration": x.duration || 0,
                    "synced": true,
                    "hash": x.hash
                });
            done();
        });
        http("https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?" + query({
            "key": text,
            "format": "json"
        }), (code, body) => {
            for (const x of (body && body.data && body.data.song ? body.data.song.itemlist || [] : []))
                out.push({
                    "source": "QQ Music",
                    "title": x.name,
                    "artist": x.singer,
                    "duration": 0,
                    "synced": true,
                    "mid": x.mid
                });
            done();
        });
        http("https://music.163.com/api/cloudsearch/pc?" + query({
            "s": text,
            "type": 1,
            "limit": 8
        }), (code, body) => {
            for (const x of (body && body.result && body.result.songs ? body.result.songs : []))
                out.push({
                    "source": "NetEase",
                    "title": x.name,
                    "artist": (x.ar || []).map(a => a.name).join(", "),
                    "duration": (x.dt || 0) / 1000,
                    "synced": true,
                    "id": x.id
                });
            done();
        });
    }
    // use a search result for the current track (remembered in the cache)
    function pick(r) {
        const key = trackKey;
        if (!title || !r || picking !== "")
            return;
        const uid = r.uid || "";
        if (r.data) {
            const data = Object.assign({
                "source": "lrclib"
            }, r.data);
            store(key, data);
            apply(data);
            return;
        }
        picking = uid;
        pickWatch.uid = uid;
        pickWatch.restart();
        const use = (source, lrc) => {
            if (key !== trackKey)
                return pickDone(uid, true);
            if (!lrc)
                return pickDone(uid, false);
            const data = root.lrcData(source, lrc);
            store(key, data);
            apply(data);
            pickDone(uid, true);
        };
        if (r.hash)
            return kugouLyrics(r.hash, (r.duration || 0) * 1000, lrc => use("Kugou", lrc));
        if (r.mid)
            return qqLyrics(r.mid, lrc => use("QQ Music", lrc));
        http("https://music.163.com/api/song/lyric?id=" + r.id + "&lv=1", (code, lyr) => {
            const lrc = lyr && lyr.lrc ? root.stripCredits(lyr.lrc.lyric) : "";
            if (!lrc || key !== trackKey)
                return pickDone(uid, key !== trackKey);
            const data = /\[\d+:\d+/.test(lrc) ? {
                "source": "NetEase",
                "syncedLyrics": lrc
            } : {
                "source": "NetEase",
                "plainLyrics": lrc
            };
            store(key, data);
            apply(data);
            pickDone(uid, true);
        });
    }
}
