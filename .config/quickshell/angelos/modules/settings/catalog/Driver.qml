// The settings once in DriverPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Device driver (2026-10-12; services/Devices, scripts/devices.py): Hall-effect keyboards
// and mice set up from the shell, without the maker's site or a Windows utility. A device
// is drawn from its description file (data/devices, ~/.config/angelos/devices): what it
// says it can do is on the page, the rest is not.
//
// The keyboard is laid out like the maker's own configurator: the board on top, tabs under
// it (keys, travel, Snap Tap, Mod-Tap/Toggle, lights, modes, profiles, a key test), and what
// the tab is about drawn on the board itself. A click on a key or a press of it picks the
// key; while the board listens, key presses stay here and do not reach the search field.
CatPage {
    id: page
    heading: I18n.t("Драйвер устройств", "Device driver")
    subtitle: I18n.t("Клавиши, подсветка, чувствительность и частота опроса мыши и клавиатуры.", "Keys, lights, sensitivity and polling rate of the mouse and keyboard.")
    // the helper runs only while this page is on the screen
    readonly property bool live: showing && !!Window.window && Window.window.visible
    property bool held: false
    function sync() {
        if (live === held)
            return;
        held = live;
        if (live)
            Devices.hold();
        else
            Devices.release();
    }
    onLiveChanged: {
        sync();
        if (!live)
            page.stopListening();
    }
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held)
            Devices.release();
        if (watching)
            Devices.unwatch();
    }
    readonly property var dev: Devices.current
    readonly property var st: Devices.state
    readonly property bool isKeyboard: !!dev && dev.kind === "keyboard"
    readonly property bool isMouse: !!dev && dev.kind === "mouse"
    readonly property var mouse: st && st.kind === "mouse" ? st : null
    readonly property var kb: st && st.kind === "keyboard" ? st : null
    function capOf(name) {
        const c = dev && dev.capabilities ? dev.capabilities[name] : null;
        return c && typeof c === "object" ? c : ({});
    }
    function sleepLabel(sec) {
        return sec < 60 ? sec + I18n.t(" с", " s") : sec / 60 + I18n.t(" мин", " min");
    }
    // the mouse's DPI stages with one of them changed, as the helper takes them
    function stagesWith(index, dpi) {
        return page.mouse.dpiStages.map((s, i) => i === index ? dpi : s.x);
    }
    readonly property real travel: {
        const sw = dev && dev.switches || [];
        return sw.reduce((a, s) => Math.max(a, s.travel), 0) || 3.3;
    }
    function cap(name) {
        return !!dev && !!dev.capabilities && !!dev.capabilities[name];
    }
    function mm(v) {
        return (Math.round(v * 100) / 100).toFixed(2) + " " + I18n.t("мм", "mm");
    }
    function switchName(id) {
        const s = (dev && dev.switches || []).find(x => x.id === id);
        return s ? s.name : I18n.t("переключатель №", "switch #") + id;
    }
    // ---- the tabs under the board ----
    property string tab: "remap"
    readonly property var tabs: [
        {
            "id": "remap",
            "label": I18n.t("Клавиши", "Keys"),
            "about": I18n.t("Что делает каждая клавиша, в основном слое и в слоях Fn. Выбери клавишу (клик по ней или просто нажми её), потом действие ниже.", "What each key does, in the base layer and in the Fn layers. Pick a key (click it, or just press it), then an action below.")
        },
        {
            "id": "travel",
            "label": I18n.t("Срабатывание", "Actuation"),
            "about": I18n.t("На какой глубине клавиша нажимается и отпускается: точка срабатывания, Rapid Trigger, мёртвые зоны. Под подписью клавиши — её точка в мм.", "How deep a key presses and lets go: the actuation point, Rapid Trigger, dead zones. Under a key's legend: its point in mm.")
        },
        {
            "id": "snaptap",
            "label": "Snap Tap",
            "about": I18n.t("Пары клавиш, которые не бывают нажаты вместе (A/D, W/S): зажал вторую — первая отпустилась.", "Pairs of keys that are never down together (A/D, W/S): hold the second and the first lets go.")
        },
        {
            "id": "special",
            "label": "Mod-Tap / Toggle",
            "about": I18n.t("Одна клавиша — два действия. Mod-Tap: тап — одно, удержание — другое (Caps: тап Esc, держишь — Ctrl). Toggle: тап залипает нажатым до следующего тапа.", "One key, two actions. Mod-Tap: a tap is one, holding it another (Caps: tap Esc, hold Ctrl). Toggle: a tap stays down until the next tap.")
        },
        {
            "id": "light",
            "label": I18n.t("Подсветка", "Lights"),
            "about": I18n.t("Подсветка клавиш и боковая полоса в текущем режиме клавиатуры.", "The key light and the side strip in the keyboard's current mode.")
        },
        {
            "id": "modes",
            "label": I18n.t("Режимы", "Modes"),
            "about": I18n.t("Три набора настроек клавиатуры (Gaming / Windows / Mac — переключаются на ней самой): частота опроса, сон, блокировки, стабилизация.", "The keyboard's three sets of settings (Gaming / Windows / Mac, switched on the keyboard itself): polling rate, sleep, locks, stabilisation.")
        },
        {
            "id": "profiles",
            "label": I18n.t("Профили", "Profiles"),
            "about": I18n.t("Все настройки клавиатуры в файл и обратно; «вернуть как было» — к снимку, снятому до первой записи из оболочки.", "Every setting of the keyboard into a file and back; \"put it back\" goes to the snapshot taken before the shell's first write.")
        },
        {
            "id": "test",
            "label": I18n.t("Проверка", "Test"),
            "about": I18n.t("Жми клавиши: каждая подсвечивается и заливается на глубину нажатия. Нажатия остаются здесь и никуда больше не попадают.", "Press keys: each one lights up and fills as deep as it goes. The presses stay here and reach nothing else.")
        }
    ]
    readonly property var tabNow: tabs.find(t => t.id === tab) || tabs[0]
    Connections {
        target: Devices
        function onPageAsk(ask) {
            if (ask.what === "tab" && page.tabs.find(t => t.id === ask.value))
                page.tab = ask.value;
            else if (ask.what === "select")
                page.selection = ask.value;
        }
    }
    onTabChanged: {
        if (tab === "test")
            catcher.forceActiveFocus();
    }
    // ---- the keys picked: a click (or a press, while the board listens) picks one,
    // Ctrl or Shift + click adds to them ----
    property var selection: []
    function pick(m, modifiers) {
        const many = modifiers & (Qt.ControlModifier | Qt.ShiftModifier);
        const at = selection.indexOf(m);
        if (many)
            selection = at >= 0 ? selection.filter(x => x !== m) : selection.concat([m]);
        else
            selection = at >= 0 && selection.length === 1 ? [] : [m];
    }
    readonly property var layoutKeys: dev && dev.layout ? dev.layout.keys : []
    function byLabels(labels) {
        return layoutKeys.filter(k => labels.includes(String(k.label || "").toUpperCase())).map(k => k.m);
    }
    function labelOf(m) {
        const k = layoutKeys.find(x => x.m === m);
        return k ? k.label || String(m) : String(m);
    }
    // the key whose numbers are shown: the last one picked, else the one pressed last
    readonly property int shownKey: tab === "test" ? (lastHeard >= 0 ? lastHeard : board.lastKey) : selection.length ? selection[selection.length - 1] : board.lastKey
    readonly property var shownRule: kb && shownKey >= 0 ? kb.keys[String(shownKey)] || null : null
    readonly property string shownLabel: shownKey >= 0 ? labelOf(shownKey) : ""
    readonly property int oneKey: selection.length === 1 ? selection[0] : -1
    // what the device says it can be set to
    readonly property var limA: dev && dev.capabilities && dev.capabilities.actuation || ({
            "min": 0.1,
            "max": travel,
            "step": 0.01
        })
    readonly property var limR: dev && dev.capabilities && dev.capabilities.rapidTrigger || ({
            "min": 0.01,
            "max": travel
        })
    readonly property real limD: dev && dev.capabilities && dev.capabilities.deadZones ? dev.capabilities.deadZones.max : 0
    readonly property bool canEdit: Devices.canWrite && selection.length > 0 && !Devices.working
    function setRt(values) {
        Devices.setRt(selection, values);
    }
    // Snap Tap pairs of the current mode, and each key's partner
    readonly property var pairs: kb && kb.pairs ? kb.pairs : []
    readonly property var partner: {
        const out = {};
        for (const p of pairs) {
            out[p.a] = p.b;
            out[p.b] = p.a;
        }
        return out;
    }
    function ruleOf(p) {
        const a = kb && kb.keys ? kb.keys[String(p.a)] : null;
        return !a ? "last" : a.priority === "own" ? "a" : a.priority === "bond" ? "b" : a.priority === "neutral" ? "neutral" : "last";
    }
    property string pairKind: "socd"
    property int modeShown: -1          // the mode whose settings are edited; -1: the keyboard's current one
    readonly property int modeIndex: !kb ? 0 : modeShown >= 0 ? modeShown : kb.mode
    readonly property var modeData: kb ? kb.modes[modeIndex] || null : null
    property bool sureRestore: false
    Timer {
        id: unsure
        interval: 5000
        onTriggered: page.sureRestore = false
    }
    // travel is asked for only while the picture of it is on the screen
    readonly property bool wantTravel: page.live && board.visible && page.isKeyboard
    property bool watching: false
    onWantTravelChanged: {
        if (wantTravel === watching)
            return;
        watching = wantTravel;
        if (wantTravel)
            Devices.watch();
        else
            Devices.unwatch();
    }
    // ---- what the board says, by tab ----
    function isEmptyKey(a) {
        return !!a && a[0] === 16 && a[1] === 0 && a[2] === 0;
    }
    readonly property bool layered: tab === "remap" || tab === "special"
    readonly property var boardLegends: {
        const o = {};
        if (!kb || !kb.labels || !layered)
            return o;
        const changed = {};
        for (const m of kb.changed || [])
            changed[m] = true;
        for (const m in kb.labels) {
            if (kb.layer > 0 && isEmptyKey(kb.actions[m]))
                o[m] = kb.baseLabels && kb.baseLabels[m] !== undefined ? (kb.baseChanged && kb.baseChanged.includes(Number(m)) ? kb.baseLabels[m] : labelOf(Number(m))) : "";
            else if (kb.layer > 0 || changed[m])
                o[m] = kb.labels[m];
            // a key as it came from the factory keeps its own legend
        }
        return o;
    }
    readonly property var boardDimmed: {
        const o = {};
        if (!kb || !layered || kb.layer === 0)
            return o;
        for (const m in kb.actions)
            if (isEmptyKey(kb.actions[m]))
                o[m] = true;
        return o;
    }
    readonly property var boardSubs: {
        const o = {};
        if (!kb)
            return o;
        if (tab === "travel") {
            for (const m in kb.keys) {
                const k = kb.keys[m];
                o[m] = k.actuation.toFixed(2) + (k.trigger === "rapid" ? " RT" : k.trigger === "continuous" ? " RT∞" : "");
            }
        } else if (layered) {
            for (const m in kb.labels) {
                const sp = kb.special ? kb.special[m] : null;
                if (sp)
                    o[m] = sp.kind === "modTap" ? "MT" : sp.kind === "toggle" ? "TGL" : sp.kind === "dks" ? "DKS" : "Snap";
                else if (!boardDimmed[m] && boardLegends[m] !== undefined && boardLegends[m] !== labelOf(Number(m)))
                    o[m] = labelOf(Number(m));
            }
        }
        return o;
    }
    readonly property var boardMarked: {
        const o = {};
        if (kb && layered && kb.changed)
            for (const m of kb.changed)
                o[m] = true;
        return o;
    }
    // ---- the board listens: key presses pick keys (and light them) instead of typing ----
    // Linux key codes (evdev) of the HID usages a keyboard sends: how a press here finds its key
    readonly property var hidToEvdev: ({
            "4": 30, "5": 48, "6": 46, "7": 32, "8": 18, "9": 33, "10": 34, "11": 35, "12": 23, "13": 36, "14": 37, "15": 38,
            "16": 50, "17": 49, "18": 24, "19": 25, "20": 16, "21": 19, "22": 31, "23": 20, "24": 22, "25": 47, "26": 17,
            "27": 45, "28": 21, "29": 44, "30": 2, "31": 3, "32": 4, "33": 5, "34": 6, "35": 7, "36": 8, "37": 9, "38": 10,
            "39": 11, "40": 28, "41": 1, "42": 14, "43": 15, "44": 57, "45": 12, "46": 13, "47": 26, "48": 27, "49": 43,
            "50": 43, "51": 39, "52": 40, "53": 41, "54": 51, "55": 52, "56": 53, "57": 58, "58": 59, "59": 60, "60": 61,
            "61": 62, "62": 63, "63": 64, "64": 65, "65": 66, "66": 67, "67": 68, "68": 87, "69": 88, "70": 99, "71": 70,
            "72": 119, "73": 110, "74": 102, "75": 104, "76": 111, "77": 107, "78": 109, "79": 106, "80": 105, "81": 108,
            "82": 103, "100": 86, "101": 127
        })
    readonly property var modEvdev: ({
            "29": 1, "42": 2, "56": 4, "125": 8, "97": 16, "54": 32, "100": 64, "126": 128
        })
    // evdev code -> the key's matrix number, from what each key sends in the base layer
    readonly property var evdevToKey: {
        const o = {};
        const base = kb && kb.layer === 0 && kb.actions ? kb.actions : null;
        for (const k of layoutKeys) {
            const a = base && base[String(k.m)] ? base[String(k.m)] : k["default"];
            if (!a || a[0] !== 16)
                continue;
            if (a[2]) {
                const e = hidToEvdev[String(a[2])];
                if (e !== undefined && o[e] === undefined)
                    o[e] = k.m;
            } else if (a[1]) {
                for (const code in modEvdev)
                    if (modEvdev[code] === a[1] && o[code] === undefined)
                        o[code] = k.m;
            }
        }
        return o;
    }
    property var heldKeys: ({})
    property bool listening: false
    property int lastHeard: -1
    property string lastHeardText: ""
    function keyEvent(e, down) {
        if (e.isAutoRepeat)
            return;
        const m = evdevToKey[e.nativeScanCode - 8];
        const o = Object.assign({}, heldKeys);
        if (m === undefined) {
            if (down)
                lastHeardText = I18n.t("клавиша не с этой клавиатуры или не из раскладки: код ", "a key not of this keyboard or not of the layout: code ") + (e.nativeScanCode - 8);
            return;
        }
        if (down) {
            o[m] = true;
            lastHeard = m;
            lastHeardText = "";
            if (tab !== "test" && tab !== "light" && tab !== "modes" && tab !== "profiles")
                selection = [m];
        } else
            delete o[m];
        heldKeys = o;
    }
    function stopListening() {
        heldKeys = ({});
        if (catcher.activeFocus)
            catcher.focus = false;
    }
    // ---- the picker of actions: what a key (or Mod-Tap's tap / hold) can be given ----
    readonly property var catalog: kb && kb.catalog ? kb.catalog : []
    property string pickGroup: "letters"
    property int pickMods: 0
    readonly property var pickItems: (catalog.find(g => g.id === pickGroup) || {
            "items": []
        }).items
    function withMods(action) {
        return pickMods && action[0] === 16 && action[2] !== 0 ? [16, action[1] | pickMods, action[2]] : action;
    }
    function actionText(a) {
        if (!a)
            return "—";
        for (const g of catalog)
            for (const it of g.items)
                if (it.action[0] === a[0] && it.action[1] === a[1] && it.action[2] === a[2])
                    return I18n.t(it.ru || it.label, it.label);
        if (a[0] === 16) {
            const names = [];
            const mods = [[1, "Ctrl"], [2, "Shift"], [4, "Alt"], [8, "Super"], [16, "R Ctrl"], [32, "R Shift"], [64, "R Alt"], [128, "R Super"]];
            for (const [bit, n] of mods)
                if (a[1] & bit)
                    names.push(n);
            let key = null;
            for (const g of catalog)
                key = key || g.items.find(it => it.action[0] === 16 && it.action[1] === 0 && it.action[2] === a[2]) || null;
            if (a[2])
                names.push(key ? key.label : "0x" + a[2].toString(16));
            return names.join("+") || "—";
        }
        return a.join("/");
    }
    // Mod-Tap / Toggle being made for the key picked
    property string specialKind: "modTap"
    property string slotTarget: "tap"
    property var mtTap: null
    property var mtHold: null
    property real mtDelay: 200
    property var tglAction: null
    readonly property var oneSpecial: kb && kb.special && oneKey >= 0 ? kb.special[String(oneKey)] || null : null
    onOneKeyChanged: loadSpecial()
    function loadSpecial() {
        const sp = oneSpecial;
        const own = kb && oneKey >= 0 ? kb.actions[String(oneKey)] : null;
        if (sp && sp.kind === "modTap") {
            specialKind = "modTap";
            mtTap = sp.tap;
            mtHold = sp.hold;
            mtDelay = sp.delay;
        } else if (sp && sp.kind === "toggle") {
            specialKind = "toggle";
            tglAction = sp.action;
        } else {
            mtTap = own && own[0] < 128 ? own : null;
            mtHold = [16, 1, 0];
            mtDelay = 200;
            tglAction = own && own[0] < 128 ? own : null;
        }
        slotTarget = "tap";
    }
    function chooseAction(action) {
        if (tab === "special") {
            if (specialKind === "toggle")
                tglAction = action;
            else if (slotTarget === "hold")
                mtHold = action;
            else {
                mtTap = action;
                slotTarget = "hold";
            }
            return;
        }
        Devices.setKeys(selection, action);
    }
    // a switch of the mode being edited (the modes' tab)
    component ModeToggle: PxToggle {
        property string key: ""
        enabled: Devices.canWrite && !Devices.working
        checked: !!page.modeData && !!page.modeData[key]
        onToggled: v => {
            const o = {};
            o[key] = v;
            Devices.setMode(page.modeIndex, o);
        }
    }
    // the actions a key can be given, by group; a click gives it
    component ActionPicker: Column {
        id: picker
        spacing: Theme.u * 3
        Flow {
            width: picker.width
            spacing: Theme.u * 2
            Repeater {
                model: page.catalog
                PxButton {
                    required property var modelData
                    compact: true
                    checkable: true
                    checked: page.pickGroup === modelData.id
                    text: I18n.t(modelData.ru, modelData.en)
                    onClicked: page.pickGroup = modelData.id
                }
            }
        }
        // a chord: the modifiers held with the key chosen next (Ctrl+C and the like)
        Flow {
            visible: ["letters", "symbols", "nav", "numpad"].includes(page.pickGroup)
            width: picker.width
            spacing: Theme.u * 2
            PxText {
                height: Theme.fit(14)
                verticalAlignment: Text.AlignVCenter
                kind: "tiny"
                dim: true
                text: I18n.t("Вместе с:", "Together with:")
            }
            Repeater {
                model: [[1, "Ctrl"], [2, "Shift"], [4, "Alt"], [8, "Super"]]
                PxButton {
                    required property var modelData
                    compact: true
                    checkable: true
                    checked: (page.pickMods & modelData[0]) !== 0
                    text: modelData[1]
                    onClicked: page.pickMods = page.pickMods ^ modelData[0]
                }
            }
        }
        Flow {
            width: picker.width
            spacing: Theme.u * 2
            Repeater {
                model: page.pickItems
                PxButton {
                    required property var modelData
                    compact: true
                    enabled: Devices.canWrite && !Devices.working && (page.tab === "special" ? page.oneKey >= 0 : page.selection.length > 0)
                    text: (page.pickMods && modelData.action[0] === 16 && modelData.action[2] !== 0 ? page.actionText([16, page.pickMods, 0]) + "+" : "") + I18n.t(modelData.ru || modelData.label, modelData.label)
                    onClicked: page.chooseAction(page.withMods(modelData.action))
                }
            }
        }
    }
    // the layer of the current mode being looked at: the base one or an Fn layer
    component LayerRow: SettingRow {
        label: I18n.t("Слой", "Layer")
        hint: I18n.t("Fn — пока зажата клавиша Fn; Fn 2 и Fn 3 — если какой-то клавише дано «Fn 2» / «Fn 3». Пустая клавиша Fn-слоя работает как в основном (подпись бледная).", "Fn: while the Fn key is held; Fn 2 and Fn 3: once some key is given \"Fn 2\" / \"Fn 3\". An empty key of an Fn layer works as in the base one (its legend pale).")
        PxSegmented {
            enabled: !Devices.working
            model: [
                {
                    "label": I18n.t("Основной", "Base"),
                    "value": 0
                },
                {
                    "label": "Fn",
                    "value": 1
                },
                {
                    "label": "Fn 2",
                    "value": 2
                },
                {
                    "label": "Fn 3",
                    "value": 3
                }
            ]
            currentValue: page.kb ? page.kb.layer : 0
            onActivated: v => Devices.setLayer(v)
        }
    }
    // a colour for the keyboard's lights: a click gives it to the zone
    component ColorChip: Rectangle {
        id: chip
        required property string modelData
        property var zone: null
        readonly property bool on: !!zone && !!zone.lt && !zone.lt.rainbow && zone.lt.color.toLowerCase() === modelData.toLowerCase()
        width: Theme.fit(14)
        height: Theme.fit(14)
        color: modelData
        border.width: on ? Theme.u : Math.max(1, Theme.u / 2)
        border.color: on ? Theme.accent : Theme.tone("edge", Theme.p5For(parent))
        MouseArea {
            anchors.fill: parent
            enabled: Devices.canWrite && !Devices.working
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.zone.put({
                "color": chip.modelData,
                "rainbow": false
            })
        }
    }
    component FailedLine: PxText {
        visible: !!Devices.failed
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.danger
        text: Devices.failed ? I18n.t("Не записано: ", "Not written: ") + I18n.t(Devices.failed.ru, Devices.failed.en) + (Devices.failed.detail ? " (" + Devices.failed.detail + ")" : "") : ""
    }
    CatGroup {
        name: "devices"
        title: I18n.t("Устройства", "Devices")
        icon: "chip"
        CatNote {
            present: Devices.testing && Devices.fake === ""
            dim: true
            text: I18n.t("Самопроверка оболочки: настоящие устройства не опрашиваются.", "The shell's self-test: no real device is asked.")
        }
        CatNote {
            present: !Devices.scanned && Devices.wanted
            dim: true
            text: I18n.t("Ищу устройства…", "Looking for devices…")
        }
        CatNote {
            present: Devices.scanned && Devices.devices.length === 0
            dim: true
            text: I18n.t("Ни одно знакомое устройство не подключено. Список — в «Ещё…»; своё можно описать файлом.", "No known device is plugged in. The list is under More…; describe your own in a file.")
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Devices.devices
                    Item {
                        id: row
                        required property var modelData
                        readonly property bool chosen: modelData.id === Devices.currentId
                        width: parent.width
                        height: Math.max(words.implicitHeight, pick.height) + Theme.u * 4
                        PxIcon {
                            id: glyph
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.kind === "mouse" ? "mouse" : "keyboard"
                        }
                        Column {
                            id: words
                            anchors.left: glyph.right
                            anchors.leftMargin: Theme.u * 4
                            anchors.right: pick.left
                            anchors.rightMargin: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                font.bold: true
                                text: row.modelData.name + (row.modelData.fake ? " · " + I18n.t("эмулятор", "emulator") : "")
                            }
                            PxText {
                                width: parent.width
                                wrapMode: Text.Wrap
                                kind: "tiny"
                                dim: true
                                text: {
                                    const parts = [Devices.supportLabel(row.modelData.support)];
                                    if (row.chosen && page.st)
                                        parts.push(I18n.t("прошивка ", "firmware ") + page.st.firmware.version);
                                    if (row.modelData.access === "denied")
                                        parts.push(I18n.t("нет доступа", "no access"));
                                    else if (row.modelData.access === "busy")
                                        parts.push(I18n.t("интерфейс занят", "the interface is taken"));
                                    if (row.modelData.origin === "user")
                                        parts.push(I18n.t("ваш файл описания", "your description file"));
                                    return parts.join(" · ");
                                }
                            }
                        }
                        PxButton {
                            id: pick
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Devices.devices.length > 1 && !row.chosen
                            compact: true
                            text: I18n.t("Открыть", "Open")
                            onClicked: {
                                Devices.close();
                                Devices.open(row.modelData.id);
                            }
                        }
                    }
                }
            }
        }
        // reading the settings: a second or less
        CatCustom {
            wide: true
            CatBox {
                // reading the settings: a second or less
                PxProgress {
                    visible: Devices.loading
                    width: parent.width
                    value: Devices.progress
                }
            }
        }
        CatNote {
            present: Devices.backingUp !== ""
            dim: true
            text: I18n.t("Снимаю резервную копию всех настроек клавиатуры — один раз, перед первой записью…", "Taking a backup of every setting of the keyboard: once, before the first write…")
        }
        // why the device does not open, in words, and what there is to do about it
        CatCustom {
            wide: true
            CatBox {
                // why the device does not open, in words, and what there is to do about it
                PxBox {
                    visible: !!Devices.error && !Devices.loading
                    width: parent.width
                    height: trouble.implicitHeight + Theme.u * 10
                    sunken: true
                    color: Theme.tone("sunken", Theme.p5For(parent))
                    Column {
                        id: trouble
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u * 2
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            font.bold: true
                            text: Devices.errorText(Devices.error)
                        }
                        PxText {
                            visible: !!Devices.error && Devices.error.code === "denied"
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "tiny"
                            dim: true
                            text: I18n.t("Настройкам клавиатуры нужен доступ к её служебному интерфейсу. «Разрешить» ставит маленькую службу-мост: менять настройки можно, читать нажатия и прошивать — нельзя. Пароль администратора — один раз.", "The keyboard's settings need its service interface. Allow installs a small bridge service: settings can change, keystrokes can't be read and the firmware can't be flashed. The admin password, once.")
                        }
                        PxText {
                            visible: Devices.grantLog !== ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "mono"
                            color: Theme.danger
                            text: Devices.grantLog
                        }
                        PxText {
                            visible: !!Devices.error && !!Devices.error.detail && Devices.error.code !== "denied"
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "mono"
                            dim: true
                            text: Devices.error ? Devices.error.detail || "" : ""
                        }
                        Row {
                            spacing: Theme.u * 3
                            PxButton {
                                readonly property bool kernel: !!Devices.error && Devices.heldByKernel(Devices.error.id)
                                // a stuck channel: only an old bridge is worth updating (else a replug)
                                visible: !!Devices.error && (Devices.error.code === "denied" || Devices.error.code === "deaf" && Devices.error.bridge !== "ok" || kernel)
                                compact: true
                                accent: true
                                icon: "lock"
                                enabled: !Devices.granting
                                // the bridge's installer also lets go a service interface usbhid holds
                                text: kernel ? I18n.t("Освободить", "Free it") : Devices.error && Devices.error.code === "deaf" ? I18n.t("Обновить мост", "Update the bridge") : I18n.t("Разрешить", "Allow")
                                onClicked: Devices.grant()
                            }
                            PxButton {
                                compact: true
                                icon: "refresh"
                                text: I18n.t("Проверить ещё раз", "Try again")
                                onClicked: {
                                    Devices.error = null;
                                    Devices.rescan();
                                }
                            }
                            PxButton {
                                compact: true
                                icon: "document"
                                text: I18n.t("Справка", "The guide")
                                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.shellDir + "/docs/devices.md"])
                            }
                        }
                    }
                }
            }
        }
        // a description file that is broken says so here, and breaks nothing else
        CatCustom {
            wide: true
            CatBox {
                // a description file that is broken says so here, and breaks nothing else
                Repeater {
            model: Devices.broken
            Column {
                id: bad
                required property var modelData
                width: parent.width
                spacing: Theme.u
                PxText {
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    font.bold: true
                    color: Theme.danger
                    text: I18n.t("Файл описания с ошибками: ", "A description file with problems: ") + bad.modelData.file
                }
                Repeater {
                    model: bad.modelData.problems.slice(0, 6)
                    PxText {
                        required property var modelData
                        width: bad.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        text: (modelData.at ? modelData.at + ": " : "") + I18n.t(modelData.ru, modelData.en)
                    }
                }
                PxText {
                    visible: bad.modelData.problems.length > 6
                    kind: "tiny"
                    dim: true
                    text: I18n.t("…и ещё ", "…and ") + (bad.modelData.problems.length - 6) + I18n.t("; все — `angelos devices check ФАЙЛ`", " more; all of them: `angelos devices check FILE`")
                }
            }
        }
            }
        }
    }
    CatGroup {
        name: "keyboard"
        title: I18n.t("Клавиатура", "The keyboard")
        icon: "keyboard"
        present: page.isKeyboard
        CatNote {
            present: !page.kb && !Devices.loading
            dim: true
            text: I18n.t("Раскладка — из файла описания. Настройки появятся, когда клавиатура откроется.", "The layout is the description file's. The settings appear once the keyboard opens.")
        }
        CatNote {
            present: !!page.kb && page.kb.mismatch.length > 0
            text: page.kb ? I18n.t("Раскладка в файле описания не сходится с клавиатурой: клавиш с другим заводским действием — ", "The description file's layout does not match the keyboard: keys with another factory action — ") + page.kb.mismatch.length + I18n.t(". Открыто только на чтение. Подробности: `angelos devices info`.", ". Open for reading only. The details: `angelos devices info`.") : ""
        }
        CatNote {
            present: !!page.kb && page.kb.readonly === "firmware"
            text: page.kb ? I18n.t("Прошивка ", "Firmware ") + page.kb.firmware.version + I18n.t(" этой оболочке не знакома: клавиатура открыта только на чтение.", " is not known to this shell: the keyboard is open for reading only.") : ""
        }
        // ---- the tabs ----
        CatCustom {
            wide: true
            CatBox {
                // ---- the tabs ----
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.tabs
                        PxButton {
                            required property var modelData
                            checkable: true
                            checked: page.tab === modelData.id
                            accent: page.tab === modelData.id
                            text: modelData.label
                            onClicked: page.tab = modelData.id
                        }
                    }
                }
            }
        }
        CatNote {
            dim: true
            text: page.tabNow.about
        }
        CatCustom {
            wide: true
            CatBox {
                Loader {
                    active: page.layered && !!page.kb
                    visible: active
                    width: parent.width
                    sourceComponent: LayerRow {}
                }
            }
        }
        // ---- the board: it listens to the keyboard while it has the focus ----
        CatCustom {
            wide: true
            CatBox {
                // ---- the board: it listens to the keyboard while it has the focus ----
                Item {
                    id: catcher
                    width: parent.width
                    height: listenBar.height + board.height + Theme.u * 2
                    activeFocusOnTab: false
                    onActiveFocusChanged: {
                        page.listening = activeFocus;
                        if (!activeFocus)
                            page.heldKeys = ({});
                    }
                    // every key, chords too, stays here: nothing reaches the search field or a shortcut
                    Keys.onShortcutOverride: e => e.accepted = true
                    Keys.onPressed: e => {
                        page.keyEvent(e, true);
                        e.accepted = true;
                    }
                    Keys.onReleased: e => {
                        page.keyEvent(e, false);
                        e.accepted = true;
                    }
                    PxBox {
                        id: listenBar
                        width: parent.width
                        height: listenRow.implicitHeight + Theme.u * 4
                        sunken: !page.listening
                        color: page.listening ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.tone("ok", Theme.p5For(parent)), 0.35) : Theme.tone("sunken", Theme.p5For(parent))
                        Row {
                            id: listenRow
                            x: Theme.u * 3
                            y: Theme.u * 2
                            width: parent.width - Theme.u * 6
                            spacing: Theme.u * 3
                            PxText {
                                width: parent.width - listenButton.width - Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.Wrap
                                text: page.listening ? (page.tab === "test" ? I18n.t("Клавиатура слушает: жми что угодно — нажатия подсвечиваются здесь и не уходят в поиск.", "The board listens: press anything — the presses light up here and do not reach the search.") : I18n.t("Клавиатура слушает: нажми клавишу — она выберется. В поиск ничего не попадает.", "The board listens: press a key and it is picked. Nothing reaches the search.")) + (page.lastHeardText ? "  " + page.lastHeardText : "") : I18n.t("Клик по клавише — выбрать её. «Слушать» — выбирать нажатием на самой клавиатуре.", "Click a key to pick it. \"Listen\": pick by pressing it on the keyboard itself.")
                            }
                            PxButton {
                                id: listenButton
                                anchors.verticalCenter: parent.verticalCenter
                                compact: true
                                accent: !page.listening
                                icon: page.listening ? "close" : "keyboard"
                                text: page.listening ? I18n.t("Отпустить", "Let go") : I18n.t("Слушать", "Listen")
                                onClicked: {
                                    if (page.listening)
                                        page.stopListening();
                                    else
                                        catcher.forceActiveFocus();
                                }
                            }
                        }
                    }
                    PxKeyTravel {
                        id: board
                        y: listenBar.height + Theme.u * 2
                        width: parent.width
                        keys: page.layoutKeys
                        settings: page.kb ? page.kb.keys : ({})
                        travel: page.travel
                        source: Devices.depth
                        moving: Devices.moving
                        active: page.live && visible
                        selection: page.tab === "test" ? [] : page.selection
                        paired: page.tab === "snaptap" || page.tab === "test" ? page.partner : ({})
                        legends: page.boardLegends
                        subs: page.boardSubs
                        marked: page.boardMarked
                        dimmed: page.boardDimmed
                        lit: page.heldKeys
                        showTravel: page.tab === "travel" || page.tab === "test"
                        onPicked: (m, modifiers) => {
                            if (page.tab !== "test")
                                page.pick(m, modifiers);
                            catcher.forceActiveFocus();
                        }
                    }
                }
            }
        }
        // which keys the settings below go to
        CatCustom {
            wide: true
            CatBox {
                // which keys the settings below go to
                Flow {
                    visible: !!page.kb && ["remap", "travel", "snaptap", "special"].includes(page.tab)
                    width: parent.width
                    spacing: Theme.u * 3
                    PxText {
                        height: Theme.fit(14)
                        verticalAlignment: Text.AlignVCenter
                        font.bold: page.selection.length > 0
                        dim: page.selection.length === 0
                        text: page.selection.length === 0 ? I18n.t("Ничего не выбрано", "Nothing picked") : page.selection.length === 1 ? "«" + page.labelOf(page.selection[0]) + "»" + (page.kb && page.tab === "remap" ? I18n.t(" сейчас: ", " now: ") + (page.kb.layer > 0 && page.isEmptyKey(page.kb.actions[String(page.selection[0])]) ? I18n.t("как в основном слое", "as in the base layer") : page.actionText(page.kb.actions[String(page.selection[0])])) : "") : I18n.t("Выбрано клавиш: ", "Keys picked: ") + page.selection.length
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Все", "All")
                        onClicked: page.selection = page.layoutKeys.map(k => k.m)
                    }
                    PxButton {
                        compact: true
                        text: "WASD"
                        onClicked: page.selection = page.byLabels(["W", "A", "S", "D"])
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Буквы и цифры", "Letters and digits")
                        onClicked: page.selection = page.layoutKeys.filter(k => /^[A-Z0-9]$/.test(String(k.label || "").toUpperCase())).map(k => k.m)
                    }
                    PxButton {
                        visible: page.selection.length > 0
                        compact: true
                        icon: "close"
                        text: I18n.t("Снять", "None")
                        onClicked: page.selection = []
                    }
                }
            }
        }
        CatNote {
            present: Devices.working
            dim: true
            text: I18n.t("Пишу в клавиатуру…", "Writing to the keyboard…")
        }
        CatCustom {
            wide: true
            CatBox {
                FailedLine {}
            }
        }
        // ---- Keys: what each key does ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Keys: what each key does ----
                Column {
                    visible: page.tab === "remap" && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 3
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 3
                        PxButton {
                            compact: true
                            icon: "refresh"
                            enabled: page.canEdit
                            text: I18n.t("Как с завода", "As from the factory")
                            onClicked: Devices.setKeys(page.selection, "factory")
                        }
                        PxButton {
                            visible: !!page.kb && page.kb.layer > 0
                            compact: true
                            icon: "layers"
                            enabled: page.canEdit
                            text: I18n.t("Как в основном слое", "As in the base layer")
                            onClicked: Devices.setKeys(page.selection, [16, 0, 0])
                        }
                        PxButton {
                            compact: true
                            icon: "close"
                            enabled: page.canEdit
                            text: I18n.t("Отключить клавишу", "Turn the key off")
                            onClicked: Devices.setKeys(page.selection, "off")
                        }
                        PxText {
                            height: Theme.fit(14)
                            verticalAlignment: Text.AlignVCenter
                            kind: "tiny"
                            dim: true
                            text: I18n.t("точка в углу — клавиша изменена; мелкая подпись — какая это клавиша на самом деле", "a dot in the corner: the key is changed; the small line: which key it really is")
                        }
                    }
                    ActionPicker {
                        width: parent.width
                    }
                }
            }
        }
        // ---- Actuation: the picked keys' travel settings ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Actuation: the picked keys' travel settings ----
                Column {
                    visible: (page.tab === "travel" || page.tab === "test") && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 2
                    Row {
                        spacing: Theme.u * 4
                        PxText {
                            kind: "title"
                            text: page.shownKey < 0 ? I18n.t("Нажми или выбери клавишу", "Press or pick a key") : I18n.t("Клавиша ", "Key ") + "«" + page.shownLabel + "»" + (page.selection.length > 1 && page.tab !== "test" ? " +" + (page.selection.length - 1) : "")
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.shownKey >= 0
                            kind: "mono"
                            text: gauge.mm.toFixed(2) + " / " + page.travel.toFixed(2) + " " + I18n.t("мм", "mm") + (gauge.down ? "  ▼" : "")
                        }
                    }
                    PxTravelGauge {
                        id: gauge
                        width: parent.width
                        travel: page.travel
                        cap: page.shownKey >= 0 && board.capsVersion >= 0 ? board.caps[page.shownKey] || null : null
                    }
                    PxText {
                        visible: page.tab === "test"
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: I18n.t("Зелёная — нажата по сигналу системы; заливка — глубина с датчика клавиши, черта — её точка срабатывания. Нажато сейчас: ", "Green: down by the system's signal; the fill: how deep, from the key's sensor; the line: its actuation point. Down now: ") + Object.keys(page.heldKeys).length + I18n.t(" · клавиша Fn системе не видна, её глубина — только заливкой", " · the Fn key is not seen by the system: its depth shows as the fill alone")
                    }
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Column {
                    visible: page.tab === "travel" && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 2
                    SettingRow {
                        visible: !!page.shownRule && page.cap("rapidTrigger")
                        label: I18n.t("Срабатывание", "Trigger")
                        hint: I18n.t("Когда срабатывает клавиша: в одной точке, или сразу на любом движении вниз и вверх.", "When a key fires: at one point, or on any move down and up.")
                        PxSegmented {
                            enabled: page.canEdit
                            model: [
                                {
                                    "label": I18n.t("Обычное", "Plain"),
                                    "value": "normal"
                                },
                                {
                                    "label": "Rapid Trigger",
                                    "value": "rapid"
                                },
                                {
                                    "label": I18n.t("Непрерывный RT", "Continuous RT"),
                                    "value": "continuous"
                                }
                            ]
                            currentValue: page.shownRule ? page.shownRule.trigger : "normal"
                            onActivated: v => page.setRt({
                                    "trigger": v
                                })
                        }
                    }
                    SettingRow {
                        visible: !!page.shownRule && page.cap("actuation")
                        label: I18n.t("Точка срабатывания", "Actuation point")
                        hint: I18n.t("на какой глубине клавиша нажимается; меньше — быстрее и легче задеть", "How deep the key presses; less is faster and easier to brush")
                        PxSlider {
                            enabled: page.canEdit
                            width: Math.min(Theme.u * 130, parent.width)
                            from: page.limA.min
                            to: page.limA.max
                            stepSize: 0.01
                            decimals: 2
                            suffix: I18n.t(" мм", " mm")
                            value: page.shownRule ? page.shownRule.actuation : 0
                            onReleased: v => page.setRt({
                                    "actuation": v
                                })
                        }
                    }
                    SettingRow {
                        visible: !!page.shownRule && page.shownRule.trigger !== "normal" && page.cap("rapidTrigger")
                        label: I18n.t("Чувствительность вниз", "Sensitivity down")
                        hint: I18n.t("на сколько надо утопить клавишу, чтобы она нажалась снова", "How far down the key has to go to press again")
                        PxSlider {
                            enabled: page.canEdit
                            width: Math.min(Theme.u * 130, parent.width)
                            from: page.limR.min
                            to: Math.min(2, page.limR.max)
                            stepSize: 0.01
                            decimals: 2
                            suffix: I18n.t(" мм", " mm")
                            value: page.shownRule ? page.shownRule.press : 0
                            onReleased: v => page.setRt({
                                    "press": v
                                })
                        }
                    }
                    SettingRow {
                        visible: !!page.shownRule && page.shownRule.trigger !== "normal" && page.cap("rapidTrigger")
                        label: I18n.t("Чувствительность вверх", "Sensitivity up")
                        hint: I18n.t("на сколько надо отпустить клавишу, чтобы она отжалась", "How far up the key has to come to let go")
                        PxSlider {
                            enabled: page.canEdit
                            width: Math.min(Theme.u * 130, parent.width)
                            from: page.limR.min
                            to: Math.min(2, page.limR.max)
                            stepSize: 0.01
                            decimals: 2
                            suffix: I18n.t(" мм", " mm")
                            value: page.shownRule ? page.shownRule.release : 0
                            onReleased: v => page.setRt({
                                    "release": v
                                })
                        }
                    }
                    SettingRow {
                        visible: !!page.shownRule && page.limD > 0
                        label: I18n.t("Мёртвая зона сверху", "Dead zone at the top")
                        hint: I18n.t("ход от верха, который не считается: от случайных касаний", "Travel from the top that counts for nothing: against chance touches")
                        PxSlider {
                            enabled: page.canEdit
                            width: Math.min(Theme.u * 130, parent.width)
                            from: 0
                            to: page.limD
                            stepSize: 0.01
                            decimals: 2
                            suffix: I18n.t(" мм", " mm")
                            value: page.shownRule ? page.shownRule.pressDead : 0
                            onReleased: v => page.setRt({
                                    "pressDead": v
                                })
                        }
                    }
                    SettingRow {
                        visible: !!page.shownRule && page.limD > 0
                        label: I18n.t("Мёртвая зона снизу", "Dead zone at the bottom")
                        hint: I18n.t("ход у дна, который не считается: клавиша не дребезжит, когда её держат в пол", "Travel at the bottom that counts for nothing: a key held to the floor does not chatter")
                        PxSlider {
                            enabled: page.canEdit
                            width: Math.min(Theme.u * 130, parent.width)
                            from: 0
                            to: page.limD
                            stepSize: 0.01
                            decimals: 2
                            suffix: I18n.t(" мм", " mm")
                            value: page.shownRule ? page.shownRule.releaseDead : 0
                            onReleased: v => page.setRt({
                                    "releaseDead": v
                                })
                        }
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: !page.kb ? "" : (Devices.canWrite ? I18n.t("Пишется в режим «", "Written to the mode \"") + page.kb.modeName + I18n.t("» сразу и читается обратно. Переключатель: ", "\" at once and read back. Switch: ") : I18n.t("Только чтение. Переключатель: ", "Reading only. Switch: ")) + (page.shownRule ? page.switchName(page.shownRule.switch) : "—")
                    }
                }
            }
        }
        // ---- Snap Tap ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Snap Tap ----
                Column {
                    visible: page.tab === "snaptap" && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 3
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: I18n.t("Пара действует в режиме «", "A pair lives in the mode \"") + (page.kb ? page.kb.modeName : "") + I18n.t("». Полоса сверху клавиши — она в паре. В части соревновательных игр такое запрещено правилами — проверь свои.", "\". A bar along a key's top: it is in a pair. Some competitive games forbid this by their rules: check yours.")
                    }
                    Repeater {
                        model: page.pairs
                        SettingRow {
                            id: pairRow
                            required property var modelData
                            label: page.labelOf(modelData.a) + " + " + page.labelOf(modelData.b) + (modelData.kind === "rs" ? " · " + I18n.t("глубже — главнее", "deeper wins") : "")
                            hint: modelData.whole ? I18n.t("кто побеждает, когда зажаты обе", "Who wins with both held") : I18n.t("пара записана в клавиатуре наполовину — пересоздай её", "The pair is half-written in the keyboard: make it anew")
                            Flow {
                                width: parent.width
                                spacing: Theme.u * 3
                                PxSegmented {
                                    enabled: Devices.canWrite && !Devices.working
                                    model: [
                                        {
                                            "label": I18n.t("Последняя", "Last"),
                                            "value": "last"
                                        },
                                        {
                                            "label": I18n.t("Нейтраль", "Neutral"),
                                            "value": "neutral"
                                        },
                                        {
                                            "label": page.labelOf(pairRow.modelData.a),
                                            "value": "a"
                                        },
                                        {
                                            "label": page.labelOf(pairRow.modelData.b),
                                            "value": "b"
                                        }
                                    ]
                                    currentValue: page.ruleOf(pairRow.modelData)
                                    onActivated: v => Devices.pair(pairRow.modelData.a, pairRow.modelData.b, v, pairRow.modelData.kind)
                                }
                                PxButton {
                                    compact: true
                                    icon: "trash"
                                    enabled: Devices.canWrite && !Devices.working
                                    text: I18n.t("Разбить", "Undo")
                                    onClicked: Devices.unpair(pairRow.modelData.a)
                                }
                            }
                        }
                    }
                    SettingRow {
                        label: I18n.t("Новая пара", "A new pair")
                        hint: I18n.t("Две клавиши, нажатые вместе: побеждает последняя или та, что нажата глубже.", "Two keys held at once: the last one wins, or the one pressed deeper.")
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxSegmented {
                                model: [
                                    {
                                        "label": "Snap Tap",
                                        "value": "socd"
                                    },
                                    {
                                        "label": I18n.t("Глубже — главнее", "Deeper wins"),
                                        "value": "rs"
                                    }
                                ]
                                currentValue: page.pairKind
                                onActivated: v => page.pairKind = v
                            }
                            PxButton {
                                compact: true
                                enabled: Devices.canWrite && !Devices.working
                                text: "A + D"
                                onClicked: {
                                    const k = page.byLabels(["A", "D"]);
                                    if (k.length === 2)
                                        Devices.pair(k[0], k[1], "last", page.pairKind);
                                }
                            }
                            PxButton {
                                compact: true
                                enabled: Devices.canWrite && !Devices.working
                                text: "W + S"
                                onClicked: {
                                    const k = page.byLabels(["W", "S"]);
                                    if (k.length === 2)
                                        Devices.pair(k[0], k[1], "last", page.pairKind);
                                }
                            }
                            PxButton {
                                compact: true
                                accent: true
                                enabled: Devices.canWrite && !Devices.working && page.selection.length === 2
                                text: page.selection.length === 2 ? page.labelOf(page.selection[0]) + " + " + page.labelOf(page.selection[1]) : I18n.t("Из двух выбранных", "From the two picked")
                                onClicked: Devices.pair(page.selection[0], page.selection[1], "last", page.pairKind)
                            }
                        }
                    }
                }
            }
        }
        // ---- Mod-Tap / Toggle ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Mod-Tap / Toggle ----
                Column {
                    visible: page.tab === "special" && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 3
                    PxText {
                        visible: page.oneKey < 0
                        width: parent.width
                        wrapMode: Text.Wrap
                        dim: true
                        text: I18n.t("Выбери одну клавишу.", "Pick one key.")
                    }
                    PxText {
                        visible: page.oneKey >= 0
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.bold: true
                        text: {
                            const sp = page.oneSpecial;
                            const k = "«" + page.labelOf(page.oneKey) + "» ";
                            if (!sp)
                                return k + I18n.t("сейчас обычная клавиша", "is a plain key now");
                            if (sp.kind === "modTap")
                                return k + I18n.t("сейчас Mod-Tap: тап — ", "is Mod-Tap now: tap ") + page.actionText(sp.tap) + I18n.t(", удержание — ", ", hold ") + page.actionText(sp.hold) + ", " + sp.delay + I18n.t(" мс", " ms");
                            if (sp.kind === "toggle")
                                return k + I18n.t("сейчас Toggle: ", "is Toggle now: ") + page.actionText(sp.action);
                            if (sp.kind === "dks")
                                return k + I18n.t("сейчас DKS (несколько действий по глубине) — здесь пока не меняется", "is DKS now (several actions by depth): not changed here yet");
                            return k + I18n.t("в паре Snap Tap — меняется на вкладке Snap Tap", "is in a Snap Tap pair: changed on the Snap Tap tab");
                        }
                    }
                    SettingRow {
                        visible: page.oneKey >= 0
                        label: I18n.t("Что сделать", "Make it")
                        hint: I18n.t("Mod-Tap: нажал — буква, держишь — Ctrl/Shift. Toggle: тап включает клавишу до следующего тапа.", "Mod-Tap: tap for a letter, hold for Ctrl/Shift. Toggle: a tap holds the key until the next tap.")
                        PxSegmented {
                            model: [
                                {
                                    "label": "Mod-Tap",
                                    "value": "modTap"
                                },
                                {
                                    "label": "Toggle",
                                    "value": "toggle"
                                }
                            ]
                            currentValue: page.specialKind
                            onActivated: v => page.specialKind = v
                        }
                    }
                    SettingRow {
                        visible: page.oneKey >= 0 && page.specialKind === "modTap"
                        label: I18n.t("Действия", "Actions")
                        hint: I18n.t("выбери, что назначаешь (тап или удержание), потом действие ниже", "Pick what you set (tap or hold), then an action below")
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxButton {
                                compact: true
                                checkable: true
                                checked: page.slotTarget === "tap"
                                accent: page.slotTarget === "tap"
                                text: I18n.t("Тап: ", "Tap: ") + page.actionText(page.mtTap)
                                onClicked: page.slotTarget = "tap"
                            }
                            PxButton {
                                compact: true
                                checkable: true
                                checked: page.slotTarget === "hold"
                                accent: page.slotTarget === "hold"
                                text: I18n.t("Удержание: ", "Hold: ") + page.actionText(page.mtHold)
                                onClicked: page.slotTarget = "hold"
                            }
                        }
                    }
                    SettingRow {
                        visible: page.oneKey >= 0 && page.specialKind === "modTap"
                        label: I18n.t("Удержание с", "Hold after")
                        hint: I18n.t("сколько держать, чтобы считалось удержанием", "How long to hold for it to count as a hold")
                        PxSlider {
                            width: Math.min(Theme.u * 130, parent.width)
                            from: 10
                            to: 1000
                            stepSize: 10
                            suffix: I18n.t(" мс", " ms")
                            value: page.mtDelay
                            onMoved: v => page.mtDelay = v
                        }
                    }
                    SettingRow {
                        visible: page.oneKey >= 0 && page.specialKind === "toggle"
                        label: I18n.t("Действие", "Action")
                        hint: I18n.t("тап — нажато и держится до следующего тапа; если держать — как обычная клавиша", "A tap: down and held until the next tap; held: like a plain key")
                        PxText {
                            font.bold: true
                            text: page.actionText(page.tglAction)
                        }
                    }
                    Flow {
                        visible: page.oneKey >= 0
                        width: parent.width
                        spacing: Theme.u * 3
                        PxButton {
                            accent: true
                            icon: "check"
                            enabled: Devices.canWrite && !Devices.working && (page.specialKind === "modTap" ? !!page.mtTap && !!page.mtHold : !!page.tglAction)
                            text: I18n.t("Записать", "Write it")
                            onClicked: {
                                if (page.specialKind === "modTap")
                                    Devices.modTap(page.oneKey, page.mtTap, page.mtHold, page.mtDelay);
                                else
                                    Devices.toggleKey(page.oneKey, page.tglAction);
                            }
                        }
                        PxButton {
                            visible: !!page.oneSpecial && page.oneSpecial.kind !== "socd" && page.oneSpecial.kind !== "rs"
                            icon: "refresh"
                            enabled: Devices.canWrite && !Devices.working
                            text: I18n.t("Сделать обычной", "Make it plain")
                            onClicked: Devices.setKeys([page.oneKey], "factory")
                        }
                    }
                    ActionPicker {
                        visible: page.oneKey >= 0
                        width: parent.width
                    }
                }
            }
        }
        // ---- Lights ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Lights ----
                Column {
                    visible: page.tab === "light" && !!page.kb && !!page.kb.modes[page.kb.mode]
                    width: parent.width
                    spacing: Theme.u * 3
                    SettingRow {
                        label: I18n.t("Цвет системы", "The system's colour")
                        hint: I18n.t("подсветка сама берёт акцентный цвет оболочки — сменились обои, сменился и цвет клавиатуры", "The lights take the shell's accent colour by themselves: a new wallpaper, a new keyboard colour")
                        PxToggle {
                            text: I18n.t("Следовать", "Follow")
                            checked: Config.peripherals.keyboardAccent
                            onToggled: v => {
                                Config.peripherals.keyboardAccent = v;
                                Devices.paintAccent();
                            }
                        }
                    }
                    Repeater {
                        model: [
                            {
                                "zone": "main",
                                "label": I18n.t("Подсветка клавиш", "Key light")
                            },
                            {
                                "zone": "side",
                                "label": I18n.t("Боковая полоса", "Side strip")
                            }
                        ]
                        Column {
                            id: zoneCol
                            required property var modelData
                            readonly property var lt: page.kb && page.kb.modes[page.modeIndex] ? page.kb.modes[page.modeIndex].light[modelData.zone] : null
                            readonly property var effects: (page.capOf("lighting")[modelData.zone] || []).map(e => ({
                                        "label": I18n.t(e.ru, e.en),
                                        "value": e.id
                                    }))
                            function put(values) {
                                // an effect with colours of its own (custom, spectrum…) ignores the colour:
                                // a colour picked switches it to one that shows it
                                const fx = (page.capOf("lighting")[zoneCol.modelData.zone] || []).find(e => zoneCol.lt && e.id === zoneCol.lt.effect);
                                const plain = (page.capOf("lighting")[zoneCol.modelData.zone] || []).find(e => !e.noColor);
                                if (values.color !== undefined && values.effect === undefined && fx && fx.noColor && plain)
                                    values.effect = plain.id;
                                if (values.color !== undefined) {
                                    const c = String(values.color).toLowerCase();
                                    Config.peripherals.keyboardColors = [c].concat((Config.peripherals.keyboardColors || []).filter(x => x !== c)).slice(0, 12);
                                }
                                // into the mode picked on the Modes tab (the keyboard's own one by default)
                                Devices.setLight(page.modeIndex, zoneCol.modelData.zone, values);
                            }
                            width: parent.width
                            spacing: Theme.u * 2
                            SettingRow {
                                label: zoneCol.modelData.label
                                hint: I18n.t("режим «", "mode \"") + (page.kb ? page.kb.modeName : "") + I18n.t("»", "\"")
                                PxToggle {
                                    enabled: Devices.canWrite && !Devices.working
                                    text: !!zoneCol.lt && zoneCol.lt.on ? I18n.t("Горит", "On") : I18n.t("Выключена", "Off")
                                    checked: !!zoneCol.lt && zoneCol.lt.on
                                    onToggled: v => zoneCol.put({
                                            "on": v
                                        })
                                }
                            }
                            SettingRow {
                                visible: zoneCol.effects.length > 0 && !!zoneCol.lt && zoneCol.lt.on
                                label: I18n.t("Эффект", "Effect")
                                PxCombo {
                                    enabled: Devices.canWrite && !Devices.working
                                    model: zoneCol.effects
                                    currentValue: zoneCol.lt ? zoneCol.lt.effect : -1
                                    onActivated: v => zoneCol.put({
                                            "effect": v
                                        })
                                }
                            }
                            SettingRow {
                                visible: !!zoneCol.lt && zoneCol.lt.on
                                label: I18n.t("Яркость", "Brightness")
                                PxSlider {
                                    enabled: Devices.canWrite && !Devices.working
                                    width: Math.min(Theme.u * 130, parent.width)
                                    from: 1
                                    to: 100
                                    stepSize: 1
                                    suffix: " %"
                                    value: zoneCol.lt ? zoneCol.lt.brightness : 0
                                    onReleased: v => zoneCol.put({
                                            "brightness": Math.round(v)
                                        })
                                }
                            }
                            SettingRow {
                                visible: !!zoneCol.lt && zoneCol.lt.on
                                label: I18n.t("Скорость", "Speed")
                                PxSegmented {
                                    enabled: Devices.canWrite && !Devices.working
                                    model: [0, 1, 2, 3, 4].map(n => ({
                                                "label": String(n + 1),
                                                "value": n
                                            }))
                                    currentValue: zoneCol.lt ? zoneCol.lt.speed : 0
                                    onActivated: v => zoneCol.put({
                                            "speed": v
                                        })
                                }
                            }
                            SettingRow {
                                visible: !!zoneCol.lt && zoneCol.lt.on
                                label: I18n.t("Цвет", "Colour")
                                hint: I18n.t("«радуга» — эффект своими цветами", "\"Rainbow\": the effect's own colours")
                                Flow {
                                    width: parent.width
                                    spacing: Theme.u * 2
                                    PxButton {
                                        compact: true
                                        checkable: true
                                        enabled: Devices.canWrite && !Devices.working
                                        checked: !!zoneCol.lt && zoneCol.lt.rainbow
                                        text: I18n.t("Радуга", "Rainbow")
                                        onClicked: zoneCol.put({
                                            "rainbow": !(zoneCol.lt && zoneCol.lt.rainbow)
                                        })
                                    }
                                    PxButton {
                                        compact: true
                                        enabled: Devices.canWrite && !Devices.working
                                        text: I18n.t("Цвет системы", "System colour")
                                        onClicked: zoneCol.put({
                                            "color": Devices.ledColor(Theme.accent),
                                            "rainbow": false
                                        })
                                    }
                                    Repeater {
                                        model: ["#ffffff", "#ff0000", "#ff7a00", "#ffd400", "#3cff00", "#00ffc8", "#00a2ff", "#2b00ff", "#a100ff", "#ff00b4"]
                                        ColorChip {
                                            zone: zoneCol
                                        }
                                    }
                                    PxField {
                                        width: Theme.u * 34
                                        placeholder: "#rrggbb"
                                        text: zoneCol.lt ? zoneCol.lt.color : ""
                                        onAccepted: {
                                            if (/^#?[0-9a-fA-F]{6}$/.test(text))
                                                zoneCol.put({
                                                    "color": text.startsWith("#") ? text : "#" + text,
                                                    "rainbow": false
                                                });
                                        }
                                    }
                                }
                            }
                            SettingRow {
                                visible: !!zoneCol.lt && zoneCol.lt.on && (Config.peripherals.keyboardColors || []).length > 0
                                label: I18n.t("Недавние", "Recent")
                                hint: I18n.t("цвета, которые ты давал клавиатуре", "The colours you gave the keyboard")
                                Flow {
                                    width: parent.width
                                    spacing: Theme.u * 2
                                    Repeater {
                                        model: Config.peripherals.keyboardColors || []
                                        ColorChip {
                                            zone: zoneCol
                                        }
                                    }
                                }
                            }
                            SettingRow {
                                visible: !!zoneCol.lt && zoneCol.lt.on
                                label: I18n.t("Палитра", "Palette")
                                hint: I18n.t("по горизонтали — оттенок, по вертикали — насыщенность; цвет пишется, когда отпускаешь", "Across: the hue, down: the saturation; the colour is written when you let go")
                                Item {
                                    id: map
                                    width: Math.min(parent.width, Theme.u * 150)
                                    height: Theme.u * 34
                                    property real hx: -1
                                    property real sy: 0
                                    // the hues, left to right
                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: "#ff0000" }
                                            GradientStop { position: 0.167; color: "#ffff00" }
                                            GradientStop { position: 0.333; color: "#00ff00" }
                                            GradientStop { position: 0.5; color: "#00ffff" }
                                            GradientStop { position: 0.667; color: "#0000ff" }
                                            GradientStop { position: 0.833; color: "#ff00ff" }
                                            GradientStop { position: 1.0; color: "#ff0000" }
                                        }
                                    }
                                    // full colour at the top, white at the bottom
                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: "#ffffff" }
                                        }
                                        border.width: Math.max(1, Theme.u / 2)
                                        border.color: Theme.tone("edge", Theme.p5For(parent))
                                    }
                                    Rectangle {
                                        visible: map.hx >= 0
                                        x: map.hx * map.width - width / 2
                                        y: map.sy * map.height - height / 2
                                        width: Theme.u * 4
                                        height: Theme.u * 4
                                        color: "transparent"
                                        border.width: Theme.u
                                        border.color: Theme.tone("text", Theme.p5For(parent))
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: Devices.canWrite && !Devices.working
                                        cursorShape: Qt.CrossCursor
                                        function at(m) {
                                            map.hx = Math.max(0, Math.min(1, m.x / map.width));
                                            map.sy = Math.max(0, Math.min(1, m.y / map.height));
                                        }
                                        onPressed: m => at(m)
                                        onPositionChanged: m => at(m)
                                        onReleased: zoneCol.put({
                                            "color": Qt.hsva(Math.min(0.999, map.hx), 1 - map.sy, 1, 1).toString(),
                                            "rainbow": false
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // ---- Modes ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Modes ----
                Column {
                    visible: page.tab === "modes" && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 2
                    SettingRow {
                        label: I18n.t("Режим", "Mode")
                        hint: I18n.t("какой из трёх наборов настраивается; на клавиатуре сейчас — «", "Which of the three sets is set up; on the keyboard now: \"") + (page.kb ? page.kb.modeName : "") + "»"
                        PxSegmented {
                            model: (page.kb ? page.kb.modeNames : []).map((n, i) => ({
                                        "label": n,
                                        "value": i
                                    }))
                            currentValue: page.modeIndex
                            onActivated: v => page.modeShown = v
                        }
                    }
                    SettingRow {
                        visible: !!page.modeData && !!page.kb && !!page.kb.reportRates
                        label: I18n.t("Частота опроса", "Polling rate")
                        hint: I18n.t("Сколько раз в секунду клавиатура сообщает о нажатиях. После смены переподключится на секунду.", "How often the keyboard reports keys. After a change it reconnects for a second.")
                        PxSegmented {
                            enabled: Devices.canWrite && !Devices.working
                            model: [4, 3, 2, 1].map(code => ({
                                        "label": (page.kb && page.kb.reportRates ? page.kb.reportRates[String(code)] / 1000 : 0) + "K",
                                        "value": code
                                    }))
                            currentValue: page.modeData ? page.modeData.reportRate : 0
                            onActivated: v => Devices.setMode(page.modeIndex, {
                                    "reportRate": v
                                })
                        }
                    }
                    SettingRow {
                        label: I18n.t("Скорость", "Speed")
                        hint: I18n.t("названия — как в nuphy.io; что именно они меняют в прошивке, производитель не описывает", "The names are nuphy.io's; what exactly they change in the firmware the maker does not say")
                        Column {
                            spacing: Theme.u * 2
                            ModeToggle {
                                key: "speedMode"
                                text: I18n.t("Макс. скорость", "Max speed")
                            }
                            ModeToggle {
                                key: "gameOptimization"
                                text: I18n.t("Игровая оптимизация", "Game optimisation")
                            }
                            ModeToggle {
                                key: "dynamicCalibration"
                                text: I18n.t("Динамическая калибровка", "Dynamic calibration")
                            }
                        }
                    }
                    SettingRow {
                        label: I18n.t("Стабилизация", "Stabilisation")
                        hint: I18n.t("сглаживание показаний датчика: выше — спокойнее, но чуть медленнее", "Smoothing of the sensor's readings: higher is calmer and a touch slower")
                        PxSegmented {
                            enabled: Devices.canWrite && !Devices.working
                            model: [
                                {
                                    "label": I18n.t("Низкая", "Low"),
                                    "value": 0
                                },
                                {
                                    "label": I18n.t("Средняя", "Medium"),
                                    "value": 3
                                },
                                {
                                    "label": I18n.t("Высокая", "High"),
                                    "value": 7
                                }
                            ]
                            currentValue: page.modeData ? page.modeData.stabilization : 0
                            onActivated: v => Devices.setMode(page.modeIndex, {
                                    "stabilization": v
                                })
                        }
                    }
                    SettingRow {
                        label: "Tick rate"
                        hint: I18n.t("как в nuphy.io: выключено, 30 или 60", "As in nuphy.io: off, 30 or 60")
                        PxSegmented {
                            enabled: Devices.canWrite && !Devices.working
                            model: [
                                {
                                    "label": I18n.t("Выкл", "Off"),
                                    "value": 0
                                },
                                {
                                    "label": "30",
                                    "value": 1
                                },
                                {
                                    "label": "60",
                                    "value": 2
                                }
                            ]
                            currentValue: page.modeData ? page.modeData.tickRate : 0
                            onActivated: v => Devices.setMode(page.modeIndex, {
                                    "tickRate": v
                                })
                        }
                    }
                    SettingRow {
                        label: I18n.t("Блокировки", "Locks")
                        hint: I18n.t("клавиши и сочетания, которые клавиатура сама не пропускает в этом режиме", "Keys and chords the keyboard itself swallows in this mode")
                        Column {
                            spacing: Theme.u * 2
                            ModeToggle {
                                key: "lockWin"
                                text: "Win"
                            }
                            ModeToggle {
                                key: "lockAltTab"
                                text: "Alt+Tab"
                            }
                            ModeToggle {
                                key: "lockAltF4"
                                text: "Alt+F4"
                            }
                        }
                    }
                    SettingRow {
                        label: I18n.t("Сон", "Sleep")
                        hint: I18n.t("через сколько минут без нажатий клавиатура засыпает", "After how many minutes without a key the keyboard falls asleep")
                        Column {
                            spacing: Theme.u * 2
                            ModeToggle {
                                key: "sleep"
                                text: I18n.t("Засыпать", "Sleep")
                            }
                            PxSpin {
                                id: sleepSpin
                                property int want: 0
                                enabled: Devices.canWrite && !!page.modeData && page.modeData.sleep
                                from: 1
                                to: 120
                                stepSize: 1
                                suffix: I18n.t(" мин", " min")
                                value: page.modeData ? page.modeData.sleepMinutes : 0
                                // one write when the clicking stops, not a write and a read-back a step
                                onMoved: v => {
                                    want = v;
                                    sleepWrite.restart();
                                }
                                Timer {
                                    id: sleepWrite
                                    interval: 600
                                    onTriggered: Devices.setMode(page.modeIndex, {
                                            "sleepMinutes": sleepSpin.want
                                        })
                                }
                            }
                        }
                    }
                }
            }
        }
        // ---- Profiles ----
        CatCustom {
            wide: true
            CatBox {
                // ---- Profiles ----
                Column {
                    visible: page.tab === "profiles" && !!page.kb
                    width: parent.width
                    spacing: Theme.u * 2
                    SettingRow {
                        label: I18n.t("Сохранить в профиль", "Save as a profile")
                        hint: I18n.t("все настройки клавиатуры (раскладка, ход, пары, подсветка, режимы) — в файл", "Every setting of the keyboard (keys, travel, pairs, lights, modes) into a file")
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxField {
                                id: profileName
                                width: Theme.u * 70
                                placeholder: I18n.t("например, CS2", "say, CS2")
                                onAccepted: saveProfile.clicked()
                            }
                            PxButton {
                                id: saveProfile
                                compact: true
                                accent: true
                                icon: "check"
                                enabled: !Devices.working
                                text: I18n.t("Сохранить", "Save")
                                onClicked: {
                                    Devices.profile("save", profileName.text);
                                    profileName.text = "";
                                }
                            }
                        }
                    }
                    Repeater {
                        model: page.kb && page.kb.profiles ? page.kb.profiles : []
                        SettingRow {
                            id: prof
                            required property var modelData
                            label: modelData.name
                            hint: modelData.taken
                            Flow {
                                width: parent.width
                                spacing: Theme.u * 3
                                PxButton {
                                    compact: true
                                    icon: "download"
                                    enabled: Devices.canWrite && !Devices.working
                                    text: I18n.t("Загрузить в клавиатуру", "Load into the keyboard")
                                    onClicked: Devices.profile("load", prof.modelData.file)
                                }
                                PxButton {
                                    compact: true
                                    icon: "trash"
                                    enabled: !Devices.working
                                    text: I18n.t("Удалить", "Delete")
                                    onClicked: Devices.profile("delete", prof.modelData.file)
                                }
                            }
                        }
                    }
                    SettingRow {
                        label: I18n.t("Вернуть как было", "Put it back")
                        hint: page.kb && page.kb.backup ? I18n.t("все настройки, как они были до первой записи из оболочки: ", "Every setting as it was before the shell's first write: ") + page.kb.backup : I18n.t("снимок снимается сам перед первой записью в устройство", "The snapshot is taken by itself before the first write to the device")
                        PxButton {
                            compact: true
                            danger: page.sureRestore
                            icon: "refresh"
                            enabled: Devices.canWrite && !Devices.working && !!page.kb && page.kb.backup !== ""
                            text: page.sureRestore ? I18n.t("Точно вернуть всё?", "Really put it all back?") : I18n.t("Вернуть как было", "Put it back")
                            onClicked: {
                                if (!page.sureRestore) {
                                    page.sureRestore = true;
                                    unsure.restart();
                                    return;
                                }
                                page.sureRestore = false;
                                Devices.restore();
                            }
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "mouse"
        title: I18n.t("Мышь", "The mouse")
        icon: "mouse"
        present: page.isMouse
        CatNote {
            present: !page.mouse && !Devices.loading && !Devices.error
            dim: true
            text: I18n.t("Открываю мышь…", "Opening the mouse…")
        }
        CatNote {
            present: !!page.mouse
            dim: true
            text: !page.mouse ? "" : I18n.t("Заряд: ", "Charge: ") + page.mouse.battery.percent + " %" + (page.mouse.battery.charging ? I18n.t(", заряжается", ", charging") : "") + " · " + I18n.t("прошивка ", "firmware ") + page.mouse.firmware.version + " · " + I18n.t("профиль ", "profile ") + page.mouse.profile + (Devices.canWrite ? I18n.t(" · настройки пишутся в мышь сразу и читаются обратно", " · settings go to the mouse at once and are read back") : I18n.t(" · только чтение", " · reading only"))
        }
        CatChoice {
            present: !!page.mouse && page.cap("pollingRate")
            label: I18n.t("Частота опроса", "Polling rate")
            hint: I18n.t("сколько раз в секунду мышь сообщает о движении; выше — плавнее и больше нагрузка на процессор и батарею", "How many times a second the mouse reports its movement; higher is smoother and costs more CPU and battery")
            enabled: Devices.canWrite && !Devices.working
            model: (page.capOf("pollingRate").values || []).map(v => ({
                        "label": v >= 1000 ? v / 1000 + "K" : String(v),
                        "value": v
                    }))
            currentValue: page.mouse ? page.mouse.pollingRate : 0
            onActivated: v => Devices.setMouse("pollingRate", v)
        }
        CatCustom {
            present: !!page.mouse && page.cap("dpi")
            label: "DPI"
            hint: I18n.t("ступени чувствительности; активная выделена, клик по номеру делает её активной", "The sensitivity stages; the active one is marked, a click on its number makes a stage the active one")
            CatBox {
                Column {
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.mouse ? page.mouse.dpiStages : []
                        Row {
                            id: stage
                            required property var modelData
                            required property int index
                            spacing: Theme.u * 3
                            PxButton {
                                compact: true
                                accent: !!page.mouse && page.mouse.dpiActive === stage.index + 1
                                enabled: Devices.canWrite && !Devices.working
                                text: String(stage.index + 1)
                                onClicked: Devices.setMouse("dpiActive", stage.index + 1)
                            }
                            PxSpin {
                                enabled: Devices.canWrite && !Devices.working
                                from: page.capOf("dpi").min || 50
                                to: page.capOf("dpi").max || 26000
                                stepSize: page.capOf("dpi").step || 50
                                value: stage.modelData.x
                                onMoved: v => Devices.setMouse("dpiStages", page.stagesWith(stage.index, v))
                            }
                            PxButton {
                                visible: !!page.mouse && page.mouse.dpiStages.length > 1
                                compact: true
                                icon: "close"
                                enabled: Devices.canWrite && !Devices.working
                                onClicked: Devices.setMouse("dpiStages", page.mouse.dpiStages.filter((s, i) => i !== stage.index).map(s => s.x))
                            }
                        }
                    }
                    PxButton {
                        visible: !!page.mouse && page.mouse.dpiStages.length < (page.capOf("dpi").stages || 5)
                        compact: true
                        icon: "plus"
                        enabled: Devices.canWrite && !Devices.working
                        text: I18n.t("Ступень", "A stage")
                        onClicked: Devices.setMouse("dpiStages", page.mouse.dpiStages.map(s => s.x).concat([page.mouse.dpiStages[page.mouse.dpiStages.length - 1].x]))
                    }
                }
            }
        }
        CatChoice {
            present: !!page.mouse && page.cap("lod")
            label: I18n.t("Высота отрыва (LOD)", "Lift-off distance")
            hint: I18n.t("на какой высоте над ковриком мышь перестаёт видеть движение", "How high above the pad the mouse stops seeing movement")
            enabled: Devices.canWrite && !Devices.working
            model: (page.capOf("lod").values || []).map(v => ({
                        "label": v + I18n.t(" мм", " mm"),
                        "value": v
                    }))
            currentValue: page.mouse ? page.mouse.lod : 0
            onActivated: v => Devices.setMouse("lod", v)
        }
        CatSpin {
            present: !!page.mouse && page.cap("debounce")
            label: "Debounce"
            hint: I18n.t("Меньше — быстрее клик, больше — меньше случайных двойных кликов.", "Less: a faster click. More: fewer accidental double clicks.")
            enabled: Devices.canWrite && !Devices.working
            from: page.capOf("debounce").min || 0
            to: page.capOf("debounce").max || 15
            stepSize: 1
            suffix: I18n.t(" мс", " ms")
            value: page.mouse ? page.mouse.debounce : 0
            onMoved: v => Devices.setMouse("debounce", v)
        }
        CatCustom {
            present: !!page.mouse && (page.cap("motionSync") || page.cap("angleSnap") || page.cap("rippleControl"))
            label: I18n.t("Сенсор", "The sensor")
            hint: I18n.t("Тонкая подстройка сенсора: плавность, выпрямление линий, меньше дрожи.", "Fine sensor tuning: smoothness, straightened lines, less jitter.")
            CatBox {
                Column {
                    spacing: Theme.u * 2
                    PxToggle {
                        visible: page.cap("motionSync")
                        enabled: Devices.canWrite && !Devices.working
                        text: "Motion Sync"
                        checked: !!page.mouse && page.mouse.motionSync
                        onToggled: v => Devices.setMouse("motionSync", v)
                    }
                    PxToggle {
                        visible: page.cap("angleSnap")
                        enabled: Devices.canWrite && !Devices.working
                        text: "Angle Snap"
                        checked: !!page.mouse && page.mouse.angleSnap
                        onToggled: v => Devices.setMouse("angleSnap", v)
                    }
                    PxToggle {
                        visible: page.cap("rippleControl")
                        enabled: Devices.canWrite && !Devices.working
                        text: "Ripple Control"
                        checked: !!page.mouse && page.mouse.ripple
                        onToggled: v => Devices.setMouse("ripple", v)
                    }
                }
            }
        }
        CatChoice {
            present: !!page.mouse && page.cap("sleep")
            label: I18n.t("Сон", "Sleep")
            hint: I18n.t("через сколько без движения мышь засыпает", "After how long without movement the mouse falls asleep")
            enabled: Devices.canWrite && !Devices.working
            model: (page.capOf("sleep").values || []).map(v => ({
                        "label": page.sleepLabel(v),
                        "value": v
                    }))
            currentValue: page.mouse ? page.mouse.sleep : 0
            onActivated: v => Devices.setMouse("sleep", v)
        }
        CatNote {
            present: !!Devices.failed
            text: Devices.failed ? I18n.t("Не записано: ", "Not written: ") + I18n.t(Devices.failed.ru, Devices.failed.en) + (Devices.failed.detail ? " (" + Devices.failed.detail + ")" : "") : ""
        }
    }
    CatGroup {
        name: "mouseBackup"
        title: I18n.t("Вернуть как было", "Put it back")
        icon: "refresh"
        advanced: true
        present: page.isMouse && !!page.mouse
        CatButton {
            label: I18n.t("Резервная копия", "The backup")
            hint: page.mouse && page.mouse.backup ? I18n.t("настройки мыши, как они были до первой записи из оболочки: ", "The mouse's settings as they were before the shell's first write: ") + page.mouse.backup : I18n.t("снимается сама перед первой записью в мышь", "Taken by itself before the first write to the mouse")
            compact: true
            danger: page.sureRestore
            icon: "refresh"
            enabled: Devices.canWrite && !Devices.working && !!page.mouse && page.mouse.backup !== ""
            text: page.sureRestore ? I18n.t("Точно вернуть всё?", "Really put it all back?") : I18n.t("Вернуть как было", "Put it back")
            onClicked: {
                if (!page.sureRestore) {
                    page.sureRestore = true;
                    unsure.restart();
                    return;
                }
                page.sureRestore = false;
                Devices.restore();
            }
        }
    }
    CatGroup {
        name: "support"
        title: I18n.t("Что поддерживается", "What is supported")
        icon: "info"
        advanced: true
        CatNote {
            dim: true
            text: I18n.t("Устройство описано файлом. «Проверено на железе» — автор держал его в руках; «по описанию» — нет.", "Each device is a description file. «Tested on hardware»: the author had it in hand; «by spec»: not.")
        }
        CatRepeat {
            model: Devices.known
            delegate: Component {
                CatCustom {
                    required property var modelData
                    label: modelData.name
                    hint: [modelData.maker || "", modelData.family, Devices.supportLabel(modelData.support), modelData.origin === "user" ? I18n.t("ваш файл", "your file") : ""].filter(x => x !== "").join(" · ")
                    CatBox {
                    }
                }
            }
        }
        CatButton {
            label: I18n.t("Своё устройство", "A device of your own")
            hint: I18n.t("Файл устройства кладётся в ~/.config/angelos/devices и появляется здесь сам.", "A device file goes into ~/.config/angelos/devices and shows up here by itself.")
            compact: true
            icon: "folder"
            text: I18n.t("Папка", "The folder")
            onClicked: Quickshell.execDetached(["sh", "-c", 'd="${XDG_CONFIG_HOME:-$HOME/.config}/angelos/devices"; mkdir -p "$d" && exec gio open "$d"'])
            CatButton {
                compact: true
                icon: "document"
                text: I18n.t("Как описать", "How to describe one")
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.shellDir + "/docs/devices.md"])
            }
        }
    }
}
