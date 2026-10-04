pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// Gamepad tester: live buttons, sticks, triggers, drift and rumble
// (scripts/gamepad.py reads the devices, never grabs them).
PxPage {
    id: page

    heading: I18n.t("Геймпад", "Gamepad")
    subtitle: I18n.t("Проверка контроллера: нажимай кнопки и крути стики — всё подсвечивается. Игры при этом продолжают видеть геймпад.", "Controller check: press buttons and move the sticks, everything lights up. Games keep seeing the pad meanwhile.")

    property var pads: []
    property var batteries: []
    property string selected: ""
    readonly property var pad: pads.find(p => p.id === selected) || pads[0] || null
    property var keys: ({})            // id -> {code: true}
    property var axes: ({})            // id -> {code: value}
    property string error: ""
    readonly property var k: pad ? keys[pad.id] || {} : {}
    readonly property var a: pad ? axes[pad.id] || {} : {}
    readonly property bool sony: !!pad && pad.vendor === "054c"
    readonly property bool nintendo: !!pad && pad.vendor === "057e"

    function pressed(code) {
        return !!k[code];
    }
    function axis(code) {
        return a[code] || 0;
    }
    function hat(dir) {
        const x = axis("ABS_HAT0X"), y = axis("ABS_HAT0Y");
        return dir === "up" ? (y < 0 || pressed("BTN_DPAD_UP")) : dir === "down" ? (y > 0 || pressed("BTN_DPAD_DOWN")) : dir === "left" ? (x < 0 || pressed("BTN_DPAD_LEFT")) : (x > 0 || pressed("BTN_DPAD_RIGHT"));
    }
    function trigger(side) {
        // analog triggers are ABS_Z/ABS_RZ (0..1); some pads only have buttons
        const v = side === "l" ? axis("ABS_Z") : axis("ABS_RZ");
        return Math.max(Math.abs(v), pressed(side === "l" ? "BTN_TL2" : "BTN_TR2") ? 1 : 0);
    }
    function rumble(strong, weak) {
        if (pad)
            reader.write(JSON.stringify({
                "cmd": "rumble",
                "id": pad.id,
                "strong": strong,
                "weak": weak,
                "ms": 450
            }) + "\n");
    }
    // Xbox letters by default; face buttons by position on Sony pads
    readonly property var face: sony ? [
        {
            "code": "BTN_NORTH",
            "label": "△",
            "pos": "top",
            "color": "#3fb68b"
        },
        {
            "code": "BTN_EAST",
            "label": "○",
            "pos": "right",
            "color": "#e5484d"
        },
        {
            "code": "BTN_SOUTH",
            "label": "✕",
            "pos": "bottom",
            "color": "#5b8def"
        },
        {
            "code": "BTN_WEST",
            "label": "□",
            "pos": "left",
            "color": "#d36ac2"
        }
    ] : [
        {
            "code": "BTN_WEST",
            "label": nintendo ? "X" : "Y",
            "pos": "top",
            "color": "#f5c542"
        },
        {
            "code": "BTN_EAST",
            "label": nintendo ? "A" : "B",
            "pos": "right",
            "color": "#e5484d"
        },
        {
            "code": "BTN_SOUTH",
            "label": nintendo ? "B" : "A",
            "pos": "bottom",
            "color": "#3fb68b"
        },
        {
            "code": "BTN_NORTH",
            "label": nintendo ? "Y" : "X",
            "pos": "left",
            "color": "#5b8def"
        }
    ]

    Process {
        id: reader
        running: true
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/gamepad.py"]
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.event === "devices") {
                    page.pads = ev.list;
                    page.batteries = ev.batteries || [];
                } else if (ev.event === "state") {
                    const ks = Object.assign({}, page.keys);
                    const set = {};
                    for (const c of ev.keys)
                        set[c] = true;
                    ks[ev.id] = set;
                    page.keys = ks;
                    const as = Object.assign({}, page.axes);
                    as[ev.id] = ev.abs;
                    page.axes = as;
                } else if (ev.event === "key") {
                    const ks = Object.assign({}, page.keys);
                    const set = Object.assign({}, ks[ev.id] || {});
                    if (ev.value)
                        set[ev.code] = true;
                    else
                        delete set[ev.code];
                    ks[ev.id] = set;
                    page.keys = ks;
                } else if (ev.event === "abs") {
                    const as = Object.assign({}, page.axes);
                    as[ev.id] = Object.assign({}, as[ev.id] || {}, ev.values);
                    page.axes = as;
                } else if (ev.event === "error") {
                    page.error = ev.message;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.includes("ModuleNotFoundError"))
                page.error = I18n.t("нужен python-evdev: sudo pacman -S python-evdev", "python-evdev is needed: sudo pacman -S python-evdev")
        }
    }

    component Stick: Item {
        id: st
        property real ax: 0
        property real ay: 0
        property bool click: false
        readonly property bool drift: Math.hypot(ax, ay) > 0.08 && Math.hypot(ax, ay) < 0.35
        width: Theme.u * 30
        height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: st.click ? Qt.alpha(Theme.accent, 0.35) : Theme.sunken
            border.width: Theme.u
            border.color: st.click ? Theme.accent : Theme.lo
        }
        // deadzone ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.16
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(Theme.text, 0.2)
        }
        Rectangle {
            width: Theme.u * 7
            height: width
            radius: width / 2
            x: (st.width - width) / 2 + st.ax * (st.width - width) / 2
            y: (st.height - height) / 2 + st.ay * (st.height - height) / 2
            color: st.drift ? Theme.accent3 : Theme.accent
            border.width: Theme.u
            border.color: Theme.edge
        }
    }
    component Pill: PxBox {
        id: pill
        property bool on: false
        property string label: ""
        width: Theme.u * 22
        height: Theme.u * 9
        sunken: on
        color: on ? Theme.accent : Theme.face
        PxText {
            anchors.centerIn: parent
            text: pill.label
            kind: "tiny"
            color: pill.on ? Theme.selectText : Theme.text
        }
    }

    PxGroup {
        name: "controller"
        title: I18n.t("Контроллер", "Controller")
        icon: "gamepad"
        width: parent.width

        PxText {
            visible: page.pads.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: page.error || I18n.t("Геймпад не найден. Подключи его (USB или Bluetooth) — он появится сам. Нужен доступ к /dev/input (группа input).", "No gamepad found. Plug it in (USB or Bluetooth), it shows up by itself. Access to /dev/input (the input group) is needed.")
        }
        SettingRow {
            visible: page.pads.length > 1
            label: I18n.t("Устройство", "Device")
            PxCombo {
                width: parent.width
                model: page.pads.map(p => ({
                            "label": p.name,
                            "value": p.id
                        }))
                currentValue: page.pad ? page.pad.id : ""
                onActivated: v => page.selected = v
            }
        }
        PxText {
            visible: !!page.pad
            width: parent.width
            wrapMode: Text.Wrap
            text: page.pad ? page.pad.name + "  ·  " + page.pad.vendor + ":" + page.pad.product + (page.batteries.length ? "  ·  ♥ " + page.batteries.map(b => b.capacity + "%").join(" / ") : "") : ""
            dim: true
        }

        // ---- the pad ----
        Item {
            visible: !!page.pad
            width: parent.width
            height: Theme.u * 96

            PxBox {
                id: body
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u * 14
                width: Math.min(parent.width, Theme.u * 210)
                height: Theme.u * 78
                color: Theme.faceAlt

                // shoulders
                Pill {
                    x: Theme.u * 10
                    y: -Theme.u * 12
                    label: "LB"
                    on: page.pressed("BTN_TL")
                }
                Pill {
                    x: parent.width - width - Theme.u * 10
                    y: -Theme.u * 12
                    label: "RB"
                    on: page.pressed("BTN_TR")
                }
                // triggers: fill from the bottom
                Repeater {
                    model: ["l", "r"]
                    PxBox {
                        id: trig
                        required property string modelData
                        x: modelData === "l" ? Theme.u * 36 : body.width - width - Theme.u * 36
                        y: -Theme.u * 13
                        width: Theme.u * 12
                        height: Theme.u * 11
                        sunken: true
                        color: Theme.sunken
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.u
                            x: Theme.u
                            width: parent.width - Theme.u * 2
                            height: (parent.height - Theme.u * 2) * page.trigger(trig.modelData)
                            color: Theme.accent
                        }
                        PxText {
                            anchors.centerIn: parent
                            text: trig.modelData === "l" ? "LT" : "RT"
                            kind: "tiny"
                        }
                    }
                }

                Stick {
                    x: Theme.u * 12
                    y: Theme.u * 8
                    ax: page.axis("ABS_X")
                    ay: page.axis("ABS_Y")
                    click: page.pressed("BTN_THUMBL")
                }
                Stick {
                    x: parent.width * 0.58
                    y: parent.height - height - Theme.u * 6
                    ax: page.axis("ABS_RX")
                    ay: page.axis("ABS_RY")
                    click: page.pressed("BTN_THUMBR")
                }

                // d-pad
                Item {
                    x: parent.width * 0.26
                    y: parent.height - height - Theme.u * 6
                    width: Theme.u * 27
                    height: width
                    Repeater {
                        model: [
                            {
                                "d": "up",
                                "x": 1,
                                "y": 0
                            },
                            {
                                "d": "left",
                                "x": 0,
                                "y": 1
                            },
                            {
                                "d": "right",
                                "x": 2,
                                "y": 1
                            },
                            {
                                "d": "down",
                                "x": 1,
                                "y": 2
                            }
                        ]
                        PxBox {
                            required property var modelData
                            x: modelData.x * Theme.u * 9
                            y: modelData.y * Theme.u * 9
                            width: Theme.u * 9
                            height: width
                            sunken: page.hat(modelData.d)
                            color: page.hat(modelData.d) ? Theme.accent : Theme.face
                        }
                    }
                }

                // face buttons
                Item {
                    x: parent.width - width - Theme.u * 12
                    y: Theme.u * 6
                    width: Theme.u * 30
                    height: width
                    Repeater {
                        model: page.face
                        Rectangle {
                            id: fb
                            required property var modelData
                            readonly property bool on: page.pressed(modelData.code)
                            width: Theme.u * 10
                            height: width
                            radius: width / 2
                            x: modelData.pos === "left" ? 0 : modelData.pos === "right" ? parent.width - width : (parent.width - width) / 2
                            y: modelData.pos === "top" ? 0 : modelData.pos === "bottom" ? parent.height - height : (parent.height - height) / 2
                            color: on ? modelData.color : Qt.alpha(modelData.color, 0.25)
                            border.width: Theme.u
                            border.color: on ? "#ffffff" : Theme.edge
                            scale: on ? 0.9 : 1
                            PxText {
                                anchors.centerIn: parent
                                text: fb.modelData.label
                                color: fb.on ? "#ffffff" : Theme.text
                                font.bold: true
                            }
                        }
                    }
                }

                // select / mode / start
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.u * 10
                    spacing: Theme.u * 3
                    Pill {
                        width: Theme.u * 18
                        label: page.sony ? "Share" : "Back"
                        on: page.pressed("BTN_SELECT")
                    }
                    Pill {
                        width: Theme.u * 12
                        label: "♥"
                        on: page.pressed("BTN_MODE")
                    }
                    Pill {
                        width: Theme.u * 18
                        label: page.sony ? "Opt" : "Start"
                        on: page.pressed("BTN_START")
                    }
                }
            }
        }

        PxText {
            visible: !!page.pad && (Math.hypot(page.axis("ABS_X"), page.axis("ABS_Y")) > 0.08 || Math.hypot(page.axis("ABS_RX"), page.axis("ABS_RY")) > 0.08) && Object.keys(page.k).length === 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.accent3
            text: I18n.t("Отпусти стики: если точка не возвращается в центр (жёлтая), это дрейф — поможет мёртвая зона в игре или чистка стика.", "Let go of the sticks: if a dot does not return to the centre (yellow), that is drift — a deadzone in the game or cleaning the stick helps.")
        }

        Flow {
            visible: !!page.pad && page.pad.ff
            width: parent.width
            spacing: Theme.u * 3
            PxText {
                text: I18n.t("Вибрация:", "Rumble:")
            }
            PxButton {
                compact: true
                text: I18n.t("слабая", "weak")
                onClicked: page.rumble(0, 0.8)
            }
            PxButton {
                compact: true
                text: I18n.t("сильная", "strong")
                onClicked: page.rumble(0.9, 0)
            }
            PxButton {
                compact: true
                accent: true
                text: I18n.t("обе ♥", "both ♥")
                onClicked: page.rumble(1, 1)
            }
        }
    }

    // ---- every button and axis the device reports ----
    PxGroup {
        name: "all-buttons-axes"
        visible: !!page.pad
        title: I18n.t("Все кнопки и оси", "All buttons and axes")
        icon: "layers"
        width: parent.width
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: page.pad ? page.pad.buttons : []
                PxBox {
                    id: bb
                    required property string modelData
                    readonly property bool on: page.pressed(modelData)
                    width: lbl.implicitWidth + Theme.u * 6
                    height: Theme.u * 10
                    sunken: on
                    color: on ? Theme.accent : Theme.face
                    PxText {
                        id: lbl
                        anchors.centerIn: parent
                        text: bb.modelData.replace("BTN_", "")
                        kind: "tiny"
                        color: bb.on ? Theme.selectText : Theme.text
                    }
                }
            }
        }
        Repeater {
            model: page.pad ? page.pad.axes : []
            Row {
                id: ar
                required property var modelData
                readonly property real v: page.axis(modelData.code)
                readonly property bool centred: modelData.min < 0
                width: parent.width
                spacing: Theme.u * 3
                PxText {
                    width: Theme.u * 32
                    text: ar.modelData.code.replace("ABS_", "")
                    kind: "tiny"
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxBox {
                    width: parent.width - Theme.u * 60
                    height: Theme.u * 6
                    sunken: true
                    color: Theme.sunken
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        readonly property real w: (parent.width - Theme.u * 2) * (ar.centred ? Math.abs(ar.v) / 2 : Math.abs(ar.v))
                        x: ar.centred ? (ar.v < 0 ? parent.width / 2 - w : parent.width / 2) : Theme.u
                        y: Theme.u
                        width: w
                        height: parent.height - Theme.u * 2
                        color: Theme.accent
                    }
                    Rectangle {
                        visible: ar.centred
                        x: parent.width / 2
                        width: Math.max(1, Theme.u / 2)
                        height: parent.height
                        color: Theme.lo
                    }
                }
                PxText {
                    width: Theme.u * 20
                    horizontalAlignment: Text.AlignRight
                    text: ar.v.toFixed(2)
                    kind: "tiny"
                    dim: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
