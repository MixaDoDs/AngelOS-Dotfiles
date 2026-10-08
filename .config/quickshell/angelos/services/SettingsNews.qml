pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What's new in Settings (like the "New" marks of Windows, KDE and macOS): a setting that
// wasn't there the last time you looked — an update added it, or renamed it — and the ones the
// release says changed (data/settings-news.json) wear a little star: on its row, its group, its
// page's tile, its section in the sidebar and on «Ещё…» while it waits in there. Leaving the page
// counts as seen (~/.local/state/angelos/settings-seen.json: id -> the day you saw it).
// Ids, from the search index (scripts/settings-index.py): "file/group" for a group,
// "file/group/Russian label" for a row.
Singleton {
    id: root

    property var seen: ({})
    property bool seenLoaded: false
    property bool hadFile: false
    property var curated: ({})

    readonly property string seenPath: Config.stateDir + "/settings-seen.json"
    AsyncFile {
        id: seenFile
        path: root.seenPath
        printErrors: false
        onLoaded: {
            try {
                root.seen = JSON.parse(text()).ids || {};
                root.hadFile = true;
            } catch (e) {
                root.seen = {};
            }
            root.seenLoaded = true;
        }
        onLoadFailed: root.seenLoaded = true
    }
    FileView {
        path: Quickshell.shellDir + "/data/settings-news.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.curated = JSON.parse(text()).items || {};
            } catch (e) {
                root.curated = {};
            }
        }
    }
    function save() {
        seenFile.write(JSON.stringify({
            "version": 1,
            "ids": seen
        }));
    }
    function today() {
        return new Date().toISOString().slice(0, 10);
    }

    readonly property var entries: SettingsSearch.entries || []
    function idOf(e) {
        if (!e.name || e.kind === "page")
            return "";
        return e.kind === "group" ? e.page + "/" + e.name : e.page + "/" + e.name + "/" + e.ru;
    }
    // the first look ever: everything there now counts as seen long ago, so only what the release
    // names (curated) shows as new; from then on whatever an update adds shows by itself
    readonly property bool ready: seenLoaded && entries.length > 0
    onReadyChanged: if (ready && !hadFile && !Shell.dev) {
        const m = {};
        for (const e of entries) {
            const id = idOf(e);
            if (id)
                m[id] = "0000-00-00";
        }
        seen = m;
        hadFile = true;
        save();
    }
    function fresh(id) {
        if (!id || !hadFile)
            return false;
        const s = seen[id];
        if (s === undefined)
            return true;
        const c = curated[id];
        return !!c && s < c;
    }

    // everything new now, by where it shows
    readonly property var news: {
        const out = {
            "count": 0,
            "groups": ({}),     // "file/group" -> true
            "rows": ({}),       // "file/group" -> [{ru, en}]
            "pages": ({}),      // tree page id -> true
            "more": ({})        // tree page id -> true: some of it under «Ещё…»
        };
        if (!ready)
            return out;
        for (const e of entries) {
            const id = idOf(e);
            if (!fresh(id))
                continue;
            const key = e.page + "/" + e.name;
            const page = SettingsTree.pageOfGroup(e.page, e.name);
            if (!page)
                continue;
            out.count++;
            if (e.kind === "group")
                out.groups[key] = true;
            else
                (out.rows[key] = out.rows[key] || []).push({
                        "ru": e.ru,
                        "en": e.en
                    });
            out.pages[page] = true;
            if (SettingsTree.inMore(page, e.page, e.name))
                out.more[page] = true;
        }
        return out;
    }
    function groupNew(src, name) {
        return !!src && !!name && !!news.groups[src + "/" + name];
    }
    function rowNew(src, group, label) {
        const list = src && group ? news.rows[src + "/" + group] : null;
        return !!list && !!label && list.some(r => r.ru === label || r.en === label);
    }
    function pageNew(id) {
        return !!news.pages[id];
    }
    function moreNew(id) {
        return !!news.more[id];
    }
    function sectionNew(section) {
        return !!section && (section.pages || []).some(id => !!news.pages[id]);
    }

    // a page was looked at: what showed on it is seen (what's under «Ещё…» only if it was open)
    function seePage(pageId, withMore) {
        if (!ready || !news.pages[pageId])
            return;
        const m = Object.assign({}, seen);
        const day = today();
        let changed = false;
        for (const e of entries) {
            const id = idOf(e);
            if (!fresh(id) || SettingsTree.pageOfGroup(e.page, e.name) !== pageId)
                continue;
            if (!withMore && SettingsTree.inMore(pageId, e.page, e.name))
                continue;
            m[id] = day;
            changed = true;
        }
        if (changed) {
            seen = m;
            save();
        }
    }
    // tests and `angelos settingsNews`: forget one id (it shows as new again) / see all
    function forget(id) {
        const m = Object.assign({}, seen);
        delete m[id];
        seen = m;
    }
    function seeAll() {
        const m = Object.assign({}, seen);
        const day = today();
        for (const e of entries) {
            const id = idOf(e);
            if (id)
                m[id] = day;
        }
        seen = m;
        save();
    }
}
