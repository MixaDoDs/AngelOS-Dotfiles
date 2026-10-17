pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// Quick Share's window (services/QuickShare; ShareSheet hosts it in a window of its own, AirDrop-
// like: it stays beside the file manager, files are dragged into it, it can sit on another
// workspace). What goes on top — files dropped anywhere on the window or picked, each with its ×;
// the devices nearby on a pixel radar round this computer, a click on one sends (the window stays:
// the next device, the next files); a device by its address under it.
Item {
    id: view

    property var host: null                  // the window (its title bar moves it)
    readonly property int u: Theme.u
    readonly property var payload: QuickShare.payload
    readonly property bool hasText: QuickShare.payloadText !== "" && !payload.length
    readonly property bool something: payload.length > 0 || QuickShare.payloadText !== ""

    function add(paths) {
        const fresh = paths.filter(p => p && p.startsWith("/") && !QuickShare.payload.includes(p));
        if (fresh.length)
            QuickShare.payload = QuickShare.payload.concat(fresh);
        if (fresh.length)
            QuickShare.payloadText = "";
    }
    function pick() {
        if (!picker.running) {
            picker.command = ["python3", Quickshell.shellDir + "/scripts/pick-file.py", "--multi", "--remember", "quickshare", I18n.t("Что отправить", "What to send")];
            picker.running = true;
        }
    }
    Process {
        id: picker
        stdout: StdioCollector {
            onStreamFinished: view.add(text.split("\n").map(s => s.trim()))
        }
    }

    Shortcut {
        context: Qt.WindowShortcut
        sequence: "Escape"
        onActivated: QuickShare.close()
    }
    Shortcut {
        context: Qt.WindowShortcut
        sequences: ["Ctrl+O", "Ctrl+Щ"]
        onActivated: view.pick()
    }

    PxWindow {
        id: frame
        anchors.fill: parent
        anchors.rightMargin: view.u * 2
        anchors.bottomMargin: view.u * 2
        skin: ""
        translucent: false
        title: I18n.exe(I18n.t("отправить_рядом", "quick_share"))
        icon: "plane"
        onCloseClicked: QuickShare.close()
        onTitlePressed: if (view.host)
            view.host.startSystemMove()

        Item {
            id: body
            readonly property string settingsSkin: "classic"
            width: parent.width
            height: parent.height

            // ---- what goes
            Item {
                id: whatHead
                width: parent.width
                height: pickBtn.height
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.bold: true
                    text: !view.something ? I18n.t("Что отправить", "What to send") : view.hasText ? I18n.t("Текст", "Text") : I18n.t("Отправляю: ", "Sending: ") + view.payload.length
                }
                Row {
                    anchors.right: parent.right
                    spacing: view.u * 2
                    PxButton {
                        visible: view.something
                        compact: true
                        icon: "trash"
                        text: I18n.t("Очистить", "Clear")
                        onClicked: {
                            QuickShare.payload = [];
                            QuickShare.payloadText = "";
                        }
                    }
                    PxButton {
                        id: pickBtn
                        compact: true
                        accent: !view.something
                        icon: "folder"
                        text: I18n.t("Выбрать файлы…", "Pick files…")
                        onClicked: view.pick()
                    }
                }
            }
            PxBox {
                id: whatBox
                anchors.top: whatHead.bottom
                anchors.topMargin: view.u * 2
                width: parent.width
                // grows with what goes, up to a third of the window (then it scrolls)
                height: Math.min(body.height / 3, Math.max(view.u * 30, list.contentHeight + view.u * 6))
                sunken: true
                color: Theme.sunken
                PxText {
                    visible: !view.something
                    anchors.centerIn: parent
                    width: parent.width - view.u * 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    dim: true
                    text: I18n.t("Перетащите сюда файлы или папку — прямо из файлового менеджера", "Drag files or a folder here, right from the file manager")
                }
                PxText {
                    visible: view.hasText
                    anchors.fill: parent
                    anchors.margins: view.u * 4
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    text: "«" + QuickShare.payloadText + "»"
                }
                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: view.u * 3
                    clip: true
                    spacing: view.u
                    model: view.payload
                    delegate: Item {
                        id: row
                        required property string modelData
                        width: ListView.view.width
                        height: rowName.implicitHeight + view.u * 3
                        readonly property string name: modelData.split("/").pop() || modelData
                        PxIcon {
                            id: rowIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(row.name) ? "image" : /\.(mp3|flac|ogg|wav|m4a|opus)$/i.test(row.name) ? "music" : /\.(mp4|mkv|webm|mov|avi)$/i.test(row.name) ? "play" : row.name.indexOf(".") < 0 ? "folder" : "document"
                        }
                        PxText {
                            id: rowName
                            anchors.left: rowIcon.right
                            anchors.leftMargin: view.u * 3
                            anchors.right: rowDel.left
                            anchors.rightMargin: view.u * 2
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: row.name + "   " + row.modelData.slice(0, row.modelData.length - row.name.length).replace(Config.home, "~")
                        }
                        PxButton {
                            id: rowDel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            compact: true
                            flat: true
                            icon: "close"
                            onClicked: QuickShare.payload = QuickShare.payload.filter(p => p !== row.modelData)
                        }
                    }
                }
            }

            // ---- the radar: this computer in the middle, the devices round it
            Item {
                id: radar
                anchors.top: whatBox.bottom
                anchors.topMargin: view.u * 4
                anchors.bottom: byAddr.top
                anchors.bottomMargin: view.u * 4
                width: parent.width
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
                    anchors.fill: parent
                    renderStrategy: Canvas.Cooperative
                    property real phase: radar.phase
                    onPhaseChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const g = view.u;
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
                    y: radar.cy - view.u * 8
                    spacing: view.u
                    PxIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "monitor"
                        pixel: view.u * 2
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
                    text: !QuickShare.wanted ? I18n.t("Отправка рядом выключена в настройках", "Quick Share is off in Settings") : !QuickShare.ready ? I18n.t("Запускаю…", "Starting…") : I18n.t("Ищу устройства с LocalSend или KDE Connect в этой сети…", "Looking for LocalSend or KDE Connect devices on this network…")
                }
                PxText {
                    visible: QuickShare.nearby.length > 0 && !view.something
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    kind: "tiny"
                    dim: true
                    text: I18n.t("Добавьте файлы сверху — потом нажмите на устройство", "Add files above, then click a device")
                }
                Repeater {
                    model: QuickShare.nearby
                    Item {
                        id: dev
                        required property var modelData
                        required property int index
                        readonly property int n: QuickShare.nearby.length
                        readonly property real ang: -Math.PI / 2 + index / Math.max(1, n) * 2 * Math.PI
                        readonly property real rad: Math.min(radar.width, radar.height) / 2 - view.u * 14
                        readonly property var job: QuickShare.jobFor(modelData.fp)
                        readonly property bool kdc: modelData.protocol === "kdeconnect"
                        readonly property bool active: !!job && (job.state === "waiting" || job.state === "sending" || job.state === "pairing")
                        width: view.u * 48
                        height: devCol.implicitHeight
                        x: radar.cx + Math.cos(ang) * rad * 1.5 - width / 2
                        y: radar.cy + Math.sin(ang) * rad - height / 2
                        Column {
                            id: devCol
                            width: parent.width
                            spacing: view.u
                            PxButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: dev.modelData.type === "mobile" ? "phone" : dev.modelData.type === "desktop" ? "monitor" : dev.modelData.type === "web" ? "window" : "laptop"
                                iconPixel: view.u * 2
                                accent: dev.active
                                enabled: view.something
                                onClicked: dev.active ? QuickShare.cancel(dev.job.job) : QuickShare.sendTo(dev.modelData.fp)
                                onRightClicked: if (!dev.kdc)
                                    QuickShare.trust(dev.modelData, !QuickShare.isTrusted(dev.modelData.fp))
                            }
                            PxText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                kind: "tiny"
                                text: (QuickShare.isTrusted(dev.modelData.fp) || dev.kdc && dev.modelData.paired ? "♥ " : "") + dev.modelData.alias
                            }
                            PxProgress {
                                visible: dev.active
                                width: parent.width
                                height: view.u * 4
                                showText: false
                                busy: !!dev.job && (dev.job.state === "waiting" || dev.job.state === "pairing")
                                value: dev.job && dev.job.total ? dev.job.done / dev.job.total : 0
                            }
                            PxText {
                                visible: !!dev.job || dev.kdc && !dev.modelData.paired
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                kind: "tiny"
                                dim: true
                                text: !dev.job ? I18n.t("KDE Connect: при отправке спросит на телефоне", "KDE Connect: asks on the phone first") : dev.job.state === "pairing" ? I18n.t("подтвердите на телефоне…", "confirm on the phone…") : dev.job.state === "error" && dev.job.msg === "offline" ? I18n.t("не на связи", "not reachable") : dev.active ? (dev.job.state === "waiting" ? I18n.t("ждём ответа…", "waiting…") : I18n.t("нажмите — отменить", "click to cancel")) : {
                                    "done": I18n.t("отправлено ✓", "sent ✓"),
                                    "declined": I18n.t("отказались", "declined"),
                                    "busy": I18n.t("занято", "busy"),
                                    "pin": I18n.t("нужен PIN", "needs a PIN"),
                                    "cancelled": I18n.t("отменено", "cancelled"),
                                    "error": I18n.t("не вышло", "failed")
                                }[dev.job.state] || ""
                            }
                        }
                    }
                }
            }

            // ---- by address, when the network keeps multicast out (guest Wi-Fi, a VPN)
            Column {
                id: byAddr
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: view.u * 2
                Row {
                    width: parent.width
                    spacing: view.u * 2
                    PxField {
                        id: addr
                        width: parent.width - addBtn.width - view.u * 2
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
                    text: I18n.t("Вас видят как «" + QuickShare.alias + "»" + (QuickShare.myIp ? " · " + QuickShare.myIp : "") + ". ПКМ по устройству — доверять (его файлы без вопроса). Файлы можно бросить и на Нимб.", "Others see you as “" + QuickShare.alias + "”" + (QuickShare.myIp ? " · " + QuickShare.myIp : "") + ". Right-click a device to trust it (no question for its files). Files can be dropped on the Halo too.") + (QuickShare.ready && !QuickShare.receiving && Config.quickshare.receive !== "off" ? I18n.t(" Принимать сейчас не могу: порт занят (открыто приложение LocalSend?).", " Can't receive right now: the port is taken (is the LocalSend app open?).") : "")
                }
            }
        }
    }

    // files dropped anywhere on the window join what goes
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: d => {
            view.add((d.urls || []).map(x => decodeURIComponent(String(x).replace(/^file:\/\//, ""))));
            d.accept();
        }
    }
    Rectangle {
        visible: drop.containsDrag
        anchors.fill: parent
        anchors.margins: view.u * 6
        color: Qt.alpha(Theme.accent, 0.16)
        border.width: Math.max(2, view.u)
        border.color: Theme.accent
        PxText {
            anchors.centerIn: parent
            font.bold: true
            text: I18n.t("Отпустите — добавлю", "Let go to add")
        }
    }
}
