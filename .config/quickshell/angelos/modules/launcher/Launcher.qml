pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// App launcher (Mod+Space): a big search field, results with the picked one's details beside
// them, the keys along the bottom. Fuzzy search, frequent apps first, ">" runs a shell command,
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

    // ---- what a row is, for its badge and the details pane ----
    function kindOf(row) {
        if (!row)
            return "";
        if (row.app)
            return I18n.t("программа", "app");
        if (row.builtin === "calc")
            return I18n.t("калькулятор", "calculator");
        if (row.builtin === "setting")
            return I18n.t("настройка", "setting");
        if (row.builtin === "file")
            return I18n.t("файл", "file");
        return row.provider && row.provider.prefix ? row.provider.prefix : I18n.t("плагин", "plugin");
    }
    function titleOf(row) {
        return !row ? "" : row.app ? row.app.name : (row.r && row.r.title) || "";
    }
    function subtitleOf(row) {
        if (!row)
            return "";
        if (row.app)
            return row.app.genericName || row.app.comment || "";
        return (row.r && row.r.subtitle) || "";
    }
    // the mode the field is in: a chip at its right end
    readonly property string mode: command ? I18n.t("команда sh", "sh command") : activeProvider ? activeProvider.prefix : /^\s*(\.\S+\s*)+$/.test(query) ? I18n.t("файлы", "files") : query.trim() ? I18n.t("поиск", "search") : I18n.t("частые", "frequent")

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.launcherOpen = false
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    // ---- the panel: a ribbon, the big field, results and details, the key hints ----
    Item {
        id: dialog
        width: Math.min(Theme.u * 320, win.width - Theme.u * 20)
        height: Math.min(Theme.u * 236, win.height - Theme.u * 20)
        x: Math.round((win.width - width) / 2)
        // a little above the middle, like a search box
        y: Math.round(Math.max(Theme.u * 10, win.height * 0.42 - height / 2)) + dropY
        property real dropY: 0
        opacity: 1

        SequentialAnimation {
            id: pop
            ParallelAnimation {
                NumberAnimation {
                    target: dialog
                    property: "dropY"
                    from: -Theme.u * 10
                    to: 0
                    duration: Motion.ms(140)
                    easing.type: Easing.OutBack
                }
                NumberAnimation {
                    target: dialog
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.ms(110)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        PxBox {
            anchors.fill: parent
            color: Theme.panel
            shadow: Config.appearance.shadows
            shadowSize: Theme.u * 3
        }
        // the ribbon: the title gradient, a few pixels twinkling along it
        Rectangle {
            id: ribbon
            x: Theme.u * 2
            y: Theme.u * 2
            width: parent.width - Theme.u * 4
            height: Theme.u * 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Theme.title1
                }
                GradientStop {
                    position: 1
                    color: Theme.title2
                }
            }
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    width: Theme.u
                    height: Theme.u
                    color: "#ffffff"
                    x: Math.round(((index * 0.618 + 0.07) % 1) * (ribbon.width - width) / Theme.u) * Theme.u
                    y: index % 2 ? 0 : Theme.u * 2
                    opacity: twinkle.phase === index % 3 ? 0.9 : 0.25
                }
            }
            Timer {
                id: twinkle
                property int phase: 0
                interval: 420
                repeat: true
                running: win.visible && !Motion.still
                onTriggered: phase = (phase + 1) % 3
            }
        }

        // the field: a big magnifier, the query, the mode chip
        Item {
            id: field
            x: Theme.u * 8
            y: ribbon.y + ribbon.height + Theme.u * 6
            width: parent.width - Theme.u * 16
            height: Theme.u * 22
            property alias text: input.text
            signal keyPressed(var event)
            function focusField() {
                input.forceActiveFocus();
            }
            PxBox {
                anchors.fill: parent
                sunken: true
                color: Theme.sunken
                edgeColor: input.activeFocus ? Theme.accent : Theme.edge
            }
            PxIcon {
                id: lens
                x: Theme.u * 6
                anchors.verticalCenter: parent.verticalCenter
                name: win.command ? "terminal" : "search"
                pixel: Theme.u * 2
                ink: Theme.dark ? Theme.text : Theme.edge
            }
            TextInput {
                id: input
                anchors.left: lens.right
                anchors.leftMargin: Theme.u * 6
                anchors.right: chip.left
                anchors.rightMargin: Theme.u * 5
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Theme.text
                selectionColor: Theme.select
                selectedTextColor: Theme.selectText
                font.family: Theme.fontTitle
                font.pixelSize: Theme.sizeBig
                renderType: Text.NativeRendering
                selectByMouse: true
                onTextEdited: {
                    win.query = text;
                    win.current = 0;
                }
                onAccepted: win.accept()
                Keys.onPressed: e => field.keyPressed(e)
                cursorDelegate: Rectangle {
                    id: caret
                    width: Theme.u * 2
                    color: Theme.accent
                    visible: input.activeFocus
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: input.activeFocus && !Motion.still
                        PropertyAction {
                            value: 1
                        }
                        PauseAnimation {
                            duration: Motion.ms(480)
                        }
                        PropertyAction {
                            value: 0
                        }
                        PauseAnimation {
                            duration: Motion.ms(480)
                        }
                    }
                }
            }
            PxText {
                anchors.fill: input
                visible: input.text === "" && !input.inputMethodComposing
                verticalAlignment: Text.AlignVCenter
                text: I18n.t("Что открыть?", "What to open?")
                dim: true
                font.family: Theme.fontTitle
                font.pixelSize: Theme.sizeBig
                elide: Text.ElideRight
            }
            // the mode, and how many results
            Rectangle {
                id: chip
                anchors.right: parent.right
                anchors.rightMargin: Theme.u * 5
                anchors.verticalCenter: parent.verticalCenter
                width: chipText.implicitWidth + Theme.u * 8
                height: Theme.u * 11
                color: win.command ? Theme.mix(Theme.face, Theme.danger, 0.35) : Theme.mix(Theme.face, Theme.accent, 0.3)
                border.width: Math.max(1, Theme.u / 2)
                border.color: win.command ? Theme.danger : Theme.accent
                PxText {
                    id: chipText
                    anchors.centerIn: parent
                    kind: "tiny"
                    text: win.mode + (!win.command && win.results.length ? " · " + win.results.length : "")
                    color: Theme.text
                }
            }
        }

        // results on the left, the picked one's details on the right
        Item {
            id: body
            x: Theme.u * 8
            y: field.y + field.height + Theme.u * 6
            width: parent.width - Theme.u * 16
            height: hints.y - y - Theme.u * 5
            readonly property bool split: width > Theme.u * 220

            PxBox {
                id: listBox
                width: body.split ? Math.round(body.width * 0.58) : body.width
                height: parent.height
                sunken: true
                color: Qt.alpha(Theme.sunken, 0.75)

                PxText {
                    visible: win.command
                    anchors.centerIn: parent
                    width: parent.width - Theme.u * 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: I18n.t("Enter — выполнить в sh ♡\n", "Enter runs it in sh ♡\n") + win.query.slice(1).trim()
                    dim: true
                }
                PxText {
                    visible: !win.command && win.results.length === 0 && win.query.trim() !== ""
                    anchors.centerIn: parent
                    text: I18n.t("ничего не нашлось… ♡", "nothing found… ♡")
                    dim: true
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: Theme.u * 3
                    clip: true
                    model: win.results
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    currentIndex: win.current
                    // the picked row's frame slides between rows in whole pixels
                    highlight: Item {
                        width: list.width
                        height: Theme.u * 17
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.select
                        }
                        // notched corners: pixel art, not a rounded rect
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: Theme.u
                                height: Theme.u
                                color: Qt.alpha(Theme.sunken, 0.95)
                                x: index % 2 ? parent.width - width : 0
                                y: index < 2 ? 0 : parent.height - height
                            }
                        }
                        PxIcon {
                            x: Theme.u * 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: "heartSmall"
                            pixel: Math.max(1, Math.round(Theme.u / 2))
                            ink: Theme.selectText
                            fill: Theme.selectText
                        }
                    }
                    delegate: Item {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === win.current
                        readonly property bool isApp: !!modelData.app
                        readonly property var r: modelData.r || ({})
                        width: list.width
                        height: Theme.u * 17

                        Rectangle {
                            anchors.fill: parent
                            visible: !item.sel && m.containsMouse
                            color: Theme.mix(Theme.face, Theme.accent, 0.12)
                        }
                        Item {
                            id: ico
                            x: Theme.u * 7
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
                            anchors.right: badge.left
                            anchors.rightMargin: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            PxText {
                                width: parent.width
                                text: win.titleOf(item.modelData)
                                elide: Text.ElideRight
                                color: item.sel ? Theme.selectText : Theme.text
                                font.bold: item.sel
                            }
                            PxText {
                                width: parent.width
                                visible: text !== "" && !body.split
                                text: win.subtitleOf(item.modelData)
                                elide: Text.ElideRight
                                kind: "tiny"
                                color: item.sel ? Theme.selectText : Theme.textDim
                            }
                        }
                        PxText {
                            id: badge
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.u * 4
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "tiny"
                            text: item.isApp ? "" : win.kindOf(item.modelData)
                            color: item.sel ? Theme.selectText : Theme.textDim
                        }
                        MouseArea {
                            id: m
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.current === item.index)
                                    win.activate(item.modelData);
                                else
                                    win.current = item.index;
                            }
                            onDoubleClicked: win.activate(item.modelData)
                        }
                    }
                }
            }

            // the details: a big icon (a file: its picture), the name, what it is, what Enter does
            PxBox {
                id: details
                visible: body.split
                x: listBox.width + Theme.u * 5
                width: body.width - x
                height: parent.height
                color: Qt.alpha(Theme.faceAlt, 0.6)
                readonly property var row: win.command ? null : win.picked
                readonly property var f: row && row.builtin === "file" ? row.file : null

                Column {
                    id: info
                    x: Theme.u * 7
                    y: Theme.u * 8
                    width: parent.width - Theme.u * 14
                    spacing: Theme.u * 4
                    visible: !!details.row

                    // the picture: an app's icon big, a file's preview, else a pixel icon
                    Item {
                        width: parent.width
                        height: details.f && FileSearch.previewable(details.f) ? Math.min(Theme.u * 90, width * 0.75) : Theme.u * 34
                        PxBox {
                            anchors.fill: parent
                            visible: !!details.f && FileSearch.previewable(details.f)
                            sunken: true
                            color: Qt.alpha(Theme.sunken, 0.75)
                            FileThumb {
                                id: bigThumb
                                anchors.fill: parent
                                anchors.margins: Theme.u * 3
                                crop: false
                                decode: 512
                                hit: details.f
                            }
                        }
                        AppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!details.row && (!!details.row.app || (!!details.row.r && !!details.row.r.image && !details.row.r.pixelIcon))
                            iconName: !details.row ? "" : details.row.app ? (details.row.app.icon || "") : (details.row.r.image || "")
                            size: Theme.u * 30
                        }
                        PxIcon {
                            anchors.centerIn: parent
                            visible: !!details.row && !details.row.app && !(details.row.r && details.row.r.image) && !(details.f && bigThumb.ok)
                            name: !details.row ? "sparkle" : details.f ? FileSearch.pixelIcon(details.f) : (details.row.r || {}).icon || "sparkle"
                            pixel: Theme.u * 3
                        }
                    }
                    PxText {
                        width: parent.width
                        kind: "title"
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: win.titleOf(details.row)
                    }
                    PxText {
                        width: parent.width
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        dim: true
                        text: details.f ? FileSearch.sizeText(details.f.size) + " · " + FileSearch.dateText(details.f) + "\n" + FileSearch.where(details.f) : win.subtitleOf(details.row)
                    }
                    // the kind, and how often it was opened
                    Row {
                        spacing: Theme.u * 3
                        Rectangle {
                            width: kindText.implicitWidth + Theme.u * 6
                            height: Theme.u * 10
                            color: Theme.mix(Theme.face, Theme.accent2, 0.3)
                            border.width: Math.max(1, Theme.u / 2)
                            border.color: Theme.accent2
                            PxText {
                                id: kindText
                                anchors.centerIn: parent
                                kind: "tiny"
                                text: win.kindOf(details.row)
                            }
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "tiny"
                            dim: true
                            readonly property int used: details.row && details.row.app ? ((Config.launcher.usage || {})[details.row.app.id] || 0) : 0
                            visible: used > 0
                            text: I18n.t("открывали ", "opened ") + used + I18n.t(" раз", used === 1 ? " time" : " times")
                        }
                    }
                }
                // what Enter does with it
                Column {
                    visible: !!details.row
                    x: Theme.u * 7
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.u * 7
                    spacing: Theme.u * 2
                    PxText {
                        kind: "tiny"
                        text: "Enter — " + (!details.row ? "" : details.row.builtin === "calc" ? I18n.t("скопировать", "copy") : details.row.builtin === "setting" ? I18n.t("открыть в настройках", "open in Settings") : I18n.t("открыть", "open"))
                    }
                    PxText {
                        visible: !!details.f
                        kind: "tiny"
                        dim: true
                        text: I18n.t("Ctrl+Enter — показать в папке", "Ctrl+Enter shows it in its folder")
                    }
                }
                // nothing picked: the angel waits
                Column {
                    visible: !details.row
                    anchors.centerIn: parent
                    spacing: Theme.u * 4
                    PxIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: win.command ? "terminal" : "heart"
                        pixel: Theme.u * 3
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.command ? I18n.t("команда", "command") : I18n.t("ищу ♡", "searching ♡")
                        dim: true
                    }
                }
            }
        }

        // the keys
        Row {
            id: hints
            x: Theme.u * 8
            y: parent.height - height - Theme.u * 6
            spacing: Theme.u * 6
            Repeater {
                model: [["↑↓", I18n.t("выбрать", "pick")], ["Enter", I18n.t("открыть", "open")], [">", I18n.t("команда", "command")]].concat(Config.launcher.calc !== false ? [["2+2", I18n.t("счёт", "maths")]] : []).concat(win.providers.filter(p => p.prefix).slice(0, 2).map(p => [p.prefix, ""])).concat([["Esc", I18n.t("закрыть", "close")]])
                Row {
                    id: hintRow
                    required property var modelData
                    spacing: Theme.u * 2
                    PxBox {
                        width: capText.implicitWidth + Theme.u * 6
                        height: Theme.u * 10
                        color: Theme.face
                        PxText {
                            id: capText
                            anchors.centerIn: parent
                            kind: "tiny"
                            text: hintRow.modelData[0]
                        }
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        dim: true
                        text: hintRow.modelData[1]
                    }
                }
            }
        }
    }

    // the keys of the field: move, run, reveal a file, leave
    Connections {
        target: field
        function onKeyPressed(e) {
            const page = Math.max(1, Math.floor(list.height / (Theme.u * 17)) - 1);
            if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier) && win.pickedFile) {
                Shell.launcherOpen = false;
                FileSearch.reveal(win.pickedFile);
                e.accepted = true;
            } else if (e.key === Qt.Key_Escape) {
                if (input.text !== "") {
                    input.text = "";
                    win.query = "";
                    win.current = 0;
                } else {
                    Shell.launcherOpen = false;
                }
                e.accepted = true;
            } else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
                win.current = Math.min(win.results.length - 1, win.current + 1);
                list.positionViewAtIndex(win.current, ListView.Contain);
                e.accepted = true;
            } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
                win.current = Math.max(0, win.current - 1);
                list.positionViewAtIndex(win.current, ListView.Contain);
                e.accepted = true;
            } else if (e.key === Qt.Key_PageDown) {
                win.current = Math.min(win.results.length - 1, win.current + page);
                list.positionViewAtIndex(win.current, ListView.Contain);
                e.accepted = true;
            } else if (e.key === Qt.Key_PageUp) {
                win.current = Math.max(0, win.current - page);
                list.positionViewAtIndex(win.current, ListView.Contain);
                e.accepted = true;
            }
        }
    }

    RightClickGuard {}
}
