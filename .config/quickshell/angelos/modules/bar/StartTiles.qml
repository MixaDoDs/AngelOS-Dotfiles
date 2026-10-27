pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Windows 10-like Start in pixels ("Плитки", 2026-10-27 references): all apps A–Z on the
// left, flat tiles on the right, user + buttons at the bottom; typing turns it into one list
// of results. Tiles: the apps you pinned 1×1 (none pinned yet: the most used, until the first
// one is taken off); live ones 2×1 — the song playing (cover, track), the weather, a messenger
// with its unread count (Telegram, Discord). From a tile's right-click menu: 1×1 or 2×1, take it
// off (the song and the weather too; their way back is in every tile's menu) — Config.bar.startTiles:
// {key: "small" | "wide" | "off", "~own": true once the pins are yours}. Live tiles are filled with
// the accent, the rest with the panel's face; under the pointer a frame.
PxBox {
    id: root

    signal closeRequested
    signal menuAsked(var items, Item item, real x, real y)
    property int current: -1
    property string query: ""
    property real room: 0                       // StartOverlay: the screen's room for it
    readonly property var prefs: StartPrefs.of("tiles")

    function px(n) {
        return StartPrefs.px(prefs, n);
    }
    readonly property int iu: prefs.iu
    readonly property int pad: px(8)
    readonly property int gap: px(4)
    readonly property int sectionGap: px(6)
    readonly property int innerW: width - pad * 2
    readonly property color accentColor: prefs.accentColor
    readonly property int selBorder: Math.max(1, Math.floor(iu / 2))
    // the hover frame of a tile: Windows 10's reveal border, in whole art pixels
    readonly property int frame: Math.max(1, iu)

    // ---- the tile grid: square cells, a wide tile takes two side by side ----
    readonly property int cols: prefs.columns > 0 ? Math.max(3, Math.min(8, prefs.columns)) : 4
    readonly property int tileIcon: iu * Math.round(13 * prefs.icons)
    readonly property int cell: Math.max(px(34), tileIcon + px(prefs.labels ? 16 : 10))
    readonly property int cellGap: px(2)
    readonly property int tilesW: cols * cell + (cols - 1) * cellGap
    readonly property int listW: Math.round(prefs.unit * 104 * prefs.size)

    readonly property var sizes: Config.bar.startTiles || ({})
    // Telegram and Discord (and its clients): the tile counts what came from it, unread
    readonly property var chats: ({
            "telegram": /telegram|ayugram|kotatogram|64gram/i,
            "discord": /discord|vesktop|vencord|legcord|armcord|webcord|equibop/i
        })
    function chatOf(app) {
        const s = String(app.id || "") + " " + String(app.name || "");
        for (const k in chats)
            if (chats[k].test(s))
                return k;
        return "";
    }
    function unreadOf(kind) {
        const re = chats[kind];
        return re ? Notifs.history.filter(h => !h.read && re.test(h.appName || "")).length : 0;
    }
    // the pins: yours; before you have any, the most used (StartApps.pinned tops them up)
    readonly property bool ownPins: !!sizes["~own"] || (Config.bar.startPinned || []).length > 0
    readonly property var pins: ownPins ? (Config.bar.startPinned || []).map(id => StartApps.apps.find(a => a.id === id)).filter(a => !!a) : StartApps.pinned.slice(0, 8)
    // the song and the weather, while there is something to show (and not taken off); then the pins
    readonly property var tiles: {
        const t = [];
        if (sizes["~music"] !== "off" && Lyrics.player && Lyrics.title)
            t.push({
                "key": "~music",
                "live": "music"
            });
        if (sizes["~weather"] !== "off" && Weather.ok)
            t.push({
                "key": "~weather",
                "live": "weather"
            });
        for (const a of pins)
            t.push({
                "key": a.id,
                "app": a,
                "live": chatOf(a)
            });
        return t;
    }
    function isWide(t) {
        const s = sizes[t.key];
        return s === "wide" || s === "small" ? s === "wide" : !!t.live;
    }
    function setSize(key, size) {
        const all = Object.assign({}, sizes);
        if (size)
            all[key] = size;
        else
            delete all[key];
        Config.bar.startTiles = all;
    }
    function setWide(t, wide) {
        setSize(t.key, wide === !!t.live ? "" : wide ? "wide" : "small");
    }
    // off Start: an app leaves the pins (the shown ones become yours first), the song and the
    // weather are marked off
    function takeOff(t) {
        if (!t.app) {
            setSize(t.key, "off");
            return;
        }
        Config.bar.startPinned = pins.map(a => a.id).filter(id => id !== t.key);
        setSize("~own", true);
    }
    // where each tile sits: the first free place, row by row (a wide one that doesn't fit
    // at the end of a row leaves the gap for the next small one)
    readonly property var places: {
        const taken = [], out = [];
        const free = (r, c) => !(taken[r] && taken[r][c]);
        const take = (r, c) => {
            taken[r] = taken[r] || [];
            taken[r][c] = true;
        };
        for (const t of tiles) {
            const w = isWide(t) && cols > 1 ? 2 : 1;
            for (let r = 0, done = false; !done; r++)
                for (let c = 0; c + w <= cols && !done; c++)
                    if (free(r, c) && (w === 1 || free(r, c + 1))) {
                        take(r, c);
                        if (w === 2)
                            take(r, c + 1);
                        out.push({
                            "r": r,
                            "c": c,
                            "w": w
                        });
                        done = true;
                    }
        }
        return out;
    }
    readonly property int tileRows: places.reduce((m, p) => Math.max(m, p.r + 1), 1)
    readonly property int headH: Math.ceil(tilesHead.implicitHeight)
    readonly property int footerH: prefs.user || prefs.power ? px(20) : 0
    readonly property int chrome: pad + (prefs.search ? Math.ceil(field.implicitHeight) + sectionGap : 0) + headH + sectionGap + pad + (footerH > 0 ? footerH + inset : 0)
    // the rows that fit in the room; more scroll inside
    readonly property int fitRows: room > 0 ? Math.max(1, Math.floor((room - chrome + cellGap) / (cell + cellGap))) : 6
    readonly property int shownRows: Math.max(3, Math.min(6, fitRows, prefs.rows > 0 ? prefs.rows : 5))
    readonly property int bodyH: shownRows * cell + (shownRows - 1) * cellGap

    readonly property bool searching: query.trim() !== ""
    readonly property var results: searching ? StartApps.searchAll(query, 40) : []
    readonly property var appList: StartPrefs.sorted("tiles", StartApps.apps)
    readonly property int count: searching ? results.length : tiles.length

    function setQuery(t) {
        field.text = t;
        query = t;
        current = t ? 0 : -1;
    }
    function reset() {
        current = -1;
        query = "";
        field.text = "";
        allList.positionViewAtBeginning();
        tilesView.contentY = 0;
        if (prefs.typeSearch && prefs.search)
            Qt.callLater(() => field.focusField());
    }
    function run(app) {
        closeRequested();
        Qt.callLater(() => StartApps.launch(app));
    }
    function act(fn) {
        closeRequested();
        Qt.callLater(fn);
    }
    function openTile(t) {
        if (t.app)
            run(t.app);
        else if (t.live === "music")
            Lyrics.player.togglePlaying();
        else if (t.live === "weather")
            act(() => Shell.openSettings("widgets"));
    }
    // pinning from the list or the search: onto the tiles (the shown ones become yours first)
    function onTiles(app) {
        return pins.some(a => a.id === app.id);
    }
    function togglePin(app) {
        const ids = pins.map(a => a.id).filter(id => id !== app.id);
        Config.bar.startPinned = onTiles(app) ? ids : ids.concat([app.id]);
        setSize("~own", true);
    }
    function appMenu(app, open) {
        return [
            {
                "label": onTiles(app) ? I18n.t("Открепить", "Unpin") : I18n.t("Закрепить", "Pin"),
                "icon": "pin",
                "run": () => togglePin(app)
            },
            {
                "label": I18n.t("Открыть", "Open"),
                "icon": "play",
                "run": open
            }
        ];
    }
    // a tile's menu: open (apps), its size, take it off; then the way back for a live tile taken off
    function tileMenu(t, open) {
        const m = [];
        if (t.app)
            m.push({
                "label": I18n.t("Открыть", "Open"),
                "icon": "play",
                "run": open
            });
        m.push({
            "label": isWide(t) ? I18n.t("Маленькая плитка", "Small tile") : I18n.t("Широкая плитка", "Wide tile"),
            "icon": "grid",
            "run": () => setWide(t, !isWide(t))
        }, {
            "label": t.app ? I18n.t("Открепить", "Unpin") : I18n.t("Убрать с «Пуска»", "Take off Start"),
            "icon": "pin",
            "run": () => takeOff(t)
        });
        if (sizes["~music"] === "off")
            m.push({
                "label": I18n.t("Вернуть плитку музыки", "Bring back the music tile"),
                "icon": "music",
                "run": () => setSize("~music", "")
            });
        if (sizes["~weather"] === "off")
            m.push({
                "label": I18n.t("Вернуть плитку погоды", "Bring back the weather tile"),
                "icon": "cloud",
                "run": () => setSize("~weather", "")
            });
        return m;
    }
    function activate(row) {
        if (!row)
            return;
        if (!searching)
            openTile(row);
        else if (row.kind === "app")
            run(row.app);
        else if (row.kind === "file")
            act(() => FileSearch.open(row.file));
        else if (row.kind === "calc") {
            Calc.copy(row.calc);
            if (row.calc.copy)
                closeRequested();
        } else if (row.keep)
            row.run();
        else
            act(row.run);
    }
    // arrows: a list while searching; over the tiles, to the tile in that direction
    function move(dx, dy) {
        if (!count)
            return;
        if (current < 0) {
            current = 0;
            return;
        }
        if (searching) {
            current = Math.max(0, Math.min(count - 1, current + dy + dx));
            resultList.positionViewAtIndex(current, ListView.Contain);
            return;
        }
        const p = places[current];
        let best = -1, score = 1e9;
        for (let i = 0; i < places.length; i++) {
            const q = places[i];
            if (i === current)
                continue;
            const ddx = (q.c + q.w / 2) - (p.c + p.w / 2), ddy = q.r - p.r;
            if ((dx && (ddy !== 0 || Math.sign(ddx) !== dx)) || (dy && Math.sign(ddy) !== dy))
                continue;
            const s = dx ? Math.abs(ddx) : Math.abs(ddy) * 100 + Math.abs(ddx);
            if (s < score) {
                score = s;
                best = i;
            }
        }
        if (best < 0)
            return;
        current = best;
        const y = places[best].r * (cell + cellGap);
        if (y < tilesView.contentY)
            tilesView.contentY = y;
        else if (y + cell > tilesView.contentY + tilesView.height)
            tilesView.contentY = y + cell - tilesView.height;
    }
    function key(e) {
        if (nav(e))
            return;
        if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            field.text += e.text;
            query = field.text;
            field.focusField();
            e.accepted = true;
        }
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R)
            closeRequested();
        else if (e.key === Qt.Key_Down)
            move(0, 1);
        else if (e.key === Qt.Key_Up)
            move(0, -1);
        else if (e.key === Qt.Key_Right && query === "")
            move(1, 0);
        else if (e.key === Qt.Key_Left && query === "")
            move(-1, 0);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            activate((searching ? results : tiles)[Math.max(0, current)]);
        else
            return false;
        e.accepted = true;
        return true;
    }

    width: pad * 2 + listW + sectionGap + tilesW
    height: chrome + bodyH
    color: Qt.alpha(Theme.menuSurface, prefs.alpha)
    edgeColor: Theme.menuBorder
    flat: true
    shadow: Config.appearance.shadows && prefs.shadow

    component RowIcon: StartGlyph {
        x: root.gap
        y: Math.floor((parent.height - height) / 2)
        width: Math.max(root.px(12), root.iu * 12)
        height: Math.max(root.px(11), root.iu * 11)
        iu: root.iu
    }

    // one tile: its place from `places`, flat; live = the accent, a pin = the face
    component Tile: Item {
        id: tile
        required property var modelData
        required property int index
        readonly property var place: root.places[index] || ({
                "r": 0,
                "c": 0,
                "w": 1
            })
        readonly property bool wide: place.w === 2
        readonly property bool live: !!modelData.live
        readonly property bool sel: root.current === index
        readonly property int unread: modelData.live === "telegram" || modelData.live === "discord" ? root.unreadOf(modelData.live) : 0
        readonly property color ink: live ? Theme.inkOn(root.accentColor) : Theme.text
        x: place.c * (root.cell + root.cellGap)
        y: place.r * (root.cell + root.cellGap)
        width: place.w * root.cell + (place.w - 1) * root.cellGap
        height: root.cell

        Rectangle {
            anchors.fill: parent
            color: tile.live ? (tm.pressed ? Theme.mix(root.accentColor, "#000000", 0.15) : root.accentColor) : Qt.alpha(Theme.menuHeader, tm.pressed ? 1 : 0.85)
            border.width: tile.sel || tm.containsMouse ? root.frame : 0
            border.color: tile.live ? Theme.mix(root.accentColor, "#ffffff", 0.55) : root.accentColor
        }
        // a pin: the icon in the middle, the name at the bottom left (as Windows 10 does)
        AppIcon {
            visible: !!tile.modelData.app
            x: tile.wide ? root.px(5) : Math.floor((tile.width - width) / 2)
            y: tile.wide ? Math.floor((tile.height - height) / 2) : Math.floor((tile.height - (root.prefs.labels ? root.px(7) : 0) - height) / 2)
            iconName: tile.modelData.app ? tile.modelData.app.icon || "" : ""
            appId: tile.modelData.app ? tile.modelData.app.id || "" : ""
            size: root.tileIcon
        }
        PxText {
            visible: !!tile.modelData.app && (root.prefs.labels || tile.wide) && !(tile.wide && tile.unread > 0)
            x: tile.wide ? root.px(5) + root.tileIcon + root.px(4) : root.px(3)
            y: tile.wide ? Math.floor((tile.height - height) / 2) : tile.height - height - root.px(2)
            width: tile.width - x - root.px(3)
            text: tile.modelData.app ? tile.modelData.app.name || "" : ""
            kind: "tiny"
            color: tile.ink
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        // a messenger: how many came from it, unread
        Column {
            visible: tile.wide && tile.unread > 0
            x: root.px(5) + root.tileIcon + root.px(4)
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - x - root.px(3)
            PxText {
                text: String(tile.unread)
                kind: "big"
                color: tile.ink
            }
            PxText {
                width: parent.width
                text: I18n.t("непрочитанных", "unread")
                kind: "tiny"
                color: tile.ink
                elide: Text.ElideRight
            }
        }
        Rectangle {
            visible: !tile.wide && tile.unread > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.px(2)
            width: Math.max(height, badge.implicitWidth + root.px(3))
            height: Math.ceil(badge.implicitHeight)
            color: Theme.inkOn(root.accentColor)
            PxText {
                id: badge
                anchors.centerIn: parent
                text: tile.unread > 99 ? "99+" : String(tile.unread)
                kind: "tiny"
                color: root.accentColor
            }
        }

        // the song: the cover, the track and who sings it
        Image {
            id: cover
            visible: tile.modelData.live === "music" && status === Image.Ready
            x: root.px(3)
            y: root.px(3)
            width: tile.height - root.px(6)
            height: width
            source: tile.modelData.live === "music" ? Lyrics.artUrl : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: false
        }
        PxIcon {
            visible: tile.modelData.live === "music" && !cover.visible
            x: tile.wide ? root.px(5) : Math.floor((tile.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            name: Lyrics.playing ? "music" : "note"
            pixel: root.iu * 2
            fill: tile.ink
            ink: tile.ink
        }
        Column {
            visible: tile.modelData.live === "music" && tile.wide
            x: cover.visible ? cover.x + cover.width + root.px(3) : root.px(5) + root.iu * 22
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - x - root.px(3)
            PxText {
                width: parent.width
                text: Lyrics.title
                color: tile.ink
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            PxText {
                width: parent.width
                text: (Lyrics.playing ? "" : "❚❚ ") + Lyrics.artist
                kind: "tiny"
                color: tile.ink
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // the weather: its icon and the temperature; wide, the words and the place too
        PxIcon {
            id: wIcon
            visible: tile.modelData.live === "weather"
            x: tile.wide ? root.px(5) : Math.floor((tile.width - width) / 2)
            y: tile.wide ? Math.floor((tile.height - height) / 2) : root.px(4)
            name: Weather.now ? Weather.icon(Weather.now.code, Weather.now.day) || "cloud" : "cloud"
            pixel: root.iu * 2
            fill: tile.ink
            ink: tile.ink
        }
        PxText {
            visible: tile.modelData.live === "weather" && !tile.wide
            anchors.horizontalCenter: parent.horizontalCenter
            y: tile.height - height - root.px(2)
            text: Weather.now ? Weather.deg(Weather.now.temp) : ""
            color: tile.ink
        }
        Column {
            visible: tile.modelData.live === "weather" && tile.wide
            x: wIcon.x + wIcon.width + root.px(4)
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - x - root.px(3)
            PxText {
                text: Weather.now ? Weather.deg(Weather.now.temp) : ""
                kind: "big"
                color: tile.ink
            }
            PxText {
                width: parent.width
                text: Weather.now ? Weather.words(Weather.now.code) + (Weather.place && Weather.place.name ? " · " + Weather.place.name : "") : ""
                kind: "tiny"
                color: tile.ink
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onEntered: root.current = tile.index
            onClicked: m => {
                const t = tile.modelData;
                if (m.button === Qt.MiddleButton)
                    root.takeOff(t);
                else if (m.button === Qt.RightButton)
                    root.menuAsked(root.tileMenu(t, () => root.openTile(t)), tm, m.x, m.y);
                else if (m.button === Qt.LeftButton)
                    root.openTile(t);
            }
        }
    }

    Column {
        x: root.pad - root.inset
        y: root.pad - root.inset
        width: root.innerW
        spacing: root.sectionGap

        PxField {
            id: field
            visible: root.prefs.search
            keepFocus: true
            width: parent.width
            height: Math.ceil(implicitHeight)
            icon: "search"
            placeholder: Config.launcher.settings !== false ? I18n.t("Приложения, настройки, 2+2…", "Apps, settings, 2+2…") : I18n.t("Поиск приложений…", "Search apps…")
            onEdited: {
                root.query = text;
                root.current = text ? 0 : -1;
            }
            onAccepted: if (root.count)
                root.activate((root.searching ? root.results : root.tiles)[Math.max(0, root.current)])
            onKeyPressed: e => root.nav(e)
        }

        Item {
            width: parent.width
            height: root.headH
            PxText {
                visible: !root.searching
                text: I18n.t("Все приложения", "All apps")
                kind: "title"
            }
            PxText {
                id: tilesHead
                x: root.searching ? 0 : root.listW + root.sectionGap
                text: root.searching ? (root.results.length ? I18n.t("Лучшие совпадения", "Best matches") : I18n.t("Ничего не нашлось", "Nothing found")) : I18n.t("Плитки", "Tiles")
                kind: "title"
            }
        }

        Item {
            width: parent.width
            height: root.bodyH

            // all apps, A–Z with letter headers; the mouse's (the keys walk the tiles)
            ListView {
                id: allList
                visible: !root.searching
                width: root.listW
                height: parent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.appList
                delegate: Item {
                    id: li
                    required property var modelData
                    required property int index
                    readonly property string letter: String(modelData.name || "?").charAt(0).toUpperCase()
                    readonly property bool first: index === 0 || letter !== String(root.appList[index - 1].name || "?").charAt(0).toUpperCase()
                    readonly property int letterH: first ? Math.ceil(letterText.implicitHeight) + root.px(2) : 0
                    width: allList.width
                    height: letterH + row.height
                    PxText {
                        id: letterText
                        visible: li.first
                        x: root.gap
                        text: li.letter
                        kind: "title"
                        color: root.accentColor
                        topPadding: root.px(2)
                    }
                    Rectangle {
                        id: row
                        y: li.letterH
                        width: allList.width
                        height: root.px(14)
                        color: lm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                        RowIcon {
                            app: li.modelData
                            appSize: root.iu * Math.round(10 * root.prefs.icons)
                        }
                        PxText {
                            x: root.gap + Math.max(root.px(12), root.iu * 12) + root.gap
                            width: parent.width - root.gap - x
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                            text: li.modelData.name
                        }
                        MouseArea {
                            id: lm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: m => {
                                const a = li.modelData;
                                if (m.button === Qt.MiddleButton)
                                    root.togglePin(a);
                                else if (m.button === Qt.RightButton)
                                    root.menuAsked(root.appMenu(a, () => root.run(a)), lm, m.x, m.y);
                                else
                                    root.run(a);
                            }
                        }
                    }
                }
            }

            Flickable {
                id: tilesView
                visible: !root.searching
                x: root.listW + root.sectionGap
                width: root.tilesW
                height: parent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: root.tileRows * root.cell + (root.tileRows - 1) * root.cellGap
                interactive: contentHeight > height
                Repeater {
                    model: tilesView.visible ? root.tiles : []
                    delegate: Tile {}
                }
            }

            // search results: one list across the menu, best first
            ListView {
                id: resultList
                visible: root.searching
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: visible ? root.results : []
                delegate: Rectangle {
                    id: hit
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.current === index
                    readonly property bool isCalc: modelData.kind === "calc"
                    readonly property bool isFile: modelData.kind === "file"
                    width: resultList.width
                    height: isCalc ? root.px(22) : root.px(16)
                    color: sel ? Qt.alpha(root.accentColor, 0.3) : hm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                    border.width: sel ? root.selBorder : 0
                    border.color: root.accentColor
                    RowIcon {
                        app: hit.modelData.kind === "app" ? hit.modelData.app : null
                        file: hit.isFile ? hit.modelData.file : null
                        icon: hit.isCalc ? "calc" : hit.isFile ? FileSearch.pixelIcon(hit.modelData.file) : hit.modelData.icon || "sparkle"
                    }
                    Column {
                        x: root.gap + Math.max(root.px(12), root.iu * 12) + root.gap
                        width: hitKind.x - root.gap - x
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            kind: hit.isCalc ? "title" : "body"
                            font.bold: hit.sel || hit.isCalc
                            text: hit.isCalc ? hit.modelData.calc.title : hit.modelData.kind === "app" ? hit.modelData.app.name : hit.isFile ? hit.modelData.file.name : hit.modelData.title
                        }
                        PxText {
                            width: parent.width
                            visible: text !== ""
                            elide: Text.ElideRight
                            kind: "tiny"
                            dim: true
                            text: hit.isCalc ? hit.modelData.calc.subtitle : hit.modelData.kind === "app" ? (hit.modelData.app.genericName || hit.modelData.app.comment || "") : hit.isFile ? FileSearch.where(hit.modelData.file) : hit.modelData.kind === "setting" ? (hit.modelData.doc.crumb || hit.modelData.doc.hint || "") : hit.modelData.sub
                        }
                    }
                    PxText {
                        id: hitKind
                        x: parent.width - root.gap - Math.ceil(implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        dim: true
                        text: hit.isCalc ? (hit.modelData.calc.copy ? "⧉" : "") : hit.modelData.kind === "app" ? I18n.t("приложение", "app") : hit.isFile ? (hit.modelData.file.isDir ? I18n.t("папка", "folder") : I18n.t("файл", "file")) : hit.modelData.kind === "setting" ? I18n.t("настройка", "setting") : hit.modelData.kind === "action" ? I18n.t("действие", "action") : hit.modelData.kind === "vault" ? I18n.t("пароль", "password") : I18n.t("таймер", "timer")
                    }
                    MouseArea {
                        id: hm
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = hit.index
                        onClicked: m => {
                            const r = hit.modelData, mid = m.button === Qt.MiddleButton;
                            if (m.button === Qt.LeftButton || (r.kind !== "app" && !hit.isFile)) {
                                root.activate(r);
                            } else if (r.kind === "app") {
                                if (mid)
                                    root.togglePin(r.app);
                                else
                                    root.menuAsked(root.appMenu(r.app, () => root.activate(r)), hm, m.x, m.y);
                            } else {
                                const reveal = () => root.act(() => FileSearch.reveal(r.file));
                                if (mid)
                                    reveal();
                                else
                                    root.menuAsked(StartApps.fileMenuFor(reveal, () => root.activate(r)), hm, m.x, m.y);
                            }
                        }
                    }
                }
            }
        }
    }

    // user + the button row, as in the Windows 11 look
    Rectangle {
        visible: root.footerH > 0
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.footerH
        color: Qt.alpha(Theme.menuHeader, 0.55)
        Rectangle {
            width: parent.width
            height: root.iu
            color: Theme.menuBorder
        }
        StartUser {
            visible: root.prefs.user
            x: root.pad - root.inset
            y: Math.floor((parent.height - height) / 2)
            size: root.iu * 13
            frameColor: root.accentColor
            onOpened: root.closeRequested()
        }
        StartButtonRow {
            visible: root.prefs.power
            unit: root.prefs.unit
            iu: root.iu
            x: parent.width - (root.pad - root.inset) - width
            y: Math.floor((parent.height - height) / 2)
        }
    }
}
