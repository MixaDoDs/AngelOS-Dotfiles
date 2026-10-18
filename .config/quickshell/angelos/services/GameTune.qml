pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config

// The game tuner (scripts/game-tune.py): for each Steam game the Proton and launch options
// that work best and why — ProtonDB's reports, angelOS's own profiles, anti-cheat. A game that
// finishes installing gets its note (modules/gametune/GameNote); Settings → Maintenance → Games
// lists them all. Steam rewrites its config on exit, so what is applied while it runs waits
// and goes in once it is closed.
Singleton {
    id: root

    property var data: null                  // game-tune.py list
    readonly property var games: data ? data.games : []
    readonly property bool hasSteam: !!data && data.steam
    readonly property var tools: data ? data.tools : []
    property string note: ""                 // the appid whose note is open
    readonly property var noteGame: games.find(g => g.appid === note) || null
    property string error: ""
    readonly property bool busy: lister.running || worker.running
    readonly property bool anyPending: games.some(g => g.pending)

    function game(appid) {
        return games.find(g => g.appid === appid) || null;
    }
    function toolName(name) {
        if (!name)
            return I18n.t("как решит Steam", "Steam's own choice");
        const t = tools.find(x => x.name === name);
        return t ? t.display : name;
    }
    function reload() {
        if (!lister.running)
            lister.running = true;
        else
            again = true;
    }
    property bool again: false
    function run(args) {
        if (worker.running)
            return;
        worker.command = ["python3", "-I", Quickshell.shellPath("scripts/game-tune.py")].concat(args);
        worker.running = true;
    }
    // null leaves that one as it is
    function apply(appid, proton, options) {
        run(["apply", appid].concat(proton === null ? [] : ["--proton", proton], options === null ? [] : ["--options", options]));
    }
    function undo(appid) {
        run(["undo", appid]);
    }
    // GE, EM, Sarek, tkg and the rest come from ProtonPlus (the gaming edition installs it);
    // without it, a terminal offers it
    function openProtonPlus() {
        if (hasProtonPlus)
            Shell.exec(["protonplus"]);
        else
            Shell.terminal("echo 'sudo pacman -S protonplus'; sudo pacman -S --needed protonplus && setsid protonplus >/dev/null 2>&1 &");
    }
    readonly property bool hasProtonPlus: data ? !!data.protonplus : false

    // ---- comparing Protons on this machine (game-tune.py bench): one run per Proton, MangoHud
    // logs 60 s from Shift+F2, the next Proton comes by itself once the game closes
    readonly property var bench: data ? data.bench : null
    readonly property bool hasMangoHud: data ? !!data.mangohud : false
    property bool restartSteam: false        // the switch is new: Steam sees it after a restart
    function benchStart(appid, names) {
        if (worker.running)
            return;
        restartSteam = false;
        benchStarter.command = ["python3", "-I", Quickshell.shellPath("scripts/game-tune.py"), "bench", "start", appid, names.join(",")];
        benchStarter.running = true;
    }
    function benchFinish(keep) {
        restartSteam = false;
        run(["bench", "finish", keep || ""]);
    }
    Process {
        id: benchStarter
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.error = r.ok === false ? (r.error || "") : "";
                    root.restartSteam = !!r.restartSteam;
                } catch (e) {}
            }
        }
        onExited: root.reload()
    }
    // a run's log lands: read it, switch to the next Proton
    FolderListModel {
        folder: root.bench && !root.bench.done && root.data ? "file://" + root.data.benchDir + "/" + root.bench.appid : ""
        nameFilters: ["*.csv"]
        showDirs: false
        onCountChanged: if (count > 0)
            benchRead.restart()
    }
    Timer {
        id: benchRead
        // MangoHud writes the file as it goes: read once its minute is over
        interval: 65000
        onTriggered: root.run(["bench", "next"])
    }
    function openNote(appid) {
        note = appid;
        seen.command = ["python3", "-I", Quickshell.shellPath("scripts/game-tune.py"), "seen", appid];
        seen.running = true;
    }
    // the helper agent (scripts/help-agent.sh) with a page about the game
    function askAgent(appid) {
        const g = game(appid);
        if (!g)
            return;
        const file = Quickshell.env("XDG_RUNTIME_DIR") + "/angelos-game-" + appid + ".md";
        Quickshell.execDetached(["sh", "-c", 'python3 -I "$1" context "$2" > "$3" && exec "$4" --context "$3" "$5"', "sh", Quickshell.shellPath("scripts/game-tune.py"), appid, file, Quickshell.shellPath("scripts/help-agent.sh"), I18n.t("Подбери лучшие настройки для игры «", "Find the best settings for the game \"") + g.name + I18n.t("»: какой Proton и какие параметры запуска, по отчётам ProtonDB и моему железу. Сначала расскажи, что предлагаешь и почему, потом примени через game-tune.py, если я соглашусь.", "\": which Proton and which launch options, from ProtonDB's reports and my hardware. First say what you suggest and why, then apply it with game-tune.py if I agree.")]);
    }

    Process {
        id: lister
        command: ["python3", "-I", Quickshell.shellPath("scripts/game-tune.py"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                    root.error = "";
                } catch (e) {
                    root.error = text.slice(0, 200);
                }
                // one new game at a time, not over a game being played
                const fresh = root.games.find(g => g.fresh);
                if (fresh && !root.note && !Shell.gaming && Config.gaming.tuneNotes)
                    root.openNote(fresh.appid);
            }
        }
        onExited: if (root.again) {
            root.again = false;
            running = true;
        }
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.error = r.ok === false ? (r.error || "") : "";
                } catch (e) {}
            }
        }
        onExited: root.reload()
    }
    Process {
        id: seen
    }
    // the network part (anti-cheat list, which games are native): cached for a week
    Process {
        id: fetcher
        command: ["python3", "-I", Quickshell.shellPath("scripts/game-tune.py"), "refresh"]
        onExited: root.reload()
    }

    // a game appears (its manifest) or finishes downloading (its folder in downloading/ goes)
    FolderListModel {
        folder: root.hasSteam ? "file://" + root.data.root + "/steamapps" : ""
        nameFilters: ["appmanifest_*.acf"]
        showDirs: false
        onCountChanged: settle.restart()
    }
    FolderListModel {
        folder: root.hasSteam ? "file://" + root.data.root + "/steamapps/downloading" : ""
        showFiles: false
        onCountChanged: settle.restart()
    }
    Timer {
        id: settle
        interval: 3000
        onTriggered: root.reload()
    }
    // applied while Steam ran: in once it is closed
    Timer {
        interval: 15000
        repeat: true
        running: root.anyPending
        onTriggered: root.run(["pending"])
    }
    // the game left: a note held back while it played comes now
    Connections {
        target: Shell
        function onGamingChanged() {
            if (!Shell.gaming)
                root.reload();
        }
    }
    Timer {
        interval: 20000
        // a test shell only with a fake Steam (STEAM_ROOT), never the real one
        running: Config.ready && (!Shell.dev || Quickshell.env("STEAM_ROOT") !== null)
        onTriggered: {
            root.reload();
            fetcher.running = true;
        }
    }
}
