pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The keys you press on screen, for guides and streams (Mod+Shift+K, Settings → Снимки и запись):
// scripts/key-cast.py reads the keyboards (evdev, read-only) and prints shortcuts — and with
// Config.keycast.text plain typing too; modules/keycast/KeyCastOverlay draws them.
// Passwords are never shown: the script stays silent while AT-SPI says a password field has the
// focus, and while the shell tells it so — its own password fields (PxField password,
// secretFields), the lock, the polkit dialog, a focused window that looks like a password prompt.
Singleton {
    id: root

    readonly property bool on: Config.ready && Config.keycast.enabled && Quickshell.env("ANGELOS_TEST") !== "1"
    // the Halo's bongo cat (Settings → Halo): the same script, the side of each key only (--taps)
    readonly property bool drum: Config.ready && Config.halo.enabled && Config.halo.idleMiddle !== "ring" && Config.halo.catBongo !== false && Quickshell.env("ANGELOS_TEST") !== "1"
    signal tapped(string side)          // "l" | "r" | "b"
    readonly property var command: ["python3", Quickshell.shellDir + "/scripts/key-cast.py"].concat(on && Config.keycast.text ? ["--text"] : [], drum ? ["--taps"] : [])
    property var items: []                 // newest last: {id, text, kind: "keys" | "text", at}
    property int _n: 0
    property bool secret: false            // the script: a password is being typed now
    property int secretFields: 0           // the shell's own password fields with the focus
    property bool polkitOpen: false        // modules/polkit/PolkitDialog
    property string error: ""

    readonly property var _fw: Niri.focusedWindow
    readonly property bool promptWindow: !!_fw && (/pinentry|polkit|keepass|bitwarden|1password|askpass|gcr-prompter|seahorse|kwallet|ksecret/i.test(_fw.app_id || "") || /password|passphrase|парол|unlock|разблок|sign ?in|log ?in|войти|вход в/i.test(_fw.title || ""))
    readonly property bool shellSecret: Shell.locked || secretFields > 0 || polkitOpen || promptWindow
    onShellSecretChanged: _tell()
    function _tell() {
        if (shellSecret)
            items = [];
        if (proc.running)
            proc.write("secret " + (shellSecret ? 1 : 0) + "\n");
    }

    function toggle() {
        Config.keycast.enabled = !Config.keycast.enabled;
    }
    onOnChanged: {
        items = [];
        error = "";
        if (on)
            _add(I18n.t("Показ клавиш · Mod+Shift+K — выключить", "Showing keys · Mod+Shift+K to stop"), "note");
    }

    function _add(text, kind) {
        const now = Date.now();
        const list = items.slice();
        const last = list.length ? list[list.length - 1] : null;
        // typing gathers into one cap while it goes on
        if (kind === "text" && last && last.kind === "text" && now - last.at < 1500 && last.text.length < 24)
            list[list.length - 1] = Object.assign({}, last, {
                "text": last.text + text,
                "at": now
            });
        else
            list.push({
                "id": ++_n,
                "text": text,
                "kind": kind,
                "at": now
            });
        items = list.slice(-5);
        expire.restart();
    }
    Timer {
        id: expire
        interval: 400
        repeat: true
        onTriggered: {
            const now = Date.now();
            const kept = root.items.filter(i => now - i.at < (i.kind === "note" ? 3500 : 2500));
            if (kept.length !== root.items.length)
                root.items = kept;
            if (!kept.length)
                stop();
        }
    }

    Process {
        id: proc
        running: root.on || root.drum
        stdinEnabled: true
        command: root.command
        onRunningChanged: if (running)
            root._tell()
        stdout: SplitParser {
            onRead: line => {
                let j;
                try {
                    j = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (j.secret !== undefined) {
                    root.secret = j.secret;
                    if (j.secret)
                        root.items = [];
                } else if (j.error) {
                    root.error = j.error;
                } else if (j.tap) {
                    if (!root.secret && !root.shellSecret)
                        root.tapped(j.tap);
                } else if (root.on && !root.secret && !root.shellSecret) {
                    if (j.keys)
                        root._add(j.keys, "keys");
                    else if (j.text)
                        root._add(j.text, "text");
                }
            }
        }
    }
    // --text or --taps changes the command: start again with it
    onCommandChanged: {
        if (proc.running) {
            proc.running = false;
            Qt.callLater(() => proc.running = Qt.binding(() => root.on || root.drum));
        }
    }
}
