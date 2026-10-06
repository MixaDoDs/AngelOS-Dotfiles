pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Files for the searches (Start, the launcher, Spotlight): by name and by type, through fd in
// the home folder (hidden folders and .gitignored ones are skipped, as fd does). "sex" finds
// every file and folder with it in the name; ".jpeg" every JPEG (.jpg too); "sex .jpeg" both;
// a kind with a dot: ".картинки"/".images", ".видео"/".video", ".музыка"/".music",
// ".документы"/".docs", ".архивы"/".archives". The newest come first.
// fd runs a moment after typing stops; until it answers, the last answer narrowed to the new
// text is shown, so the section doesn't blink while typing.
// Rows: {path, name, dir, ext, kind, isDir, mtime, size, s} — s is 0…1 like StartApps.searchAll.
// Settings: launcher.files (search at all), launcher.filePreview (thumbnails and the preview).
Singleton {
    id: root

    readonly property bool enabled: Config.launcher.files !== false
    readonly property bool preview: Config.launcher.filePreview !== false

    readonly property var kinds: ({
            "image": ["jpg", "jpeg", "jpe", "jfif", "png", "gif", "webp", "bmp", "tif", "tiff", "svg", "avif", "heic", "heif", "ico", "jxl"],
            "video": ["mp4", "mkv", "webm", "avi", "mov", "m4v", "wmv", "flv", "mpg", "mpeg", "3gp", "ogv"],
            "audio": ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "wma", "mid", "midi"],
            "pdf": ["pdf"],
            "doc": ["txt", "md", "doc", "docx", "odt", "rtf", "xls", "xlsx", "ods", "ppt", "pptx", "odp", "csv", "epub", "djvu", "fb2"],
            "archive": ["zip", "rar", "7z", "tar", "gz", "xz", "zst", "bz2", "tgz", "iso", "deb", "rpm", "appimage"],
            "code": ["js", "ts", "py", "qml", "c", "h", "cpp", "hpp", "rs", "go", "sh", "fish", "json", "toml", "yaml", "yml", "kdl", "lua", "java", "html", "css", "conf", "ini"]
        })
    // ".kind" words → the extensions of that kind
    readonly property var kindWords: ({
            "картинки": "image",
            "картинка": "image",
            "фото": "image",
            "изображения": "image",
            "images": "image",
            "image": "image",
            "pictures": "image",
            "photos": "image",
            "видео": "video",
            "video": "video",
            "videos": "video",
            "музыка": "audio",
            "аудио": "audio",
            "music": "audio",
            "audio": "audio",
            "документы": "doc",
            "docs": "doc",
            "documents": "doc",
            "архивы": "archive",
            "archives": "archive"
        })
    // one type, several spellings
    readonly property var aliases: [["jpg", "jpeg", "jpe", "jfif"], ["tif", "tiff"], ["htm", "html"], ["yml", "yaml"], ["mpg", "mpeg"], ["md", "markdown"], ["heic", "heif"], ["mid", "midi"]]

    function kindOf(ext, isDir) {
        if (isDir)
            return "folder";
        for (const k in kinds)
            if (kinds[k].includes(ext))
                return k;
        return "file";
    }
    // "sex .jpeg" → {name: "sex", exts: ["jpeg", "jpg", "jpe", "jfif"]}; null = not a file search
    function parse(text) {
        const words = String(text || "").trim().split(/\s+/).filter(w => w !== "");
        let exts = [];
        const name = [];
        for (const w of words) {
            const m = /^\.([\p{L}\p{N}_+-]{1,16})$/u.exec(w);
            if (!m) {
                name.push(w);
                continue;
            }
            const e = m[1].toLowerCase();
            if (kindWords[e])
                exts = exts.concat(kinds[kindWords[e]]);
            else
                exts = exts.concat(aliases.find(a => a.includes(e)) || [e]);
        }
        const n = name.join(" ");
        // one letter finds half the disk; a type alone is fine
        if (exts.length === 0 && n.length < 2)
            return null;
        return {
            "name": n,
            "exts": Array.from(new Set(exts))
        };
    }
    function same(a, b) {
        return !!a && !!b && a.name === b.name && a.exts.join() === b.exts.join();
    }

    // ---- asking fd ----
    property var asked: null      // what we want answered
    property var answered: null   // what `hits` answer
    property var hits: []
    readonly property bool busy: proc.running || debounce.running

    function want(text) {
        const p = enabled ? parse(text) : null;
        if (!p) {
            asked = null;
            return;
        }
        if (same(p, asked))
            return;
        asked = p;
        debounce.restart();
    }
    Timer {
        id: debounce
        interval: 160
        onTriggered: root.run()
    }
    function run() {
        if (!asked || same(asked, answered))
            return;
        if (proc.running) {
            proc.running = false;     // the old question is dropped; onExited asks the new one
            return;
        }
        const p = asked;
        const args = ["--absolute-path", "--color", "never", "-i", "-F", "--max-results", "4000", "--exclude", "node_modules", "--exclude", "__pycache__", "--exclude", "**/drive_c/windows"];
        for (const e of p.exts)
            args.push("-e", e);
        args.push("--", p.name, Config.home);
        proc.question = p;
        // newest first; a name with a newline in it is lost (stat prints one per line)
        proc.command = ["sh", "-c", "fd -0 \"$@\" | xargs -0 -r stat -L --printf '%Y\\t%s\\t%F\\t%n\\n' 2>/dev/null | sort -rn | head -n 400", "sh"].concat(args);
        proc.running = true;
    }
    Process {
        id: proc
        property var question: null
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 4 || !f[3].startsWith("/"))
                        continue;
                    const path = f.slice(3).join("\t");
                    const isDir = f[2] === "directory";
                    const name = path.slice(path.lastIndexOf("/") + 1);
                    const dot = name.lastIndexOf(".");
                    const ext = !isDir && dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
                    out.push({
                        "path": path,
                        "name": name,
                        "dir": path.slice(0, path.lastIndexOf("/")) || "/",
                        "ext": ext,
                        "kind": root.kindOf(ext, isDir),
                        "isDir": isDir,
                        "mtime": Number(f[0]),
                        "size": Number(f[1])
                    });
                }
                root.hits = out;
                root.answered = proc.question;
            }
        }
        onExited: if (root.asked && !root.same(root.asked, root.answered))
            Qt.callLater(root.run)
    }

    // ---- what the searches show ----
    // the hits for `text` ranked: the name exactly, from the start, inside; newer first among
    // equals. Asks fd when the text changed (later, not inside the caller's binding)
    function rows(text, limit) {
        const p = enabled ? parse(text) : null;
        Qt.callLater(() => root.want(text));
        if (!p)
            return [];
        const q = p.name.toLowerCase();
        const now = Date.now() / 1000;
        const out = [];
        for (const h of hits) {
            const n = h.name.toLowerCase();
            const stem = h.isDir || !h.ext ? n : n.slice(0, n.length - h.ext.length - 1);
            if (p.exts.length && !p.exts.includes(h.ext))
                continue;
            const at = q ? n.indexOf(q) : 0;
            if (at < 0)
                continue;
            // a type alone: only the newest order; the files rank under good app matches
            const base = !q ? 0.5 : stem === q ? 0.72 : at === 0 ? 0.6 : 0.42;
            const fresh = Math.max(0, 0.06 - Math.max(0, now - h.mtime) / 86400 / 365 * 0.06);
            out.push(Object.assign({
                "s": base + fresh
            }, h));
        }
        out.sort((a, b) => b.s - a.s || b.mtime - a.mtime);
        return out.slice(0, limit || 30);
    }

    // ---- acting on one ----
    function open(h) {
        Achievements.note("file.open", h.kind || "");
        Shell.openPath(h.path);
    }
    // the file manager with the file picked (Nautilus, Dolphin… via FileManager1), else its folder
    function reveal(h) {
        Shell.exec(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems \"['$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"", "sh", uri(h.path).replace(/'/g, "%27"), h.dir]);
    }
    // copy the path
    function copyPath(h) {
        Quickshell.execDetached(["wl-copy", "--", h.path]);
    }

    // ---- looks ----
    function uri(path) {
        // as GLib writes it (the thumbnail cache's key): # and ? escaped too
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }
    // the pictures to try for a thumbnail, best first: the freedesktop cache (Nautilus filled
    // it), then the picture itself (images only)
    function thumbs(h) {
        if (!h || h.isDir)
            return [];
        const key = Qt.md5(uri(h.path));
        const cache = Config.home + "/.cache/thumbnails/";
        const out = ["file://" + cache + "large/" + key + ".png", "file://" + cache + "normal/" + key + ".png"];
        if (h.kind === "image")
            out.push(uri(h.path));
        return out;
    }
    function previewable(h) {
        return !!h && preview && (h.kind === "image" || h.kind === "video" || h.kind === "pdf");
    }
    function pixelIcon(h) {
        return ({
                "folder": "folder",
                "image": "image",
                "video": "camera",
                "audio": "music",
                "pdf": "document",
                "doc": "document",
                "archive": "package",
                "code": "terminal"
            })[h.kind] || "document";
    }
    function macIcon(h) {
        return ({
                "folder": "folder",
                "image": "image",
                "video": "play",
                "audio": "music",
                "pdf": "file-text",
                "doc": "file-text",
                "archive": "layers",
                "code": "terminal"
            })[h.kind] || "file";
    }
    function sizeText(n) {
        const u = I18n.english ? ["B", "KB", "MB", "GB", "TB"] : ["Б", "КБ", "МБ", "ГБ", "ТБ"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) {
            n /= 1024;
            i++;
        }
        return (i === 0 ? n : n.toFixed(n < 10 ? 1 : 0)) + " " + u[i];
    }
    // "~/Pictures/2024" — the folder, short
    function where(h) {
        const d = h.dir;
        return d === Config.home ? "~" : d.startsWith(Config.home + "/") ? "~" + d.slice(Config.home.length) : d;
    }
    function dateText(h) {
        return new Date(h.mtime * 1000).toLocaleString(Qt.locale(I18n.english ? "en_US" : "ru_RU"), "d MMM yyyy, HH:mm");
    }
}
