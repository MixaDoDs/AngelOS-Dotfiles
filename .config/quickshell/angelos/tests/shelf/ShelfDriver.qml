import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The Halo's shelf, offscreen (started by tests/shelf/run.sh): what lands on it from a drop, the
// duplicates, the stars, the copies into a starred folder, a deleted file, the state file.
// $FIX_DIR holds a.txt, dir/ and fav/ (with an a.txt of its own); the stand-ins write what they
// were asked into $FAKE_DIR.
Scope {
    id: root

    property int step: 0
    readonly property string fix: Quickshell.env("FIX_DIR")
    readonly property string site: "http://127.0.0.1:" + Quickshell.env("SHELF_PORT")
    property int n0: 0
    readonly property string fake: Quickshell.env("FAKE_DIR")
    Component.onCompleted: Quickshell.watchFiles = false

    function ok(name, cond, detail) {
        console.log("TEST " + name + " " + (cond ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    // a check waits for its state up to 15 s instead of failing at its step
    property int waited: 0
    function hold(cond) {
        if (cond || waited >= 30) {
            waited = 0;
            return false;
        }
        waited++;
        step--;
        return true;
    }
    function fakeLog(name) {
        const f = name === "wl-copy" ? wlcopy : notify;
        f.reload();
        return String(f.text() || "");
    }
    function by(kind) {
        return Shelf.items.find(i => i.kind === kind) || null;
    }
    function file(p) {
        return Shelf.items.find(i => i.path === root.fix + "/" + p) || null;
    }
    FileView {
        id: wlcopy
        path: root.fake + "/wl-copy"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: notify
        path: root.fake + "/notify"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: copied
        path: root.fix + "/fav/a (2).txt"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: saved
        path: Config.stateDir + "/shelf.json"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            root.step++;
            const S = Shelf;
            if (root.step === 2) {
                if (root.hold(S.loaded))
                    return;
                root.ok("empty", S.items.length === 0 && S.count === 0, S.items.length);
                S.addDrop(["file://" + encodeURI(root.fix + "/a.txt"), "file://" + root.fix + "/dir", "https://www.example.com/page/?q=1", root.site + "/p/cat.png?x=2"], "", false);
                S.addDrop([], "  hello note  ", false);
            } else if (root.step === 3) {
                if (root.hold(S.items.length === 5 && !!root.by("folder") && !!root.by("image") && !!root.by("image").path))
                    return;
                const kinds = S.items.map(i => i.kind).sort().join(",");
                root.ok("kinds", kinds === "file,folder,image,link,text", kinds);
                root.ok("newest-first", S.items[0].kind === "image" || S.items[0].kind === "text", S.items.map(i => i.kind).join(","));
                root.ok("link-name", root.by("link").name === "example.com/page" && root.by("link").url.startsWith("https://www."), root.by("link").name);
                const img = root.by("image");
                root.ok("image-downloaded", img.path.startsWith(S.dir + "/") && img.path.endsWith("cat.png") && img.url.includes("cat.png") && !img.pending, img.path);
                root.ok("text-trimmed", root.by("text").text === "hello note", JSON.stringify(root.by("text")));
                root.ok("file-path-decoded", !!root.file("a.txt") && root.file("a.txt").name === "a.txt" && root.file("dir").kind === "folder", JSON.stringify(S.items.map(i => i.path)));
                // the same file again: no second one, it moves up
                S.addDrop(["file://" + root.fix + "/a.txt"], "", false);
            } else if (root.step === 4) {
                root.ok("duplicate-moves-up", S.items.length === 5 && S.items[0].path === root.fix + "/a.txt", S.items.map(i => i.name).join(","));
                // a star keeps what is dragged out; the rest goes
                const a = root.file("a.txt"), link = root.by("link");
                S.setFav(a.id, true);
                S.taken(a.id);
                S.taken(link.id);
                root.ok("star-keeps", !!root.file("a.txt") && root.file("a.txt").fav && !root.by("link"), S.items.map(i => i.kind).join(","));
                root.ok("loose-favs", S.favs.length === 1 && S.count === 3 && S.loose.length === 3, S.favs.length + " " + S.count);
                S.remove(root.by("text").id);
                root.ok("remove", !root.by("text") && S.items.length === 3, S.items.length);
                root.ok("uri", S.uri(root.file("a.txt")) === "file://" + encodeURI(root.fix + "/a.txt"), S.uri(root.file("a.txt")));
                S.copy(root.file("a.txt").id);
                // a starred folder, and a file dropped on it whose name is taken there
                S.addDrop(["file://" + root.fix + "/fav"], "", false);
            } else if (root.step === 5) {
                const f = root.file("fav");
                if (root.hold(!!f && f.kind === "folder"))
                    return;
                S.setFav(f.id, true);
                // the starred folder dropped again: it arrives as "file", still one, still starred
                const n = S.items.length;
                S.addDrop(["file://" + root.fix + "/fav"], "", false);
                root.ok("folder-again-once", S.items.length === n && S.items.filter(i => i.path === root.fix + "/fav").length === 1 && root.file("fav").fav, JSON.stringify(S.items.map(i => [i.kind, i.path, i.fav])));
                S.intoFolder(f.id, ["file://" + root.fix + "/a.txt"]);
            } else if (root.step === 6) {
                copied.reload();
                if (root.hold(String(copied.text() || "").trim() === "hello"))
                    return;
                root.ok("into-folder", String(copied.text()).trim() === "hello", copied.text());
            } else if (root.step === 7) {
                if (root.hold(root.fakeLog("notify").includes("Скопировано в fav")))
                    return;
                root.ok("into-folder-told", root.fakeLog("notify").includes("a.txt"), root.fakeLog("notify"));
                root.ok("copy-uri-list", root.fakeLog("wl-copy").includes("--type text/uri-list file://" + root.fix + "/a.txt"), root.fakeLog("wl-copy"));
                // the file goes away: missing after a check
                Quickshell.execDetached(["rm", "-f", root.fix + "/a.txt"]);
            } else if (root.step === 8) {
                S.check();
            } else if (root.step === 9) {
                if (root.hold(root.file("a.txt") && root.file("a.txt").missing))
                    return;
                root.ok("missing", root.file("a.txt").missing && !root.file("dir").missing, JSON.stringify(root.file("a.txt")));
            } else if (root.step === 10) {
                saved.reload();
                let list = [];
                try {
                    list = JSON.parse(saved.text());
                } catch (e) {}
                if (root.hold(list.length === S.items.length && list.some(i => i.missing)))
                    return;
                root.ok("state-file", list.length === S.items.length && list.some(i => i.fav && i.path === root.fix + "/fav"), saved.text().slice(0, 200));
                // a picture inside a link, as Pinterest or Google's pictures drag it: the link's
                // address as the URL, the picture in the HTML (srcset: the biggest)
                const html = '<a href="https://pins.example/pin/1"><img alt="x" src="' + root.site + '/php?id=3&amp;s=1" srcset="' + root.site + '/php?id=3&amp;s=1 1x, ' + root.site + '/php?id=3&amp;s=2 2x"></a>';
                root.ok("img-src", S.imgSrc(html) === root.site + "/php?id=3&s=2" && S.imgSrc('<img src="/rel.png">') === "" && S.imgSrc("<img src='data:image/png;base64,AA'>") === "data:image/png;base64,AA", S.imgSrc(html));
                root.n0 = S.items.length;
                S.addDrop(["https://pins.example/pin/1"], "https://pins.example/pin/1", true, S.imgSrc(html));
                root.ok("pending-at-once", S.items[0].kind === "image" && S.items[0].pending && !S.items.some(i => i.url === "https://pins.example/pin/1"), JSON.stringify(S.items[0]));
            } else if (root.step === 11) {
                const it = S.items.find(i => i.url === root.site + "/php?id=3&s=2");
                if (root.hold(!!it && !it.pending))
                    return;
                root.ok("in-link-fetched", !!it && it.kind === "image" && /\.jpg$/.test(it.path) && S.items.length === root.n0 + 1, JSON.stringify(it));
                // data:, blob:, and an address that gives no picture
                S.addDrop([], "", true, "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");
                S.addDrop([], "", true, "blob:https://site.example/5f1c");
                S.addDrop([root.site + "/page.html"], "", true, root.site + "/page.html");
            } else if (root.step === 12) {
                if (root.hold(!S.items.some(i => i.pending)))
                    return;
                const data = S.items.find(i => i.kind === "image" && /\.png$/.test(i.path) && !i.url);
                root.ok("data-uri", !!data, JSON.stringify(S.items.slice(0, 4)));
                const blob = S.items.find(i => i.failed && i.kind === "link" && i.url.startsWith("blob:"));
                const page = S.items.find(i => i.failed && i.url === root.site + "/page.html");
                root.ok("not-had-marked", !!blob && !!page && page.kind === "link", JSON.stringify(S.items.slice(0, 4)));
                // the picture handed over as bytes, as Helium's drag does («application/octet-stream;
                // name="f9e.jpg"»): its type from the bytes (a [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 240, 31, 0, 5, 0, 2, 1, 166, 214, 184, 209, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130] named .jpg), its name kept
                S.addBytes(new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 240, 31, 0, 5, 0, 2, 1, 166, 214, 184, 209, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]).buffer, "f9e.jpg", "https://img.example/f9e.jpg");
            } else if (root.step === 13) {
                const it = S.items.find(i => i.url === "https://img.example/f9e.jpg");
                if (root.hold(!!it && !it.pending))
                    return;
                root.ok("bytes", !!it && it.kind === "image" && /-f9e\.png$/.test(it.path) && it.name === "f9e.png", JSON.stringify(it));
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
