pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The Halo's shelf (Нимб → «Полка»): files, folders, pictures, links and bits of text dropped on
// the Halo wait there to be dragged out somewhere else (Yoink on a Mac). Files are kept as
// links to where they lie (a moved or deleted one shows as missing); a picture dragged from the
// browser is downloaded into ~/.local/state/angelos/shelf/. Starred ones (fav) stay after being
// dragged out; a starred folder takes files dropped on it (a copy). Kept in shelf.json.
Singleton {
    id: root

    // [{id, kind: file|folder|image|link|text, path, url, text, name, added (ms), fav, missing,
    //   note (a text written by hand)}]
    property var items: []
    property bool loaded: false
    readonly property var loose: items.filter(i => !i.fav)
    readonly property var favs: items.filter(i => i.fav)
    readonly property int count: loose.length
    readonly property string dir: Config.stateDir + "/shelf"

    function set(list) {
        items = list;
        store.write(JSON.stringify(list));
    }
    // the same thing: a text by its words, a link or a downloaded picture by its address, a file
    // or a folder by its path (a dropped path is "file" until check() finds it is a folder)
    function same(a, b) {
        if (b.kind === "text")
            return a.kind === "text" && a.text === b.text;
        if (b.url)
            return a.url === b.url;
        return !!b.path && a.path === b.path;
    }
    function find(id) {
        return items.find(i => i.id === id) || null;
    }
    function base(p) {
        return String(p).replace(/\/+$/, "").split("/").pop() || p;
    }
    function pathOf(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\/[^/]*/, ""));
    }
    function shortUrl(url) {
        const s = String(url).replace(/^[a-z]+:\/\//i, "").replace(/^www\./, "").replace(/[?#].*$/, "").replace(/\/$/, "");
        return s.length > 40 ? s.slice(0, 39) + "…" : s;
    }
    readonly property var imageExt: /\.(png|jpe?g|gif|webp|avif)([?#]|$)/i

    // a new entry on top; one already there (the same path, url or text) moves up instead
    function put(entry) {
        const same = i => root.same(i, entry);
        const old = items.find(same);
        const it = old ? Object.assign({}, old, {
            "added": Date.now()
        }) : Object.assign({
            "id": Date.now() + "-" + Math.floor(Math.random() * 1e6),
            "path": "",
            "url": "",
            "text": "",
            "name": "",
            "added": Date.now(),
            "fav": false,
            "missing": false
        }, entry);
        set([it].concat(items.filter(i => !same(i))));
        return it;
    }

    // what came from a drop: file:// urls (files or folders), http(s) ones (pictures are
    // downloaded, the rest kept as links), or only text
    // imgSrc: the picture's own address from the drag's <img> (Shell's drop reads the HTML): a
    // picture inside a link drags the link's address as its URL — the picture is what is meant
    function addDrop(urls, text, isImage, imgSrc) {
        let list = (urls || []).map(u => String(u).trim()).filter(u => u !== "");
        const src = String(imgSrc || "").trim();
        if (src && !/^file:/i.test(src)) {
            fetchImage(src, list.find(u => /^https?:/i.test(u) && u !== src) || "");
            list = list.filter(u => /^file:/i.test(u));
            if (!list.length)
                return;
        }
        let files = false;
        for (const u of list) {
            if (/^file:/i.test(u)) {
                const p = pathOf(u);
                put({
                    "kind": "file",
                    "path": p,
                    "name": base(p)
                });
                files = true;
            } else if (/^https?:/i.test(u)) {
                if (isImage || imageExt.test(u))
                    fetchImage(u, "");
                else
                    put({
                        "kind": "link",
                        "url": u,
                        "name": shortUrl(u)
                    });
            }
        }
        if (!list.length && String(text || "").trim() !== "")
            addText(text);
        if (files)
            check();
    }
    // the dragged picture's own address in the drag's HTML: the biggest of its srcset, else its
    // src (a picture inside a link drags the link's address as the URL); only an absolute one
    function imgSrc(html) {
        const tag = (String(html || "").match(/<img\b[^>]*>/i) || [""])[0];
        const attr = n => {
            const m = tag.match(new RegExp("\\s" + n + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", "i"));
            return m ? (m[1] || m[2] || m[3] || "") : "";
        };
        const unent = t => t.replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
        let best = "", width = 0;
        for (const part of unent(attr("srcset")).split(/,\s+/)) {
            const [u, d] = part.trim().split(/\s+/);
            const w = parseFloat(d) || 1;
            if (u && w > width) {
                best = u;
                width = w;
            }
        }
        const src = best || unent(attr("src"));
        return /^(https?:|data:image\/|blob:)/i.test(src) ? src : "";
    }
    // a picture handed over as bytes (a browser's drag): written out by shelf-fetch.py as a data:
    // address, under the name it came with; src = where it came from, kept as its link
    function addBytes(buffer, name, src) {
        const it = put({
            "kind": "image",
            "url": /^https?:/i.test(src || "") ? src : "",
            "name": name || I18n.t("картинка", "picture"),
            "pending": true
        });
        const out = (code, text) => {
            const path = text.trim().split("\n").pop();
            set(items.map(i => i.id !== it.id ? i : code === 0 && path ? Object.assign({}, i, {
                    "path": path,
                    "name": base(path).replace(/^\d+-/, ""),
                    "pending": false
                }) : Object.assign({}, i, {
                    "kind": i.url ? "link" : "text",
                    "text": i.url ? "" : I18n.t("Картинка не скачалась", "The picture didn't come"),
                    "pending": false,
                    "failed": true
                })));
        };
        run(["python3", Quickshell.shellDir + "/scripts/shelf-fetch.py", dir, "", "--name", String(name || "").replace(/\.[^.]*$/, "")], out, "data:application/octet-stream;base64," + b64(buffer));
    }
    // ArrayBuffer → base64 (Qt.btoa takes text, not bytes)
    function b64(buffer) {
        const a = new Uint8Array(buffer), abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const out = [];
        let i = 0;
        for (; i + 2 < a.length; i += 3) {
            const n = a[i] << 16 | a[i + 1] << 8 | a[i + 2];
            out.push(abc[n >> 18 & 63] + abc[n >> 12 & 63] + abc[n >> 6 & 63] + abc[n & 63]);
        }
        if (i < a.length) {
            const n = a[i] << 16 | (i + 1 < a.length ? a[i + 1] << 8 : 0);
            out.push(abc[n >> 18 & 63] + abc[n >> 12 & 63] + (i + 1 < a.length ? abc[n >> 6 & 63] : "=") + "=");
        }
        return out.join("");
    }
    // note: written by hand (the shelf's ＋, the buttons page's field), not dropped — it stays
    // when dragged out, as a note does, until it is ticked off
    function addText(text, note) {
        const t = String(text || "").trim();
        if (t === "")
            return null;
        return put(Object.assign({
            "kind": "text",
            "text": t,
            "name": t.split("\n")[0].slice(0, 60)
        }, note ? {
            "note": true
        } : {}));
    }
    // an empty note to be written at once (the shelf's ＋); left empty, it goes (setText)
    function newNote() {
        const it = {
            "id": Date.now() + "-" + Math.floor(Math.random() * 1e6),
            "kind": "text",
            "path": "",
            "url": "",
            "text": "",
            "name": "",
            "added": Date.now(),
            "fav": false,
            "missing": false,
            "note": true
        };
        set([it].concat(items.filter(i => !(i.kind === "text" && String(i.text).trim() === ""))));
        return it;
    }
    // a text's words changed in the note view; "" with drop: gone
    function setText(id, text, drop) {
        const t = String(text || "");
        if (drop && t.trim() === "") {
            remove(id);
            return;
        }
        set(items.map(i => i.id === id ? Object.assign({}, i, {
                    "text": t,
                    "name": t.trim().split("\n")[0].slice(0, 60)
                }) : i));
    }

    function remove(id) {
        set(items.filter(i => i.id !== id));
    }
    function setFav(id, on) {
        set(items.map(i => i.id === id ? Object.assign({}, i, {
                    "fav": !!on
                }) : i));
    }
    // dragged out somewhere: gone from the shelf unless starred or a note written by hand
    function taken(id) {
        const it = find(id);
        if (it && !it.fav && !it.note)
            remove(id);
    }

    function uri(it) {
        if (!it)
            return "";
        return it.kind === "link" ? it.url : it.kind === "text" ? "" : "file://" + encodeURI(it.path);
    }
    function copy(id) {
        const it = find(id);
        if (!it)
            return;
        if (it.kind === "link" || it.kind === "text")
            Quickshell.execDetached(["wl-copy", "--", it.kind === "link" ? it.url : it.text]);
        else
            Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", uri(it)]);
    }
    function share(id) {
        const it = find(id);
        if (!it)
            return;
        if (it.kind === "link" || it.kind === "text")
            QuickShare.share([], it.kind === "link" ? it.url : it.text);
        else
            QuickShare.share([it.path], "");
    }
    function look(id) {
        const it = find(id);
        if (it && it.path)
            QuickLook.show(it.path, false);
    }
    function open(id) {
        const it = find(id);
        if (it && (it.path || it.url))
            Quickshell.execDetached(["xdg-open", it.kind === "link" ? it.url : it.path]);
    }
    // the file manager with it selected (as scripts/capture_save.py does), else its folder
    function showInFolder(id) {
        const it = find(id);
        if (!it || !it.path)
            return;
        Quickshell.execDetached(["sh", "-c", 'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "[\'$1\']" "" >/dev/null 2>&1 || xdg-open "$(dirname "$2")"', "sh", uri(it).replace(/'/g, "%27"), it.path]);
    }

    // files dropped on a starred folder: copied in, a name already there gets « (2)»
    function intoFolder(folderId, urls) {
        const f = find(folderId);
        const paths = (urls || []).filter(u => /^file:/i.test(String(u))).map(pathOf);
        if (!f || f.kind !== "folder" || !paths.length)
            return;
        run(["sh", "-c", 'd="$1"; shift; for s; do b=$(basename "$s"); case "$b" in ?*.*) n="${b%.*}"; e=".${b##*.}";; *) n="$b"; e="";; esac; t="$d/$b"; i=2; while [ -e "$t" ]; do t="$d/$n ($i)$e"; i=$((i+1)); done; cp -rn -- "$s" "$t"; done', "sh", f.path].concat(paths), () => Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Скопировано в ", "Copied to ") + f.name, paths.map(base).join(", ")]));
    }

    // a picture from the browser: on the shelf at once (a spinner while it comes), then the
    // file scripts/shelf-fetch.py made of it — a browser's headers, data: written out, the type
    // from the bytes. Not to be had (refused, blob:, not a picture): kept as its link, marked.
    function fetchImage(src, referer) {
        const shown = /^data:/i.test(src) ? I18n.t("картинка", "picture") : shortUrl(src);
        const it = put({
            "kind": "image",
            "url": /^data:/i.test(src) ? "" : src,
            "name": shown,
            "pending": true
        });
        run(["python3", Quickshell.shellDir + "/scripts/shelf-fetch.py", dir].concat(referer ? [referer] : []), (code, out) => {
            const path = out.trim().split("\n").pop();
            set(items.map(i => i.id !== it.id ? i : code === 0 && path ? Object.assign({}, i, {
                    "path": path,
                    "name": base(path).replace(/^\d+-/, ""),
                    "pending": false
                }) : Object.assign({}, i, {
                    "kind": i.url ? "link" : "text",
                    "text": i.url ? "" : I18n.t("Картинка не скачалась", "The picture didn't come"),
                    "pending": false,
                    "failed": true
                })));
        }, src);
    }

    // missing (moved, deleted) and file or folder, every path in one process
    function check() {
        const list = items.filter(i => i.path);
        if (!list.length)
            return;
        run(["sh", "-c", 'for p; do if [ -d "$p" ]; then echo d; elif [ -e "$p" ]; then echo f; else echo -; fi; done', "sh"].concat(list.map(i => i.path)), (code, out) => {
            const got = {};
            out.split("\n").forEach((s, n) => {
                if (n < list.length)
                    got[list[n].id] = s;
            });
            let changed = false;
            const next = items.map(i => {
                const s = got[i.id];
                if (s === undefined)
                    return i;
                const kind = i.kind === "file" && s === "d" ? "folder" : i.kind === "folder" && s === "f" ? "file" : i.kind;
                const missing = s === "-";
                if (kind === i.kind && missing === !!i.missing)
                    return i;
                changed = true;
                return Object.assign({}, i, {
                    "kind": kind,
                    "missing": missing
                });
            });
            if (changed)
                set(next);
        });
    }

    // the shell jobs, one after another: [argv, done(code, stdout)]
    property var queue: []
    function run(argv, done, input) {
        queue = queue.concat([[argv, done || null, input === undefined ? null : String(input)]]);
        if (!job.running)
            next();
    }
    function next() {
        if (!queue.length)
            return;
        job.done = queue[0][1];
        job.input = queue[0][2];
        job.command = queue[0][0];
        job.stdinEnabled = true;
        queue = queue.slice(1);
        job.running = true;
    }
    // the exit and the end of its output come in either order: the job is done at the second
    Process {
        id: job
        property var done: null
        property var input: null            // written to its stdin, then closed
        property int code: -1
        property int halves: 0
        onStarted: {
            if (input !== null)
                write(input);
            input = null;
            stdinEnabled = false;
        }
        onRunningChanged: if (running) {
            code = -1;
            halves = 0;
        }
        function half() {
            if (++halves < 2)
                return;
            const cb = done;
            done = null;
            if (cb)
                cb(code, jobOut.text);
            root.next();
        }
        stdout: StdioCollector {
            id: jobOut
            onStreamFinished: job.half()
        }
        onExited: c => {
            code = c;
            half();
        }
    }

    AsyncFile {
        id: store
        path: Config.stateDir + "/shelf.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list)) {
                    // what was dropped before the file was read stays, on top
                    // (the one kept on disk wins: its star, its id)
                    const early = root.items.map(e => list.find(i => i && root.same(i, e)) || e);
                    // a picture still coming when the shell went: its fetch is gone with it;
                    // a note left empty when it went: gone too
                    const kept = list.filter(i => i && i.id && ["file", "folder", "image", "link", "text"].includes(i.kind) && !early.some(e => root.same(i, e)) && !(i.pending && !i.url) && !(i.kind === "text" && String(i.text || "").trim() === "")).map(i => i.pending ? Object.assign({}, i, {
                                "kind": "link",
                                "pending": false,
                                "failed": true
                            }) : i);
                    root.items = early.concat(kept);
                    if (early.length)
                        root.set(root.items);
                }
            } catch (e) {}
            root.loaded = true;
            root.check();
        }
        onLoadFailed: root.loaded = true
    }
}
