pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The game's debug panel — the author's only. Its code is not here: it lives in owner/debug/
// (never published) and comes from the author's private repository after the GitHub login
// (scripts/author-tools.sh, services/Owner). A public install has no such folder, so this stub
// loads nothing and every way in (the IPC, «Пуск», Settings, the settings search) stays shut;
// developer mode does not open it.
//   core     owner/debug/GameDebugCore.qml once it is on disk and the owner check passed
//            (or a dev instance: with no owner/debug there is nothing to load anyway)
//   window   owner/debug/GameDebugWindow.qml (modules/LazyWindows), while `shown`
// What other parts of the shell read stays here, so they work without the core: the demon's
// skin override (StreamerCast, the corner helper), the open flag, the tab, the status line.
Singleton {
    id: root

    readonly property string dir: Owner.dir + "/debug"
    readonly property string coreUrl: hasCore ? "file://" + dir + "/GameDebugCore.qml" : ""
    readonly property string windowUrl: hasCore ? "file://" + dir + "/GameDebugWindow.qml" : ""
    property bool hasCore: false
    readonly property var core: coreLoader.item
    readonly property bool allowed: !!core && (Owner.enabled || Shell.dev)
    property bool open: false
    readonly property bool shown: open && allowed
    property string tab: "state"
    // the demon in the corner wears this circle's skin ("" — the circle's own, "-" — none)
    property string skin: ""
    // the last thing done, for the panel's status line
    property string log: ""
    function note(s) {
        log = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss") + "  " + s;
        return s;
    }
    function toggle() {
        open = !open;
        return open ? "open" : "closed";
    }
    onAllowedChanged: if (!allowed) {
        open = false;
        skin = "";
    }
    // `angelos debug …` (modules/Ipc): no hint how to get in for anyone else
    function command(line: string): string {
        return allowed ? core.command(line) : "owner only";
    }

    // look again for owner/debug (after the author's tools were fetched: the setup wizard,
    // the Dotfiles page)
    function probe() {
        coreProbe.running = false;
        coreProbe.running = true;
    }
    Process {
        id: coreProbe
        running: true
        command: ["test", "-f", root.dir + "/GameDebugCore.qml"]
        onExited: code => root.hasCore = code === 0
    }
    Connections {
        target: Owner
        function onRefreshed() {
            root.probe();
        }
        function onHasDirChanged() {
            root.probe();
        }
        function onEnabledChanged() {
            root.probe();
        }
    }
    // the author is confirmed but owner/ came before the debug tools did: fetch the missing
    // files once, in the background (Owner.fetchTools → Owner.refreshed → probe)
    property bool fetched: false
    readonly property bool wantsFetch: Owner.enabled && !hasCore && !coreProbe.running
    onWantsFetchChanged: if (wantsFetch && !fetched) {
        fetched = true;
        Owner.fetchTools();
    }

    // no source without the file: Qt would look for it anyway and warn in every public
    // install's log. The source is set a beat before active turns on (a later source is
    // not picked up by an active loader)
    property bool coreOn: false
    onCoreUrlChanged: Qt.callLater(() => root.coreOn = root.coreUrl !== "")
    LazyLoader {
        id: coreLoader
        source: root.coreUrl
        active: root.coreOn && (Owner.enabled || Shell.dev)
    }
}
