pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The author's apps after an update: what the author added to the groups this user took in the
// installer or the wizard (data/apps-catalog.json), and new base packages of the dotfiles
// repository (scripts/apps-install.py pending). Told once per login and after each update, with
// «Поставить» (a terminal: apps-install.py sync, everything ticked, sudo there) and «Не надо»
// (ack: not offered again). Nothing is installed without the user, nothing is ever removed.
// Not on the author's own machine (owner/), not before the setup wizard ran (it asks itself).
// At login it also puts the author's Spotify look back after a Spotify update (spicetify-apply.sh).
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/apps-install.py"
    property var apps: []          // catalog ids
    property var packages: []      // base package names
    property bool fish: false      // the login shell is still bash: the author's fish is offered
    readonly property int count: apps.length + packages.length + (fish ? 1 : 0)
    property string _told: ""
    property var _names: ({})

    function check() {
        if (Shell.dev || Owner.hasDir || !Config.ready || !Config.setup.complete || probe.running)
            return;
        probe.command = ["python3", script, "pending", "--repo", Updates.repo || ""];
        probe.running = true;
    }
    function install() {
        Shell.exec(Shell.terminalArgv(["python3", script, "sync", "--repo", Updates.repo || ""], "angelos-apps"));
    }
    function skip() {
        Quickshell.execDetached(["python3", script, "ack", "--repo", Updates.repo || ""]);
        apps = [];
        packages = [];
        fish = false;
    }

    FileView {
        path: Quickshell.shellDir + "/data/apps-catalog.json"
        printErrors: false
        onLoaded: {
            try {
                const names = {};
                for (const a of JSON.parse(text()).apps)
                    names[a.id] = I18n.t(a.ru, a.en);
                root._names = names;
            } catch (e) {}
        }
    }
    Process {
        id: probe
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.apps = p.apps || [];
                    root.packages = p.packages || [];
                    root.fish = !!p.fish;
                } catch (e) {
                    return;
                }
                root.tell();
            }
        }
    }
    function tell() {
        const key = apps.concat(packages).join(",") + (fish ? ",fish" : "");
        if (count === 0 || key === _told)
            return;
        _told = key;
        const list = (fish ? [I18n.t("fish вместо bash", "fish instead of bash")] : []).concat(apps.map(i => _names[i] || i), packages);
        const shown = list.slice(0, 6).join(", ") + (list.length > 6 ? I18n.t(" и ещё ", " and ") + (list.length - 6) : "");
        notifier.command = ["notify-send", "-a", "angelOS", "-i", "system-software-install", "--wait", "-A", "install=" + I18n.t("Поставить", "Install"), "-A", "skip=" + I18n.t("Не надо", "No, thanks"), I18n.t("Как у автора angelOS", "As angelOS's author has it"), shown + I18n.t(" — как у автора. Поставить? (в терминале, всё отмечено — сними лишнее)", " — as the author has them. Install? (in a terminal, all ticked: untick what you don't want)")];
        notifier.running = true;
    }
    Process {
        id: notifier
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.trim();
                if (a === "install")
                    root.install();
                else if (a === "skip")
                    root.skip();
            }
        }
    }
    // Spotify in the author's look (spicetify): again after each Spotify update, quietly
    Process {
        id: spicetify
        command: ["bash", Quickshell.shellDir + "/scripts/spicetify-apply.sh"]
    }
    // once per login, after the desktop has settled (and the intro is over)
    Timer {
        interval: 4 * 60 * 1000
        running: Config.ready
        onTriggered: {
            root.check();
            if (!Shell.dev && !Owner.hasDir)
                spicetify.running = true;
        }
    }
}
