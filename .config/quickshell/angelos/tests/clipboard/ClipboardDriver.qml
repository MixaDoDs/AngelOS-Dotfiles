pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Win+V pastes (issue #61), offscreen (started by tests/clipboard/run.sh): the Clipboard service
// against stand-ins of wl-copy and wtype. A picked entry goes back into the clipboard and, once
// the history is shut and the window it was opened over has the keyboard again, Ctrl+V is pressed
// there (Ctrl+Shift+V in a terminal); copy only, the setting off and no window press nothing.
Scope {
    id: root

    property int step: 0
    property double since: Date.now()
    readonly property string fake: Quickshell.env("FAKE_CLIP_DIR")
    readonly property string store: Quickshell.env("ANGELOS_CLIPBOARD_DIR")

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail === undefined ? "" : detail));
    }
    function next() {
        step++;
        since = Date.now();
    }
    function until(name, cond, ms, detail) {
        let ok = false;
        try {
            ok = !!cond();
        } catch (e) {
            ok = false;
            detail = () => String(e);
        }
        if (!ok && Date.now() - since < (ms || 5000))
            return false;
        report(name, ok, detail ? detail() : "");
        next();
        return true;
    }
    // nothing may happen for ms: then report
    function quiet(name, cond, ms, detail) {
        if (cond()) {
            report(name, false, detail ? detail() : "");
            next();
            return true;
        }
        if (Date.now() - since < ms)
            return false;
        report(name, true, "");
        next();
        return true;
    }

    FloatingWindow {
        id: holder
        visible: false
        implicitWidth: 800
        implicitHeight: 600
    }
    FileView {
        id: typed
        path: root.fake + "/wtype.log"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    FileView {
        id: copied
        path: root.fake + "/clip"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    FileView {
        id: copiedArgs
        path: root.fake + "/clip.args"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    function lines() {
        return typed.text().split("\n").filter(l => l);
    }
    function lastKeys() {
        const l = lines();
        return l.length ? l[l.length - 1] : "";
    }
    property int before: 0

    // the history opened over window `id` (or over nothing), the entry picked, the history shut
    function pickOver(win, entry, copyOnly) {
        Niri.windows = win ? [win] : [];
        Niri.focusedWindowId = win ? win.id : -1;
        Shell.clipboardOpen = true;
        Clipboard.aim();
        before = lines().length;
        if (copyOnly)
            Clipboard.copy(entry);
        else
            Clipboard.paste(entry);
        Shell.clipboardOpen = false;
    }
    readonly property var obsidian: ({
            "id": 7,
            "app_id": "obsidian",
            "title": "Без названия 1"
        })
    readonly property var kitty: ({
            "id": 9,
            "app_id": "kitty",
            "title": "fish"
        })
    readonly property string imageId: "0123456789abcdef0123456789abcdef"

    Timer {
        interval: 40
        repeat: true
        running: true
        onTriggered: {
            switch (root.step) {
            case 0:
                Config.launcher.clipboardPaste = true;
                root.pickOver(root.obsidian, "привет из истории", false);
                root.next();
                return;
            case 1:
                root.until("pastes-ctrl-v", () => root.lines().length === root.before + 1 && root.lastKeys() === "-M ctrl -k v -m ctrl" && copied.text() === "привет из истории", 5000, () => JSON.stringify(root.lines()) + " clip=" + copied.text());
                return;
            case 2:
                root.pickOver(root.kitty, "ls -la", false);
                root.next();
                return;
            case 3:
                root.until("terminal-ctrl-shift-v", () => root.lines().length === root.before + 1 && root.lastKeys() === "-M ctrl -M shift -k v -m shift -m ctrl" && copied.text() === "ls -la", 5000, () => JSON.stringify(root.lines()) + " clip=" + copied.text());
                return;
            case 4:
                root.pickOver(root.obsidian, "только скопировать", true);
                root.next();
                return;
            case 5:
                root.quiet("shift-enter-only-copies", () => root.lines().length !== root.before, 1200, () => JSON.stringify(root.lines()));
                return;
            case 6:
                root.report("copy-only-copied", copied.text() === "только скопировать", copied.text());
                Config.launcher.clipboardPaste = false;
                root.pickOver(root.obsidian, "без вставки", false);
                root.next();
                return;
            case 7:
                root.quiet("setting-off-no-keys", () => root.lines().length !== root.before, 1200, () => JSON.stringify(root.lines()));
                return;
            case 8:
                root.report("setting-off-copied", copied.text() === "без вставки", copied.text());
                Config.launcher.clipboardPaste = true;
                root.pickOver(null, "на пустой стол", false);
                root.next();
                return;
            case 9:
                root.quiet("no-window-no-keys", () => root.lines().length !== root.before, 1200, () => JSON.stringify(root.lines()));
                return;
            case 10:
                // niri says the keyboard is nowhere while the history holds it: wait for the window
                Niri.ready = true;
                root.pickOver(root.obsidian, "дождаться окна", false);
                Niri.focusedWindowId = -1;
                root.next();
                return;
            case 11:
                root.quiet("waits-for-the-window", () => root.lines().length !== root.before, 400, () => JSON.stringify(root.lines()));
                return;
            case 12:
                Niri.focusedWindowId = root.obsidian.id;
                root.next();
                return;
            case 13:
                root.until("pastes-once-it-is-back", () => root.lines().length === root.before + 1, 3000, () => JSON.stringify(root.lines()));
                return;
            case 14:
                Niri.ready = false;
                root.pickOver(root.obsidian, {
                    "kind": "image",
                    "id": root.imageId,
                    "mime": "image/png",
                    "path": root.store + "/" + root.imageId + ".png"
                }, false);
                root.next();
                return;
            case 15:
                root.until("image-pasted", () => root.lines().length === root.before + 1 && copiedArgs.text().trim() === "--type image/png" && copied.text().indexOf("PNG") === 1, 5000, () => JSON.stringify(root.lines()) + " args=" + copiedArgs.text());
                return;
            case 16:
                {
                    // the history and its settings row build (they are not shown offscreen)
                    const panel = Qt.createComponent(Quickshell.shellDir + "/modules/clipboard/ClipboardPanel.qml");
                    const page = Qt.createComponent(Quickshell.shellDir + "/modules/settings/CatalogPage.qml");
                    // offscreen has no layer shell: reaching PanelWindow means the file itself parsed
                    root.report("panel-compiles", panel.status === Component.Ready || /^[^\n]*: No PanelWindow backend loaded\.\s*$/.test(panel.errorString()), panel.errorString());
                    const made = page.status === Component.Ready ? page.createObject(holder.contentItem, {
                        "width": 800,
                        "catalog": "Keyboard"
                    }) : null;
                    root.report("settings-row", !!made && JSON.stringify(Config.launcher.clipboardPaste) === "true", page.errorString());
                    if (made)
                        made.destroy();
                    root.next();
                    return;
                }
            default:
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
