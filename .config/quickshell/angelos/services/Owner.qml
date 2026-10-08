pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Owner-only features (dotfiles pull/publish) exist only when ALL of this holds:
//   <shell>/owner/                  — never published (see owner/checks.sh)
//   ~/.config/angelos/owner         — marker with `remote=<public dotfiles repo url>` (and
//                                     optionally `admin=<private admin repo url>`), never published
//   the user check                  — the GitHub account logged in here (gh) administers
//                                     the dotfiles repo (scripts/owner-check.sh; GitHub's
//                                     answer, remembered 14 days for offline use)
// In the public version none of it exists, so none of this shows up.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/owner"
    readonly property string markerPath: Config.dir + "/owner"
    property bool hasDir: false
    property bool hasMarker: false
    property string remote: ""
    property string admin: ""
    // whose admin rights make the owner: the public dotfiles repo (only its owner
    // administers it), the admin repo for an old marker without remote=
    readonly property string checkRepo: remote || admin
    // the user check: "admin" | "cached" | "denied" | "unknown" | "" (not asked yet)
    property string check: ""
    property string login: ""
    readonly property bool verified: check === "admin" || check === "cached"
    readonly property bool enabled: hasDir && hasMarker && verified
    // look again for owner/ and the marker, then ask GitHub (the setup wizard, after it
    // fetched the author's tools)
    // (services/GameDebug looks for owner/debug again on it)
    signal refreshed
    function refresh() {
        dirProbe.running = false;
        dirProbe.running = true;
        marker.reload();
        recheck();
        refreshed();
    }
    // ask GitHub again (the Dotfiles page has a button; also every 6 hours)
    function recheck() {
        if (!hasDir || !hasMarker || !checkRepo)
            return;
        verify.running = false;
        verify.running = true;
    }
    Process {
        id: verify
        command: ["sh", Quickshell.shellDir + "/scripts/owner-check.sh", root.checkRepo]
        stdout: StdioCollector {
            onStreamFinished: {
                const [state, who] = text.trim().split(" ");
                root.check = state || "unknown";
                root.login = who || "";
            }
        }
    }
    onHasDirChanged: recheck()
    onCheckRepoChanged: recheck()
    Timer {
        interval: 6 * 3600 * 1000
        running: root.hasDir && root.hasMarker
        repeat: true
        onTriggered: root.recheck()
    }
    // the author's tools again (scripts/author-tools.sh fetch: only the files not there yet,
    // e.g. owner/debug that came after owner/): the Dotfiles page's button, and once by
    // itself when owner/debug is missing (services/GameDebug); nothing for anyone else
    readonly property bool fetching: fetcher.running
    property string fetchNote: ""
    function fetchTools() {
        if (fetcher.running)
            return;
        fetchNote = "";
        fetcher.running = true;
    }
    Process {
        id: fetcher
        command: ["sh", Quickshell.shellDir + "/scripts/author-tools.sh", "fetch"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                root.fetchNote = text.trim().split("\n").pop()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.fetchNote = text.trim().split("\n").pop()
        }
        onExited: root.refresh()
    }
    // background jobs live here so an update keeps running when the settings page closes
    readonly property var jobs: jobsLoader.item

    Process {
        id: dirProbe
        running: true
        command: ["test", "-f", root.dir + "/DotfilesJobs.qml"]
        onExited: code => root.hasDir = code === 0
    }
    FileView {
        id: marker
        path: root.markerPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.hasMarker = true;
            const m = text().match(/^remote=(.+)$/m);
            root.remote = m ? m[1].trim() : "";
            const a = text().match(/^admin=(.+)$/m);
            root.admin = a ? a[1].trim() : "";
        }
        onLoadFailed: {
            root.hasMarker = false;
            root.remote = "";
            root.admin = "";
            root.check = "";
        }
    }
    LazyLoader {
        id: jobsLoader
        active: root.enabled
        // no source without owner/: Qt would look for the file anyway and warn in
        // every public install's log (seen in an issue's angelos report). hasDir, not
        // enabled: the source has to be there before active turns on, a later source
        // is not picked up
        source: root.hasDir ? "file://" + root.dir + "/DotfilesJobs.qml" : ""
    }
}
