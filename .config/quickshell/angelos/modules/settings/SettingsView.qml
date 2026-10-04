pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.views
import qs.modules.settings.dresses

// Settings content (frame, navigation, pages). Hosted by SettingsWindow.
// Every page and every section is described once, here (pageList, runs) and in the pages'
// own QML; the views (Config.settingsUi.view, modules/settings/views) are only ways of
// laying them out:
//   sidebar      like macOS's System Settings: search and the sections on the left, the
//                page on the right (what every install had before the views)
//   controlpanel a Win98 Control Panel: a folder of icons, a page fills the window
//   properties   a Win98 properties sheet: pick a section, its pages are tabs
//   tiles        big tiles under a big search field
// A view gives three slots — searchSlot (the search field), resultsSlot (what it finds),
// pageSlot (the page) — and this file puts its single search field, results list and page
// Loader into them, so a page is never built twice and plugins' pages work in every view.
// The keyboard is the same everywhere: Ctrl+F searches, ↓ from an empty search walks the
// view's navigation (arrows, Enter; typing searches again), Ctrl+PgUp/PgDn the sections,
// Ctrl+Tab the pages of a section, Alt+↑ goes up, Alt+←/→ through the history.
// The skins (Config.settingsUi.skin: classic | windose | stream) dress any view. While the
// demon rules it is her grimoire (GrimoireBook): the sidebar becomes the book's spread, any
// other view is written on one parchment page inside the same leather cover — or the
// circle's own dress (story/circles.json → dress, modules/settings/dresses: the case file,
// the letter, the bill of fare…), the view written on its page the same way.
Item {
    id: win

    Component.onCompleted: {
        lastLoc = loc;
        Shell.settingsView = win;
        Theme.scriptWindow = scriptHost;
        Theme.inkWindow = inkHost;
        Theme.macWindow = macHost;
        if (typeof SettingsSearch.reload === "function")
            SettingsSearch.reload();
        else
            SettingsSearch.load();
        SettingsKeys.load();
    }
    Component.onDestruction: {
        if (Shell.settingsView === win)
            Shell.settingsView = null;
        if (Theme.scriptWindow === win.Window.window)
            Theme.scriptWindow = null;
        if (Theme.inkWindow === win.Window.window)
            Theme.inkWindow = null;
        if (Theme.macWindow === win.Window.window)
            Theme.macWindow = null;
    }
    function diagnostics() {
        return {
            page: Shell.settingsPage,
            sub: Shell.settingsSub,
            section: sectionOf(Shell.settingsPage),
            view: viewId,
            dress: dressId,
            viewStatus: viewLoader.status,
            atHome: atHome,
            source: String(page.source),
            status: atHome ? Loader.Ready : page.status,
            sidebarVisible: !!viewItem && viewItem.sidebarVisible === true,
            settingsSkin: page.item && page.item.settingsSkin !== undefined ? page.item.settingsSkin : atHome ? skin : "",
            plugin: page.item && page.item.loadedPlugin !== undefined ? page.item.loadedPlugin : "",
            query: query,
            results: results.length,
            navActive: navActive
        };
    }
    property var hostWindow: null
    readonly property Item frame: mac ? macFrame : pxFrame
    readonly property var pageItem: atHome ? null : page.item
    // while the demon rules (Y2K → Angel or demon → Settings in hell): a grimoire (GrimoireBook)
    // or a circle's own dress (HellLook.settingsPick)
    readonly property string dressId: Angel.demon ? HellLook.settingsPick : ""
    readonly property bool grimoire: dressId === "grimoire"
    readonly property bool dressed: dressId !== "" && !grimoire
    readonly property bool hellDress: grimoire || dressed
    // …written by hand: every PxText in this window takes the grimoire's script (Theme.fontScript)
    // (the letter, lust's dress, is handwritten too)
    readonly property var scriptHost: grimoire || dressId === "letter" ? win.Window.window : null
    onScriptHostChanged: Theme.scriptWindow = scriptHost
    readonly property var inkHost: hellDress ? win.Window.window : null
    onInkHostChanged: Theme.inkWindow = inkHost
    // Classic stays the default; Windose and Stream are optional settings skins. Golden Gate is
    // the whole desktop's skin (services/GoldenGate): here it is macOS's System Settings — its
    // own view (views/MacView.qml), the Windows 11 look's cards drawn as a Mac's grouped rows
    readonly property string skin: ["classic", "windose", "stream", "goldengate"].includes(Config.settingsUi.skin) ? Config.settingsUi.skin : "classic"
    readonly property bool mac: skin === "goldengate" && !hellDress
    readonly property string settingsSkin: hellDress ? "classic" : mac ? "goldengate" : fluent ? "classic" : skin
    readonly property var macHost: mac ? win.Window.window : null
    onMacHostChanged: Theme.macWindow = macHost
    // (there is no simple view or Expert any more: every page is a click away)
    readonly property bool expert: true

    // ---- the views ----
    readonly property var views: [
        {
            "id": "win11",
            "file": "Win11View.qml",
            "label": I18n.t("Как в Windows 11", "Like Windows 11"),
            "hint": I18n.t("категории слева, карточки справа", "categories on the left, cards on the right")
        },
        {
            "id": "sidebar",
            "file": "SidebarView.qml",
            "label": I18n.t("Боковая панель", "Sidebar"),
            "hint": I18n.t("разделы слева, страница справа", "sections on the left, the page on the right")
        },
        {
            "id": "controlpanel",
            "file": "ControlPanelView.qml",
            "label": I18n.t("Панель управления", "Control Panel"),
            "hint": I18n.t("папка значков, как в Win98", "a folder of icons, like Win98")
        },
        {
            "id": "properties",
            "file": "PropertiesView.qml",
            "label": I18n.t("Свойства", "Properties"),
            "hint": I18n.t("раздел сверху, его страницы — вкладки", "a section on top, its pages as tabs")
        },
        {
            "id": "tiles",
            "file": "TilesView.qml",
            "label": I18n.t("Плитки", "Tiles"),
            "hint": I18n.t("крупный поиск и большие плитки", "a big search and big tiles")
        }
    ]
    readonly property string viewId: mac ? "mac" : views.some(v => v.id === Config.settingsUi.view) ? Config.settingsUi.view : "win11"
    // the Windows 11 look: a category with several pages has a page of its own ("cat:<id>",
    // CategoryPage), sub-pages unfold in place (PxGroup), every setting is a card (SettingRow)
    readonly property bool fluent: viewId === "win11" || viewId === "mac"
    readonly property var viewItem: viewLoader.item
    // a folder of icons / the tiles: "home" is the view's own screen, no page on it
    readonly property bool hasHome: viewId === "controlpanel" || viewId === "tiles"
    readonly property bool atHome: hasHome && (Shell.settingsPage === "home" || Shell.settingsPage === "more")
    // properties: a section's pages and a page's sub-pages are its tabs, not links on the page
    readonly property bool ownsSubpages: viewId === "properties"
    // the grimoire's spread is the sidebar laid out as a book
    readonly property bool spread: grimoire && viewId === "sidebar"

    // ---- every page, by id: titles, the page loader, the search's crumbs ----
    // The tree (services/SettingsTree, modules/settings/tree.json): your account, the
    // categories and their pages, each put together from groups of the page files
    // (ComposedPage); plugins' own pages are in it too.
    readonly property var pageList: Object.keys(SettingsTree.pages).map(id => SettingsTree.pages[id])
    function pageEntry(id) {
        if (String(id).startsWith("cat:")) {
            const c = SettingsTree.categories.find(x => x.id === id.slice(4));
            return c ? {
                "id": id,
                "label": c.label,
                "icon": c.icon
            } : null;
        }
        return pageList.find(p => p.id === id) || null;
    }
    function labelOf(id) {
        const p = pageEntry(id);
        return p ? p.label : id;
    }
    // owner-only pages vanish in the public version, Plugin Studio is for developers
    function pageShown(id) {
        return SettingsTree.shown(pageEntry(id));
    }

    // ---- the sections: the tree's categories (the sidebar's lines, the folder's icons) ----
    readonly property var runs: [
        {
            "title": "",
            "sections": SettingsTree.categories
        }
    ]
    // what is shown: pages the user may see, sections with something left
    readonly property var visibleRuns: runs.map(r => ({
                "title": r.title,
                "sections": r.sections.map(s => Object.assign({}, s, {
                        "pages": s.pages.filter(id => win.pageShown(id))
                    })).filter(s => s.pages.length > 0)
            })).filter(r => r.sections.length > 0)
    readonly property var visibleSections: visibleRuns.reduce((a, r) => a.concat(r.sections), [])
    // your account as a section of its own (the sidebar's card; the folder's and the
    // properties' first entry)
    readonly property var accountSection: ({
            "id": "account",
            "label": labelOf(SettingsTree.accountPage),
            "icon": "heart",
            "tint": Theme.accent,
            "pages": [SettingsTree.accountPage]
        })
    // the views with a home show every section in its run, your account first
    readonly property var homeRuns: [
        {
            "title": I18n.t("Ты", "You"),
            "sections": [accountSection]
        }
    ].concat(visibleRuns)
    readonly property var navSections: [accountSection].concat(visibleSections)
    // the same as groups of sections (the grimoire's contents, Windose and Stream's home)
    readonly property var visibleGroups: visibleRuns.map(r => ({
                "title": r.title,
                "pages": r.sections.map(s => ({
                        "id": s.pages[0],
                        "label": s.label,
                        "icon": s.icon
                    }))
            }))
    readonly property var allPages: [pageEntry("account")].concat(visibleSections.reduce((a, s) => a.concat(s.pages.map(id => win.pageEntry(id))), [])).filter(p => !!p)
    readonly property string currentId: Shell.settingsPage === "home" || Shell.settingsPage === "more" ? "account" : Shell.settingsPage
    readonly property var currentPage: currentId.startsWith("cat:") ? pageEntry(currentId) : allPages.find(p => p.id === currentId) || null
    function sectionFor(id) {
        return visibleSections.find(s => s.pages.includes(id)) || null;
    }
    function sectionOf(id) {
        if (id === "home" || id === "more" || id === "account")
            return "account";
        if (String(id).startsWith("cat:"))
            return id.slice(4);
        const s = sectionFor(id);
        return s ? s.id : "";
    }
    // the section a page belongs to, your account included
    function navSectionOf(id) {
        const sid = sectionOf(id);
        return navSections.find(s => s.id === sid) || null;
    }
    function tintOf(id) {
        const s = sectionFor(id);
        return s ? s.tint : Theme.accent;
    }
    // the section's first page for its other pages ("‹ Sound" on System sounds)
    function parentOf(id) {
        const s = sectionFor(id);
        // the Windows 11 look: up from a page is its category's own page
        if (fluent)
            return s && s.pages.length > 1 ? "cat:" + s.id : "";
        return s && s.pages[0] !== id ? s.pages[0] : "";
    }
    // a section's first page lists the others as links
    function subpagesOf(id) {
        if (fluent)
            return [];
        const s = sectionFor(id);
        return s && s.pages[0] === id ? s.pages.slice(1).map(p => win.pageEntry(p)).filter(p => !!p) : [];
    }
    function openSection(s) {
        Shell.settingsPage = fluent && s.pages.length > 1 ? "cat:" + s.id : s.pages[0];
        Shell.settingsSub = "";
    }
    // the page's advanced groups: its sub-pages ("Title ›")
    readonly property var subTitles: pageItem && pageItem.advancedGroups ? pageItem.advancedGroups.map(g => g.title) : []
    // every place in the current section, in order: its pages, each with its sub-pages
    // (known for the open page only) — the properties' tabs, Ctrl+Tab everywhere
    readonly property var sectionLocs: {
        const s = navSectionOf(currentId);
        const out = [];
        for (const id of s ? s.pages : [currentId]) {
            out.push({
                "page": id,
                "sub": "",
                "label": labelOf(id),
                "child": false
            });
            if (id === currentId)
                for (const t of subTitles)
                    out.push({
                        "page": id,
                        "sub": t,
                        "label": t,
                        "child": true
                    });
        }
        return out;
    }
    function goLocOf(l) {
        if (Shell.settingsPage !== l.page)
            Shell.settingsPage = l.page;
        Shell.settingsSub = l.sub || "";
    }

    // ---- old page ids (the wizard, the tour, the helper, scripts) → their places in the tree ----
    Connections {
        target: Shell
        function onSettingsPageChanged() {
            win.redirect();
        }
    }
    function redirect() {
        const r = SettingsTree.resolve(Shell.settingsPage);
        if (r.page === Shell.settingsPage)
            return;
        Shell.settingsPage = r.page;
        if (r.to)
            showGroup(r.to);
    }
    // scroll to a group ("src/name") once the page is there, opening it if it is a sub-page
    function showGroup(ref) {
        pendingTarget = {
            "kind": "name",
            "target": String(ref).split("/").slice(-1)[0],
            "crumb": ""
        };
        targetTimer.restart();
    }

    // ---- moving around: the same keys in every view ----
    function navSection(delta) {
        const list = navSections;
        if (!list.length)
            return;
        let i = list.findIndex(s => s.id === sectionOf(Shell.settingsPage));
        if (atHome)
            i = delta > 0 ? -1 : 0;
        const next = list[((i < 0 ? 0 : i) + delta + list.length * 2) % list.length];
        openSection(next);
    }
    function navPage(delta) {
        const locs = sectionLocs;
        if (locs.length < 2 || atHome)
            return;
        const i = Math.max(0, locs.findIndex(l => l.page === currentId && l.sub === Shell.settingsSub));
        goLocOf(locs[(i + delta + locs.length) % locs.length]);
    }
    // up one level: a sub-page → its page → the section's first page → the view's home
    function goUp() {
        if (Shell.settingsSub !== "") {
            Shell.settingsSub = "";
            return true;
        }
        const parentId = parentOf(currentId);
        if (parentId) {
            Shell.settingsPage = parentId;
            return true;
        }
        if (hasHome && !atHome) {
            goHome();
            return true;
        }
        return false;
    }
    function goHome() {
        Shell.settingsPage = hasHome ? "home" : "account";
        Shell.settingsSub = "";
    }
    // a page's subtitle, its first sentence (from the search index): the tiles' small print
    function pageHint(id) {
        const e = (SettingsSearch.entries || []).find(x => x.kind === "page" && x.page === id);
        const t = e && e.hint ? String(I18n.english ? e.hint.en : e.hint.ru) : "";
        const cut = t.search(/[.!?](\s|$)/);
        return cut > 0 ? t.slice(0, cut) : t;
    }
    // the pages opened most (the account's "Everyday", the tiles' row)
    function frequent(n) {
        // visits counted under old page ids count for their pages in the tree
        const raw = Config.settingsUi.usage || {};
        const usage = {};
        for (const id in raw) {
            const to = SettingsTree.resolve(id).page;
            usage[to] = (usage[to] || 0) + raw[id];
        }
        return Object.keys(usage).filter(id => usage[id] >= 2 && allPages.some(p => p.id === id)).sort((a, b) => usage[b] - usage[a]).slice(0, n).map(id => pageEntry(id));
    }

    // ---- "Revert changes" (properties): everything changed since the window opened ----
    property var sessionStep: null
    property bool sessionMarked: false
    readonly property bool sessionChanged: sessionMarked && Config.canUndo && Config.lastStep !== sessionStep
    function revertSession() {
        Config.flush();
        let guard = 60;
        while (Config.canUndo && Config.lastStep !== sessionStep && guard-- > 0)
            Config.undo();
    }

    // ---- history: ◀ ▶ like a browser (a page and its sub-page) ----
    property var backStack: []
    property var forwardStack: []
    property string lastLoc: ""             // set once at start, then by recordLoc (no binding)
    property bool travelling: false
    readonly property string loc: Shell.settingsPage + "|" + Shell.settingsSub
    onLocChanged: Qt.callLater(recordLoc)
    function recordLoc() {
        if (loc === lastLoc)
            return;
        if (!travelling) {
            backStack = backStack.filter(l => l !== loc).concat([lastLoc]).slice(-30);
            forwardStack = [];
            // how often each page is opened: the account page's "Everyday" follows it (a
            // category's own page is a way through, not a page anyone wants back)
            if (Config.ready && Shell.settingsOpen && Shell.settingsSub === "" && Shell.settingsPage !== "home" && Shell.settingsPage !== "more" && !Shell.settingsPage.startsWith("cat:")) {
                const u = Object.assign({}, Config.settingsUi.usage || {});
                u[Shell.settingsPage] = (u[Shell.settingsPage] || 0) + 1;
                Config.settingsUi.usage = u;
            }
        }
        travelling = false;
        lastLoc = loc;
    }
    Connections {
        target: Shell
        function onSettingsOpenChanged() {
            if (!Shell.settingsOpen) {
                win.backStack = [];
                win.forwardStack = [];
                win.sessionMarked = false;
                win.query = "";
                searchInput.text = "";
            } else {
                Config.flush();
                win.sessionStep = Config.lastStep;
                win.sessionMarked = true;
                Qt.callLater(win.focusSearch);
            }
        }
    }
    function goLoc(l) {
        const [p, sub] = l.split("|");
        travelling = true;
        Shell.settingsPage = p;
        Shell.settingsSub = sub || "";
        Qt.callLater(recordLoc);
    }
    readonly property bool canBack: backStack.length > 0
    readonly property bool canForward: forwardStack.length > 0
    readonly property string backTarget: canBack ? backStack[backStack.length - 1].split("|")[0] : "account"
    readonly property string backLabel: labelOf(backTarget)
    function back() {
        recordLoc();
        if (!canBack)
            return;
        const b = backStack.slice();
        const target = b.pop();
        backStack = b;
        forwardStack = forwardStack.concat([loc]);
        goLoc(target);
    }
    function forward() {
        recordLoc();
        if (!canForward)
            return;
        const f = forwardStack.slice();
        const target = f.pop();
        forwardStack = f;
        backStack = backStack.concat([loc]);
        goLoc(target);
    }
    // the home of the folder and tiles views, as the first crumb
    readonly property string homeLabel: viewId === "controlpanel" ? I18n.t("Панель управления", "Control Panel") : I18n.t("Все настройки", "All settings")
    // where you are, for the toolbar: Section › Page › Sub-page
    readonly property var crumbs: {
        const out = [];
        if (fluent) {
            const c = String(currentId).startsWith("cat:") ? SettingsTree.categories.find(x => x.id === currentId.slice(4)) : sectionFor(currentId);
            if (currentId === "account" || !c)
                out.push(labelOf(currentId));
            else {
                if (c.pages.length > 1 || currentId.startsWith("cat:"))
                    out.push(c.label);
                if (!currentId.startsWith("cat:"))
                    out.push(labelOf(currentId));
            }
            if (Shell.settingsSub)
                out.push(Shell.settingsSub);
            return out;
        }
        if (hasHome)
            out.push(homeLabel);
        if (atHome)
            return out;
        const s = sectionFor(currentId);
        if (currentId === "account")
            out.push(labelOf("account"));
        else if (s) {
            out.push(s.label);
            if (s.pages[0] !== currentId)
                out.push(labelOf(currentId));
        } else
            out.push(labelOf(currentId));
        if (Shell.settingsSub)
            out.push(Shell.settingsSub);
        return out;
    }
    // a crumb clicked: up to that level (the home, the section's first page, the page)
    function crumbClicked(index) {
        if (fluent) {
            const c = sectionFor(currentId) || navSectionOf(currentId);
            if (index === 0 && c && c.pages.length > 1 && !currentId.startsWith("cat:"))
                openSection(c);
            else
                Shell.settingsSub = "";
            return;
        }
        const at = hasHome ? index - 1 : index;
        if (at < 0)
            return goHome();
        const s = sectionFor(currentId);
        if (at === 0 && s)
            openSection(s);
        else
            Shell.settingsSub = "";
    }

    // ---- search (services/SettingsSearch) ----
    property string query: ""
    property int sel: 0
    property var results: []
    onQueryChanged: {
        if (!query.trim())
            results = [];
        searchTimer.restart();
    }
    // one frame: keys typed together are searched once (a search takes ~1 ms)
    Timer {
        id: searchTimer
        interval: 16
        onTriggered: win.results = win.query.trim() ? SettingsSearch.search(win.query, 14) : []
    }
    Connections {
        target: SettingsSearch
        function onDocsChanged() {
            if (win.query.trim())
                searchTimer.restart();
        }
    }
    readonly property string ghost: query ? SettingsSearch.complete(query) : ""
    property var pendingTarget: null
    Binding {
        target: SettingsSearch
        property: "pageInfo"
        value: {
            const m = {};
            for (const p of win.allPages) {
                const s = win.sectionFor(p.id);
                m[p.id] = {
                    "label": s && s.pages[0] !== p.id ? s.label + " › " + p.label : p.label,
                    "icon": p.icon
                };
            }
            return m;
        }
    }
    // `angelos settingsQuery "…"`: type into the search box (scripts, previews)
    function setQuery(t) {
        searchInput.text = t;
        query = t;
        sel = 0;
        searchInput.focusField();
    }
    function focusSearch() {
        if (Shell.settingsOpen)
            searchInput.focusField();
    }
    function acceptGhost() {
        if (!ghost)
            return false;
        searchInput.text = query + ghost;
        query = searchInput.text;
        sel = 0;
        return true;
    }
    function openResult(r) {
        if (!r)
            return;
        pendingTarget = r.kind === "page" ? null : r;
        query = "";
        searchInput.text = "";
        if (Shell.settingsPage === r.page)
            targetTimer.restart();
        else
            Shell.settingsPage = r.page;
        if (r.kind === "page")
            Shell.settingsSub = "";
    }
    // the found setting: on the page (a visible one) or anywhere in it (`any`)
    function findItem(item, r, any) {
        if (!item || (!any && !item.visible))
            return null;
        if (r.kind === "row" && item.label === r.target && item.hint !== undefined)
            return item;
        if (r.kind === "group" && item.title === r.target && item.spacing !== undefined)
            return item;
        if (r.kind === "name" && item.name === r.target && item.advanced !== undefined)
            return item;
        for (const c of item.children) {
            const f = findItem(c, r, any);
            if (f)
                return f;
        }
        return null;
    }
    function groupOf(item) {
        for (let p = item; p; p = p.parent)
            if (p.advanced !== undefined && p.title !== undefined)
                return p;
        return null;
    }
    // scroll the page to the found setting and flash it; one in a sub-page opens it first
    function showTarget() {
        const r = pendingTarget;
        pendingTarget = null;
        const pg = page.item;
        if (!r || !pg || !pg.flick)
            return;
        const groupHint = {
            "kind": "group",
            "target": String(r.crumb).split(" › ").slice(-1)[0] || ""
        };
        let it = findItem(pg.flick.contentItem, r, false) || (r.kind === "row" ? findItem(pg.flick.contentItem, groupHint, false) : null);
        if (!it) {
            const hidden = findItem(pg.flick.contentItem, r, true) || (r.kind === "row" ? findItem(pg.flick.contentItem, groupHint, true) : null);
            const g = hidden ? groupOf(hidden) : null;
            if (g && g.advanced && !r.opened && Shell.settingsSub !== g.title) {
                Shell.settingsSub = g.title;
                pendingTarget = Object.assign({}, r, {
                    "opened": true
                });
                targetTimer.restart();
            }
            return;
        }
        const y = it.mapToItem(pg.flick.contentItem, 0, 0).y;
        pg.scrollBy(Math.max(0, y - Theme.u * 8) - pg.flick.contentY);
        flashComp.createObject(it);
    }
    Timer {
        id: targetTimer
        interval: 80
        onTriggered: win.showTarget()
    }
    Component {
        id: flashComp
        Rectangle {
            id: flash
            anchors.fill: parent
            anchors.margins: -Theme.u * 2
            z: 100
            color: Qt.alpha(Theme.accent, 0.12)
            border.width: Math.max(2, Theme.u)
            border.color: Theme.accent
            SequentialAnimation on opacity {
                running: true
                PauseAnimation {
                    duration: Motion.ms(900)
                }
                NumberAnimation {
                    to: 0
                    duration: Motion.ms(900)
                }
                ScriptAction {
                    script: flash.destroy()
                }
            }
        }
    }

    // ---- the keyboard ----
    // the view's navigation (the sections, the icons, the tabs, the tiles) takes the arrows
    // while this has the focus: ↓ from an empty search field, or a click into it
    readonly property bool navActive: navFocus.activeFocus
    function focusNav() {
        navFocus.forceActiveFocus();
    }
    function navKey(e) {
        if (viewItem && viewItem.navKey && viewItem.navKey(e))
            return true;
        if (e.key === Qt.Key_Escape) {
            if (!goUp())
                focusSearch();
            return true;
        }
        if (e.key === Qt.Key_Backspace)
            return goUp() || true;
        if (e.text && e.text.length === 1 && e.text >= " " && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            // typing searches
            searchInput.text = searchInput.text + e.text;
            query = searchInput.text;
            sel = 0;
            searchInput.focusField();
            return true;
        }
        return false;
    }
    // `angelos settingsKey …` (dev): the same, without a real key press
    function navKeyForTest(key) {
        return navKey({
            "key": key,
            "text": "",
            "modifiers": 0
        });
    }
    Item {
        id: navFocus
        Keys.onPressed: e => {
            if (win.navKey(e))
                e.accepted = true;
        }
    }
    Shortcut {
        sequences: ["Ctrl+F", "Ctrl+K"]
        onActivated: win.focusSearch()
    }
    // Ctrl+Z: the last change of a setting goes back (Config.undo)
    Shortcut {
        sequence: "Ctrl+Z"
        enabled: Config.canUndo
        onActivated: Config.undo()
    }
    // ◀ ▶ from the keyboard too, like Finder (Ctrl+[ / Ctrl+], Alt+← / Alt+→)
    Shortcut {
        sequences: ["Ctrl+[", "Alt+Left"]
        onActivated: win.back()
    }
    Shortcut {
        sequences: ["Ctrl+]", "Alt+Right"]
        onActivated: win.forward()
    }
    Shortcut {
        sequence: "Alt+Up"
        onActivated: win.goUp()
    }
    Shortcut {
        sequence: "Alt+Home"
        onActivated: win.goHome()
    }
    Shortcut {
        sequence: "Ctrl+PgDown"
        onActivated: win.navSection(1)
    }
    Shortcut {
        sequence: "Ctrl+PgUp"
        onActivated: win.navSection(-1)
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: win.navPage(1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
        onActivated: win.navPage(-1)
    }

    // ---- the grimoire: the book's cover (and, for the sidebar, its spread) ----
    GrimoireBook {
        id: book
        anchors.fill: parent
        view: win
        visible: win.grimoire
        spread: win.spread
    }
    // …or the circle's own dress round one page
    Loader {
        id: dressLoader
        anchors.fill: parent
        active: win.dressed
        function load() {
            if (win.dressed)
                setSource(Qt.resolvedUrl("dresses/" + win.dressId.charAt(0).toUpperCase() + win.dressId.slice(1) + "Dress.qml"), {
                    "view": win
                });
        }
        Component.onCompleted: load()
        Connections {
            target: win
            function onDressIdChanged() {
                dressLoader.load();
            }
        }
    }
    // the grimoire (or the dress) re-inks what it shows on its paper
    readonly property var inkSource: dressed && dressLoader.item ? dressLoader.item : book
    Component {
        id: inkFx
        ShaderEffect {
            fragmentShader: Qt.resolvedUrl("../../shaders/grimoire.frag.qsb")
            property color paper: win.inkSource.paper
            property color ink: win.inkSource.ink
            property color redInk: win.inkSource.redInk
            property real invert: Theme.dark ? 1 : 0
        }
    }

    // the Golden Gate skin: a Mac window — niri rounds and shadows it (templates/niri-mac.kdl), the
    // view draws the traffic lights and the toolbar
    Rectangle {
        id: macFrame
        visible: win.mac
        anchors.fill: parent
        color: GoldenGate.contentBg
        Item {
            id: macHost
            anchors.fill: parent
        }
    }
    PxWindow {
        id: pxFrame
        visible: !win.hellDress && !win.mac
        anchors.fill: parent
        anchors.rightMargin: Config.appearance.shadows ? Theme.u * 2 : 0
        anchors.bottomMargin: Config.appearance.shadows ? Theme.u * 2 : 0
        skin: win.skin
        title: win.viewId === "properties" ? I18n.t("Свойства: ", "Properties: ") + (win.navSectionOf(win.currentId) || win.accountSection).label : (win.skin === "windose" ? I18n.exe("settings") + " ♡ " : "angelOS · ") + (win.atHome ? win.homeLabel : win.currentPage ? win.currentPage.label : I18n.t("Настройки", "Settings"))
        icon: win.atHome ? "gear" : win.currentPage ? win.currentPage.icon : "gear"
        minimizable: false
        maximizable: true
        onCloseClicked: Shell.settingsOpen = false
        onMaximizeClicked: if (win.hostWindow)
            win.hostWindow.maximized = !win.hostWindow.maximized
        onTitlePressed: if (win.hostWindow)
            win.hostWindow.startSystemMove()
        bodyPadding: Theme.u * 4

        Item {
            id: viewHost
            anchors.fill: parent
        }

        // resize grip
        PxIcon {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -Theme.u * 3
            name: "sparkle"
            fill: Theme.textDim
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.u * 3
                cursorShape: Qt.SizeFDiagCursor
                onPressed: if (win.hostWindow)
                    win.hostWindow.startSystemResize(Edges.Bottom | Edges.Right)
            }
        }
    }

    // the chosen view; in the grimoire's spread its place is taken by the book
    Item {
        id: offstage
        visible: false
    }
    Loader {
        id: viewLoader
        parent: win.mac ? macHost : !win.hellDress ? viewHost : win.spread ? offstage : win.dressed ? (dressLoader.item ? dressLoader.item.viewSlot : offstage) : book.viewSlot
        anchors.fill: parent
        layer.enabled: (win.grimoire && !win.spread) || win.dressed
        layer.effect: inkFx
        function load() {
            const v = win.viewId === "mac" ? {
                "file": "MacView.qml"
            } : win.views.find(x => x.id === win.viewId) || win.views[0];
            setSource(Qt.resolvedUrl("views/" + v.file), {
                "view": win
            });
        }
        Component.onCompleted: load()
        Connections {
            target: win
            function onViewIdChanged() {
                viewLoader.load();
            }
        }
    }

    // ---- what every view shares: one search field, one results list, one page ----
    readonly property int searchFieldHeight: searchInput.implicitHeight
    readonly property bool searchFocused: searchInput.input.activeFocus
    Item {
        id: searchArea
        parent: win.spread ? book.fieldSlot : win.viewItem && win.viewItem.searchSlot ? win.viewItem.searchSlot : offstage
        anchors.fill: parent
        z: 5
        layer.enabled: win.spread
        layer.effect: inkFx

        PxField {
            id: searchInput
            keepFocus: true
            width: parent.width
            kind: win.viewItem && win.viewItem.searchBig ? "title" : "body"
            icon: "search"
            placeholder: win.viewItem && win.viewItem.searchBig ? I18n.t("Что настроить?", "What would you like to change?") : I18n.t("Поиск", "Search")
            onEdited: {
                win.query = text;
                win.sel = 0;
            }
            onAccepted: win.openResult(win.results[Math.min(win.sel, win.results.length - 1)])
            onKeyPressed: e => {
                if (e.key === Qt.Key_Tab || (e.key === Qt.Key_Right && searchInput.input.cursorPosition === searchInput.text.length)) {
                    if (win.acceptGhost())
                        e.accepted = true;
                } else if (e.key === Qt.Key_Down) {
                    // results first; with nothing typed ↓ walks the view's navigation
                    if (win.query.trim() === "")
                        win.focusNav();
                    else
                        win.sel = Math.min(win.results.length - 1, win.sel + 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Up) {
                    win.sel = Math.max(0, win.sel - 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape && searchInput.text !== "") {
                    searchInput.text = "";
                    win.query = "";
                    e.accepted = true;
                }
            }
            // the rest of the suggested word, dimmed after the caret: "Bl" → "ur"
            PxText {
                visible: win.ghost !== "" && searchInput.input.activeFocus && searchInput.input.contentWidth + implicitWidth < searchInput.input.width
                x: searchInput.input.x + searchInput.input.contentWidth
                anchors.verticalCenter: parent.verticalCenter
                text: win.ghost
                font: searchInput.input.font
                color: Theme.textDim
                opacity: 0.8
            }
        }
        PxText {
            visible: win.ghost !== "" && searchInput.input.activeFocus
            anchors.top: searchInput.bottom
            anchors.right: searchInput.right
            anchors.topMargin: Theme.u
            text: "Tab ↹ " + searchInput.text + win.ghost
            kind: "tiny"
            dim: true
            width: searchInput.width
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }

    // results: wherever the view puts them, while there is a query
    Item {
        id: resultsArea
        parent: win.spread ? book.resultsSlot : win.viewItem && win.viewItem.resultsSlot ? win.viewItem.resultsSlot : offstage
        anchors.fill: parent
        visible: win.query.trim() !== ""
        z: 5
        layer.enabled: win.spread
        layer.effect: inkFx
        Rectangle {
            visible: win.spread
            anchors.fill: parent
            color: Theme.face
        }
        PxScroll {
            id: resultsBox
            anchors.fill: parent
            contentHeight: resultCol.implicitHeight
            Column {
                id: resultCol
                width: parent.width
                spacing: Theme.u
                PxText {
                    visible: win.results.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: SettingsSearch.loaded ? I18n.t("Ничего не нашлось. Попробуй другое слово — «экран», «прозрачность», «хоткеи»…", "Nothing found. Try another word — “display”, “transparency”, “hotkeys”…") : "…"
                    dim: true
                    leftPadding: Theme.u * 3
                }
                Repeater {
                    model: win.results
                    Rectangle {
                        id: res
                        required property var modelData
                        required property int index
                        readonly property bool picked: win.sel === index
                        width: resultCol.width
                        height: resRow.implicitHeight + Theme.u * 4
                        color: picked ? Theme.select : rm.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.15) : "transparent"
                        Row {
                            id: resRow
                            x: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 3
                            PxIcon {
                                name: res.modelData.icon || "gear"
                                anchors.verticalCenter: parent.verticalCenter
                                ink: res.picked ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
                            }
                            Column {
                                width: res.width - Theme.u * 20
                                PxText {
                                    width: parent.width
                                    text: res.modelData.title
                                    elide: Text.ElideRight
                                    font.bold: res.modelData.kind === "page"
                                    color: res.picked ? Theme.selectText : Theme.text
                                }
                                PxText {
                                    visible: text !== ""
                                    width: parent.width
                                    text: res.modelData.crumb || res.modelData.hint
                                    kind: "tiny"
                                    elide: Text.ElideRight
                                    color: res.picked ? Theme.selectText : Theme.textDim
                                }
                            }
                        }
                        MouseArea {
                            id: rm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = res.index
                            onClicked: win.openResult(res.modelData)
                        }
                    }
                }
            }
        }
    }

    // the page itself
    Loader {
        id: page
        parent: win.spread ? book.pageSlot : win.viewItem && win.viewItem.pageSlot ? win.viewItem.pageSlot : offstage
        anchors.fill: parent
        layer.enabled: win.spread
        layer.effect: inkFx
        visible: !win.atHome
        active: win.hostWindow ? win.hostWindow.visible : true
        onLoaded: if (win.pendingTarget)
            targetTimer.restart()
        // the page to show: a page of the tree is put together (ComposedPage) — the same file
        // for every one of them, so it is loaded anew with its key whenever the page changes
        readonly property string want: {
            const id = Shell.settingsPage;
            if (id === "home" || id === "more") {
                // the folder and the tiles show their own home, no page
                if (win.hasHome)
                    return "";
                // the old home: your account in Classic, Windose and Stream keep their own
                return win.skin === "classic" || win.hellDress || win.viewId !== "sidebar" ? "tree:" + SettingsTree.accountPage : id === "home" ? "pages/HomePage.qml" : "pages/MorePage.qml";
            }
            if (id.startsWith("plugin:"))
                return "pages/PluginSettingsPage.qml";
            if (id.startsWith("cat:"))
                return id;
            if (id === "dotfiles" && !Owner.enabled)
                return "tree:" + SettingsTree.accountPage;
            return "tree:" + (win.allPages.find(p => p.id === id) ? id : SettingsTree.accountPage);
        }
        onWantChanged: reload()
        Component.onCompleted: reload()
        function reload() {
            if (want.startsWith("tree:"))
                setSource(Qt.resolvedUrl("ComposedPage.qml"), {
                    "pageKey": want.slice(5)
                });
            else if (want.startsWith("cat:"))
                setSource(Qt.resolvedUrl("CategoryPage.qml"), {
                    "categoryId": want.slice(4)
                });
            else
                source = want;
        }
    }
}
