pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Quick Share: send to and get from phones and computers nearby that run LocalSend (Android,
// iOS, Windows, macOS, Linux) — its protocol, without the app (scripts/quickshare.py).
//   in: a question in a notification (Accept / Accept and always from <name> / Decline);
//       trusted devices come without one; what came is on the clipboard at once (files as
//       files, one picture as a picture, a message as text); the files land in ~/Downloads/LocalSend
//   out: `angelos share <files…>`, Nautilus → "Send nearby", Circle to Search, the sheet
//        (modules/quickshare/ShareSheet) with the devices found and a drop area
Singleton {
    id: root

    // the daemon: not in tests and not in a dev copy (one port per computer), unless told
    readonly property string port: Quickshell.env("ANGELOS_QUICKSHARE_PORT") || ""
    readonly property bool wanted: Config.quickshare.enabled && Quickshell.env("ANGELOS_TEST") !== "1" && (!Shell.dev || port !== "")
    property bool ready: false
    property bool receiving: false          // the port is ours (else LocalSend's own app has it)
    property string busy: ""
    property string fingerprint: ""
    property string myIp: ""
    readonly property string alias: Config.quickshare.alias || ("angelOS " + (Quickshell.env("HOSTNAME") || hostName))
    property string hostName: ""
    readonly property string saveDir: Config.quickshare.dir || (Quickshell.env("HOME") + "/Downloads/LocalSend")

    property var devices: ({})             // fp → {fp, alias, ip, port, protocol, type, model, seen}
    readonly property var nearby: {
        const now = clock.now;
        return Object.values(devices).filter(d => now - d.seen < 5 * 60 * 1000).sort((a, b) => a.alias.localeCompare(b.alias));
    }
    property var jobs: ({})                // job → {to, state, done, total, msg}
    property var incoming: null            // the receive now: {id, from, done, total, state}

    // the sheet
    property bool sheetOpen: false
    property var payload: []               // files to send
    property string payloadText: ""
    property int jobSerial: 0

    function share(paths, text) {
        payload = (paths || []).filter(p => p !== "");
        payloadText = text || "";
        sheetOpen = true;
        scan();
    }
    function close() {
        sheetOpen = false;
    }
    function scan() {
        command({
            "cmd": "scan"
        });
    }
    function addAddress(addr) {
        const m = /^\s*([\w.-]+)(?::(\d+))?\s*$/.exec(addr || "");
        if (!m)
            return false;
        command({
            "cmd": "add",
            "ip": m[1],
            "port": parseInt(m[2] || "53317")
        });
        return true;
    }
    function sendTo(fp) {
        if (!payload.length && !payloadText)
            return;
        const job = "j" + (++jobSerial);
        const j = Object.assign({}, jobs);
        j[job] = {
            "to": fp,
            "state": "waiting",
            "done": 0,
            "total": 0,
            "msg": ""
        };
        jobs = j;
        command({
            "cmd": "send",
            "job": job,
            "to": fp,
            "files": payload,
            "text": payloadText,
            "pin": Config.quickshare.pin
        });
    }
    function cancel(job) {
        command({
            "cmd": "cancel",
            "job": job
        });
    }
    function jobFor(fp) {
        let best = null;
        for (const k in jobs)
            if (jobs[k].to === fp)
                best = Object.assign({
                    "job": k
                }, jobs[k]);
        return best;
    }
    function isTrusted(fp) {
        return (Config.quickshare.trusted || []).some(t => t.fp === fp);
    }
    function trust(dev, on) {
        const rest = (Config.quickshare.trusted || []).filter(t => t.fp !== dev.fp);
        Config.quickshare.trusted = on ? rest.concat([{
                "fp": dev.fp,
                "alias": dev.alias
            }]) : rest;
    }
    function answer(id, accept) {
        command({
            "cmd": "answer",
            "id": id,
            "accept": accept
        });
    }
    function command(obj) {
        if (daemon.running)
            daemon.write(JSON.stringify(obj) + "\n");
    }
    function size(n) {
        if (n < 1024)
            return n + " " + I18n.t("Б", "B");
        const u = I18n.t(["КБ", "МБ", "ГБ"], ["KB", "MB", "GB"]);
        let i = -1;
        do {
            n /= 1024;
            i++;
        } while (n >= 1024 && i < 2)
        return (n < 10 ? n.toFixed(1) : Math.round(n)) + " " + u[i];
    }
    function notify(title, body, actions, onAction) {
        const args = ["notify-send", "-a", I18n.t("Отправить рядом", "Quick Share"), "-i", "folder-download"];
        for (const a of actions || [])
            args.push("-A", a[0] + "=" + a[1]);
        if (actions && actions.length)
            args.push("--wait");
        args.push(title, body);
        const p = asker.createObject(root, {
            "command": args,
            "handler": onAction || null
        });
        p.running = true;
    }

    // what the daemon says
    function onEvent(ev) {
        if (ev.ev === "ready") {
            ready = true;
            receiving = ev.receive;
            busy = ev.busy || "";
            fingerprint = ev.fingerprint || "";
            myIp = ev.ip || "";
        } else if (ev.ev === "device") {
            const d = Object.assign({}, devices);
            d[ev.fp] = Object.assign({
                "seen": Date.now()
            }, ev);
            devices = d;
        } else if (ev.ev === "send") {
            const j = Object.assign({}, jobs);
            j[ev.job] = Object.assign({}, j[ev.job] || {}, {
                "state": ev.state,
                "done": ev.done || 0,
                "total": ev.total || 0,
                "msg": ev.msg || ""
            });
            jobs = j;
        } else if (ev.ev === "ask") {
            const names = ev.files.slice(0, 3).map(f => f.name).join(", ") + (ev.files.length > 3 ? I18n.t(" и ещё ", " and ") + (ev.files.length - 3) : "");
            notify(I18n.t(ev.from.alias + " хочет прислать: " + ev.files.length + " шт., " + size(ev.total), ev.from.alias + " wants to send " + ev.files.length + " file(s), " + size(ev.total)), names, [["accept", I18n.t("Принять", "Accept")], ["trust", I18n.t("Принять и всегда от ", "Accept, and always from ") + ev.from.alias], ["decline", I18n.t("Отклонить", "Decline")]], act => {
                if (act === "trust")
                    root.trust(ev.from, true);
                root.answer(ev.id, act === "accept" || act === "trust");
            });
        } else if (ev.ev === "text") {
            notify(I18n.t("Сообщение от ", "A message from ") + ev.from.alias + I18n.t(" · в буфере", " · on the clipboard"), ev.text, [], null);
        } else if (ev.ev === "recv") {
            incoming = ev.state === "receiving" ? Object.assign({}, incoming || {}, ev) : null;
            if (ev.state === "done") {
                const items = ev.items || ev.paths || [];
                // one thing: a look at it in Quick Look first (the shell's own, no app to wait for)
                const acts = (items.length === 1 && QuickLook.wanted ? [["look", I18n.t("Посмотреть", "Look")]] : []).concat([["open", I18n.t("Открыть", "Open")], ["folder", I18n.t("Показать в папке", "Show in folder")], ["copy", I18n.t("В буфер ещё раз", "Copy again")]]);
                notify(I18n.t("Получено от " + ((ev.from || {}).alias || "?") + ": " + items.length + " шт. · в буфере", "Received from " + ((ev.from || {}).alias || "?") + ": " + items.length + " · on the clipboard"), items.map(p => p.split("/").pop()).slice(0, 4).join(", "), acts, act => {
                    // up to three things open each in its app (the photo in the viewer, the video in
                    // the player, a folder in the file manager); more are shown in the folder, picked
                    if (act === "look")
                        QuickLook.show(items[0], false);
                    else if (act === "copy")
                        root.command({
                            "cmd": "clip",
                            "items": items
                        });
                    else if (act === "open" && items.length <= 3)
                        items.forEach(p => Quickshell.execDetached(["gio", "open", p]));
                    else if (act === "open" || act === "folder")
                        root.reveal(items);
                });
            } else if (ev.state === "error") {
                notify(I18n.t("Не получилось принять", "Could not receive"), ev.msg || "", []);
            }
        }
    }

    // the file manager at the folder, the files picked (FileManager1, as FileSearch.reveal)
    function reveal(paths) {
        const list = "[" + paths.map(p => "'" + FileSearch.uri(p).replace(/'/g, "%27") + "'").join(",") + "]";
        Quickshell.execDetached(["sh", "-c", 'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "$1" "" >/dev/null 2>&1 || xdg-open "$2"', "sh", list, root.saveDir]);
    }

    // the settings the daemon follows without a restart
    function pushConfig() {
        command({
            "cmd": "config",
            "alias": root.alias,
            "receive": Config.quickshare.receive,
            "dir": root.saveDir,
            "trusted": (Config.quickshare.trusted || []).map(t => t.fp),
            "pin": Config.quickshare.pin
        });
    }
    Connections {
        target: Config.quickshare
        function onAliasChanged() {
            root.pushConfig();
        }
        function onDirChanged() {
            root.pushConfig();
        }
        function onTrustedChanged() {
            root.pushConfig();
        }
        function onPinChanged() {
            root.pushConfig();
        }
        // to or from "off": the port is opened or let go — a new daemon
        function onReceiveChanged() {
            root.restart();
        }
    }
    function restart() {
        if (!wanted)
            return;
        daemon.running = false;
        ready = false;
        restartTimer.restart();
    }
    Timer {
        id: restartTimer
        interval: 300
        onTriggered: daemon.running = root.wanted
    }

    Process {
        id: daemon
        running: root.wanted
        stdinEnabled: true
        command: ["python3", Quickshell.shellPath("scripts/quickshare.py"), "daemon", "--alias", root.alias, "--receive", Config.quickshare.receive, "--dir", root.saveDir, "--trusted", (Config.quickshare.trusted || []).map(t => t.fp).join(","), "--pin", Config.quickshare.pin].concat(root.port ? ["--port", root.port] : [])
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.onEvent(JSON.parse(line));
                } catch (e) {}
            }
        }
        onExited: {
            root.ready = false;
            root.receiving = false;
        }
    }
    Process {
        running: true
        command: ["uname", "-n"]
        stdout: StdioCollector {
            onStreamFinished: root.hostName = text.trim()
        }
    }
    // the devices go stale: the list is re-read every half minute, and asked again while the sheet is open
    QtObject {
        id: clock
        property double now: Date.now()
    }
    Timer {
        interval: root.sheetOpen ? 5000 : 30000
        running: root.ready
        repeat: true
        onTriggered: {
            clock.now = Date.now();
            if (root.sheetOpen)
                root.scan();
        }
    }
    Component {
        id: asker
        Process {
            id: pr
            property var handler: null
            stdout: StdioCollector {
                id: said
            }
            // the action's key (notify-send --wait prints it), "" = closed without one
            onExited: {
                if (pr.handler)
                    pr.handler(said.text.trim());
                pr.destroy();
            }
        }
    }
}
