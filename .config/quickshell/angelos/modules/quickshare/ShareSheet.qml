pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Quick Share (services/QuickShare): what goes, the devices nearby on a pixel radar round
// this computer, a click on one sends; files dropped on the window join what goes.
// Esc / a click beside it: away.
Scope {
    LazyLoader {
        active: QuickShare.sheetOpen

        PanelWindow {
            id: win
            screen: Shell.focusedScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.alpha(Theme.shadow, 0.25)
            WlrLayershell.namespace: "angelos-quickshare"
            WlrLayershell.layer: WlrLayer.Overlay
            // takes input: the share sheet: a click beside it closes it
            WlrLayershell.keyboardFocus: Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

            readonly property int u: Theme.u
            readonly property var payload: QuickShare.payload
            readonly property string what: {
                if (QuickShare.payloadText && !payload.length)
                    return "«" + QuickShare.payloadText.slice(0, 80) + (QuickShare.payloadText.length > 80 ? "…" : "") + "»";
                if (!payload.length)
                    return I18n.t("Перетащите сюда файлы или папку", "Drop files or a folder here");
                if (payload.length === 1)
                    return payload[0].split("/").pop();
                return I18n.t(payload.length + " шт.: ", payload.length + " items: ") + payload.slice(0, 3).map(p => p.split("/").pop()).join(", ") + (payload.length > 3 ? "…" : "");
            }

            MouseArea {
                anchors.fill: parent
                onClicked: QuickShare.close()
            }
            Shortcut {
                sequence: "Escape"
                onActivated: QuickShare.close()
            }

            PxWindow {
                id: dialog
                anchors.centerIn: parent
                width: win.u * 210
                height: body.implicitHeight + titleHeight + chrome * 2 + bodyPadding * 2
                title: I18n.exe(I18n.t("отправить_рядом", "quick_share"))
                icon: "plane"
                translucent: false
                onCloseClicked: QuickShare.close()

                MouseArea {
                    anchors.fill: parent
                }
                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: d => {
                        const add = (d.urls || []).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(p => p.startsWith("/"));
                        QuickShare.payload = QuickShare.payload.concat(add.filter(p => !QuickShare.payload.includes(p)));
                        d.accept();
                    }
                }

                Column {
                    id: body
                    width: parent.width
                    spacing: win.u * 4

                    // what goes
                    PxBox {
                        width: parent.width
                        height: whatRow.implicitHeight + win.u * 6
                        sunken: true
                        Row {
                            id: whatRow
                            anchors.verticalCenter: parent.verticalCenter
                            x: win.u * 3
                            width: parent.width - win.u * 6
                            spacing: win.u * 3
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: QuickShare.payloadText && !win.payload.length ? "chat" : win.payload.length ? "document" : "download"
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - win.u * 30
                                elide: Text.ElideMiddle
                                text: win.what
                                dim: !win.payload.length && !QuickShare.payloadText
                            }
                        }
                    }

                    // the radar: this computer in the middle, the devices round it
                    Item {
                        id: radar
                        width: parent.width
                        height: win.u * 110
                        readonly property real cx: width / 2
                        readonly property real cy: height / 2
                        property real phase: 0
                        NumberAnimation on phase {
                            from: 0
                            to: 1
                            duration: 2400
                            loops: Animation.Infinite
                            running: QuickShare.sheetOpen
                        }
                        Canvas {
                            id: rings
                            anchors.fill: parent
                            renderStrategy: Canvas.Cooperative
                            property real phase: radar.phase
                            onPhaseChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const g = win.u;
                                const maxR = Math.min(width, height) / 2 - g;
                                // three rings going out, pixel squares on the grid, fading as they go
                                for (let k = 0; k < 3; k++) {
                                    const t = (phase + k / 3) % 1;
                                    const r = maxR * (0.25 + 0.75 * t);
                                    ctx.fillStyle = Qt.alpha(Theme.accent, 0.55 * (1 - t));
                                    const steps = Math.max(24, Math.round(2 * Math.PI * r / g));
                                    const seen = {};
                                    for (let i = 0; i < steps; i++) {
                                        const a = i / steps * 2 * Math.PI;
                                        const x = Math.round((radar.cx + Math.cos(a) * r) / g) * g;
                                        const y = Math.round((radar.cy + Math.sin(a) * r) / g) * g;
                                        if (seen[x + "," + y])
                                            continue;
                                        seen[x + "," + y] = 1;
                                        ctx.fillRect(x, y, g, g);
                                    }
                                }
                            }
                        }
                        // me
                        Column {
                            x: radar.cx - width / 2
                            y: radar.cy - win.u * 8
                            spacing: win.u
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "monitor"
                                pixel: win.u * 2
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                kind: "tiny"
                                dim: true
                                text: I18n.t("это я", "me")
                            }
                        }
                        PxText {
                            visible: !QuickShare.nearby.length
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            kind: "tiny"
                            dim: true
                            text: !QuickShare.wanted ? I18n.t("Отправка рядом выключена в настройках", "Quick Share is off in Settings") : !QuickShare.ready ? I18n.t("Запускаю…", "Starting…") : I18n.t("Ищу устройства с LocalSend в этой сети…", "Looking for LocalSend devices on this network…")
                        }
                        Repeater {
                            model: QuickShare.nearby
                            Item {
                                id: dev
                                required property var modelData
                                required property int index
                                readonly property int n: QuickShare.nearby.length
                                readonly property real ang: -Math.PI / 2 + index / Math.max(1, n) * 2 * Math.PI + (n > 1 ? 0 : 0)
                                readonly property real rad: Math.min(radar.width, radar.height) / 2 - win.u * 14
                                readonly property var job: QuickShare.jobFor(modelData.fp)
                                readonly property bool active: !!job && (job.state === "waiting" || job.state === "sending")
                                width: win.u * 44
                                height: devCol.implicitHeight
                                x: radar.cx + Math.cos(ang) * rad * 1.5 - width / 2
                                y: radar.cy + Math.sin(ang) * rad - height / 2
                                Column {
                                    id: devCol
                                    width: parent.width
                                    spacing: win.u
                                    PxButton {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        icon: dev.modelData.type === "mobile" ? "phone" : dev.modelData.type === "desktop" ? "monitor" : dev.modelData.type === "web" ? "window" : "laptop"
                                        iconPixel: win.u * 2
                                        accent: dev.active
                                        enabled: win.payload.length > 0 || QuickShare.payloadText !== ""
                                        onClicked: dev.active ? QuickShare.cancel(dev.job.job) : QuickShare.sendTo(dev.modelData.fp)
                                        onRightClicked: QuickShare.trust(dev.modelData, !QuickShare.isTrusted(dev.modelData.fp))
                                    }
                                    PxText {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        kind: "tiny"
                                        text: (QuickShare.isTrusted(dev.modelData.fp) ? "♥ " : "") + dev.modelData.alias
                                    }
                                    PxProgress {
                                        visible: dev.active
                                        width: parent.width
                                        height: win.u * 4
                                        showText: false
                                        busy: !!dev.job && dev.job.state === "waiting"
                                        value: dev.job && dev.job.total ? dev.job.done / dev.job.total : 0
                                    }
                                    PxText {
                                        visible: !!dev.job && !dev.active
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        kind: "tiny"
                                        dim: true
                                        text: !dev.job ? "" : {
                                            "done": I18n.t("отправлено ✓", "sent ✓"),
                                            "declined": I18n.t("отказались", "declined"),
                                            "busy": I18n.t("занято", "busy"),
                                            "pin": I18n.t("нужен PIN", "needs a PIN"),
                                            "cancelled": I18n.t("отменено", "cancelled"),
                                            "error": I18n.t("не вышло", "failed")
                                        }[dev.job.state] || ""
                                    }
                                    PxText {
                                        visible: dev.active
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        kind: "tiny"
                                        dim: true
                                        text: dev.job && dev.job.state === "waiting" ? I18n.t("ждём ответа…", "waiting…") : I18n.t("нажмите — отменить", "click to cancel")
                                    }
                                }
                            }
                        }
                    }

                    // by address, when the network keeps multicast out (guest Wi-Fi, a VPN)
                    Row {
                        width: parent.width
                        spacing: win.u * 2
                        PxField {
                            id: addr
                            width: parent.width - addBtn.width - win.u * 2
                            icon: "wifi"
                            placeholder: I18n.t("не видно? адрес устройства, напр. 192.168.1.20", "not there? the device's address, e.g. 192.168.1.20")
                            onAccepted: if (QuickShare.addAddress(text))
                                text = ""
                        }
                        PxButton {
                            id: addBtn
                            text: I18n.t("Найти", "Find")
                            onClicked: if (QuickShare.addAddress(addr.text))
                                addr.text = ""
                        }
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: I18n.t("Вас видят как «" + QuickShare.alias + "»" + (QuickShare.myIp ? " · " + QuickShare.myIp : "") + ". ПКМ по устройству — доверять (его файлы без вопроса).", "Others see you as “" + QuickShare.alias + "”" + (QuickShare.myIp ? " · " + QuickShare.myIp : "") + ". Right-click a device to trust it (no question for its files).") + (QuickShare.ready && !QuickShare.receiving && Config.quickshare.receive !== "off" ? I18n.t(" Принимать сейчас не могу: порт занят (открыто приложение LocalSend?).", " Can't receive right now: the port is taken (is the LocalSend app open?).") : "")
                    }
                }
            }
            RightClickGuard {}
        }
    }
}
