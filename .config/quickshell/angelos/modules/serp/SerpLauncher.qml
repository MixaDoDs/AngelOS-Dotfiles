pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp.settings
import "../../widgets/MacIcons.js" as MacIcons
import "launcher/EmojiData.js" as EmojiData

// serp skin (after frostpix's pc-kit): Start under the Serpantinum skin (StartOverlay's look "serp"; the
// separate app launcher, Mod+Space, opens it too — hunks/start.py). Serpantinum's launcher look:
// a 600 px card of liquid glass (frosted and tinted hard: it stands over windows), a search
// capsule, the tabs Apps · Files · Emoji (the segmented switch with the stretching plate), 44 px
// rows with the accent plate sliding under them, and a footer with the user and the power buttons.
// The logic is Golden Gate's Spotlight's (modules/mac/MacSpotlight): Start's one search
// (StartApps.searchAll: apps, the calculator, settings, actions, files…), the plugins' launcher
// providers ("web …", "claude …"), the files mode (FileSearch). An empty query shows the pinned
// apps, the frequent ones, then all. `>` runs a command (silently, or in the terminal), `?`
// searches the web (the web-search plugin, else Google).
// Keys: type to search, ↑↓ (and ←→ among the emoji) pick, PgUp/PgDn, Enter runs, Ctrl+Enter shows
// a found file in its folder, Tab / Shift+Tab or Ctrl+1…3 switch the tabs, Esc clears, then goes
// back to Apps, then closes. A right click on an app pins it (StartOverlay's menu).
Item {
    id: root

    // ---- the Start look's interface (StartOverlay) ----
    signal closeRequested
    signal menuAsked(var items, Item item, real x, real y)
    property int current: 0
    property real room: 0
    property string query: ""
    property int tab: 0                    // 0 apps · 1 files · 2 emoji
    property string powerTip: ""           // the power button under the pointer, told in the footer

    readonly property real screenW: parent && parent.parent ? parent.parent.width : 1200
    readonly property int pad: Serp.px(14)
    readonly property int rowH: Serp.px(44)
    readonly property int secH: Serp.px(26)
    readonly property int searchH: Serp.px(36)
    readonly property int tabsH: Serp.px(28)
    readonly property int footH: Serp.px(44)
    readonly property int gap: Serp.px(8)
    readonly property int chromeH: pad * 2 + searchH + tabsH + footH + gap * 3
    // as many rows as the screen has room for, eight at most (the card keeps one height)
    readonly property int listH: Math.max(rowH * 3, Math.min(rowH * 8, (room > 0 ? room : 900) - chromeH))
    width: Math.min(Serp.px(600), screenW - Serp.px(32))
    height: chromeH + listH

    // ---- the pointer takes the pick only when it moves (MacSpotlight's rule) ----
    property var _anchor: null
    property bool _pointerMoved: false
    function pointed(area, m, index) {
        if (!_pointerMoved) {
            const p = area.mapToItem(null, m.x, m.y);
            if (!_anchor) {
                _anchor = p;
                return;
            }
            if (Math.abs(p.x - _anchor.x) + Math.abs(p.y - _anchor.y) < 3)
                return;
            _pointerMoved = true;
        }
        if (current !== index)
            current = index;
    }
    function _stillPointer() {
        _anchor = null;
        _pointerMoved = false;
    }
    onRowsChanged: _stillPointer()
    onEmojisChanged: _stillPointer()

    // ---- the plugins' launcher providers (as MacSpotlight) ----
    property var providers: []
    property int providerTick: 0
    Instantiator {
        model: Plugins.launcherProviders
        delegate: LazyLoader {
            required property var modelData
            active: true
            source: Plugins.url(modelData, modelData.launcher)
            onItemChanged: {
                if (!item)
                    return;
                if (item.hasOwnProperty("plugin"))
                    item.plugin = Plugins.context(modelData);
                item.pluginId = modelData.id;
                if (item.changed)
                    item.changed.connect(() => root.providerTick++);
                root.providers = root.providers.filter(p => p.pluginId !== modelData.id).concat([item]);
            }
        }
        onObjectRemoved: (i, obj) => root.providers = root.providers.filter(p => p.pluginId !== (obj.modelData ? obj.modelData.id : ""))
    }
    readonly property var activeProvider: {
        const q = query.replace(/^\s+/, "");
        return providers.find(p => p.prefix && (q === p.prefix || q.startsWith(p.prefix + " "))) || null;
    }
    readonly property var webProvider: providers.find(p => p.pluginId === "web-search") || null
    function providerRows(p, text, prefixed) {
        let list = [];
        try {
            list = p.query(text, prefixed) || [];
        } catch (e) {
            console.warn("serp launcher provider", p.pluginId, e);
        }
        const pl = Plugins.byId(p.pluginId);
        const section = pl ? I18n.label(pl.name) : p.pluginId;
        return list.slice().sort((x, y) => (y.score === undefined ? 10 : y.score) - (x.score === undefined ? 10 : x.score)).map(r => ({
                    "section": section,
                    "label": String(r.title || ""),
                    "sub": String(r.subtitle || ""),
                    "mac": MacIcons.fromPixel(r.icon || "") || "puzzle",
                    "image": r.image ? (String(r.image).startsWith("/") ? "file://" + r.image : String(r.image)) : "",
                    "provider": p,
                    "r": r
                }));
    }

    // ---- rows ----
    readonly property bool searching: query.trim() !== ""
    readonly property string trimmed: query.replace(/^\s+/, "")
    readonly property bool cmdMode: tab === 0 && trimmed.startsWith(">")
    readonly property bool webMode: tab === 0 && trimmed.startsWith("?")
    function matches(label, q) {
        return String(label).toLowerCase().indexOf(q) >= 0;
    }
    function appRow(a, section) {
        return {
            "section": section,
            "label": a.name,
            "sub": a.genericName || a.comment || "",
            "app": a,
            "run": () => StartApps.launch(a)
        };
    }
    function fileRow(f, section) {
        return {
            "section": section,
            "label": f.name,
            "sub": FileSearch.where(f),
            "mac": FileSearch.macIcon(f),
            "file": f,
            "run": () => FileSearch.open(f)
        };
    }
    function plain(list, section, icon) {
        return list.map(r => ({
                    "section": section,
                    "label": r.label,
                    "sub": r.sub || "",
                    "mac": icon || "",
                    "run": r.run
                }));
    }
    // a command: silently (sh -c), or in the terminal that stays open after it
    function cmdRows(cmd) {
        const sec = I18n.t("Команда", "Command");
        if (!cmd)
            return [
                {
                    "section": sec,
                    "label": "> …",
                    "sub": I18n.t("набери команду", "type a command"),
                    "mac": "terminal"
                }
            ];
        return [
            {
                "section": sec,
                "label": I18n.t("Выполнить: ", "Run: ") + cmd,
                "sub": I18n.t("в фоне, sh -c", "in the background, sh -c"),
                "mac": "zap",
                "run": () => Shell.sh(cmd)
            },
            {
                "section": sec,
                "label": I18n.t("В терминале: ", "In the terminal: ") + cmd,
                "sub": Config.system.terminal || "kitty",
                "mac": "terminal",
                "run": () => Shell.exec(Shell.terminalArgv(["sh", "-c", cmd + "; exec \"${SHELL:-sh}\""]))
            }
        ];
    }
    function webRows(text) {
        if (webProvider)
            return text ? providerRows(webProvider, text, true).slice(0, 30) : [];
        if (!text)
            return [];
        return [
            {
                "section": I18n.t("Веб", "Web"),
                "label": I18n.t("Искать в Google", "Search with Google"),
                "sub": text,
                "mac": "globe",
                "run": () => Shell.exec(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(text)])
            }
        ];
    }
    readonly property var rows: {
        if (tab === 2)
            return [];
        const q = query.trim().toLowerCase();
        if (tab === 1)
            return plain(StartItems.places, I18n.t("Папки", "Folders"), "folder").filter(r => !searching || matches(r.label, q)).concat(searching ? FileSearch.rows(query, 60).map(f => fileRow(f, I18n.t("Файлы", "Files"))) : []);
        if (cmdMode)
            return cmdRows(trimmed.slice(1).trim());
        providerTick;
        if (webMode)
            return webRows(trimmed.slice(1).trim());
        if (!searching) {
            // Serpantinum's empty launcher: what you keep, what you use, then everything
            const pinned = StartApps.apps.filter(a => StartApps.isPinned(a));
            const freq = StartApps.frequent.filter(a => !pinned.includes(a)).slice(0, 6);
            const rest = StartApps.apps.filter(a => !pinned.includes(a) && !freq.includes(a));
            return pinned.map(a => appRow(a, I18n.t("Закреплённые", "Pinned"))).concat(freq.map(a => appRow(a, I18n.t("Частые", "Frequent"))), rest.map(a => appRow(a, I18n.t("Все приложения", "All apps"))));
        }
        if (activeProvider)
            return providerRows(activeProvider, trimmed.slice(activeProvider.prefix.length).trim(), true).slice(0, 40);
        const out = [];
        for (const r of StartApps.searchAll(query, 24)) {
            if (r.kind === "calc")
                out.push({
                    "section": I18n.t("Калькулятор", "Calculator"),
                    "label": r.calc.title,
                    "sub": r.calc.subtitle || I18n.t("Enter — скопировать", "Enter copies"),
                    "mac": "calculator",
                    "run": () => Calc.copy(r.calc)
                });
            else if (r.kind === "app")
                out.push(appRow(r.app, I18n.t("Приложения", "Applications")));
            else if (r.kind === "file")
                out.push(fileRow(r.file, I18n.t("Файлы", "Files")));
            else if (r.kind !== "setting")
                out.push({
                    "section": r.kind === "action" ? I18n.t("Действия", "Actions") : r.kind === "vault" ? I18n.t("Пароли", "Passwords") : I18n.t("Таймеры", "Timers"),
                    "label": r.title,
                    "sub": r.sub,
                    "mac": r.kind === "action" ? "zap" : r.kind === "vault" ? "lock" : "clock",
                    "run": r.run
                });
            else
                out.push({
                    "section": I18n.t("Настройки", "Settings"),
                    "label": r.doc.title,
                    "sub": r.doc.crumb || r.doc.hint || "",
                    "mac": "settings",
                    "run": () => StartApps.openSetting(r.doc)
                });
        }
        for (const p of plain(StartItems.places, I18n.t("Папки", "Folders"), "folder"))
            if (matches(p.label, q))
                out.push(p);
        for (const a of plain(StartItems.power, I18n.t("Действия", "Actions"), "zap"))
            if (matches(a.label, q) && !out.some(o => o.label === a.label))
                out.push(a);
        for (const p of providers)
            if (p.global !== false)
                for (const r of providerRows(p, query.trim(), false).slice(0, 6))
                    out.push(r);
        const order = [];
        for (const r of out)
            if (!order.includes(r.section))
                order.push(r.section);
        return order.reduce((acc, s) => acc.concat(out.filter(r => r.section === s)), []).slice(0, 40);
    }
    // where each row stands in the list (the section headers above the first of each): the plate's y
    readonly property var rowYs: {
        const ys = [];
        let s = 0;
        for (let i = 0; i < rows.length; i++) {
            if ((i === 0 || rows[i].section !== rows[i - 1].section) && rows[i].section)
                s += secH;
            ys.push(i * rowH + s);
        }
        return ys;
    }

    // ---- emoji (Serpantinum's list) ----
    readonly property int emojiCols: 8
    readonly property var emojis: tab === 2 ? EmojiData.search(query.trim(), searching ? 160 : 400) : []
    readonly property int count: tab === 2 ? emojis.length : rows.length
    function runEmoji(e) {
        if (!e)
            return;
        Quickshell.execDetached(["wl-copy", "--", e.emoji]);
        closeRequested();
    }

    // ---- acting ----
    function runRow(r) {
        if (!r)
            return;
        if (r.provider) {
            let keep = false;
            try {
                keep = r.provider.activate(r.r.id, r.r) === true;
            } catch (e) {
                console.warn("serp launcher provider", r.provider.pluginId, e);
            }
            if (!keep)
                closeRequested();
            return;
        }
        if (!r.run)
            return;
        closeRequested();
        Qt.callLater(r.run);
    }
    function askMenu(r, from, x, y) {
        if (r.app)
            menuAsked(StartApps.menuFor(r.app, () => runRow(r)), from, x, y);
        else if (r.file) {
            const f = r.file;
            menuAsked(StartApps.fileMenuFor(() => {
                closeRequested();
                FileSearch.reveal(f);
            }, () => runRow(r)), from, x, y);
        }
    }
    function runPower(b) {
        closeRequested();
        Qt.callLater(b.run);
    }

    // ---- the Start look's interface ----
    function setQuery(t) {
        field.text = t;
        query = t;
        current = 0;
        scrollTop();
    }
    function reset() {
        _stillPointer();
        query = "";
        field.text = "";
        current = 0;
        tab = Shell.startMode === "files" ? 1 : 0;
        Shell.startMode = "";
        scrollTop();
        Qt.callLater(() => field.forceActiveFocus());
    }
    function setTab(t) {
        tab = (t + 3) % 3;
        current = 0;
        scrollTop();
        field.forceActiveFocus();
    }
    function scrollTop() {
        list.positionViewAtBeginning();
        emojiGrid.positionViewAtBeginning();
    }
    function move(d) {
        if (!count)
            return;
        current = Math.max(0, Math.min(count - 1, current + d));
        if (tab === 2)
            emojiGrid.positionViewAtIndex(current, GridView.Contain);
        else
            list.positionViewAtIndex(current, ListView.Contain);
    }
    readonly property var pickedFile: tab !== 2 && rows[current] && rows[current].file ? rows[current].file : null
    function key(e) {
        const ctrl = e.modifiers & Qt.ControlModifier;
        if (ctrl && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && pickedFile) {
            const f = pickedFile;
            closeRequested();
            FileSearch.reveal(f);
            e.accepted = true;
            return;
        }
        if (ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_3) {
            setTab(e.key - Qt.Key_1);
            e.accepted = true;
            return;
        }
        const step = tab === 2 ? emojiCols : 1;
        const page = tab === 2 ? emojiCols * 4 : Math.max(1, Math.floor(listH / rowH) - 1);
        switch (e.key) {
        case Qt.Key_Tab:
            setTab(tab + 1);
            break;
        case Qt.Key_Backtab:
            setTab(tab - 1);
            break;
        case Qt.Key_Down:
            move(current < 0 ? 1 : step);
            break;
        case Qt.Key_Up:
            move(-step);
            break;
        case Qt.Key_PageDown:
            move(page);
            break;
        case Qt.Key_PageUp:
            move(-page);
            break;
        case Qt.Key_Right:
            if (tab !== 2)
                return;
            move(1);
            break;
        case Qt.Key_Left:
            if (tab !== 2)
                return;
            move(-1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (tab === 2)
                runEmoji(emojis[current]);
            else
                runRow(rows[current]);
            break;
        case Qt.Key_Escape:
            if (query !== "")
                setQuery("");
            else if (tab !== 0)
                setTab(0);
            else
                closeRequested();
            break;
        case Qt.Key_Backspace:
            field.text = field.text.slice(0, -1);
            query = field.text;
            current = 0;
            break;
        default:
            if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                field.text += e.text;
                query = field.text;
                current = 0;
                field.forceActiveFocus();
            } else
                return;
        }
        e.accepted = true;
    }

    // ---- the card ----
    // the wallpaper in screen space for the glass: the window covers the screen, the card stands
    // where StartOverlay's Loader puts it
    SerpBackdrop {
        id: glassBack
        origin: Qt.point(root.parent ? root.parent.x : 0, root.parent ? root.parent.y : 0)
    }
    SGlass {
        id: card
        anchors.fill: parent
        radius: Serp.radius
        backdrop: glassBack
        tintAmount: Math.max(Serp.cfg.glassTint, 0.75)  // text-heavy, over windows: must read
        frost: 6
        // flat: niri blurs nothing under Start's Spotlight-like looks, so a plate that reads
        Rectangle {
            visible: !card.glass
            anchors.fill: parent
            radius: card.radius
            color: Serp.solid
            border.width: 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        }
        MouseArea {
            anchors.fill: parent
            onClicked: field.forceActiveFocus()
        }
    }

    // ---- the search capsule ----
    Rectangle {
        id: search
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: root.searchH
        radius: height / 2
        color: card.glass ? Qt.alpha(Serp.surface0, 0.55) : Serp.surface0
        border.width: 1
        border.color: field.activeFocus ? Qt.alpha(Serp.accent, 0.55) : Qt.alpha(Serp.surface2, 0.6)
        Behavior on border.color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
        SIcon {
            id: lens
            x: Serp.px(14)
            anchors.verticalCenter: parent.verticalCenter
            name: root.cmdMode ? "terminal" : root.webMode ? "globe" : "search"
            size: Serp.px(15)
            color: field.activeFocus ? Serp.accent : Serp.subtext0
        }
        TextInput {
            id: field
            anchors.left: lens.right
            anchors.leftMargin: Serp.px(10)
            anchors.right: modeChip.visible ? modeChip.left : parent.right
            anchors.rightMargin: Serp.px(12)
            anchors.verticalCenter: parent.verticalCenter
            font.family: Serp.font
            font.pixelSize: Serp.px(12)
            font.letterSpacing: 1
            color: Serp.text
            selectionColor: Serp.selected
            selectedTextColor: Serp.text
            clip: true
            focus: true
            cursorDelegate: Rectangle {
                width: Serp.px(2)
                color: Serp.accent
                visible: field.activeFocus
            }
            onTextEdited: {
                root.query = text;
                root.current = 0;
                root.scrollTop();
            }
            Keys.onPressed: e => {
                const k = e.key;
                const nav = [Qt.Key_Down, Qt.Key_Up, Qt.Key_PageDown, Qt.Key_PageUp, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape, Qt.Key_Tab, Qt.Key_Backtab];
                if (nav.includes(k) || ((e.modifiers & Qt.ControlModifier) && k >= Qt.Key_1 && k <= Qt.Key_3) || (root.tab === 2 && (k === Qt.Key_Left || k === Qt.Key_Right)))
                    root.key(e);
            }
            SText {
                visible: field.text === ""
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                text: root.tab === 1 ? I18n.t("Поиск файлов: имя или .jpeg…", "Search files: a name or .jpeg…") : root.tab === 2 ? I18n.t("Эмодзи по имени (по-английски)…", "Emoji by name…") : I18n.t("Поиск…  > команда  ? веб", "Search…  > command  ? web")
                size: Serp.px(12)
                dim: true
            }
        }
        // what the prefix turned the search into
        Rectangle {
            id: modeChip
            visible: root.cmdMode || root.webMode || !!root.activeProvider
            anchors.right: parent.right
            anchors.rightMargin: Serp.px(6)
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + Serp.px(16)
            height: parent.height - Serp.px(10)
            radius: height / 2
            color: Serp.selected
            SText {
                id: chipText
                anchors.centerIn: parent
                text: root.cmdMode ? I18n.t("команда", "command") : root.webMode ? I18n.t("веб", "web") : root.activeProvider ? root.activeProvider.prefix : ""
                size: Serp.px(10)
                bold: true
                color: Serp.accent
            }
        }
    }

    // ---- the tabs ----
    SSwitch {
        id: tabs
        x: root.pad
        y: search.y + search.height + root.gap
        width: root.width - root.pad * 2
        height: root.tabsH
        options: [I18n.t("Приложения", "Apps"), I18n.t("Файлы", "Files"), I18n.t("Эмодзи", "Emoji")]
        currentIndex: root.tab
        onPicked: i => root.setTab(i)
    }

    // ---- the list ----
    Item {
        id: listArea
        x: root.pad - Serp.px(4)
        y: tabs.y + tabs.height + root.gap
        width: root.width - (root.pad - Serp.px(4)) * 2
        height: root.listH
        clip: true

        ListView {
            id: list
            visible: root.tab !== 2
            anchors.fill: parent
            model: root.tab === 2 ? [] : root.rows
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            cacheBuffer: root.rowH * 6
            section.property: "section"
            section.delegate: SText {
                required property string section
                width: list.width
                height: section ? root.secH : 0
                leftPadding: Serp.px(10)
                verticalAlignment: Text.AlignBottom
                bottomPadding: Serp.px(5)
                text: section.toUpperCase()
                size: Serp.px(10)
                bold: true
                font.letterSpacing: 1
                color: Serp.subtext0
            }
            // the accent plate: slides from row to row (not ListView's own highlight)
            Rectangle {
                id: plate
                parent: list.contentItem
                z: -1
                readonly property var picked: root.tab !== 2 && root.current >= 0 && root.current < root.rows.length ? root.rows[root.current] : null
                readonly property bool valid: !!picked && (!!picked.run || !!picked.provider)
                x: 0
                width: list.width
                height: root.rowH
                radius: Serp.radiusSmall
                color: Serp.accent
                y: root.rowYs[Math.max(0, Math.min(root.current, root.rowYs.length - 1))] || 0
                opacity: valid ? 1 : 0
                Behavior on y {
                    NumberAnimation {
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }
            }
            delegate: SerpLauncherRow {
                required property var modelData
                r: modelData
                width: list.width
                host: root
                sel: plate.valid && root.current === index
            }
        }

        GridView {
            id: emojiGrid
            visible: root.tab === 2
            anchors.fill: parent
            model: root.emojis
            cellWidth: width / root.emojiCols
            cellHeight: Serp.px(52)
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            cacheBuffer: cellHeight * 4
            Rectangle {
                id: emojiPlate
                parent: emojiGrid.contentItem
                z: -1
                readonly property bool valid: root.tab === 2 && root.current >= 0 && root.current < root.emojis.length
                x: (Math.max(0, root.current) % root.emojiCols) * emojiGrid.cellWidth + Serp.px(3)
                y: Math.floor(Math.max(0, root.current) / root.emojiCols) * emojiGrid.cellHeight + Serp.px(3)
                width: emojiGrid.cellWidth - Serp.px(6)
                height: emojiGrid.cellHeight - Serp.px(6)
                radius: Serp.radiusSmall
                color: Serp.accent
                opacity: valid ? 1 : 0
                Behavior on x {
                    NumberAnimation {
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool sel: root.current === index
                width: emojiGrid.cellWidth
                height: emojiGrid.cellHeight
                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.emoji
                    font.pixelSize: Serp.px(26)
                    color: Serp.text
                    scale: cell.sel ? 1.15 : emojiMa.containsMouse ? 1.08 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.25
                        }
                    }
                }
                MouseArea {
                    id: emojiMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: m => root.pointed(this, m, cell.index)
                    onClicked: root.runEmoji(cell.modelData)
                }
            }
        }

        SText {
            visible: root.count === 0
            anchors.centerIn: parent
            width: parent.width - Serp.px(60)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: root.webMode ? I18n.t("что искать в интернете?", "What to search the web for?") : root.tab === 1 && !root.searching ? I18n.t("набери имя файла", "Type a file name") : I18n.t("ничего не нашлось", "Nothing found")
            dim: true
        }
    }

    // ---- the footer: the user, the power buttons ----
    Rectangle {
        x: root.pad
        y: listArea.y + listArea.height + root.gap - Serp.px(4)
        width: root.width - root.pad * 2
        height: 1
        color: Serp.line
    }
    Item {
        id: footer
        x: root.pad
        y: listArea.y + listArea.height + root.gap
        width: root.width - root.pad * 2
        height: root.footH

        Item {
            id: face
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(30)
            height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Serp.surface1
                border.width: 1
                border.color: Qt.alpha(Serp.accent, 0.6)
            }
            SerpLockRound {
                id: avatar
                anchors.fill: parent
                anchors.margins: Serp.px(2)
                source: StartPrefs.avatarUrl
            }
            SIcon {
                visible: !avatar.ready
                anchors.centerIn: parent
                name: "user"
                size: Serp.px(15)
                color: Serp.subtext1
            }
        }
        Column {
            anchors.left: face.right
            anchors.leftMargin: Serp.px(10)
            anchors.right: powerRow.left
            anchors.rightMargin: Serp.px(10)
            anchors.verticalCenter: parent.verticalCenter
            SText {
                width: parent.width
                text: StartPrefs.userName
                size: Serp.px(12)
                bold: true
            }
            SText {
                width: parent.width
                text: root.powerTip ? root.powerTip : root.tab === 2 && root.emojis[root.current] ? root.emojis[root.current].emoji + "  " + root.emojis[root.current].name + I18n.t("  · Enter — скопировать", "  · Enter copies") : root.pickedFile ? I18n.t("Ctrl+Enter — показать в папке", "Ctrl+Enter shows it in its folder") : "Tab · ↑↓ · Enter"
                size: Serp.px(10)
                dim: true
            }
        }
        Row {
            id: powerRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Serp.px(2)
            Repeater {
                model: StartItems.power
                SButton {
                    id: pb
                    required property var modelData
                    implicitWidth: Serp.px(30)
                    implicitHeight: Serp.px(30)
                    SIcon {
                        name: ({
                                "logout": "log-out",
                                "refresh": "refresh-cw"
                            })[pb.modelData.icon] || MacIcons.fromPixel(pb.modelData.icon || "") || "circle-dot"
                        size: Serp.px(15)
                        color: pb.hovered ? Serp.accent : Serp.subtext1
                    }
                    onClicked: root.runPower(pb.modelData)
                    onHoveredChanged: root.powerTip = hovered ? modelData.label : (root.powerTip === modelData.label ? "" : root.powerTip)
                }
            }
        }
    }
}
