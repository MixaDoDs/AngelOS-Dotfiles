pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Qt.labs.folderlistmodel
import qs.config
import qs.services

// What the Golden Gate Dock holds (MacDock draws it): the apps kept in it (Config.mac.dockApps; by
// default the file manager, Apps, the browser, the terminal, Start's pinned apps and System
// Settings), then the apps that run but are not kept, a divider, the minimized windows
// (services/Minimize), Downloads and the Trash. An app is running when niri has a window whose
// app id leads to its .desktop file — a minimized one counts.
Singleton {
    id: root

    Component.onCompleted: if (!DefaultApps.data || !DefaultApps.data.files)
        DefaultApps.refresh()

    function entryOf(id) {
        if (!id)
            return null;
        const bare = String(id).replace(/\.desktop$/, "");
        return DesktopEntries.byId(bare) || DesktopEntries.heuristicLookup(bare);
    }
    function defaultId(cat) {
        const d = DefaultApps.data && DefaultApps.data[cat];
        return d && d.current ? String(d.current).replace(/\.desktop$/, "") : "";
    }
    // the ids kept in the Dock ("@apps" — the Apps grid, "@settings" — System Settings)
    readonly property var keptIds: {
        const own = Config.mac.dockApps || [];
        if (own.length)
            return own;
        const out = [defaultId("files") || "org.gnome.Nautilus", "@apps", defaultId("browser"), defaultId("terminal")];
        for (const id of Config.bar.startPinned || [])
            out.push(String(id).replace(/\.desktop$/, ""));
        out.push("@settings");
        return out.filter((id, i) => id && out.indexOf(id) === i);
    }
    // the windows of each running app: entry id (or app id) -> [window], most recent first
    readonly property var running: {
        const out = {};
        const ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos : 0;
        for (const w of Niri.windows.slice().sort((a, b) => ts(b) - ts(a))) {
            const e = entryOf(w.app_id);
            const key = e ? e.id : String(w.app_id || "");
            if (!key)
                continue;
            (out[key] = out[key] || []).push(w);
        }
        return out;
    }
    function appItem(id, kept) {
        if (id === "@apps")
            return {
                "kind": "apps",
                "id": id,
                "name": I18n.t("Приложения", "Apps"),
                "kept": true,
                "windows": []
            };
        if (id === "@settings")
            return {
                "kind": "settings",
                "id": id,
                "name": I18n.t("Системные настройки", "System Settings"),
                "kept": true,
                "windows": Niri.windows.filter(w => w.app_id === "org.quickshell" && String(w.title).indexOf("angelOS") === 0)
            };
        const e = entryOf(id);
        const key = e ? e.id : id;
        return {
            "kind": "app",
            "id": key,
            "entry": e,
            "name": e && e.name ? e.name : AppMenu.prettyName(id),
            "icon": e ? e.icon : id,
            "kept": kept,
            "windows": running[key] || []
        };
    }
    readonly property var apps: {
        const out = [];
        const seen = {};
        for (const id of keptIds) {
            const it = appItem(id, true);
            if (it.kind === "app" && !it.entry)
                continue;           // uninstalled since
            if (seen[it.id])
                continue;
            seen[it.id] = true;
            out.push(it);
        }
        for (const key in running) {
            if (seen[key] || key === "org.quickshell")
                continue;
            seen[key] = true;
            out.push(appItem(key, false));
        }
        return out;
    }
    // the minimized windows, oldest first: a snapshot each, its app's icon in the corner
    readonly property var minimized: Minimize.windows.map(w => {
        const e = entryOf(w.app_id);
        return {
            "kind": "window",
            "id": "@w" + w.id,
            "wid": w.id,
            "entry": e,
            "name": Niri.titleOf(w) || (e && e.name ? e.name : AppMenu.prettyName(w.app_id)),
            "icon": e ? e.icon : w.app_id,
            "shot": Minimize.shots[w.id] || "",
            "windows": []
        };
    })
    function isKept(id) {
        return keptIds.includes(id);
    }
    function setKept(id, on) {
        const ids = keptIds.slice();
        const i = ids.indexOf(id);
        if (on && i < 0)
            ids.splice(Math.max(0, ids.indexOf("@settings")), 0, id);
        else if (!on && i >= 0)
            ids.splice(i, 1);
        Config.mac.dockApps = ids;
    }

    // ---- Downloads and the Trash ----
    readonly property string downloads: Config.home + "/Downloads"
    readonly property string trashFiles: Config.home + "/.local/share/Trash/files"
    // (a folder that isn't there lists another one: the first file must be in the Trash)
    readonly property bool trashFull: trashModel.count > 0 && String(trashModel.get(0, "filePath")).indexOf(trashFiles + "/") === 0
    FolderListModel {
        id: trashModel
        folder: "file://" + root.trashFiles
        showHidden: true
        showDirs: true
        showDotAndDotDot: false
    }

    // the Downloads stack (MacStack, a left click on Downloads): the folder's newest first
    readonly property int stackMax: 15
    property var recent: []                  // [{path, name, dir, suffix, modified}], newest first
    property int recentMore: 0               // how many more are in the folder
    FolderListModel {
        id: downloadsModel
        folder: "file://" + root.downloads
        sortField: FolderListModel.Time      // QDir::Time: the newest first
        showDirs: true
        showDirsFirst: false
        showHidden: false
        showDotAndDotDot: false
        onCountChanged: recentTimer.restart()
        onStatusChanged: recentTimer.restart()
    }
    Timer {
        id: recentTimer
        interval: 150
        onTriggered: root.refreshRecent()
    }
    function refreshRecent() {
        const out = [];
        let total = 0;
        const n = downloadsModel.status === FolderListModel.Ready ? downloadsModel.count : 0;
        for (let i = 0; i < n; i++) {
            const path = String(downloadsModel.get(i, "filePath"));
            // a folder that isn't there lists another one; half-downloaded files aren't shown
            if (path.indexOf(downloads + "/") !== 0 || /\.(part|crdownload|download)$/i.test(path))
                continue;
            total++;
            if (out.length < stackMax)
                out.push({
                    "path": path,
                    "name": String(downloadsModel.get(i, "fileName")),
                    "dir": !!downloadsModel.get(i, "fileIsDir"),
                    "suffix": String(downloadsModel.get(i, "fileName")).indexOf(".") > 0 ? String(downloadsModel.get(i, "fileName")).split(".").pop().toLowerCase() : "",
                    "modified": downloadsModel.get(i, "fileModified")
                });
        }
        recent = out;
        recentMore = total - out.length;
    }
    // a file of the stack: its default app (xdg-open)
    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }
    // the file manager of Settings → Default apps (DefaultApps "files"), at a folder
    readonly property string fileManagerId: defaultId("files")
    readonly property string fileManagerName: {
        const e = entryOf(fileManagerId);
        return e && e.name ? e.name : I18n.t("Файлы", "Files");
    }
    function openInFileManager(path) {
        if (fileManagerId)
            Quickshell.execDetached(["gtk-launch", fileManagerId, path]);
        else if (Config.system.fileManager)
            Quickshell.execDetached([Config.system.fileManager, path]);
        else
            Shell.openPath(path);
    }

    // ---- what a click does ----
    property var bouncing: ({})             // entry id -> true while it starts
    function open(it) {
        if (it.kind === "apps") {
            Shell.openApps(Shell.focusedScreen ? Shell.focusedScreen.name : "");
            return;
        }
        if (it.kind === "settings") {
            Shell.openSettings();
            return;
        }
        if (it.kind === "window") {
            Minimize.restore(it.wid);
            return;
        }
        // only minimized windows: the last one comes back
        const shown = it.windows.filter(w => !Minimize.isMinimized(w));
        if (it.windows.length && !shown.length) {
            const m = Minimize.windows.filter(w => it.windows.some(x => x.id === w.id));
            Minimize.restore((m[m.length - 1] || it.windows[0]).id);
            return;
        }
        if (shown.length) {
            // the app in front already: its next window; otherwise its last used one
            const front = AppMenu.window;
            const mine = shown;
            const i = front ? mine.findIndex(w => w.id === front.id) : -1;
            Niri.focusWindow(i >= 0 ? mine[(i + 1) % mine.length].id : mine[0].id);
            return;
        }
        if (it.entry) {
            StartApps.launch(it.entry);
            const b = Object.assign({}, bouncing);
            b[it.id] = true;
            bouncing = b;
            bounceStop.restart();
        }
    }
    // a window of a bouncing app came: it stops (or after 8 s anyway)
    onRunningChanged: {
        let changed = false;
        const b = Object.assign({}, bouncing);
        for (const id in b)
            if (running[id]) {
                delete b[id];
                changed = true;
            }
        if (changed)
            bouncing = b;
    }
    Timer {
        id: bounceStop
        interval: 8000
        onTriggered: root.bouncing = ({})
    }
    function quit(it) {
        for (const w of it.windows)
            Niri.closeWindow(w.id);
    }
    function openTrash() {
        Quickshell.execDetached(["gio", "open", "trash:///"]);
    }
    function emptyTrash() {
        Quickshell.execDetached(["gio", "trash", "--empty"]);
    }
    function openDownloads() {
        openInFileManager(downloads);
    }

    function short(s) {
        s = String(s);
        return s.length > 48 ? s.slice(0, 46) + "…" : s;
    }
    // the Dock menu of an app (right click): its windows, New Window, Keep in Dock, Quit
    function menuFor(it) {
        if (it.kind === "window")
            return AppMenu.tidy([MacMenus.fn("d:open", I18n.t("Открыть", "Open"), () => Minimize.restore(it.wid)), AppMenu.sep("d1"), MacMenus.fn("d:close", I18n.t("Закрыть", "Close"), () => Niri.closeWindow(it.wid))]);
        const out = [];
        // a minimized one with a diamond, as on a Mac (Niri.focusWindow brings it back)
        for (const w of it.windows)
            out.push(MacMenus.fn("d:w" + w.id, (Minimize.isMinimized(w) ? "◆ " : "") + root.short(Niri.titleOf(w) || it.name), () => Niri.focusWindow(w.id), {
                "toggle": "check",
                "checked": AppMenu.window && AppMenu.window.id === w.id
            }));
        if (it.windows.length)
            out.push(AppMenu.sep("d1"));
        const acts = it.entry && it.entry.actions ? it.entry.actions : [];
        for (let i = 0; i < acts.length; i++)
            out.push(MacMenus.fn("d:a" + i, acts[i].name, () => acts[i].execute()));
        if (acts.length)
            out.push(AppMenu.sep("d2"));
        if (it.kind === "app") {
            out.push(MacMenus.fn("d:keep", I18n.t("Оставить в Dock", "Keep in Dock"), () => root.setKept(it.id, !root.isKept(it.id)), {
                "toggle": "check",
                "checked": root.isKept(it.id)
            }));
            if (!it.windows.length)
                out.push(MacMenus.fn("d:open", I18n.t("Открыть", "Open"), () => root.open(it)));
        }
        if (it.windows.length)
            out.push(AppMenu.sep("d3"), MacMenus.fn("d:quit", I18n.t("Завершить", "Quit"), () => root.quit(it)));
        return AppMenu.tidy(out);
    }
    function trashMenu() {
        return AppMenu.tidy([MacMenus.fn("t:open", I18n.t("Открыть", "Open"), root.openTrash), AppMenu.sep("t1"), AppMenu.submenu("t:empty", I18n.t("Очистить Корзину", "Empty Trash"), trashFull ? [MacMenus.fn("t:yes", I18n.t("Удалить всё в Корзине навсегда", "Delete Everything in the Trash Permanently"), root.emptyTrash)] : [])]);
    }
}
