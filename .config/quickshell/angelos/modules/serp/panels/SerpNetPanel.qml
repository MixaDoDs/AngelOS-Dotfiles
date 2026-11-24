pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.services
import qs.modules.serp

// serp-skin: Serpantinum's network popup re-made for angelOS (services/Wifi through
// NetworkManager, services/Bt through BlueZ). Its signature orbit — this PC in the middle, the
// networks / devices circling it on tilted rings (the strongest closest), the connected one tied
// by a line of the accent — next to a plain list one can scan; a node or a row picks one and the
// card under them tells about it and does the work: connect (the password right there), cut,
// forget; on Bluetooth: power, search, pair, connect, forget, the battery, the pairing question.
Item {
    id: root
    property string screenName: ""
    property real progress: 1
    property string tab: "wifi"          // wifi | bt (bluetooth)
    readonly property bool isBt: tab === "bt" || tab === "bluetooth"

    implicitWidth: Serp.px(720)
    implicitHeight: Serp.px(560)

    function st(d) {
        return Math.max(0, Math.min(1, (progress - d) / Math.max(0.01, 1 - d)));
    }
    function ease(t) {
        return 1 - Math.pow(1 - t, 3);
    }
    readonly property int pad: Serp.px(16)
    readonly property bool shown: visible && progress > 0

    // ---- fresh scans while we are seen: Wifi.scanners / Bt.users (also runs the pairing agent) ----
    property bool heldWifi: false
    property bool heldBt: false
    function hold() {
        const w = shown && !isBt, b = shown && isBt;
        if (w !== heldWifi) {
            Wifi.scanners += w ? 1 : -1;
            heldWifi = w;
        }
        if (b !== heldBt) {
            Bt.users += b ? 1 : -1;
            heldBt = b;
        }
    }
    onShownChanged: hold()
    onIsBtChanged: hold()
    Component.onCompleted: hold()
    Component.onDestruction: {
        if (heldWifi)
            Wifi.scanners--;
        if (heldBt)
            Bt.users--;
    }

    // ---- what is picked ----
    property var selWifi: null
    property var selBt: null
    readonly property var curWifi: selWifi && Wifi.networks.indexOf(selWifi) >= 0 ? selWifi : Wifi.enabled ? Wifi.connected : null
    readonly property var curBt: selBt && Bt.devices.indexOf(selBt) >= 0 ? selBt : Bt.enabled ? (Bt.connectedDevices[0] || null) : null
    onCurWifiChanged: pw.text = ""

    // ---- helpers ----
    function wifiIcon(s) {
        const b = Wifi.bars(s);
        return b >= 3 ? "wifi" : b === 2 ? "wifi-low" : "wifi-zero";
    }
    function btIcon(d) {
        return ({
                "music": "music",
                "monitor": "monitor",
                "keyboard": "keyboard",
                "mouse": "mouse-pointer-2",
                "gamepad": "gamepad-2"
            })[Bt.iconFor(d)] || "bluetooth";
    }
    function btName(d) {
        return d ? (d.name || d.deviceName || d.address || "") : "";
    }
    function btBusy(d) {
        return !!d && (d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting);
    }
    function btBattery(d) {
        return d && d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "";
    }
    function freq(n) {
        const f = n ? n.frequency : undefined;
        if (typeof f !== "number" || f <= 0)
            return "";
        return f >= 5925 ? "6 ГГц" : f >= 4900 ? "5 ГГц" : "2.4 ГГц";
    }
    function security(n) {
        if (!n)
            return "";
        if (!Wifi.secured(n))
            return "открытая";
        const s = Wifi.securityName(n);
        return s && s !== "Unknown" ? s : "защищена";
    }
    // spread each ring's satellites evenly, in a stable (by name) order; a full ring spills outward
    function layout(items) {
        const caps = [6, 9, 14];
        const rings = [[], [], []];
        items.forEach(it => {
            let r = it.ring;
            while (r < 2 && rings[r].length >= caps[r])
                r++;
            if (rings[r].length < caps[r] || r < 2) {
                it.ring = r;
                rings[r].push(it);
            }
        });
        const out = [];
        rings.forEach((arr, r) => {
            arr.sort((a, b) => String(a.key).localeCompare(String(b.key)));
            arr.forEach((it, i) => {
                it.angle = i / arr.length * Math.PI * 2 + r * 0.9 + 0.35;
                out.push(it);
            });
        });
        return out;
    }
    readonly property var wifiItems: {
        if (!Wifi.enabled)
            return [];
        return layout(Wifi.networks.slice(0, 24).map(n => {
            const b = Wifi.bars(n.signalStrength);
            return {
                "key": n.name,
                "obj": n,
                "ring": n.connected || b >= 3 ? 0 : b === 2 ? 1 : 2,
                "angle": 0,
                "icon": wifiIcon(n.signalStrength),
                "label": n.name,
                "connected": n.connected,
                "locked": Wifi.secured(n),
                "busy": Wifi.pending === n.name
            };
        }));
    }
    readonly property var btItems: {
        if (!Bt.enabled)
            return [];
        return layout(Bt.paired.concat(Bt.nearby).slice(0, 24).map(d => ({
                    "key": d.address || btName(d),
                    "obj": d,
                    "ring": d.connected ? 0 : (d.paired || d.bonded) ? 1 : 2,
                    "angle": 0,
                    "icon": btIcon(d),
                    "label": btName(d),
                    "connected": d.connected,
                    "locked": false,
                    "busy": btBusy(d)
                })));
    }

    // ---- the card ----
    Rectangle {
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, 24)
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }

    // ---- header: what we are + the Wi-Fi | Bluetooth switch ----
    Item {
        id: head
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        height: Serp.px(36)
        opacity: root.ease(root.st(0))
        transform: Translate {
            y: (1 - root.ease(root.st(0))) * -Serp.px(10)
        }
        Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(34)
            height: width
            radius: width / 2
            color: Serp.selected
            SIcon {
                anchors.centerIn: parent
                name: root.isBt ? "bluetooth" : "network"
                size: Serp.px(17)
                color: Serp.accent
            }
        }
        Column {
            anchors.left: badge.right
            anchors.leftMargin: Serp.px(10)
            anchors.right: seg.left
            anchors.rightMargin: Serp.px(10)
            anchors.verticalCenter: parent.verticalCenter
            SText {
                width: parent.width
                text: root.isBt ? "Bluetooth" : "Сеть"
                size: Serp.px(15)
                black: true
            }
            SText {
                width: parent.width
                size: Serp.px(10.5)
                dim: true
                text: {
                    if (root.isBt) {
                        if (!Bt.available)
                            return "адаптера нет";
                        if (!Bt.enabled)
                            return "выключен";
                        const c = Bt.connectedDevices.length;
                        return (c ? "подключено: " + c : "ничего не подключено") + (Bt.discovering ? " · поиск…" : "");
                    }
                    if (!Wifi.available)
                        return "NetworkManager не работает";
                    const wired = Wifi.wiredDevice && Wifi.wiredDevice.hasLink;
                    return (Wifi.connected ? Wifi.connected.name + " · " : wired ? "кабель · " : "") + Wifi.connectivityText;
                }
            }
        }
        // Wi-Fi | Bluetooth
        Rectangle {
            id: seg
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(236)
            height: Serp.px(32)
            radius: height / 2
            color: Serp.surface0
            border.width: 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            Rectangle {
                x: Serp.px(3) + (root.isBt ? (seg.width - Serp.px(6)) / 2 : 0)
                y: Serp.px(3)
                width: (seg.width - Serp.px(6)) / 2
                height: seg.height - Serp.px(6)
                radius: height / 2
                color: Serp.accent
                Behavior on x {
                    NumberAnimation {
                        duration: Serp.slow
                        easing.type: Easing.OutQuint
                    }
                }
            }
            Row {
                anchors.fill: parent
                anchors.margins: Serp.px(3)
                Repeater {
                    model: [
                        {
                            "id": "wifi",
                            "icon": "wifi",
                            "label": "Wi-Fi"
                        },
                        {
                            "id": "bt",
                            "icon": "bluetooth",
                            "label": "Bluetooth"
                        }
                    ]
                    Item {
                        id: segItem
                        required property var modelData
                        readonly property bool on: (modelData.id === "bt") === root.isBt
                        width: (seg.width - Serp.px(6)) / 2
                        height: parent.height
                        Row {
                            anchors.centerIn: parent
                            spacing: Serp.px(6)
                            SIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: segItem.modelData.icon
                                size: Serp.px(14)
                                color: segItem.on ? Serp.onAccent : segMa.containsMouse ? Serp.text : Serp.subtext0
                            }
                            SText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: segItem.modelData.label
                                size: Serp.px(11.5)
                                bold: true
                                color: segItem.on ? Serp.onAccent : segMa.containsMouse ? Serp.text : Serp.subtext0
                            }
                        }
                        MouseArea {
                            id: segMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = segItem.modelData.id
                        }
                    }
                }
            }
        }
    }

    // ---- controls: power, the cable, search ----
    Item {
        id: ctl
        x: root.pad
        y: head.y + head.height + Serp.px(10)
        width: parent.width - root.pad * 2
        height: Serp.px(32)
        opacity: root.ease(root.st(0.08))
        SToggle {
            id: power
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.isBt ? Bt.available : Wifi.available && Wifi.hasWifi
            opacity: enabled ? 1 : 0.4
            checked: root.isBt ? Bt.enabled : Wifi.enabled
            onToggled: on => {
                if (root.isBt)
                    Bt.setEnabled(on);
                else
                    Wifi.setEnabled(on);
            }
        }
        SText {
            id: powerLabel
            anchors.left: power.right
            anchors.leftMargin: Serp.px(10)
            anchors.verticalCenter: parent.verticalCenter
            text: root.isBt ? (Bt.enabled ? "Bluetooth включён" : "Bluetooth выключен") : (Wifi.enabled ? "Wi-Fi включён" : "Wi-Fi выключен")
            size: Serp.px(12)
            bold: true
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Serp.px(8)
            // the cable, when there is one
            Rectangle {
                visible: !root.isBt && !!Wifi.wiredDevice && Wifi.wiredDevice.hasLink
                anchors.verticalCenter: parent.verticalCenter
                width: wiredRow.implicitWidth + Serp.px(18)
                height: Serp.px(26)
                radius: height / 2
                color: Qt.alpha(Serp.green, 0.12)
                Row {
                    id: wiredRow
                    anchors.centerIn: parent
                    spacing: Serp.px(5)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "ethernet-port"
                        size: Serp.px(13)
                        color: Serp.green
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Кабель"
                        size: Serp.px(10.5)
                        bold: true
                        color: Serp.green
                    }
                }
            }
            SText {
                visible: !root.isBt && Wifi.enabled
                anchors.verticalCenter: parent.verticalCenter
                text: "сетей: " + Wifi.networks.length
                size: Serp.px(10.5)
                dim: true
            }
            SerpNetAction {
                visible: root.isBt
                enabled: Bt.enabled
                anchors.verticalCenter: parent.verticalCenter
                text: Bt.discovering ? "Стоп" : "Поиск"
                icon: "search"
                busy: Bt.discovering
                kind: Bt.discovering ? "accent" : "plain"
                onClicked: Bt.scan(!Bt.discovering)
            }
        }
    }

    // ---- the body: the orbit and the list ----
    readonly property int cardH: Serp.px(150)
    Item {
        id: body
        x: root.pad
        y: ctl.y + ctl.height + Serp.px(10)
        width: parent.width - root.pad * 2
        height: parent.height - y - root.cardH - root.pad - Serp.px(12)

        Rectangle {
            id: orbitBox
            width: parent.width - listBox.width - Serp.px(12)
            height: parent.height
            radius: Serp.radius
            color: Qt.alpha(Serp.crust, 0.35)
            border.width: 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            clip: true
            opacity: root.ease(root.st(0.05))
            SerpNetOrbit {
                anchors.fill: parent
                intro: root.st(0.1)
                running: root.shown
                off: root.isBt ? !Bt.enabled : !Wifi.enabled
                model: root.isBt ? root.btItems : root.wifiItems
                selected: root.isBt ? root.curBt : root.curWifi
                centerIcon: root.isBt ? "bluetooth" : (!Wifi.available || !Wifi.hasWifi || !Wifi.enabled) ? "wifi-off" : "monitor"
                centerLabel: "Этот ПК"
                centerSub: {
                    if (root.isBt)
                        return !Bt.available ? "нет адаптера" : !Bt.enabled ? "выключен" : Bt.discovering ? "ищу устройства…" : Bt.connectedDevices.length ? "подключено: " + Bt.connectedDevices.length : "ничего не подключено";
                    return !Wifi.available ? "NetworkManager выключен" : !Wifi.hasWifi ? "нет Wi-Fi адаптера" : !Wifi.enabled ? "Wi-Fi выключен" : Wifi.pending !== "" ? "подключаюсь…" : Wifi.connected ? Wifi.connected.name : "не подключено";
                }
                live: root.isBt ? Bt.enabled && Bt.connectedDevices.length > 0 : Wifi.enabled && !!Wifi.connected
                pulsing: root.isBt ? Bt.discovering : Wifi.enabled && (Wifi.pending !== "" || !Wifi.connected)
                onPicked: o => {
                    if (root.isBt)
                        root.selBt = o;
                    else
                        root.selWifi = o;
                }
                onCoreClicked: {
                    if (root.isBt)
                        root.selBt = null;
                    else
                        root.selWifi = null;
                }
            }
        }

        Rectangle {
            id: listBox
            anchors.right: parent.right
            width: Serp.px(258)
            height: parent.height
            radius: Serp.radius
            color: Serp.surface0
            border.width: 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            opacity: root.ease(root.st(0.2))
            transform: Translate {
                x: (1 - root.ease(root.st(0.2))) * Serp.px(16)
            }
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: Serp.px(5)
                contentHeight: listCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: listCol
                    width: flick.width
                    spacing: Serp.px(2)

                    // Wi-Fi
                    Repeater {
                        model: !root.isBt && Wifi.enabled ? Wifi.networks : []
                        SerpNetRow {
                            id: wrow
                            required property var modelData
                            required property int index
                            width: listCol.width
                            intro: root.ease(root.st(0.25 + Math.min(index, 8) * 0.04))
                            icon: root.wifiIcon(modelData.signalStrength)
                            name: modelData.name
                            sub: Math.round(modelData.signalStrength * 100) + "%" + (modelData.connected ? " · подключено" : modelData.known ? " · сохранена" : "")
                            connected: modelData.connected
                            locked: Wifi.secured(modelData)
                            busy: Wifi.pending === modelData.name
                            selected: root.curWifi === modelData
                            onClicked: root.selWifi = modelData
                        }
                    }

                    // Bluetooth: paired first, then what is around
                    SText {
                        visible: root.isBt && Bt.enabled && Bt.paired.length > 0
                        x: Serp.px(8)
                        height: Serp.px(24)
                        text: "СОПРЯЖЁННЫЕ"
                        size: Serp.px(9.5)
                        bold: true
                        dim: true
                    }
                    Repeater {
                        model: root.isBt && Bt.enabled ? Bt.paired : []
                        SerpNetRow {
                            required property var modelData
                            required property int index
                            width: listCol.width
                            intro: root.ease(root.st(0.25 + Math.min(index, 8) * 0.04))
                            icon: root.btIcon(modelData)
                            name: root.btName(modelData)
                            sub: modelData.pairing ? "сопрягаю…" : modelData.state === BluetoothDeviceState.Connecting ? "подключаюсь…" : modelData.connected ? "подключено" : "сопряжено"
                            badge: root.btBattery(modelData)
                            connected: modelData.connected
                            busy: root.btBusy(modelData)
                            selected: root.curBt === modelData
                            onClicked: root.selBt = modelData
                        }
                    }
                    SText {
                        visible: root.isBt && Bt.enabled && Bt.nearby.length > 0
                        x: Serp.px(8)
                        height: Serp.px(24)
                        text: "РЯДОМ"
                        size: Serp.px(9.5)
                        bold: true
                        dim: true
                    }
                    Repeater {
                        model: root.isBt && Bt.enabled ? Bt.nearby : []
                        SerpNetRow {
                            required property var modelData
                            required property int index
                            width: listCol.width
                            intro: root.ease(root.st(0.3 + Math.min(index, 8) * 0.04))
                            icon: root.btIcon(modelData)
                            name: root.btName(modelData)
                            sub: modelData.pairing ? "сопрягаю…" : modelData.address || ""
                            badge: root.btBattery(modelData)
                            busy: root.btBusy(modelData)
                            selected: root.curBt === modelData
                            onClicked: root.selBt = modelData
                        }
                    }
                }
            }
            // empty / off
            Column {
                anchors.centerIn: parent
                width: parent.width - Serp.px(30)
                spacing: Serp.px(6)
                visible: listCol.implicitHeight < Serp.px(10)
                SIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.isBt ? "bluetooth" : "wifi-off"
                    size: Serp.px(22)
                    color: Serp.overlay
                }
                SText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    size: Serp.px(11)
                    dim: true
                    text: root.isBt ? (!Bt.available ? "Bluetooth-адаптер не найден" : !Bt.enabled ? "Bluetooth выключен" : Bt.discovering ? "Ищу устройства…" : "Устройств нет. Нажмите «Поиск».") : (!Wifi.available ? "NetworkManager не работает" : !Wifi.hasWifi ? "Wi-Fi адаптер не найден" : !Wifi.enabled ? "Wi-Fi выключен" : "Ищу сети…")
                }
            }
        }
    }

    // ---- the info card ----
    Rectangle {
        id: card
        x: root.pad
        y: parent.height - root.pad - height
        width: parent.width - root.pad * 2
        height: root.cardH
        radius: Serp.radius
        color: Serp.surface0
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        opacity: root.ease(root.st(0.35))
        transform: Translate {
            y: (1 - root.ease(root.st(0.35))) * Serp.px(16)
        }

        readonly property var n: root.curWifi
        readonly property var d: root.curBt
        readonly property var req: Bt.request

        // the big icon
        Rectangle {
            id: bigIco
            x: Serp.px(16)
            y: Serp.px(16)
            width: Serp.px(52)
            height: width
            radius: width / 2
            readonly property bool lit: root.isBt ? !!card.d && card.d.connected : !!card.n && card.n.connected
            color: lit ? Serp.accent : Serp.surface1
            border.width: 1
            border.color: lit ? Qt.lighter(Serp.accent, 1.2) : Serp.line
            Behavior on color {
                ColorAnimation {
                    duration: Serp.normal
                }
            }
            SIcon {
                anchors.centerIn: parent
                name: root.isBt ? (card.req ? "key-round" : card.d ? root.btIcon(card.d) : "bluetooth") : card.n ? root.wifiIcon(card.n.signalStrength) : "wifi-off"
                size: Serp.px(24)
                color: bigIco.lit ? Serp.onAccent : Serp.subtext1
            }
        }
        // signal bars under it
        Row {
            visible: !root.isBt && !!card.n
            anchors.horizontalCenter: bigIco.horizontalCenter
            y: bigIco.y + bigIco.height + Serp.px(10)
            spacing: Serp.px(3)
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: Serp.px(5)
                    height: Serp.px(5 + index * 4)
                    radius: Serp.px(2)
                    color: card.n && Wifi.bars(card.n.signalStrength) > index ? Serp.accent : Serp.surface2
                }
            }
        }

        Item {
            id: info
            anchors.left: bigIco.right
            anchors.leftMargin: Serp.px(14)
            anchors.right: parent.right
            anchors.rightMargin: Serp.px(16)
            y: Serp.px(14)
            height: parent.height - Serp.px(28)

            // ===== Wi-Fi =====
            Item {
                anchors.fill: parent
                visible: !root.isBt
                Column {
                    width: parent.width
                    spacing: Serp.px(4)
                    SText {
                        width: parent.width
                        text: card.n ? card.n.name : !Wifi.available ? "NetworkManager не работает" : !Wifi.hasWifi ? "Нет Wi-Fi адаптера" : !Wifi.enabled ? "Wi-Fi выключен" : "Сеть не выбрана"
                        size: Serp.px(15)
                        black: true
                    }
                    // chips: signal, security, band, saved
                    Row {
                        visible: !!card.n
                        spacing: Serp.px(6)
                        Repeater {
                            model: card.n ? [
                                {
                                    "icon": "activity",
                                    "text": "сигнал " + Math.round(card.n.signalStrength * 100) + "%"
                                },
                                {
                                    "icon": Wifi.secured(card.n) ? "lock" : "globe",
                                    "text": root.security(card.n)
                                },
                                {
                                    "icon": "zap",
                                    "text": root.freq(card.n)
                                },
                                {
                                    "icon": "star",
                                    "text": card.n.known ? "сохранена" : ""
                                }
                            ].filter(c => c.text !== "") : []
                            Rectangle {
                                id: chip
                                required property var modelData
                                width: chipRow.implicitWidth + Serp.px(14)
                                height: Serp.px(22)
                                radius: height / 2
                                color: Serp.surface1
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: Serp.px(4)
                                    SIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: chip.modelData.icon
                                        size: Serp.px(11)
                                        color: Serp.subtext0
                                    }
                                    SText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: chip.modelData.text
                                        size: Serp.px(10)
                                        color: Serp.subtext1
                                    }
                                }
                            }
                        }
                    }
                    SText {
                        width: parent.width
                        size: Serp.px(10.5)
                        readonly property bool err: Wifi.lastError !== "" && (!card.n || Wifi.lastError.indexOf(card.n.name + ":") === 0)
                        color: err ? Serp.red : card.n && card.n.connected ? Serp.green : Serp.subtext0
                        text: {
                            if (err)
                                return Wifi.lastError;
                            if (!card.n)
                                return !Wifi.available ? (Wifi.serviceInstalled ? "Служба установлена, но не запущена" : "NetworkManager не установлен") : Wifi.enabled ? "Выберите сеть на орбите или в списке" : "Включите Wi-Fi переключателем выше";
                            if (Wifi.pending === card.n.name)
                                return "Подключаюсь…";
                            if (card.n.connected)
                                return "Подключено · " + Wifi.connectivityText;
                            return Wifi.needsPassword(card.n) ? "Нужен пароль" : card.n.known ? "Сеть сохранена, подключусь без пароля" : "Открытая сеть";
                        }
                    }
                }
                // actions (and the password)
                Row {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    spacing: Serp.px(8)
                    Rectangle {
                        id: pwBox
                        visible: !!card.n && !card.n.connected && Wifi.needsPassword(card.n)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Serp.px(220)
                        height: Serp.px(30)
                        radius: height / 2
                        color: Serp.base
                        border.width: 1
                        border.color: pw.activeFocus ? Qt.alpha(Serp.accent, 0.6) : Serp.line
                        property bool reveal: false
                        SIcon {
                            id: keyIco
                            x: Serp.px(10)
                            anchors.verticalCenter: parent.verticalCenter
                            name: "key-round"
                            size: Serp.px(13)
                            color: Serp.subtext0
                        }
                        TextInput {
                            id: pw
                            anchors.left: keyIco.right
                            anchors.leftMargin: Serp.px(8)
                            anchors.right: eye.left
                            anchors.rightMargin: Serp.px(6)
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            color: Serp.text
                            selectionColor: Serp.selected
                            selectedTextColor: Serp.text
                            font.family: Serp.font
                            font.pixelSize: Serp.px(12)
                            echoMode: pwBox.reveal ? TextInput.Normal : TextInput.Password
                            onAccepted: if (card.n && text !== "")
                                Wifi.connect(card.n, text)
                            SText {
                                visible: pw.text === "" && !pw.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Пароль"
                                size: Serp.px(11.5)
                                color: Serp.overlay
                            }
                        }
                        MouseArea {
                            anchors.fill: pw
                            cursorShape: Qt.IBeamCursor
                            onClicked: pw.forceActiveFocus()
                        }
                        SIcon {
                            id: eye
                            anchors.right: parent.right
                            anchors.rightMargin: Serp.px(10)
                            anchors.verticalCenter: parent.verticalCenter
                            name: "eye"
                            size: Serp.px(13)
                            color: pwBox.reveal ? Serp.accent : Serp.subtext0
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Serp.px(6)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pwBox.reveal = !pwBox.reveal
                            }
                        }
                    }
                    SerpNetAction {
                        visible: !Wifi.available && Wifi.serviceInstalled
                        text: "Запустить"
                        icon: "power"
                        kind: "accent"
                        onClicked: Wifi.startService()
                    }
                    SerpNetAction {
                        visible: !!card.n && card.n.known
                        text: "Забыть"
                        icon: "trash-2"
                        kind: "danger"
                        onClicked: {
                            Wifi.forget(card.n);
                            root.selWifi = null;
                        }
                    }
                    SerpNetAction {
                        visible: !!card.n && card.n.connected
                        text: "Отключить"
                        icon: "x"
                        onClicked: Wifi.disconnect(card.n)
                    }
                    SerpNetAction {
                        visible: !!card.n && !card.n.connected
                        enabled: !pwBox.visible || pw.text.length >= 8
                        text: "Подключить"
                        icon: "plug"
                        kind: "accent"
                        busy: !!card.n && Wifi.pending === card.n.name
                        onClicked: Wifi.connect(card.n, pwBox.visible ? pw.text : undefined)
                    }
                }
            }

            // ===== Bluetooth =====
            Item {
                anchors.fill: parent
                visible: root.isBt
                // the pairing question from the agent wins the card
                Column {
                    visible: !!card.req
                    width: parent.width
                    spacing: Serp.px(4)
                    readonly property var r: card.req || ({})
                    SText {
                        width: parent.width
                        size: Serp.px(14)
                        black: true
                        text: parent.r.kind === "confirm" ? "Совпадает код на «" + parent.r.device + "»?" : parent.r.kind === "display" ? "Введите код на «" + parent.r.device + "»" : parent.r.kind === "authorize" ? "Пустить «" + parent.r.device + "»?" : "PIN для «" + parent.r.device + "»"
                    }
                    SText {
                        visible: !!parent.r.passkey
                        text: parent.r.passkey || ""
                        size: Serp.px(24)
                        black: true
                        color: Serp.accent
                        font.letterSpacing: Serp.px(4)
                    }
                }
                Column {
                    visible: !card.req
                    width: parent.width
                    spacing: Serp.px(4)
                    SText {
                        width: parent.width
                        text: card.d ? root.btName(card.d) : !Bt.available ? "Нет Bluetooth-адаптера" : !Bt.enabled ? "Bluetooth выключен" : "Устройство не выбрано"
                        size: Serp.px(15)
                        black: true
                    }
                    Row {
                        visible: !!card.d
                        spacing: Serp.px(6)
                        Repeater {
                            model: card.d ? [
                                {
                                    "icon": card.d.connected ? "check" : "bluetooth",
                                    "text": card.d.connected ? "подключено" : (card.d.paired || card.d.bonded) ? "сопряжено" : "рядом"
                                },
                                {
                                    "icon": "battery",
                                    "text": root.btBattery(card.d)
                                },
                                {
                                    "icon": "info",
                                    "text": card.d.address || ""
                                }
                            ].filter(c => c.text !== "") : []
                            Rectangle {
                                id: bchip
                                required property var modelData
                                width: bchipRow.implicitWidth + Serp.px(14)
                                height: Serp.px(22)
                                radius: height / 2
                                color: Serp.surface1
                                Row {
                                    id: bchipRow
                                    anchors.centerIn: parent
                                    spacing: Serp.px(4)
                                    SIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: bchip.modelData.icon
                                        size: Serp.px(11)
                                        color: Serp.subtext0
                                    }
                                    SText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: bchip.modelData.text
                                        size: Serp.px(10)
                                        color: Serp.subtext1
                                    }
                                }
                            }
                        }
                    }
                    SText {
                        width: parent.width
                        size: Serp.px(10.5)
                        color: Bt.lastError !== "" ? Serp.red : card.d && card.d.connected ? Serp.green : Serp.subtext0
                        text: {
                            if (Bt.lastError !== "")
                                return Bt.lastError;
                            const d = card.d;
                            if (!d)
                                return !Bt.available ? (Bt.serviceInstalled && !Bt.serviceActive ? "Служба bluetooth не запущена" : "Адаптер не найден") : Bt.enabled ? "Выберите устройство или нажмите «Поиск»" : "Включите Bluetooth переключателем выше";
                            if (d.pairing)
                                return "Сопрягаю…";
                            if (d.state === BluetoothDeviceState.Connecting)
                                return "Подключаюсь…";
                            if (d.state === BluetoothDeviceState.Disconnecting)
                                return "Отключаюсь…";
                            return d.connected ? "Подключено" : (d.paired || d.bonded) ? "Сопряжено, не подключено" : "Новое устройство: сначала сопрягите";
                        }
                    }
                }
                Row {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    spacing: Serp.px(8)
                    // the pairing answer
                    Rectangle {
                        id: pinBox
                        visible: !!card.req && (card.req.kind === "pin" || card.req.kind === "passkey")
                        anchors.verticalCenter: parent.verticalCenter
                        width: Serp.px(140)
                        height: Serp.px(30)
                        radius: height / 2
                        color: Serp.base
                        border.width: 1
                        border.color: pin.activeFocus ? Qt.alpha(Serp.accent, 0.6) : Serp.line
                        TextInput {
                            id: pin
                            anchors.fill: parent
                            anchors.leftMargin: Serp.px(12)
                            anchors.rightMargin: Serp.px(12)
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: Serp.text
                            font.family: Serp.font
                            font.pixelSize: Serp.px(12)
                            onAccepted: {
                                Bt.answer(true, text);
                                text = "";
                            }
                            SText {
                                visible: pin.text === "" && !pin.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PIN"
                                size: Serp.px(11.5)
                                color: Serp.overlay
                            }
                        }
                    }
                    SerpNetAction {
                        visible: !!card.req && card.req.kind !== "display"
                        text: "Да"
                        icon: "check"
                        kind: "accent"
                        onClicked: {
                            Bt.answer(true, pin.text);
                            pin.text = "";
                        }
                    }
                    SerpNetAction {
                        visible: !!card.req
                        text: !!card.req && card.req.kind === "display" ? "OK" : "Нет"
                        onClicked: Bt.answer(false)
                    }
                    // the device's actions
                    SerpNetAction {
                        visible: !card.req && !Bt.available && Bt.serviceInstalled && !Bt.serviceActive
                        text: "Запустить службу"
                        icon: "power"
                        kind: "accent"
                        onClicked: Bt.startService()
                    }
                    SerpNetAction {
                        visible: !card.req && !!card.d && (card.d.paired || card.d.bonded)
                        text: "Забыть"
                        icon: "trash-2"
                        kind: "danger"
                        onClicked: {
                            Bt.forget(card.d);
                            root.selBt = null;
                        }
                    }
                    SerpNetAction {
                        visible: !card.req && !!card.d && (card.d.paired || card.d.bonded)
                        enabled: !root.btBusy(card.d)
                        text: card.d && card.d.connected ? "Отключить" : "Подключить"
                        icon: card.d && card.d.connected ? "x" : "plug"
                        kind: card.d && card.d.connected ? "plain" : "accent"
                        busy: !!card.d && card.d.state === BluetoothDeviceState.Connecting
                        onClicked: Bt.toggleConnect(card.d)
                    }
                    SerpNetAction {
                        visible: !card.req && !!card.d && !card.d.paired && !card.d.bonded
                        enabled: !!card.d && !card.d.pairing
                        text: "Сопрячь"
                        icon: "plus"
                        kind: "accent"
                        busy: !!card.d && card.d.pairing
                        onClicked: Bt.pair(card.d)
                    }
                }
            }
        }
    }

    // swallow clicks
    MouseArea {
        anchors.fill: parent
        z: -1
    }
}
