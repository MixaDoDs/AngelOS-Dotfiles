pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The conversion ring (services/Convert): over the screen with the files' window, at the pointer
// (where it is once the overlay sees it; the middle if it never moves). First the kinds when the
// files are of several (pictures / video / sound), then the formats, the ring look of the desktop
// menu (modules/background/RingLook). Click a slot: converted; the hub, Esc or a right click: back
// a ring, or away; a click beside it: away; 1–9: a slot.
Scope {
    LazyLoader {
        active: Convert.open

        PanelWindow {
            id: win
            screen: Shell.focusedScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // takes input: a modal ring, a click outside it closes it
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "angelos-convert"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property real u: Theme.u
            readonly property var names: ({
                    "image": I18n.t("Картинки", "Pictures"),
                    "video": I18n.t("Видео", "Video"),
                    "audio": I18n.t("Звук", "Sound")
                })
            readonly property var icons: ({
                    "image": "image",
                    "video": "play",
                    "audio": "music",
                    "discord": "chat",
                    "edit": "layers"
                })
            // the slots now: {id, label, icon, big (a format's name drawn in the tile)}
            readonly property var slots: Convert.level === "" ? Convert.ringKinds.map(k => ({
                        "id": k,
                        "label": names[k] + " · " + Convert.filesFor(k).length,
                        "icon": icons[k],
                        "big": ""
                    })) : (Convert.formats[Convert.level] || []).map(f => ({
                        "id": f.id,
                        "label": f.label,
                        "icon": icons[f.id] || "",
                        "big": icons[f.id] ? "" : f.label,
                        "same": Convert.same.includes(f.id),
                        "size": Convert.sizes[f.id] !== undefined ? Convert.sizes[f.id] : -1
                    }))
            // 12.4 МБ
            function bytes(n) {
                return n < 0 ? "…" : QuickLook.size(n);
            }
            // the estimate against what there is now: «≈45 МБ (сейчас 120 МБ)»
            function sizeSay(s) {
                return s.same ? I18n.t("уже в этом формате", "already this format") : s.size < 0 ? I18n.t("считаю…", "working it out…") : "≈" + bytes(s.size) + I18n.t(" (сейчас ", " (now ") + bytes(Convert.now) + ")"
            }
            readonly property int count: Convert.level ? Convert.filesFor(Convert.level).length : Object.values(Convert.groups).reduce((n, l) => n + l.length, 0)
            readonly property real slotSize: Math.round(u * 26)
            readonly property real r1: Math.max(u * 50, slots.length * (slotSize + u * 22) / (2 * Math.PI))
            readonly property real reach: r1 + slotSize + Theme.sizeTiny + u * 16
            property int current: -1
            property real cx: width / 2
            property real cy: height / 2
            property bool placed: false
            property real reveal: 0

            function angleOf(i) {
                return -Math.PI / 2 + i * 2 * Math.PI / Math.max(1, slots.length);
            }
            function place(x, y) {
                if (placed)
                    return;
                placed = true;
                cx = Math.max(reach, Math.min(width - reach, x));
                cy = Math.max(reach, Math.min(height - reach, y));
                grow.restart();
            }
            function pick(i) {
                const s = slots[i];
                if (!s || s.same)
                    return;
                if (Convert.level === "")
                    Convert.level = s.id;
                else
                    Convert.run(s.id);
            }
            // a new ring flies out again
            Connections {
                target: Convert
                function onLevelChanged() {
                    win.current = -1;
                    grow.restart();
                }
            }
            NumberAnimation {
                id: grow
                target: win
                property: "reveal"
                from: 0
                to: 1
                duration: Motion.ms(180)
                easing.type: Easing.OutBack
            }
            // the pointer's place comes with the first hover; none soon: the middle
            Timer {
                interval: 350
                running: true
                onTriggered: win.place(win.width / 2, win.height / 2)
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.shadow, 0.3 * win.reveal)
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: win.place(mouseX, mouseY)
                onPositionChanged: m => win.place(m.x, m.y)
                onClicked: m => m.button === Qt.RightButton ? Convert.back() : Convert.close()
            }
            Item {
                focus: true
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape)
                        Convert.back();
                    else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9)
                        win.pick(e.key - Qt.Key_1);
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && win.current >= 0)
                        win.pick(win.current);
                    else
                        return;
                    e.accepted = true;
                }
                Component.onCompleted: forceActiveFocus()
            }

            Item {
                anchors.fill: parent
                visible: win.placed
                // a glow behind the ring
                Rectangle {
                    x: win.cx - width / 2
                    y: win.cy - height / 2
                    width: (win.r1 + win.slotSize) * 2 * Math.max(0.2, win.reveal)
                    height: width
                    radius: width / 2
                    color: Qt.alpha(Theme.accent, 0.1 * win.reveal)
                    border.width: Math.max(1, win.u / 2)
                    border.color: Qt.alpha(Theme.accent, 0.25 * win.reveal)
                }
                // the hub: how many files; back a ring, or away
                PxBox {
                    id: hub
                    x: win.cx - width / 2
                    y: win.cy - height / 2
                    width: Math.round(win.slotSize * 1.25)
                    height: width
                    scale: Math.min(1, win.reveal)
                    color: hubMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.35) : Qt.alpha(Theme.menuSurface, Math.max(0.88, Theme.panelAlpha))
                    shadow: Config.appearance.shadows
                    Column {
                        anchors.centerIn: parent
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            kind: "title"
                            text: hubMouse.containsMouse && Convert.level && Convert.ringKinds.length > 1 ? "←" : String(win.count)
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            kind: "tiny"
                            dim: true
                            text: Convert.level ? win.names[Convert.level].toLowerCase() : I18n.t("файлов", "files")
                        }
                    }
                    MouseArea {
                        id: hubMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.current = -1
                        onClicked: Convert.back()
                    }
                }
                // above the ring: the hovered slot's name, else what the ring asks
                PxBox {
                    x: win.cx - width / 2
                    y: win.cy - win.r1 - win.slotSize / 2 - height - win.u * 6
                    visible: win.reveal > 0.6
                    width: ask.implicitWidth + win.u * 8
                    height: ask.implicitHeight + win.u * 4
                    color: Qt.alpha(Theme.menuSurface, 0.92)
                    PxText {
                        id: ask
                        anchors.centerIn: parent
                        kind: "tiny"
                        font.bold: true
                        text: win.current >= 0 && win.slots[win.current] ? (Convert.level ? I18n.t("в ", "to ") + win.slots[win.current].label + " · " + win.sizeSay(win.slots[win.current]) : win.slots[win.current].label) : Convert.level ? I18n.t("В какой формат?", "Which format?") : I18n.t("Что конвертировать?", "Convert what?") + (Convert.skipped ? I18n.t(" (пропущено: ", " (skipped: ") + Convert.skipped + ")" : "")
                    }
                }
                Repeater {
                    model: win.slots
                    Item {
                        id: slot
                        required property var modelData
                        required property int index
                        readonly property real a: win.angleOf(index)
                        readonly property bool sel: win.current === index
                        // one after another
                        readonly property real out: Math.max(0, Math.min(1, win.reveal * 1.25 - index * 0.03))
                        width: win.slotSize
                        height: win.slotSize + Theme.sizeTiny + win.u * 3
                        x: win.cx + Math.cos(a) * win.r1 * out - width / 2
                        y: win.cy + Math.sin(a) * win.r1 * out - win.slotSize / 2
                        opacity: Math.min(1, out) * (modelData.same ? 0.4 : 1)
                        PxBox {
                            id: tile
                            width: win.slotSize
                            height: win.slotSize
                            scale: slot.sel ? 1.14 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.ms(90)
                                }
                            }
                            sunken: slotMouse.pressed
                            color: slot.sel ? Theme.mix(Theme.face, Theme.accent, 0.4) : Qt.alpha(Theme.menuSurface, Math.max(0.88, Theme.panelAlpha))
                            shadow: Config.appearance.shadows
                            PxIcon {
                                visible: !slot.modelData.big
                                anchors.centerIn: parent
                                name: slot.modelData.icon || "heart"
                                pixel: Math.max(1, Math.round(win.u))
                            }
                            PxText {
                                visible: !!slot.modelData.big
                                anchors.centerIn: parent
                                font.bold: true
                                text: slot.modelData.big
                            }
                        }
                        PxText {
                            anchors.horizontalCenter: tile.horizontalCenter
                            anchors.top: tile.bottom
                            anchors.topMargin: win.u
                            kind: "tiny"
                            font.bold: slot.sel
                            color: Theme.text
                            style: Text.Outline
                            styleColor: Qt.alpha(Theme.menuSurface, 0.9)
                            // a format: how big it comes out; the one they already are says so
                            text: (slot.index < 9 ? (slot.index + 1) + " " : "") + (slot.modelData.big ? "" : slot.modelData.label + " ") + (!Convert.level ? "" : slot.modelData.same ? I18n.t("уже", "already") : "≈" + win.bytes(slot.modelData.size))
                        }
                        MouseArea {
                            id: slotMouse
                            width: win.slotSize
                            height: win.slotSize
                            hoverEnabled: true
                            cursorShape: slot.modelData.same ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                            onEntered: win.current = slot.index
                            onExited: if (win.current === slot.index)
                                win.current = -1
                            onClicked: win.pick(slot.index)
                        }
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
