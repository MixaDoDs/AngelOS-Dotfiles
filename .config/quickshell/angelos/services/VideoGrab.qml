pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Video for Discord and from a link (scripts/videograb.py), with no window of its own:
//  · shrink(): a video (a replay clip, a recording, anything on the shelf) cut to Quick Look's
//    marks and squeezed under Discord's limit (Settings → Screenshots and recording, 20 MB) —
//    beside it as «<name> (Discord).mp4», onto the shelf and into the clipboard as a file;
//  · edit(): for editing — extras/mediafix (the video as it is, PCM sound) into ~/Videos/MediaFix;
//    wav(): the sound alone, PCM, beside it; estimate(): what the squeeze would make (`guess`);
//  · grab(): one link through yt-dlp (the clipboard's ⇩, `angelos grab <url>`) into ~/Downloads.
// How far it is goes into services/Downloads (the Halo's capsule), a failure into a notification
// (a newer yt-dlp offered when it may help). One job at a time; during a game (Shell.gaming)
// squeezing waits for its end: the game's FPS first.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/videograb.py"
    readonly property real limitMb: Config.capture.discordMb > 0 ? Config.capture.discordMb : 20
    readonly property var videoRe: /\.(mp4|mkv|webm|mov|m4v|avi|flv|ts|ogv)$/i
    property var queue: []          // [{kind: shrink|grab|update, argv, src}]
    property var job: null          // the one running
    property var held: []           // the shrinks waiting for the game to end
    property string error: ""       // the last failure's words
    property var guess: null        // estimate()'s answer: {path, fits, size, height, mbit} or {fits: false, max}
    readonly property bool busy: job !== null

    function isVideo(path) {
        return videoRe.test(String(path || ""));
    }
    // the clipboard's ⇩ only on the sites people take a clip from (`angelos grab` takes any link)
    readonly property var siteRe: /^https?:\/\/([^/]*\.)?(youtube\.com|youtu\.be|twitch\.tv|kick\.com|vk\.com|vkvideo\.ru|rutube\.ru|dzen\.ru|ok\.ru|tiktok\.com|instagram\.com|x\.com|twitter\.com|reddit\.com|redd\.it|vimeo\.com|coub\.com|bilibili\.com|streamable\.com|medal\.tv|dailymotion\.com|t\.me)\//i
    function grabbable(url) {
        return siteRe.test(String(url || ""));
    }
    // start, end: seconds (0 = from the start / to the end)
    function cut(start, end) {
        return (start > 0 ? ["--start", String(start)] : []).concat(end > 0 ? ["--end", String(end)] : []);
    }
    function shrink(path, start, end) {
        if (!path)
            return;
        const j = {
            "kind": "shrink",
            "src": path,
            "argv": ["shrink", path, "--mb", String(limitMb)].concat(cut(start, end))
        };
        if (Shell.gaming) {
            held = held.concat([j]);
            tell(I18n.t("Сожму после игры", "Squeezing it after the game"), Shelf.base(path) + I18n.t(" — сейчас кодирование съело бы FPS", ": encoding now would eat the game's FPS"));
            return;
        }
        add(j);
    }
    // files into a format of scripts/videograb.py formats (services/Convert's ring); heavy: video
    // or sound encoding, held while a game runs (pictures go at once)
    function convert(fmt, files, heavy) {
        if (!files || !files.length)
            return;
        const j = {
            "kind": "convert",
            "src": files[0],
            "argv": ["convert", fmt].concat(files)
        };
        if (heavy && Shell.gaming) {
            held = held.concat([j]);
            tell(I18n.t("Сконвертирую после игры", "Converting after the game"), I18n.t("Файлов: ", "Files: ") + files.length);
            return;
        }
        add(j);
    }
    // no encoding (a copy, the sound to PCM): not held for a game
    function edit(path, start, end) {
        if (path)
            add({
                "kind": "edit",
                "src": path,
                "argv": ["edit", path].concat(cut(start, end))
            });
    }
    function wav(path, start, end) {
        if (path)
            add({
                "kind": "wav",
                "src": path,
                "argv": ["wav", path].concat(cut(start, end))
            });
    }
    function estimate(path, start, end) {
        guess = null;
        guesser.running = false;
        if (!path)
            return;
        guesser.path = path;
        guesser.command = ["python3", script, "estimate", path, "--mb", String(limitMb)].concat(cut(start, end));
        guesser.running = true;
    }
    Process {
        id: guesser
        property string path
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text.trim().split("\n").pop());
                    root.guess = j.ev === "estimate" ? Object.assign({
                        "path": guesser.path
                    }, j) : null;
                } catch (e) {
                    root.guess = null;
                }
            }
        }
    }
    function grab(url, audio) {
        url = String(url || "").trim();
        if (!/^https?:\/\//i.test(url))
            return;
        add({
            "kind": "grab",
            "src": url,
            "argv": ["grab", url, "--dir", Config.home + "/Downloads"].concat(audio ? ["--audio"] : [])
        });
    }
    function updateTool() {
        add({
            "kind": "update",
            "src": "yt-dlp",
            "argv": ["update"]
        });
    }
    function add(j) {
        queue = queue.concat([j]);
        next();
    }
    function next() {
        if (job || !queue.length)
            return;
        job = queue[0];
        queue = queue.slice(1);
        error = "";
        runner.command = ["python3", script].concat(job.argv);
        runner.running = true;
    }
    Connections {
        target: Shell
        function onGamingChanged() {
            if (Shell.gaming || !root.held.length)
                return;
            const h = root.held;
            root.held = [];
            for (const j of h)
                root.add(j);
        }
    }

    function tell(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "video-x-generic", summary, body]);
    }
    function failed(text, offerUpdate) {
        error = text;
        const k = job ? job.kind : "";
        const what = k === "grab" ? I18n.t("Видео не скачалось", "The video did not download") : k === "update" ? I18n.t("yt-dlp не обновился", "yt-dlp did not update") : k === "edit" ? I18n.t("Видео для монтажа не вышло", "The video for editing failed") : k === "wav" ? I18n.t("Звук не сохранился", "The sound was not saved") : k === "convert" ? I18n.t("Не всё сконвертировалось", "Not everything was converted") : I18n.t("Видео не сжалось", "The video was not squeezed");
        if (offerUpdate && !asker.running) {
            asker.command = ["notify-send", "-a", "angelOS", "-i", "dialog-warning", "--wait", "-A", "update=" + I18n.t("Обновить систему и yt-dlp", "Update the system and yt-dlp"), what, text.slice(-400)];
            asker.running = true;
        } else
            tell(what, text.slice(-400));
    }
    Process {
        id: asker
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "update")
                root.updateTool()
        }
    }

    Process {
        id: runner
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru",
                "VIDEOGRAB_MB": String(root.limitMb)
            })
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.ev === "progress")
                    Downloads.told = [{
                            "file": ev.file,
                            "received": ev.got,
                            "total": ev.total
                        }];
                else if (ev.ev === "done") {
                    Downloads.told = [];
                    if (ev.path) {
                        Downloads.done(Shelf.base(ev.path), ev.path);
                        // ready to paste into Discord as a file
                        const it = Shelf.items.find(i => i.path === ev.path);
                        if (it && root.job && root.job.kind === "shrink")
                            Shelf.copy(it.id);
                    } else if (ev.version)
                        root.tell(I18n.t("yt-dlp обновлён", "yt-dlp updated"), ev.version);
                } else if (ev.ev === "error")
                    root.failed(String(ev.text || ""), !!ev.update);
            }
        }
        onExited: {
            Downloads.told = [];
            root.job = null;
            root.next();
        }
    }
}
