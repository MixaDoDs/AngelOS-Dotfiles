pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The screens menu (Mod+P, a laptop's display key — cfg/angelos-laptop.kdl), as Win+P: only the
// laptop's panel, the same picture on both (wl-mirror, when installed), both side by side, only
// the other screen. The key again moves to the next choice; Enter or a click takes it. Applied
// with `niri msg output … on|off` for this session; Settings → Display keeps a layout for good.
// Without a laptop panel the first screen plays its part (a desktop with two screens).
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Shell.projectOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.35)
    WlrLayershell.namespace: "angelos-project"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: a menu of four choices; a click beside it closes it
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    // every connected output (the switched-off ones too): niri's own list
    readonly property var names: Object.keys(Outputs.outputs || {}).sort()
    readonly property string inner: names.find(n => /^(eDP|LVDS|DSI)/i.test(n)) || names[0] || ""
    readonly property var others: names.filter(n => n !== inner)
    readonly property bool canMirror: !!Laptop.info.mirrorTool
    readonly property var choices: [
        {
            "id": "inner",
            "label": I18n.t("Только этот экран", "This screen only"),
            "icon": "laptop"
        },
        {
            "id": "mirror",
            "label": I18n.t("Повторять", "Duplicate"),
            "icon": "layers",
            "off": !canMirror,
            "why": I18n.t("нужен wl-mirror", "needs wl-mirror")
        },
        {
            "id": "extend",
            "label": I18n.t("Расширить", "Extend"),
            "icon": "grid"
        },
        {
            "id": "outer",
            "label": I18n.t("Только второй экран", "Second screen only"),
            "icon": "monitor"
        }
    ]
    property int current: 2
    readonly property string state: {
        const on = n => !!(Outputs.outputs[n] && Outputs.outputs[n].logical);
        if (!others.length)
            return "inner";
        const outerOn = others.some(on);
        return !on(inner) ? "outer" : outerOn ? "extend" : "inner";
    }

    function step() {
        let i = current;
        do
            i = (i + 1) % choices.length;
        while (choices[i].off)
        current = i;
    }
    function run(id) {
        close();
        if (!others.length)
            return;
        const cmds = [];
        const out = (name, on) => cmds.push("niri msg output " + name + (on ? " on" : " off"));
        Quickshell.execDetached(["pkill", "-x", "wl-mirror"]);
        if (id === "inner") {
            out(inner, true);
            others.forEach(n => out(n, false));
        } else if (id === "outer") {
            others.forEach(n => out(n, true));
            out(inner, false);
        } else {
            out(inner, true);
            others.forEach(n => out(n, true));
            if (id === "mirror" && canMirror)
                cmds.push("sleep 0.5; niri msg action spawn -- wl-mirror --fullscreen-output " + others[0] + " " + inner);
        }
        Quickshell.execDetached(["sh", "-c", cmds.join("; ")]);
        Laptop.flag(choices.find(c => c.id === id).icon, choices.find(c => c.id === id).label);
        Qt.callLater(Outputs.refresh);
    }

    Component.onCompleted: if (visible)
        opened()
    onVisibleChanged: if (visible)
        opened()
    function opened() {
        Outputs.refresh();
        current = Math.max(0, choices.findIndex(c => c.id === state));
        keys.forceActiveFocus();
    }
    // the key pressed again while it is open: the next choice (Laptop.ipc "project")
    Connections {
        target: Shell
        function onProjectNext() {
            win.step();
        }
    }
    function close() {
        Shell.projectOpen = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    PxWindow {
        id: dialog
        anchors.centerIn: parent
        width: row.implicitWidth + Theme.pad * 2 + Theme.u * 8
        height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 10
        title: I18n.t("Экраны", "Screens")
        icon: "monitor"
        onCloseClicked: win.close()

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)
                    win.close();
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                    let i = win.current;
                    do
                        i = (i + win.choices.length - 1) % win.choices.length;
                    while (win.choices[i].off)
                    win.current = i;
                } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab || e.key === Qt.Key_P)
                    win.step();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                    win.run(win.choices[win.current].id);
                e.accepted = true;
            }
        }
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 6
            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.others.length ? I18n.t("Как показывать на экранах?", "How to use the screens?") : I18n.t("Второй экран не подключён", "No second screen connected")
                kind: "title"
            }
            Row {
                id: row
                spacing: Theme.u * 5
                Repeater {
                    model: win.choices
                    PxButton {
                        id: b
                        required property var modelData
                        required property int index
                        width: Theme.u * 46
                        height: Theme.u * 42
                        enabled: !modelData.off && win.others.length > 0
                        checked: win.current === index
                        onClicked: win.run(modelData.id)
                        onHoveredChanged: if (hovered && enabled)
                            win.current = index
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.u * 3
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: b.modelData.icon
                                pixel: Theme.u * 2
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: b.width - Theme.u * 4
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                text: b.modelData.label
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !!b.modelData.off || win.state === b.modelData.id
                                text: b.modelData.off ? b.modelData.why : I18n.t("сейчас", "now")
                                kind: "tiny"
                                dim: true
                            }
                        }
                    }
                }
            }
            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("Mod+P ещё раз — следующий · Enter — выбрать · Esc — закрыть", "Mod+P again: next · Enter: pick · Esc: close")
                kind: "tiny"
                dim: true
            }
        }
    }

    RightClickGuard {}
}
