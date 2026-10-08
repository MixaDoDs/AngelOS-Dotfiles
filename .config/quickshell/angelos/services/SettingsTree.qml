pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The settings tree (modules/settings/tree.json): the categories on the left, their pages and
// what each page is put together from — the groups of the page files (PxGroup.name). Data, so
// moving a group to another page is a line in the JSON. Old page ids (links from the wizard,
// the tour, the helper, `angelos settings <page>`) lead to their new places through "legacy",
// and every group knows its page (the search, a link to one setting).
Singleton {
    id: root

    property var data: ({})
    // the Golden Gate skin has a tree of its own (tree.json "mac"): its look-and-feel pages and the
    // system pages without the pixel skins' groups; the pixel tree is not shown meanwhile
    readonly property bool mac: GoldenGate.on && !!data.mac
    readonly property var tree: mac ? data.mac : data
    FileView {
        id: file
        path: Quickshell.shellDir + "/modules/settings/tree.json"
        blockLoading: true
        watchChanges: Quickshell.env("ANGELOS_DEV") === "1"
        onFileChanged: reload()
        onLoaded: root.parse()
    }
    // the Windows 11 look became the default (2026-10-04): an install still on the old default
    // (the sidebar) moves to it once; a view picked on purpose stays. A beat after Config is
    // ready — the file's values land just after `ready`
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                moveOnce.restart();
        }
    }
    Timer {
        id: moveOnce
        interval: 400
        onTriggered: {
            if (!Config.ready || Config.settingsUi.win11Once)
                return;
            if (Config.settingsUi.view === "sidebar")
                Config.settingsUi.view = "win11";
            Config.settingsUi.win11Once = true;
        }
    }
    Component.onCompleted: {
        parse();
        if (Config.ready)
            moveOnce.restart();
    }
    function parse() {
        try {
            data = JSON.parse(file.text());
        } catch (e) {
            console.warn("angelOS settings: tree.json:", e);
        }
    }

    function label(o) {
        if (!o)
            return "";
        if (Angel.demon && o.ruHell)
            return I18n.t(o.ruHell, o.enHell || o.en);
        return I18n.t(o.ru, o.en);
    }
    function hint(o) {
        return o && o.hintRu ? I18n.t(o.hintRu, o.hintEn || o.hintRu) : "";
    }
    // plugins with a settings page of their own (Plugins.settingsPages): listed in the category
    // the tree names, or right after the page it says ("after": the night light after Display)
    readonly property var pluginPages: Plugins.settingsPages.map(p => ({
                "id": "plugin:" + p.id,
                "plugin": p.id,
                "label": I18n.label(p.name),
                "icon": p.icon || "plug",
                "hint": "",
                "blocks": [],
                // the manifest's "settingsNear": the page it goes after ("display", "network"…)
                "near": p.settingsNear || ""
            }))
    // "needs": the hardware a page is about ("battery", "touchpad", "laptop"): a desktop doesn't
    // see the laptop's pages (developer mode does, to look at them)
    function shown(p) {
        return !!p && (!p.owner || Owner.enabled) && (!p.developer || Config.developer.enabled) && (!p.game || Story.enabled) && (!p.needs || Laptop.has(p.needs) || Config.developer.enabled);
    }
    // every page of the tree (the hidden ones too), id -> {id, label, icon, hint, blocks, open,
    // category, owner, developer}; "open": its groups shown open (a page of sub-pages only)
    readonly property var pages: {
        const m = {};
        const acc = data.account;
        if (acc)
            m[acc.page] = {
                "id": acc.page,
                "label": label(acc),
                "icon": acc.icon,
                "hint": hint(acc),
                "blocks": acc.blocks || [],
                "category": ""
            };
        for (const c of tree.categories || [])
            for (const p of c.pages || [])
                m[p.id] = {
                    "id": p.id,
                    "label": label(p),
                    "icon": p.icon || c.icon,
                    "hint": hint(p),
                    // every group of the page; "top" shows at once, "more" folded under «Ещё…»
                    "blocks": (p.blocks || []).concat(p.more || []),
                    "top": p.blocks || [],
                    "more": p.more || [],
                    // pages next door ("lens", "game:y2k/hell" — a page, and a group on it)
                    "links": p.links || [],
                    "open": p.open || [],
                    "category": c.id,
                    "owner": !!p.owner,
                    "developer": !!p.developer,
                    "game": !!p.game,
                    "needs": p.needs || ""
                };
        for (const p of pluginPages) {
            const after = ((tree.plugins || {}).after || {})[p.plugin] || p.near;
            m[p.id] = Object.assign({}, p, {
                "category": after && m[after] ? m[after].category : (tree.plugins || {}).category || ""
            });
        }
        return m;
    }
    // the categories as they show: their visible pages, plugin pages put in, empty ones left out
    readonly property var categories: {
        const pl = tree.plugins || {};
        const after = pl.after || {};
        const out = [];
        // a plugin whose page to follow isn't in this tree (or hidden) goes to the plugins' category
        const everyId = (tree.categories || []).reduce((a, c) => a.concat((c.pages || []).filter(p => root.shown(p)).map(p => p.id)), []);
        for (const c of tree.categories || []) {
            let ids = (c.pages || []).filter(p => root.shown(p)).map(p => p.id);
            for (const p of pluginPages) {
                const a = after[p.plugin] || p.near;
                if (a && ids.includes(a))
                    ids.splice(ids.indexOf(a) + 1, 0, p.id);
                else if ((!a || !everyId.includes(a)) && pl.category === c.id)
                    ids.push(p.id);
            }
            if (!ids.length)
                continue;
            out.push({
                "id": c.id,
                "label": label(c),
                "icon": Angel.demon && c.iconHell ? c.iconHell : c.icon,
                "tint": Angel.demon && c.tintHell ? c.tintHell : c.tint,
                "hint": hint(c),
                "pages": ids
            });
        }
        return out;
    }
    // «Ещё…» opened on a page stays open for the session (page id -> true)
    property var moreOpen: ({})
    function setMoreOpen(id, open) {
        const m = Object.assign({}, moreOpen);
        if (open)
            m[id] = true;
        else
            delete m[id];
        moreOpen = m;
    }
    // the page's group (its "src/name") is under «Ещё…»
    function inMore(id, src, name) {
        const p = pages[id];
        return !!p && (p.more || []).some(b => b === src + "/" + name || b === src);
    }
    readonly property string accountPage: data.account ? data.account.page : "account"
    function page(id) {
        return pages[id] || null;
    }
    function categoryOf(id) {
        return categories.find(c => c.pages.includes(id)) || null;
    }
    // "src/name" of every group, -> the tree page it is on
    readonly property var groupPages: {
        const m = {};
        for (const id in pages)
            for (const b of pages[id].blocks)
                if (!b.endsWith("/@"))
                    m[b] = id;
        return m;
    }
    // the page a group of a page file is on now: "bar", "style" -> "taskbar"
    function pageOfGroup(src, name) {
        return groupPages[src + "/" + name] || groupPages[src] || "";
    }
    // an old page id (or a current one) -> {page, to: "src/name" | ""}
    function resolve(id) {
        // the views' own homes (the folder, the tiles) are no pages of the tree
        // the old stand-alone Community Store's page is the Plugins page now (CommunityPlugins)
        if (id === "plugin:community-store")
            id = "plugins";
        if (!id || pages[id] || id.startsWith("plugin:") || id === "home" || id === "more")
            return {
                "page": id,
                "to": ""
            };
        const l = (tree.legacy || {})[id];
        if (l)
            return {
                "page": l.page,
                "to": l.to || ""
            };
        // a page file's id whose groups went to one page
        const p = groupPages[id];
        // the Golden Gate tree: a page only the pixel skins have leads to its first page
        if (!p && mac)
            return {
                "page": tree.fallback || accountPage,
                "to": ""
            };
        return {
            "page": p || id,
            "to": ""
        };
    }
    // the page file a block comes from: "keyboard/…" -> pages/KeyboardPage.qml
    function fileOf(src) {
        return Qt.resolvedUrl("../modules/settings/pages/" + src.charAt(0).toUpperCase() + src.slice(1) + "Page.qml");
    }
    // one group of the tree on its own ("keyboard/keyboard-layouts"), for the setup wizard:
    // its file, and the page the tree puts it on (wherever tree.json moves it)
    function blockPart(block) {
        const [src, name] = block.split("/");
        return {
            "file": fileOf(src),
            "only": name ? [name] : [],
            "page": pageOfGroup(src, name)
        };
    }
    // the parts a page is put together from: one per run of blocks from the same file
    // [{file, only: [names] (empty: all), loose}] — "monitor" is the whole file
    // `which`: "top" (shown at once, the default), "more" (under «Ещё…») or "all"
    // "src/@" adds what sits outside the groups of src (a log line, the Apply buttons)
    function partsOf(id, which) {
        const p = pages[id];
        if (!p)
            return [];
        const out = [];
        const list = which === "more" ? (p.more || []) : which === "all" ? p.blocks : (p.top || p.blocks);
        for (const b of list) {
            if (b.startsWith("@owner/")) {
                out.push({
                    "file": "file://" + Owner.dir + "/" + b.slice(7),
                    "src": "",
                    "only": [],
                    "loose": true
                });
                continue;
            }
            const [src, name] = b.split("/");
            const last = out.length ? out[out.length - 1] : null;
            if (name === "@") {
                if (last && last.src === src)
                    last.loose = true;
                else
                    out.push({
                        "file": fileOf(src),
                        "src": src,
                        "only": ["@"],
                        "loose": true
                    });
                continue;
            }
            if (last && last.src === src && name && last.only.length) {
                last.only.push(name);
                continue;
            }
            out.push({
                "file": fileOf(src),
                "src": src,
                "only": name ? [name] : [],
                "loose": !name
            });
        }
        return out;
    }
}
