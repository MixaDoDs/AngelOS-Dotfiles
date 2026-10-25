// The settings once in SystemPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "../../../widgets/Logos.js" as Logos
import qs.modules.settings.kit

CatPage {
    id: systemPage
    heading: "System"
    // a gear field: type a bit of the name ("sm7", "м50", "аудиотехника") and the catalog's
    // matches drop down with their prices; ↑↓ and Enter pick one; a name it doesn't know is
    // added as your own, with a price
    component GearPick: Row {
        id: pick
        property var kinds: ["xlr"]
        property var current: null
        property string empty: I18n.t("напиши модель…", "type a model…")
        signal picked(var entry)
        spacing: Theme.u * 3
        readonly property var choices: SystemInfo.gearCatalog.filter(c => pick.kinds.includes(c.kind))
        property string own: ""          // your own name, waiting for its price
        property int hi: 0               // the highlighted suggestion

        // brands as people say them in Russian → as the catalog writes them
        readonly property var aliases: ({
                "шур": "shure",
                "сенхайзер": "sennheiser",
                "зенхайзер": "sennheiser",
                "сенхейзер": "sennheiser",
                "аудиотехника": "audiotechnica",
                "бейердинамик": "beyerdynamic",
                "байердинамик": "beyerdynamic",
                "роде": "rode",
                "рёде": "rode",
                "сони": "sony",
                "акг": "akg",
                "нейман": "neumann",
                "электровойс": "electrovoice",
                "хейл": "heil",
                "фокал": "focal",
                "одези": "audeze",
                "хайфайман": "hifiman",
                "эппл": "apple",
                "боуз": "bose",
                "элгато": "elgato",
                "логитек": "logitech",
                "рейзер": "razer",
                "хайперикс": "hyperx",
                "стилсириес": "steelseries",
                "филипс": "philips",
                "фостекс": "fostex",
                "левитт": "lewitt",
                "клаудлифтер": "cloudlifter",
                "наушники": "",
                "микрофон": ""
            })
        // a model number typed in Cyrillic lookalikes: "м50х" is M50x
        readonly property var lookalike: ({
                "а": "a",
                "в": "b",
                "е": "e",
                "к": "k",
                "м": "m",
                "н": "h",
                "о": "o",
                "р": "p",
                "с": "c",
                "т": "t",
                "у": "y",
                "х": "x"
            })
        function norm(s) {
            let n = String(s).toLowerCase().replace(/ø/g, "o").replace(/ё/g, "е").replace(/[^a-z0-9а-я+]/g, "");
            if (/[a-z0-9]/.test(n))
                n = n.replace(/[а-я]/g, ch => lookalike[ch] || ch);
            return n;
        }
        // typed on the Russian layout: "ыь7и" is sm7b
        readonly property string ru: "йцукенгшщзхъфывапролджэячсмитьбю"
        readonly property string en: "qwertyuiop[]asdfghjkl;'zxcvbnm,."
        function relayout(s) {
            return s.toLowerCase().split("").map(ch => ru.indexOf(ch) >= 0 ? en[ru.indexOf(ch)] : ch).join("");
        }
        function token(t) {
            const n = norm(t);
            if (n.length >= 3)
                for (const k in aliases)
                    if (k.startsWith(n) || n.startsWith(k))
                        return aliases[k];
            return n;
        }
        readonly property string query: field.text.trim()
        readonly property var matches: {
            const found = find(query);
            return found.length || !/[а-яё]/i.test(query) ? found : find(relayout(query));
        }
        function find(q) {
            const words = q.split(/\s+/).map(token).filter(w => w);
            if (!words.length)
                return q ? [] : choices.slice(0, 8);
            const scored = [];
            for (const c of choices) {
                const n = norm(c.name);
                if (words.every(w => n.includes(w)))
                    scored.push({
                        "c": c,
                        "s": (n.startsWith(words[0]) ? 0 : 1) * 1000 + n.length
                    });
            }
            return scored.sort((a, b) => a.s - b.s).slice(0, 8).map(x => x.c);
        }
        // the suggestions, then "add as your own" when what's typed isn't one of them
        readonly property var rows: matches.map(c => ({
                    "label": (pick.kinds.length > 1 ? setupGroup.kindName[c.kind] + ": " : "") + c.name,
                    "price": "~$" + Math.round(c.usd),
                    "entry": c
                })).concat(query && !matches.some(c => norm(c.name) === norm(query)) ? [{
                    "label": I18n.t("＋ «", "＋ “") + query + I18n.t("» — своё", "” — your own"),
                    "price": "",
                    "entry": null
                }] : [])
        onRowsChanged: {
            hi = 0;
            if (drop.want && !drop.opened)
                drop.open();
        }

        function choose(i) {
            const r = rows[i];
            if (!r)
                return;
            if (r.entry) {
                pick.picked(r.entry);
                field.text = "";
                field.input.focus = false;
            } else {
                own = query;
                field.text = "";
                field.input.focus = false;
                price.text = "";
                price.focusField();
            }
        }
        function saveOwn() {
            if (!own)
                return;
            pick.picked({
                "kind": pick.kinds[0],
                "name": own,
                "usd": Math.max(0, parseFloat(price.text.replace(/[^0-9.,]/g, "").replace(",", ".")) || 0)
            });
            own = "";
        }

        PxField {
            id: field
            width: Theme.u * 130
            visible: !pick.own
            placeholder: pick.current ? pick.current.name + "  ~$" + Math.round(pick.current.usd) : pick.empty
            // what the slot holds reads as plain text; a click empties the field for a search
            Binding on text {
                when: !field.input.activeFocus && !!pick.current
                value: pick.current ? pick.current.name + "  ~$" + Math.round(pick.current.usd) : ""
            }
            onKeyPressed: e => {
                if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
                    pick.hi = Math.min(pick.hi + 1, pick.rows.length - 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
                    pick.hi = Math.max(pick.hi - 1, 0);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    pick.choose(pick.hi);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape)
                    field.text = "";
            }

            T.Popup {
                id: drop
                readonly property bool want: field.input.activeFocus && pick.rows.length > 0
                onWantChanged: want ? open() : close()
                y: field.height + Theme.u
                width: Math.max(field.width, Theme.u * 170)
                height: Math.min(list.contentHeight, Theme.u * 150) + Theme.u * 4
                padding: Theme.u * 2
                margins: Theme.u * 2
                modal: false
                focus: false
                closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent
                background: PxBox {
                    color: Theme.tone("face", Theme.p5For(parent))
                    shadow: true
                }
                contentItem: ListView {
                    id: list
                    clip: true
                    model: pick.rows
                    currentIndex: pick.hi
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: sug
                        required property var modelData
                        required property int index
                        readonly property bool lit: index === pick.hi
                        width: list.width
                        height: Theme.sizeBody + Theme.u * 7
                        color: lit ? Theme.select : "transparent"
                        PxText {
                            anchors.left: parent.left
                            anchors.right: cost.left
                            anchors.leftMargin: Theme.u * 4
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: sug.modelData.label
                            color: sug.lit ? Theme.selectText : Theme.tone("text", Theme.p5For(parent))
                        }
                        PxText {
                            id: cost
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.u * 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: sug.modelData.price
                            color: sug.lit ? Theme.selectText : Theme.tone("text", Theme.p5For(parent))
                            dim: !sug.lit
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: pick.hi = sug.index
                            // on press: a click must not lose to the field losing focus
                            onPressed: pick.choose(sug.index)
                        }
                    }
                }
            }
        }
        // your own: its price, then ✓
        PxText {
            visible: !!pick.own
            anchors.verticalCenter: parent.verticalCenter
            text: pick.own
            font.bold: true
        }
        PxField {
            id: price
            visible: !!pick.own
            width: Theme.u * 30
            placeholder: I18n.t("цена $", "price $")
            onAccepted: pick.saveOwn()
            onKeyPressed: e => {
                if (e.key === Qt.Key_Escape)
                    pick.own = "";
            }
        }
        PxButton {
            visible: !!pick.own
            compact: true
            icon: "check"
            onClicked: pick.saveOwn()
        }
        // empty the slot
        PxButton {
            visible: !pick.own && !!pick.current
            compact: true
            icon: "close"
            onClicked: pick.picked(null)
        }
    }
    CatGroup {
        name: "rendering"
        title: I18n.t("Движок отрисовки", "Renderer")
        advanced: true
        icon: "monitor"
        Component.onCompleted: Renderer.refresh()
        CatChoice {
            label: I18n.t("Движок", "Renderer")
            hint: Renderer.mode === "vulkan" ? I18n.t("Vulkan: на NVIDIA (Qt 6.12) окна замирают, пока не двинешь мышь — не рекомендуется", "Vulkan: on NVIDIA (Qt 6.12) windows freeze until the mouse moves — not recommended") : Renderer.mode === "opengl" ? I18n.t("обычный Qt; на NVIDIA анимации упираются в ~60 кадров и дёргаются", "stock Qt; on NVIDIA animations are capped near 60 fps and stutter") : I18n.t("OpenGL + исправленный плагин Qt (если он собран) — рекомендуется", "OpenGL + the fixed Qt plugin (when built) — recommended")
            model: [
                {
                    "label": I18n.t("Авто", "Auto"),
                    "value": "auto"
                },
                {
                    "label": "Vulkan",
                    "value": "vulkan"
                },
                {
                    "label": I18n.t("Обычный", "Stock"),
                    "value": "opengl"
                }
            ]
            currentValue: Renderer.mode
            onActivated: v => Renderer.setMode(v)
        }
        CatNote {
            dim: true
            text: I18n.t("Сейчас: ", "Now: ") + ({
                    "patched": I18n.t("OpenGL, многопоточная отрисовка (исправленный плагин)", "OpenGL, threaded rendering (fixed plugin)"),
                    "vulkan": "Vulkan",
                    "stock": I18n.t("стандартный OpenGL", "stock OpenGL")
                })[Renderer.active] + I18n.t(". Новый режим включится после перезапуска оболочки.", ". A new mode applies after the shell restarts.")
        }
        CatCustom {
            present: !!Renderer.fix.qt
            label: I18n.t("Исправление Qt для NVIDIA", "Qt fix for NVIDIA")
            hint: "Qt " + (Renderer.fix.qt || "?") + " · " + (!Renderer.fix.needed ? I18n.t("не нужно: в этой версии Qt уже исправлено", "not needed: this Qt already has it") : Renderer.fix.built ? I18n.t("собрано ♡", "built ♡") : I18n.t("не собрано", "not built")) + (Renderer.fix.nvidia ? "" : I18n.t(" · видеокарта не NVIDIA", " · not an NVIDIA GPU"))
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxButton {
                        visible: !!Renderer.fix.needed
                        icon: "gear"
                        enabled: !Renderer.building
                        text: Renderer.building ? I18n.t("собираю…", "building…") : Renderer.fix.built ? I18n.t("Пересобрать", "Rebuild") : I18n.t("Собрать", "Build")
                        onClicked: Renderer.build()
                    }
                    PxButton {
                        icon: "power"
                        text: I18n.t("Перезапустить оболочку", "Restart the shell")
                        onClicked: Quickshell.execDetached([Quickshell.shellDir + "/bin/angelos", "restart"])
                    }
                }
            }
        }
        CatNote {
            present: Renderer.log.length > 0
            textKind: "tiny"
            dim: true
            text: Renderer.log.join("\n")
        }
    }
    CatGroup {
        name: "power"
        title: I18n.t("Питание", "Power")
        icon: "power"
        present: SystemInfo.powerProfile !== ""
        CatChoice {
            label: I18n.t("Профиль", "Profile")
            hint: I18n.t("Экономия — тише и дольше от батареи, Мощность — быстрее, но горячее.", "Power saver: quieter, longer on battery. Performance: faster but hotter.")
            model: [
                {
                    "label": I18n.t("Экономия", "Power saver"),
                    "value": "power-saver"
                },
                {
                    "label": I18n.t("Баланс", "Balanced"),
                    "value": "balanced"
                },
                {
                    "label": I18n.t("Мощность", "Performance"),
                    "value": "performance"
                },
                {
                    "label": I18n.t("Киберспорт", "Esports"),
                    "value": "esports"
                }
            ]
            currentValue: Power.profile
            onActivated: v => Power.setProfile(v)
        }
        CatToggle {
            label: I18n.t("Окно в фокусе — первым", "The window in focus first")
            hint: I18n.t("Программа, в которой ты сейчас, получает процессор первой: меньше подтормаживаний.", "The app you're in gets the CPU first: fewer hitches.")
            checked: Config.system.focusBoost !== false
            onToggled: c => Config.system.focusBoost = c
        }
    }
    // angel-niri: the screens without the game draw less while it runs, the game may tear
    // (niri-game-mode → niri's set-background-fps, set-tearing); stock niri has no such thing.
    // NVIDIA's clock (niri-game-mode → gpu-clocks) works on either
    CatGroup {
        name: "games-background"
        title: I18n.t("Во время игры", "While a game runs")
        icon: "gamepad"
        present: Niri.nativeMinimize || ScreenTune.nvidia
        CatChoice {
            present: Niri.nativeMinimize
            label: I18n.t("Фон во время игры", "The rest while gaming")
            hint: I18n.t("Пока идёт игра, другие экраны рисуются реже — видеокарта остаётся игре.", "While a game runs, other screens draw less often, leaving the GPU to the game.")
            model: [
                {"label": I18n.t("как есть", "as is"), "value": 0},
                {"label": "30", "value": 30},
                {"label": "60", "value": 60},
                {"label": "120", "value": 120}
            ]
            currentValue: Config.gaming.backgroundFps
            onActivated: v => Config.gaming.backgroundFps = v
        }
        CatToggle {
            present: Niri.nativeMinimize
            label: I18n.t("Разрыв кадра", "Tearing")
            hint: I18n.t("Меньше задержка мыши, но иногда видна полоса разрыва. Со следующей игры.", "Less mouse lag, but a tear line may show. From the next game.")
            checked: Config.gaming.tearing !== false
            onToggled: c => Config.gaming.tearing = c
        }
        CatToggle {
            present: Niri.nativeMinimize
            label: I18n.t("Мышь не уходит из игры", "The mouse stays in the game")
            hint: I18n.t("Курсор не убегает на другой монитор в игре. Держи Win — выйдет. Со следующей игры.", "The pointer stays in the game's screen. Hold Win to leave. From the next game.")
            checked: Config.gaming.pointerLock !== false
            onToggled: c => Config.gaming.pointerLock = c
        }
        CatToggle {
            present: ScreenTune.nvidia
            label: I18n.t("Видеокарта на полной частоте", "The video card at full speed")
            hint: I18n.t("Видеокарта NVIDIA не сбавляет частоту в игре — лёгкие игры не дёргаются. Со следующей игры.", "The NVIDIA card keeps its clock up in games, so light games don't stutter. Next game on.")
            checked: Config.gaming.gpuClocks !== false
            onToggled: c => Config.gaming.gpuClocks = c
        }
    }
    CatGroup {
        name: "this-computer"
        title: I18n.t("Этот компьютер", "This computer")
        icon: "chip"
        CatCustom {
            wide: true
            CatBox {
                Row {
                    spacing: Theme.u * 8
                    width: parent.width
                    PxIcon {
                        id: ghost
                        name: "ghost"
                        pixel: Theme.u * 5
                    }
                    Grid {
                        id: infoGrid
                        // the names' column: the values wrap in what is left
                        readonly property real namesWidth: {
                            let w = 0;
                            for (const c of children)
                                if (c.modelData && c.modelData.dim)
                                    w = Math.max(w, c.implicitWidth);
                            return w;
                        }
                        width: parent.width - ghost.width - parent.spacing
                        columns: 2
                        columnSpacing: Theme.u * 8
                        rowSpacing: Theme.u * 2
                        Repeater {
                            model: [[I18n.t("Система", "System"), "os"], [I18n.t("Ядро", "Kernel"), "kernel"], [I18n.t("Хост", "Host"), "host"], [I18n.t("Процессор", "CPU"), "cpu"], [I18n.t("Видеокарта", "GPU"), "gpu"], [I18n.t("Память", "Memory"), "mem"], ["Работает", "uptime"], ["niri", "niri"], ["Quickshell", "qs"], [I18n.t("Шелл", "Shell"), "shell"]].reduce((a, r) => a.concat([
                                    {
                                        "t": r[0],
                                        "dim": true
                                    },
                                    {
                                        "t": SystemInfo.info[r[1]] || "—",
                                        "dim": false
                                    }
                                ]), [])
                            PxText {
                                required property var modelData
                                width: modelData.dim ? implicitWidth : Math.max(0, Math.min(implicitWidth, infoGrid.width - infoGrid.namesWidth - infoGrid.columnSpacing))
                                wrapMode: Text.Wrap
                                text: modelData.t
                                dim: modelData.dim
                            }
                        }
                    }
                }
            }
        }
        // services/QsVersion: older than the Quickshell angelOS is tested on
        CatNote {
            present: QsVersion.outdated
            text: "⚠ " + QsVersion.advice
        }
    }
    Component.onCompleted: {
        SystemInfo.refresh();
        DesktopActions.refresh();
    }
    // the expensive toys: popular models over $100 found plugged in, plus what each user adds
    // (what is in the interface's inputs and jacks, the rest of the desk) — kept by gear.py in
    // their own ~/.config/angelos/gear.json, never published
    CatGroup {
        id: setupGroup
        name: "your-setup"
        title: I18n.t("Твой сетап ✧", "Your setup ✧")
        icon: "star"
        readonly property var kindIcon: ({
                "keyboard": "keyboard",
                "mouse": "mouse",
                "mic": "mic",
                "xlr": "mic",
                "headphones": "headphones"
            })
        readonly property var kindName: ({
                "keyboard": I18n.t("Клавиатура", "Keyboard"),
                "mouse": I18n.t("Мышь", "Mouse"),
                "mic": I18n.t("Микрофон", "Microphone"),
                "xlr": I18n.t("Микрофон (XLR)", "Microphone (XLR)"),
                "headphones": I18n.t("Наушники", "Headphones"),
                "other": I18n.t("На столе", "On the desk")
            })
        // detected ones, and own ones not plugged into a detected interface
        readonly property var topLevel: SystemInfo.gear.filter(d => !d.mine || !d.on || !SystemInfo.gear.some(p => !p.mine && p.name === d.on))
        function plain(d) {
            const r = {
                "kind": d.kind,
                "name": d.name,
                "usd": d.usd
            };
            if (d.on)
                r.on = d.on;
            if (d.port)
                r.port = d.port;
            return r;
        }
        function same(a, b) {
            return a.name === b.name && (a.on || "") === (b.on || "") && (a.port || "") === (b.port || "");
        }
        function inSlot(on, port) {
            return SystemInfo.gearMine.find(d => d.on === on && d.port === port) || null;
        }
        // entry: {kind, name, usd} or null to empty the slot
        function setSlot(on, port, entry) {
            const rows = SystemInfo.gearMine.filter(d => !(d.on === on && d.port === port)).map(plain);
            if (entry)
                rows.push(Object.assign(plain(entry), {
                    "on": on,
                    "port": port
                }));
            SystemInfo.saveGear(rows);
        }
        function add(entry) {
            SystemInfo.saveGear(SystemInfo.gearMine.map(plain).concat([plain(entry)]));
        }
        function remove(d) {
            SystemInfo.saveGear(SystemInfo.gearMine.filter(m => !same(m, d)).map(plain));
        }
        function slots(d) {
            const out = [], p = d.ports || {};
            for (let i = 1; i <= (p["in"] || 0); i++)
                out.push({
                    "port": "in" + i,
                    "kind": "xlr",
                    "label": I18n.t("Вход ", "Input ") + i
                });
            for (let i = 1; i <= (p.phones || 0); i++)
                out.push({
                    "port": "phones" + i,
                    "kind": "headphones",
                    "label": p.phones > 1 ? I18n.t("Наушники ", "Headphones ") + i : I18n.t("Наушники", "Headphones")
                });
            return out;
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: setupGroup.topLevel
                    Column {
                        id: gearRow
                        required property var modelData
                        width: parent.width
                        spacing: Theme.u * 2
                        Row {
                            spacing: Theme.u * 4
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: setupGroup.kindIcon[gearRow.modelData.kind] || "star"
                                pixel: Theme.u * 2
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                PxText {
                                    text: gearRow.modelData.name
                                    font.bold: true
                                }
                                PxText {
                                    text: setupGroup.kindName[gearRow.modelData.kind] + " · ~$" + Math.round(gearRow.modelData.usd) + (gearRow.modelData.on ? I18n.t(" · в ", " · in ") + gearRow.modelData.on : "")
                                    kind: "tiny"
                                    dim: true
                                }
                            }
                            PxButton {
                                visible: !!gearRow.modelData.mine
                                anchors.verticalCenter: parent.verticalCenter
                                compact: true
                                icon: "close"
                                onClicked: setupGroup.remove(gearRow.modelData)
                            }
                        }
                        // what is plugged into the interface: a row per input and headphone jack
                        Repeater {
                            model: gearRow.modelData.mine ? [] : setupGroup.slots(gearRow.modelData)
                            SettingRow {
                                id: slotRow
                                required property var modelData
                                width: gearRow.width
                                label: "   " + slotRow.modelData.label
                                GearPick {
                                    kinds: [slotRow.modelData.kind]
                                    current: setupGroup.inSlot(gearRow.modelData.name, slotRow.modelData.port)
                                    onPicked: e => setupGroup.setSlot(gearRow.modelData.name, slotRow.modelData.port, e)
                                }
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            label: I18n.t("Добавить ещё", "Add more")
            hint: I18n.t("наушники, микрофон, камера — что угодно на столе", "headphones, a mic, a camera — anything on the desk")
            CatBox {
                GearPick {
                    kinds: ["headphones", "xlr", "mic", "other"]
                    empty: I18n.t("напиши, что ещё на столе…", "type what else is on the desk…")
                    onPicked: e => {
                        if (e)
                            setupGroup.add(e);
                    }
                }
            }
        }
        CatNote {
            textKind: "tiny"
            dim: true
            text: I18n.t("Популярные клавиатуры, мыши и микрофоны дороже $", "Popular keyboards, mice and microphones over $") + Math.round(SystemInfo.gearThreshold) + I18n.t(" находятся сами. Остальное добавь сам — это хранится только у тебя и никуда не публикуется.", " are found by themselves. Add the rest yourself: it stays only with you and is never published.")
        }
        CatButton {
            compact: true
            icon: "refresh"
            text: I18n.t("Проверить снова", "Check again")
            onClicked: SystemInfo.refresh()
        }
    }
    // fastfetch in angelOS's styles (scripts/fastfetch_style.py, services/FastfetchLogo):
    // a card each, the picked one run for real below — in heaven or in any circle of hell
    CatGroup {
        id: ffGroup
        name: "fastfetch"
        title: "fastfetch"
        icon: "monitor"
        property string pick: FastfetchLogo.style
        property string realm: Angel.demon ? (HellLook.circle || "base") : "heaven"
        readonly property var styles: FastfetchLogo.styles
        readonly property var circles: ["base", "limbo", "lust", "gluttony", "greed", "wrath", "heresy", "violence", "fraud", "treachery"]
        // what ThemeExport.fastfetchHell gives terminal-hell.py, for any circle
        function hellOf(c) {
            const look = HellLook.merged(HellLook.fallback, HellLook.looks.base, c !== "base" ? HellLook.looks[c] : null);
            const p = look.palette, n = look.n || 0;
            const h = x => Theme.hex(Qt.color(x));
            const lab = id => look.labels && look.labels[id] ? I18n.label(look.labels[id]) : "";
            return {
                "circle": c,
                "number": n,
                "roman": n > 0 ? Theme.roman(n) : "",
                "name": I18n.label(look.name || {}),
                "where": I18n.label(look.where || {}),
                "circleWord": I18n.t("Круг", "Circle"),
                "labels": {
                    "cpu": lab("cpu"),
                    "gpu": lab("gpu"),
                    "ram": lab("ram")
                },
                "keys": h(p.accent),
                "title": h(p.text),
                "dim": h(p.textDim),
                "palette": {
                    "#": h(Theme.mix(Qt.color(p.accent), Qt.color(p.edge), 0.55)),
                    "o": h(p.accent),
                    "x": h(p.blood),
                    "y": h(p.flame),
                    "w": h(p.text),
                    "f": h(p.textDim),
                    "r": h(p.accent),
                    "p": h(Theme.mix(Qt.color(p.accent), Qt.color(p.text), 0.45))
                }
            };
        }
        function refresh() {
            if (ffPreview.running) {
                ffPreview.again = true;
                return;
            }
            const st = pick === "own" ? "compact" : pick;
            let cmd = FastfetchLogo.args("preview", st);
            if (realm !== "heaven") {
                cmd = cmd.concat(["--hell", JSON.stringify(hellOf(realm))]);
                // before any circle: the emblem with horns
                cmd[cmd.indexOf("--emblem-rows") + 1] = JSON.stringify(Logos.emblem(FastfetchLogo.emblem, true));
            }
            ffPreview.command = cmd;
            ffPreview.running = true;
        }
        onPickChanged: refresh()
        onRealmChanged: refresh()
        Component.onCompleted: refresh()
        Process {
            id: ffPreview
            property bool again: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const r = JSON.parse(text);
                        if (r.lines)
                            ffScreen.screen = r;
                    } catch (e) {}
                }
            }
            onExited: if (again) {
                again = false;
                ffGroup.refresh();
            }
        }
        CatNote {
            dim: true
            text: I18n.t("Что печатает fastfetch в новом терминале. Цвета и значок — из темы и «Пуска».", "What fastfetch prints in a new terminal. Colours and the logo come from the theme and Start.")
        }
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: ffGroup.styles
                        Item {
                            id: ffCard
                            required property var modelData
                            readonly property bool picked: ffGroup.pick === modelData.id
                            width: Math.floor((parent.width - Theme.u * 8) / 3)
                            height: ffCol.implicitHeight + Theme.u * 10
                            PxBox {
                                anchors.fill: parent
                                sunken: ffCard.picked
                                color: ffCard.picked ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.22) : ffm.containsMouse ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.1) : Theme.tone("face", Theme.p5For(parent))
                                edgeColor: ffCard.picked ? Theme.accent : Theme.tone("edge", Theme.p5For(parent))
                            }
                            Column {
                                id: ffCol
                                x: Theme.u * 5
                                y: Theme.u * 5
                                width: parent.width - Theme.u * 10
                                spacing: Theme.u * 2
                                PxText {
                                    text: (ffCard.picked ? "♡ " : "") + ffCard.modelData.name
                                    font.bold: true
                                }
                                PxText {
                                    width: parent.width
                                    text: ffCard.modelData.hint
                                    kind: "tiny"
                                    dim: true
                                    wrapMode: Text.Wrap
                                }
                            }
                            MouseArea {
                                id: ffm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ffGroup.pick = ffCard.modelData.id;
                                    Config.bar.fastfetchStyle = ffCard.modelData.id;
                                }
                            }
                        }
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Анимация", "Animation")
            hint: I18n.t("картинка оживает в новом терминале: машет крыльями, блестит, искрится; любая клавиша — сразу к делу", "the picture comes alive in a new terminal: wings flap, it shines and sparkles; any key gets you straight to work")
            combo: true
            model: [
                {
                    "label": I18n.t("Выключена", "Off"),
                    "value": "off"
                },
                {
                    "label": I18n.t("Коротко — 2,5 с", "Short: 2.5 s"),
                    "value": "short"
                },
                {
                    "label": I18n.t("Подольше — 6 с", "Longer: 6 s"),
                    "value": "long"
                }
            ]
            currentValue: Config.bar.fastfetchAnim || "short"
            onActivated: v => Config.bar.fastfetchAnim = v
        }
        CatNote {
            textKind: "tiny"
            dim: true
            present: Motion.still && Config.bar.fastfetchAnim !== "off"
            text: I18n.t("Сейчас картинка стоит: анимации выключены (Окна и столы → Анимации).", "The picture stays still for now: animations are off (Windows and desks → Animations).")
        }
        CatChoice {
            label: I18n.t("Показать", "Show")
            hint: I18n.t("рай — как сейчас; круги — как будет в аду (там fastfetch меняется сам)", "heaven is how it is now; the circles are how hell shows it (it changes there by itself)")
            combo: true
            model: [
                {
                    "label": I18n.t("Рай", "Heaven"),
                    "value": "heaven"
                }
            ].concat(ffGroup.circles.map(c => {
                const look = c === "base" ? null : HellLook.looks[c];
                return {
                    "label": c === "base" ? I18n.t("Ад (до кругов)", "Hell (before the circles)") : (look && look.n ? Theme.roman(look.n) + " · " : "") + I18n.label(look ? look.name || {} : {}),
                    "value": c
                };
            }))
            currentValue: ffGroup.realm
            onActivated: v => ffGroup.realm = v
        }
        CatCustom {
            wide: true
            CatBox {
                PxBox {
                    width: parent.width
                    height: ffScreen.height * ffScreen.scale + Theme.u * 4
                    sunken: true
                    color: ffScreen.background
                    clip: true
                    FastfetchPreview {
                        id: ffScreen
                        animate: Config.bar.fastfetchAnim !== "off"
                        x: Theme.u * 2
                        y: Theme.u * 2
                        width: implicitWidth
                        height: implicitHeight
                        transformOrigin: Item.TopLeft
                        scale: Math.min(1, (parent.width - Theme.u * 4) / Math.max(1, implicitWidth))
                    }
                    PxText {
                        anchors.centerIn: parent
                        visible: !(ffScreen.screen.lines || []).length
                        text: ffPreview.running ? I18n.t("запускаю fastfetch…", "running fastfetch…") : I18n.t("fastfetch не установлен?", "is fastfetch installed?")
                        dim: true
                    }
                }
            }
        }
        CatNote {
            textKind: "tiny"
            dim: true
            present: ffGroup.pick === "own"
            text: I18n.t("Выше — «Компакт» для сравнения. Свой config.jsonc angelOS не трогает.", "Compact is above for comparison. angelOS never touches your own config.jsonc.")
        }
    }
    CatGroup {
        name: "angelos"
        title: "angelOS"
        icon: "heart"
        CatNote {
            text: I18n.t("angelOS — пиксельная оболочка на Quickshell для niri. Конфиг: ", "angelOS is a pixel shell built with Quickshell for niri. Config: ") + Quickshell.shellDir + I18n.t(", настройки: ", ", settings: ") + Config.dir
            dim: true
        }
        CatButton {
            text: I18n.t("Перезапустить оболочку", "Restart shell")
            icon: "refresh"
            onClicked: Quickshell.reload(true)
            CatButton {
                text: I18n.t("Перечитать niri", "Reload niri")
                icon: "refresh"
                onClicked: Niri.action("LoadConfigFile", {})
            }
            CatButton {
                text: I18n.t("Папка настроек", "Settings folder")
                icon: "folder"
                onClicked: Shell.openPath(Config.dir)
            }
            CatButton {
                text: I18n.t("Бэкапы", "Backups")
                icon: "package"
                onClicked: Shell.openPath(Config.stateDir + "/backups")
            }
        }
    }
    CatGroup {
        name: "report-problem"
        id: reportGroup
        title: I18n.t("Сообщить о проблеме", "Report a problem")
        advanced: true
        icon: "warn"
        property var result: null
        property bool busy: false
        CatButton {
            label: I18n.t("Отчёт для issue", "A report for an issue")
            hint: reportGroup.result ? I18n.t("готово: ", "done: ") + reportGroup.result.archive.replace(Config.home, "~") + I18n.t(" — прикрепи его к issue на GitHub", " — attach it to a GitHub issue") : I18n.t("версии, лог оболочки, краш-отчёты и настройки в одном архиве; путь к дому и имя заменены, личное (история запусков, имена столов, данные плагинов) не попадает. То же в терминале: angelos report", "Versions, the shell log, crash reports and settings in one archive; your home path and name are replaced, personal bits (launch history, workspace names, plugin data) stay out. Same in a terminal: angelos report")
            enabled: !reportGroup.busy
            icon: "package"
            text: reportGroup.busy ? I18n.t("Собираю…", "Packing…") : I18n.t("Собрать отчёт", "Make a report")
            onClicked: {
                reportGroup.busy = true;
                reportProc.running = true;
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    visible: !!reportGroup.result
                    spacing: Theme.u * 4
                    PxButton {
                        icon: "folder"
                        text: I18n.t("Показать архив", "Show the archive")
                        onClicked: Shell.openPath(reportGroup.result.archive.replace(/\/[^\/]*$/, ""))
                    }
                    PxButton {
                        accent: true
                        icon: "bell"
                        text: I18n.t("Открыть форму issue", "Open the issue form")
                        onClicked: Shell.exec(["xdg-open", reportGroup.result.issue])
                    }
                }
            }
        }
        Process {
            id: reportProc
            command: ["python3", Quickshell.shellDir + "/scripts/report.py", "--json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        reportGroup.result = JSON.parse(text);
                    } catch (e) {
                        reportGroup.result = null;
                    }
                }
            }
            onExited: reportGroup.busy = false
        }
    }
    CatGroup {
        name: "development"
        title: I18n.t("Разработка", "Development")
        advanced: true
        icon: "sparkle"
        CatToggle {
            label: I18n.t("Режим разработчика", "Developer mode")
            hint: I18n.t("Добавляет мастер плагинов в настройки и меню «Пуск». Установленные плагины работают и без этого режима.", "Adds Plugin Studio to Settings and Start. Installed plugins keep working when this mode is off.")
            checked: Config.developer.enabled
            onToggled: c => Config.developer.enabled = c
        }
        CatToggle {
            present: Config.developer.enabled
            label: I18n.t("Показывать настройки ноутбука", "Show the laptop's settings")
            hint: Laptop.isLaptop ? I18n.t("это ноутбук — они и так видны", "This is a laptop: they show anyway") : I18n.t("на ПК их нет: батарея, тачпад, крышка, подсветка, клавиши ноутбука, планшет. Включи, чтобы показать их (как выглядят на ноутбуке); работать без железа они не будут", "A desktop has none: battery, touchpad, lid, backlight, laptop keys, tablet. Turn on to show them (as on a laptop); without the hardware they do nothing")
            checked: Config.developer.showLaptop
            onToggled: c => Config.developer.showLaptop = c
        }
        CatCustom {
            wide: true
            CatBox {
                PxButton {
                    visible: Config.developer.enabled
                    text: I18n.t("Открыть мастер плагинов", "Open Plugin Studio")
                    icon: "sparkle"
                    onClicked: Shell.settingsGo(systemPage, "studio")
                }
            }
        }
    }
    // ---- the author's only: see and steer the story — the game's debug panel (GameDebug,
    // owner/debug after the GitHub login); developer mode does not open it ----
    CatGroup {
        name: "game-developer-tools"
        title: I18n.t("Игра: инструменты разработчика", "The game: developer tools")
        advanced: true
        icon: "chip"
        present: GameDebug.allowed
        CatButton {
            label: I18n.t("Панель отладки игры", "The game's debug panel")
            hint: I18n.t("Всё состояние игры и любая переменная, любой круг и сцена, эффекты, облики и звуки, снимок сохранения — в отдельном окне. Или `angelos debug`.", "The whole state of the game and every variable, any circle and scene, the effects, looks and sounds, a snapshot of the save — in a window of its own. Or `angelos debug`.")
            icon: "chip"
            text: I18n.t("Открыть", "Open")
            onClicked: GameDebug.open = true
        }
    }
    CatGroup {
        name: "task-manager"
        title: I18n.t("Диспетчер задач", "Task Manager")
        advanced: true
        icon: "chip"
        CatChoice {
            label: I18n.t("Системный монитор", "System monitor")
            hint: I18n.t("Запускается также через ПКМ по свободному месту панели", "Also available by right-clicking empty taskbar space")
            combo: true
            model: [{value: "auto", label: I18n.t("Автоматически", "Automatic")}].concat(DesktopActions.monitors, [{value: "custom", label: I18n.t("Другая программа…", "Custom application…")}])
            currentValue: Config.system.monitor
            onActivated: v => Config.system.monitor = v
        }
        CatField {
            present: Config.system.monitor === "custom"
            label: I18n.t("Программа", "Executable")
            hint: I18n.t("Имя программы или полный путь, без аргументов", "Program name or full path, without arguments")
            text: Config.system.monitorProgram
            placeholder: "missioncenter"
            onEdited: Config.system.monitorProgram = text
        }
        CatToggle {
            present: Config.system.monitor === "custom"
            label: I18n.t("Запускать в терминале", "Run in terminal")
            hint: I18n.t("Для консольных программ вроде btop: открыть их в терминале.", "For console apps like btop: open them in a terminal.")
            checked: Config.system.monitorInTerminal
            onToggled: c => Config.system.monitorInTerminal = c
        }
        CatToggle {
            label: I18n.t("Всегда плавающее окно", "Always a floating window")
            hint: I18n.t("окно диспетчера открывается поверх остальных", "The task manager opens on top of the rest")
            checked: Config.system.monitorFloat
            onToggled: c => Config.system.monitorFloat = c
        }
        CatChoice {
            present: Config.system.monitorFloat
            label: I18n.t("Размер окна", "Window size")
            hint: ({
                    "compact": "900 × 560",
                    "medium": "1200 × 760",
                    "large": "1500 × 950",
                    "tall": I18n.t("40% ширины × 90% высоты экрана — колонка сбоку", "40% of the width × 90% of the height — a side column"),
                    "custom": I18n.t("свои значения ниже", "your values below")
                })[Config.system.monitorSize] || ""
            model: [
                {
                    "label": I18n.t("Компактный", "Compact"),
                    "value": "compact"
                },
                {
                    "label": I18n.t("Средний", "Medium"),
                    "value": "medium"
                },
                {
                    "label": I18n.t("Большой", "Large"),
                    "value": "large"
                },
                {
                    "label": I18n.t("Высокий", "Tall"),
                    "value": "tall"
                },
                {
                    "label": I18n.t("Свой", "Custom"),
                    "value": "custom"
                }
            ]
            currentValue: Config.system.monitorSize
            onActivated: v => Config.system.monitorSize = v
        }
        CatCustom {
            present: Config.system.monitorFloat && Config.system.monitorSize === "custom"
            label: I18n.t("Ширина × высота", "Width × height")
            hint: I18n.t("логические пиксели", "logical pixels")
            CatBox {
                Row {
                    spacing: Theme.u * 3
                    PxSpin {
                        from: 320
                        to: 7680
                        stepSize: 20
                        value: Config.system.monitorWidth
                        onMoved: v => Config.system.monitorWidth = v
                    }
                    PxText {
                        text: "×"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PxSpin {
                        from: 240
                        to: 4320
                        stepSize: 20
                        value: Config.system.monitorHeight
                        onMoved: v => Config.system.monitorHeight = v
                    }
                }
            }
        }
        CatChoice {
            present: Config.system.monitorFloat
            label: I18n.t("Где открывать", "Where it opens")
            hint: I18n.t("Где появится окно диспетчера задач.", "Where the task manager window appears.")
            model: [
                {
                    "label": I18n.t("По центру", "Centre"),
                    "value": "center"
                },
                {
                    "label": I18n.t("У трея (справа внизу)", "By the tray (bottom right)"),
                    "value": "corner"
                }
            ]
            currentValue: Config.system.monitorPlace
            onActivated: v => Config.system.monitorPlace = v
        }
        CatNote {
            present: Config.system.monitorFloat && WindowConfig.log !== ""
            textKind: "tiny"
            dim: true
            text: WindowConfig.log
        }
        CatButton {
            text: I18n.t("Открыть диспетчер задач", "Open Task Manager")
            icon: "chip"
            enabled: DesktopActions.available
            onClicked: DesktopActions.launchMonitor()
        }
    }
    CatGroup {
        name: "programs"
        title: I18n.t("Свои команды", "Your own commands")
        advanced: true
        icon: "terminal"
        CatNote {
            dim: true
            text: I18n.t("Обычно их ставит выбор выше. Здесь — если нужна команда с ключами.", "The choice above sets them. Here: when a command needs its own options.")
        }
        CatField {
            label: I18n.t("Терминал", "Terminal")
            text: Config.system.terminal
            onEdited: Config.system.terminal = text
        }
        CatField {
            label: I18n.t("Файловый менеджер", "File manager")
            text: Config.system.fileManager
            onEdited: Config.system.fileManager = text
        }
    }
    // ---- the game (services/Story): accessibility, and the way back in once it was switched off ----
    CatGroup {
        name: "game"
        title: I18n.t("Игра", "The game")
        icon: "heart"
        present: !Config.game.enabled
        CatButton {
            present: !Config.game.enabled
            label: I18n.t("Игра выключена", "The game is off")
            hint: I18n.t("angelOS без ангела, демоницы и новеллы. Включишь — ангел снова в углу.", "angelOS without the angel, the demon or the novel. Switch it on and she's back.")
            icon: "heart"
            accent: true
            text: I18n.t("Включить игру", "Turn the game on")
            onClicked: Story.setEnabled(true)
        }
    }
}
