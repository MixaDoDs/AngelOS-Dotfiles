pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// App launcher ("Run…" dialog). Fuzzy search, frequent apps first, ">" runs a shell command,
// files by name or type (FileSearch: "sex", ".jpeg") with a preview beside it; Ctrl+Enter shows
// a found file in its folder.
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Shell.launcherOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.25)
    WlrLayershell.namespace: "angelos-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: the launcher: a click beside it closes it
    WlrLayershell.keyboardFocus: visible && !focusKick ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    // opened while a menu's grab was ending (issue #22): if the keyboard did not
    // arrive, ask niri again — the interactivity goes None and back
    property bool focusKick: false
    Timer {
        id: focusCheck
        interval: 150
        onTriggered: {
            if (win.visible && !field.Window.active && !win.focusKick) {
                win.focusKick = true;
                Qt.callLater(() => {
                    win.focusKick = false;
                    field.focusField();
                });
            }
        }
    }

    property string query: ""
    property int current: 0
    property int providerTick: 0   // bumped when a provider has fresh async results
    readonly property bool command: query.startsWith(">")
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)

    // plugin launcher providers (manifest "launcher"), instantiated once
    property var providers: []
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
                    item.changed.connect(() => win.providerTick++);
                win.providers = win.providers.filter(p => p.pluginId !== modelData.id).concat([item]);
            }
        }
        onObjectRemoved: (i, obj) => win.providers = win.providers.filter(p => p.pluginId !== (obj.modelData ? obj.modelData.id : ""))
    }
    readonly property var activeProvider: {
        const q = query.replace(/^\s+/, "");
        return providers.find(p => p.prefix && (q === p.prefix || q.startsWith(p.prefix + " "))) || null;
    }
    readonly property string providerQuery: activeProvider ? query.replace(/^\s+/, "").slice(activeProvider.prefix.length).trim() : query.trim()

    function score(app, q) {
        const name = (app.name || "").toLowerCase();
        if (!q)
            return 1;
        if (name.startsWith(q))
            return 100 - name.length / 10;
        if (name.includes(q))
            return 70 - name.indexOf(q);
        const extra = ((app.genericName || "") + " " + String(app.keywords || "") + " " + (app.id || "")).toLowerCase();
        if (extra.includes(q))
            return 40;
        // subsequence match
        let i = 0;
        for (const ch of name)
            if (ch === q[i])
                i++;
        return i === q.length ? 20 - name.length / 20 : -1;
    }

    // unified rows: {app} for desktop entries, {provider, r} for plugin results
    readonly property var results: {
        providerTick;
        if (command)
            return [];
        const fromProvider = (p, text, prefixed) => {
            let list = [];
            try {
                list = p.query(text, prefixed) || [];
            } catch (e) {
                console.warn("launcher provider", p.pluginId, e);
            }
            return list.map(r => ({
                        "provider": p,
                        "r": r,
                        "s": r.score === undefined ? 10 : r.score
                    }));
        };
        if (activeProvider)
            return fromProvider(activeProvider, providerQuery, true).sort((x, y) => y.s - x.s).slice(0, 60);
        const q = query.trim().toLowerCase();
        const usage = Config.launcher.usage || {};
        let rows = apps.map(a => ({
                    "app": a,
                    "base": score(a, q),
                    "s": score(a, q) + Math.min(30, (usage[a.id] || 0) * 2)
                })).filter(r => r.base > 0);   // frequent apps rank higher, but only when they match
        if (q)
            for (const p of providers)
                if (p.global !== false)
                    rows = rows.concat(fromProvider(p, query.trim(), false));
        // the calculator on top (2+2, 10 km in mi, 100 usd in rub) and settings among the apps
        if (q) {
            const calc = Calc.evaluate(query);
            if (calc)
                rows.push({
                    "builtin": "calc",
                    "calc": calc,
                    "r": {
                        "title": calc.title,
                        "subtitle": calc.subtitle,
                        "icon": "calc"
                    },
                    "s": 1000
                });
            if (Config.launcher.settings !== false && !calc) {
                SettingsSearch.load();
                for (const d of SettingsSearch.search(query, 5))
                    rows.push({
                        "builtin": "setting",
                        "doc": d,
                        "r": {
                            "title": d.title,
                            "subtitle": I18n.t("Настройки", "Settings") + (d.crumb ? " › " + d.crumb : ""),
                            "icon": d.icon || "gear"
                        },
                        "s": Math.min(95, d.score / 6.3 * 100)
                    });
            }
            if (!calc)
                for (const f of FileSearch.rows(query, /^(\.\S+\s*)+$/.test(q) ? 40 : 10))
                    rows.push({
                        "builtin": "file",
                        "file": f,
                        "r": {
                            "title": f.name,
                            "subtitle": FileSearch.where(f),
                            "icon": FileSearch.pixelIcon(f)
                        },
                        "s": f.s * 100
                    });
        }
        return rows.sort((x, y) => y.s - x.s || (x.app && y.app ? x.app.name.localeCompare(y.app.name) : 0)).slice(0, 60);
    }

    function activate(row) {
        if (row.app) {
            launch(row.app);
            return;
        }
        if (row.builtin === "calc") {
            Calc.copy(row.calc);
            if (row.calc.copy)
                Shell.launcherOpen = false;
            return;
        }
        if (row.builtin === "setting") {
            Shell.launcherOpen = false;
            Qt.callLater(() => StartApps.openSetting(row.doc));
            return;
        }
        if (row.builtin === "file") {
            Shell.launcherOpen = false;
            FileSearch.open(row.file);
            return;
        }
        const keep = row.provider.activate(row.r.id, row.r);
        if (keep !== true)
            Shell.launcherOpen = false;
    }

    function launch(app) {
        const usage = Object.assign({}, Config.launcher.usage || {});
        usage[app.id] = (usage[app.id] || 0) + 1;
        Config.launcher.usage = usage;
        if (app.runInTerminal)
            Shell.exec(Shell.terminalArgv(app.command), app.workingDirectory, app.id);
        else if (app.command && app.command.length)
            Shell.exec(app.command, app.workingDirectory, app.id);
        else
            app.execute();      // no command line to run with the apps' environment
        Shell.launcherOpen = false;
    }
    readonly property var picked: results.length > 0 ? results[Math.min(current, results.length - 1)] : null
    readonly property var pickedFile: picked && picked.builtin === "file" ? picked.file : null
    function accept() {
        if (command) {
            const cmd = query.slice(1).trim();
            if (cmd)
                Shell.sh(cmd);
            Shell.launcherOpen = false;
            return;
        }
        if (results.length > 0)
            activate(results[Math.min(current, results.length - 1)]);
    }

    // scripting: `angelos launcherText <text>` types into the open launcher
    Connections {
        target: Shell
        function onLauncherTextChanged() {
            if (!win.visible)
                return;
            field.text = Shell.launcherText;
            win.query = Shell.launcherText;
            win.current = 0;
        }
    }

    // built when it opens (shell.qml: LazyLoader), so the first showing is the creation itself
    Component.onCompleted: if (visible)
        opened()
    onVisibleChanged: if (visible)
        opened()
    function opened() {
        focusCheck.restart();
        query = Shell.launcherPrefill;
        field.text = Shell.launcherPrefill;
        Shell.launcherPrefill = "";
        current = 0;
        field.focusField();
        pop.restart();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.launcherOpen = false
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    PxWindow {
        id: dialog
        width: Theme.u * 220
        height: Theme.u * 250
        anchors.centerIn: parent
        title: I18n.t("Выполнить…", "Run…")
        icon: "search"
        onCloseClicked: Shell.launcherOpen = false

        SequentialAnimation {
            id: pop
            NumberAnimation {
                target: dialog
                property: "scale"
                from: 0.9
                to: 1.02
                duration: Motion.ms(110)
            }
            NumberAnimation {
                target: dialog
                property: "scale"
                to: 1
                duration: Motion.ms(90)
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        PxField {
            id: field
            keepFocus: true
            width: parent.width
            icon: "search"
            placeholder: I18n.t("Программа… ", "Application… ") + win.providers.filter(p => p.prefix).map(p => p.prefix + " …").concat(Config.launcher.calc !== false ? ["2+2"] : []).concat([I18n.t("> команда", "> command")]).join(" · ")
            kind: "title"
            onEdited: {
                win.query = text;
                win.current = 0;
            }
            onAccepted: win.accept()
            onKeyPressed: e => {
                if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier) && win.pickedFile) {
                    Shell.launcherOpen = false;
                    FileSearch.reveal(win.pickedFile);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    Shell.launcherOpen = false;
                    e.accepted = true;
                } else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
                    win.current = Math.min(win.results.length - 1, win.current + 1);
                    list.positionViewAtIndex(win.current, ListView.Contain);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
                    win.current = Math.max(0, win.current - 1);
                    list.positionViewAtIndex(win.current, ListView.Contain);
                    e.accepted = true;
                }
            }
        }

        PxBox {
            y: field.height + Theme.u * 5
            width: parent.width
            height: parent.height - y
            sunken: true
            color: Qt.alpha(Theme.sunken, 0.75)

            PxText {
                visible: win.command
                anchors.centerIn: parent
                text: I18n.t("Enter — выполнить в sh ♡", "Enter to run in sh ♡")
                dim: true
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: Theme.u * 2
                clip: true
                model: win.results
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.current
                    readonly property bool isApp: !!modelData.app
                    readonly property var r: modelData.r || ({})
                    width: list.width
                    height: Theme.u * 17
                    color: sel ? Theme.select : m.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.12) : "transparent"

                    Item {
                        id: ico
                        x: Theme.u * 4
                        width: Theme.u * 12
                        height: Theme.u * 12
                        anchors.verticalCenter: parent.verticalCenter
                        FileThumb {
                            id: rowThumb
                            anchors.fill: parent
                            visible: ok
                            hit: item.modelData.file || null
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            visible: item.isApp || (!!item.r.image && !item.r.pixelIcon)
                            iconName: item.isApp ? (item.modelData.app.icon || "") : (item.r.image || "")
                            size: Theme.u * 12
                        }
                        PxIcon {
                            anchors.centerIn: parent
                            visible: !item.isApp && !item.r.image && !rowThumb.ok
                            name: item.r.icon || "sparkle"
                            ink: item.sel ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
                        }
                    }
                    Column {
                        anchors.left: ico.right
                        anchors.leftMargin: Theme.u * 5
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            text: item.isApp ? item.modelData.app.name : (item.r.title || "")
                            elide: Text.ElideRight
                            color: item.sel ? Theme.selectText : Theme.text
                            font.bold: item.sel
                        }
                        PxText {
                            width: parent.width
                            visible: text !== ""
                            text: item.isApp ? (item.modelData.app.genericName || item.modelData.app.comment || "") : (item.r.subtitle || "")
                            elide: Text.ElideRight
                            kind: "tiny"
                            color: item.sel ? Theme.selectText : Theme.textDim
                        }
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.activate(item.modelData)
                    }
                }
            }
        }
    }

    // the picked file's preview, beside the dialog (Settings → Start → Search → previews)
    PxWindow {
        id: previewWin
        readonly property var f: win.pickedFile
        visible: !!f && FileSearch.previewable(f) && x + width < win.width
        width: Theme.u * 150
        height: Theme.u * 170
        x: dialog.x + dialog.width + Theme.u * 6
        y: dialog.y
        title: f ? f.name : ""
        icon: "image"
        closable: false
        MouseArea {
            anchors.fill: parent
        }
        PxBox {
            id: previewBox
            width: parent.width
            height: parent.height - previewInfo.height - Theme.u * 4
            sunken: true
            color: Qt.alpha(Theme.sunken, 0.75)
            FileThumb {
                id: bigThumb
                anchors.fill: parent
                anchors.margins: Theme.u * 3
                crop: false
                decode: 512
                hit: previewWin.f
            }
            PxIcon {
                visible: !bigThumb.ok
                anchors.centerIn: parent
                pixel: Theme.u * 2
                name: previewWin.f ? FileSearch.pixelIcon(previewWin.f) : "document"
            }
        }
        PxText {
            id: previewInfo
            anchors.bottom: parent.bottom
            width: parent.width
            kind: "tiny"
            dim: true
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: previewWin.f ? FileSearch.sizeText(previewWin.f.size) + " · " + FileSearch.dateText(previewWin.f) + "\n" + FileSearch.where(previewWin.f) + "\n" + I18n.t("Ctrl+Enter — показать в папке", "Ctrl+Enter shows it in its folder") : ""
        }
    }

    RightClickGuard {}
}
