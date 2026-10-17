pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.desktop
import qs.modules.desktop.widgets

// The phone's screen held upright (Phone): a phone of its own, not a settings panel. Programs
// on a stack, like an old mobile's menus:
//   home      the clock, the operator, missed calls and messages; ◀ messages, OK the menu,
//             ▶ contacts, the green key the call log, a digit starts dialling
//   menu      twelve programs on 1…9 * 0 # or the arrows: messages, contacts, calls, the
//             camera (selfies with her, the album), games (Snake, Heaven Raid), tunes (hers, the
//             composer), tuning, the magic ball, the torch, sound, system, on its side
//   dialler   a number; the green key calls it (PhoneLine.dial: her, the codes, a wrong number)
//   messages  the inbox, reading, writing by multi-tap («T9»: 2 = абвг…, 0 a space, # ru/en,
//             * capitals, ◀ erases) or straight from the keyboard
//   games     Snake (2 4 6 8, the walls wrap round like the 3310's) and Heaven Raid (PhoneRaid)
//   tunes     the ones she sent and yours; the green key makes one the ringtone; the composer
//             (PhoneComposer) writes new ones
//   a call    over everything while there is one (PhoneLine.call): who rings; then her lines
//             and your answers on 1 2 3
// Keys come from the keypad (PhoneKeys) and the keyboard (Phone): key(k), k one of 0…9 * #
// call end left right up down ok, or "t:" and a typed character.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property bool hell: phone.hell
    readonly property color ink: phone.screenInk
    readonly property color dimInk: phone.screenDim
    readonly property color trim: phone.trim

    // ---- the stack ----
    property var stack: [{
            "app": "home"
        }]
    readonly property var cur: stack[stack.length - 1]
    readonly property string app: cur.app
    function go(app, args) {
        stack = stack.concat([Object.assign({
                "app": app
            }, args || {})]);
    }
    function back() {
        if (stack.length > 1)
            stack = stack.slice(0, -1);
    }
    function home() {
        stack = [{
                "app": "home"
            }];
    }
    // the turned phone's sound page and the like are kept: leaf = ◀ ▶ (Phone.leaf)
    function leaf(step) {
        key(step < 0 ? "left" : "right");
    }

    readonly property bool inCall: !!PhoneLine.call
    function key(k) {
        if (inCall)
            return callView.key(k);
        const item = view.item;
        if (item && item.key && item.key(k))
            return true;
        if (k === "end") {
            if (stack.length > 1)
                back();
            return true;
        }
        return false;
    }
    // the lid shut: back home, the half-typed number gone
    Connections {
        target: Sidebar
        function onOpenChanged() {
            if (!Sidebar.open && !root.inCall)
                root.home();
        }
    }

    // ---- the status line: signal (the antenna), the operator's mood, the time ----
    Rectangle {
        id: status
        width: parent.width
        height: root.k * 9
        color: root.trim
        Row {
            x: root.k * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.k
            // the bars: two, more with the antenna pulled out
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: root.k
                    height: root.k * (2 + index * 1.5)
                    color: index < root.phone.bars ? "#ffffff" : Qt.alpha("#ffffff", 0.3)
                }
            }
            Item {
                width: root.k
                height: 1
            }
            PxIcon {
                visible: Config.notifications.dnd
                anchors.verticalCenter: parent.verticalCenter
                name: "bellOff"
                fill: "#ffffff"
                ink: Theme.mix(root.trim, "#000000", 0.55)
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.k * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.k * 2
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.time(root.phone.now, false)
                kind: "tiny"
                color: Theme.selectText
            }
            PhoneBattery {
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
            }
        }
    }
    // the phone's own words a moment (the battery low, full)
    property double noticeTill: 0
    Connections {
        target: PhoneLine
        function onNoticeAtChanged() {
            root.noticeTill = PhoneLine.noticeAt + 4000;
            noticeOff.restart();
        }
    }
    Timer {
        id: noticeOff
        interval: 4000
        onTriggered: root.noticeTill = 0
    }
    Rectangle {
        z: 20
        visible: root.noticeTill > 0
        anchors.centerIn: parent
        width: parent.width - root.k * 8
        height: noticeText.implicitHeight + root.k * 6
        color: root.trim
        border.width: root.k
        border.color: Theme.mix(root.trim, "#000000", 0.4)
        PxText {
            id: noticeText
            anchors.centerIn: parent
            width: parent.width - root.k * 4
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: PhoneLine.notice
            kind: "tiny"
            color: Theme.selectText
        }
    }

    // ---- what is on now ----
    Item {
        id: body
        x: root.k * 2
        y: status.height + root.k
        width: parent.width - root.k * 4
        height: foot.y - y - root.k
        clip: true
        Loader {
            id: view
            anchors.fill: parent
            visible: !root.inCall
            sourceComponent: ({
                    "home": homeApp,
                    "menu": menuApp,
                    "dial": dialApp,
                    "info": infoApp,
                    "contacts": contactsApp,
                    "log": logApp,
                    "inbox": inboxApp,
                    "read": readApp,
                    "reply": replyApp,
                    "write": writeApp,
                    "camera": cameraApp,
                    "games": gamesApp,
                    "raid": raidApp,
                    "tunes": tunesApp,
                    "tuning": tuningApp,
                    "ball": ballApp,
                    "sound": soundApp,
                    "system": systemApp,
                    "snake": snakeApp,
                    "composer": composerApp
                })[root.app] || homeApp
        }
        PhoneCall {
            id: callView
            anchors.fill: parent
            visible: root.inCall
            phone: root.phone
        }
    }

    // ---- the soft keys' words, or what the key under the pointer does ----
    readonly property var soft: inCall ? (PhoneLine.ringing && !PhoneLine.call.outgoing ? [root.phone.taco ? "↻" : I18n.t("Ответ", "Answer"), "", I18n.t("Сброс", "Decline")] : ["", "", I18n.t("Отбой", "End")]) : view.item && view.item.soft ? view.item.soft : ["", "", I18n.t("Назад", "Back")]
    Rectangle {
        id: foot
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.k * 9
        color: Qt.alpha(root.trim, 0.18)
        PxText {
            visible: root.phone.hint !== ""
            anchors.centerIn: parent
            width: parent.width - root.k * 4
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.phone.hint
            kind: "tiny"
            color: root.ink
        }
        Repeater {
            model: root.phone.hint === "" ? 3 : 0
            PxText {
                required property int index
                x: index === 0 ? root.k * 2 : index === 1 ? (foot.width - width) / 2 : foot.width - width - root.k * 2
                y: Math.round((foot.height - height) / 2)
                width: Math.min(implicitWidth, foot.width / 3 - root.k)
                elide: Text.ElideRight
                text: root.soft[index] || ""
                kind: "tiny"
                color: root.ink
            }
        }
    }

    // ---- a list with a cursor (contacts, calls, messages, menus) ----
    component Pick: ListView {
        id: pick
        property int at: 0
        clip: true
        interactive: false
        currentIndex: at
        highlightMoveDuration: 0
        onAtChanged: positionViewAtIndex(at, ListView.Contain)
        function move(step) {
            if (count)
                at = (at + step + count) % count;
        }
        function keyNav(k) {
            if (k === "left" || k === "up" || k === "2") {
                move(-1);
                return true;
            }
            if (k === "right" || k === "down" || k === "8") {
                move(1);
                return true;
            }
            return false;
        }
    }
    component PickRow: Rectangle {
        id: row
        required property int index
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool strong: false
        property bool lit: ListView.isCurrentItem
        signal hit()
        width: ListView.view ? ListView.view.width : 0
        height: sub ? root.k * 16 : root.k * 10
        color: lit ? root.trim : "transparent"
        Row {
            x: root.k * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.k * 2
            PxIcon {
                visible: row.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: row.icon || "heart"
                fill: row.lit ? "#ffffff" : root.trim
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                PxText {
                    width: row.width - root.k * 14
                    elide: Text.ElideRight
                    text: row.title
                    kind: "tiny"
                    font.bold: row.strong
                    color: row.lit ? Theme.selectText : root.ink
                }
                PxText {
                    visible: row.sub !== ""
                    width: row.width - root.k * 14
                    elide: Text.ElideRight
                    text: row.sub
                    kind: "tiny"
                    color: row.lit ? Qt.alpha(Theme.selectText, 0.8) : root.dimInk
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                row.ListView.view.at = row.index;
                row.hit();
            }
        }
    }
    function when(at) {
        const d = new Date(at), today = new Date().toDateString() === d.toDateString();
        return today ? I18n.time(d, false) : Qt.formatDate(d, "dd.MM");
    }

    // ---- home ----
    Component {
        id: homeApp
        Item {
            // the soft keys' words are the green key's, OK's and the red key's; ◀ ▶ here: messages, names
            readonly property var soft: [I18n.t("Вызовы", "Calls"), I18n.t("Меню", "Menu"), ""]
            function key(k) {
                if (/^[0-9*#]$/.test(k)) {
                    root.go("dial", {
                        "number": k
                    });
                    return true;
                }
                if (k === "ok") {
                    root.go("menu");
                    return true;
                }
                if (k === "left") {
                    root.go("inbox");
                    return true;
                }
                if (k === "right") {
                    root.go("contacts");
                    return true;
                }
                if (k === "call") {
                    root.go("log");
                    return true;
                }
                return false;
            }
            // the screen's wallpaper (the tuning)
            PhoneWall {
                anchors.fill: parent
                anchors.margins: -root.k * 2
                kind: root.phone.screenWall
                color: root.trim
            }
            Column {
                anchors.fill: parent
                spacing: root.k * 2
                PxText {
                    text: root.hell ? I18n.t("АД GSM", "HELL GSM") : I18n.t("НЕБО ♡", "HEAVEN ♡")
                    kind: "tiny"
                    color: root.trim
                }
                Column {
                    width: parent.width
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.time(root.phone.now, false)
                        kind: "big"
                        color: root.ink
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(root.phone.now, I18n.english ? "ddd, MMM d" : "ddd, d MMMM")
                        kind: "tiny"
                        color: root.dimInk
                    }
                }
                // what waits: missed calls, messages
                Row {
                    spacing: root.k * 4
                    Row {
                        visible: PhoneLine.missedCount > 0
                        spacing: root.k
                        PxIcon {
                            name: "phone"
                            fill: Theme.danger
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: PhoneLine.missedCount + " " + I18n.t("пропущ.", "missed")
                            kind: "tiny"
                            color: root.ink
                        }
                    }
                    Row {
                        visible: PhoneLine.unread > 0
                        spacing: root.k
                        PxIcon {
                            name: "chat"
                            fill: root.trim
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: PhoneLine.unread + " " + I18n.t("SMS", "texts")
                            kind: "tiny"
                            color: root.ink
                        }
                    }
                }
                PxText {
                    visible: Sidebar.has("media") && Lyrics.title !== ""
                    width: parent.width
                    elide: Text.ElideRight
                    text: "♪ " + (Lyrics.hasLyrics && Lyrics.current !== "" ? Lyrics.current : Lyrics.title)
                    kind: "tiny"
                    color: root.trim
                }
            }
        }
    }

    // ---- the menu ----
    readonly property var programs: [["inbox", "chat", I18n.t("Сообщения", "Messages")], ["contacts", "phone", I18n.t("Контакты", "Contacts")], ["log", "clock", I18n.t("Вызовы", "Calls")], ["camera", "camera", I18n.t("Камера", "Camera")], ["games", "gamepad", I18n.t("Игры", "Games")], ["tunes", "music", I18n.t("Мелодии", "Tunes")], ["tuning", "sparkleStar", I18n.t("Тюнинг", "Tuning")], ["ball", "eye", I18n.t("Шар судьбы", "Magic ball")], ["torch", "sun", I18n.t("Фонарик", "Torch")], ["sound", "speaker", I18n.t("Звук", "Sound")], ["system", "gauge", I18n.t("Система", "System")]].concat(root.phone.bar ? [] : [["turn", "rotate", I18n.t("На бок", "Sideways")]])
    readonly property string menuKeys: "123456789*0#"
    function open(id) {
        if (id === "turn")
            Sidebar.turned = true;
        else if (id === "torch")
            root.phone.torch = true;
        else
            go(id);
    }
    Component {
        id: menuApp
        Item {
            id: menu
            property int at: 0
            readonly property var soft: ["", I18n.t("Выбор", "Select"), ""]
            function key(k) {
                const n = root.menuKeys.indexOf(k);
                if (n >= 0) {
                    root.open(root.programs[n][0]);
                    return true;
                }
                const step = {
                    "left": -1,
                    "right": 1,
                    "up": -3,
                    "down": 3
                }[k];
                if (step) {
                    at = (at + step + root.programs.length) % root.programs.length;
                    return true;
                }
                if (k === "ok" || k === "call") {
                    root.open(root.programs[at][0]);
                    return true;
                }
                return false;
            }
            PxText {
                id: menuTitle
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.programs[menu.at][2]
                kind: "tiny"
                color: root.trim
            }
            Grid {
                anchors.top: menuTitle.bottom
                anchors.topMargin: root.k * 2
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: root.k * 2
                Repeater {
                    model: root.programs
                    Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        width: (menu.width - root.k * 4) / 3
                        height: Math.min(width, (menu.height - menuTitle.height - root.k * 8) / 4)
                        color: index === menu.at ? root.trim : Qt.alpha(root.trim, 0.12)
                        PxIcon {
                            anchors.centerIn: parent
                            name: cell.modelData[1]
                            pixel: cell.height > root.k * 20 ? root.k * 2 : root.k
                            fill: cell.index === menu.at ? "#ffffff" : root.trim
                        }
                        PxText {
                            x: root.k
                            text: root.menuKeys.charAt(cell.index)
                            kind: "tiny"
                            color: cell.index === menu.at ? Theme.selectText : root.dimInk
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menu.at = cell.index;
                                root.open(cell.modelData[0]);
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- the dialler ----
    Component {
        id: dialApp
        Item {
            id: dialer
            property string number: root.cur.number || ""
            readonly property var soft: [I18n.t("Вызов", "Call"), I18n.t("◀ стереть", "◀ erase"), I18n.t("Назад", "Back")]
            function key(k) {
                if (/^[0-9*#]$/.test(k) || k === "t:+") {
                    if (number.length < 16)
                        number += k.replace("t:", "");
                    return true;
                }
                if (k.startsWith("t:") && /^[0-9*#]$/.test(k.slice(2))) {
                    number += k.slice(2);
                    return true;
                }
                if (k === "left") {
                    number = number.slice(0, -1);
                    if (!number)
                        root.back();
                    return true;
                }
                if (k === "call" || k === "ok") {
                    const r = PhoneLine.dial(number);
                    if (!r)
                        return true;
                    if (r.sound)
                        PhoneLine.play(r.sound, 0.6);
                    if (r.kind !== "call") {
                        root.back();
                        root.go("info", {
                            "text": r.text,
                            "wrong": r.kind === "wrong"
                        });
                    } else {
                        root.home();
                    }
                    return true;
                }
                return false;
            }
            // who it is, when the number is someone's
            readonly property var known: PhoneLine.contacts.find(c => c.number === number) || null
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: root.k * 2
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: dialer.number
                    kind: dialer.number.length > 8 ? "title" : "big"
                    color: root.ink
                    elide: Text.ElideLeft
                }
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: !!dialer.known
                    text: dialer.known ? dialer.known.name : ""
                    kind: "tiny"
                    color: root.trim
                }
            }
        }
    }

    // ---- what a number said ----
    Component {
        id: infoApp
        Item {
            readonly property var soft: ["", "OK", ""]
            function key(k) {
                if (k === "ok" || k === "end" || k === "call") {
                    root.home();
                    return true;
                }
                return false;
            }
            PxText {
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.cur.text || ""
                kind: "tiny"
                color: root.cur.wrong ? Theme.danger : root.ink
            }
        }
    }

    // ---- contacts ----
    Component {
        id: contactsApp
        Pick {
            id: list
            readonly property var soft: [I18n.t("Вызов", "Call"), "SMS", I18n.t("Назад", "Back")]
            model: PhoneLine.contacts
            function key(k) {
                if (keyNav(k))
                    return true;
                const c = PhoneLine.contacts[at];
                if (!c)
                    return false;
                if (k === "call") {
                    const r = PhoneLine.dial(c.number);
                    if (r && r.kind !== "call") {
                        if (r.sound)
                            PhoneLine.play(r.sound, 0.6);
                        root.go("info", {
                            "text": r.text
                        });
                    } else
                        root.home();
                    return true;
                }
                if (k === "ok") {
                    if (c.who)
                        root.go("write", {
                            "to": c.who
                        });
                    else
                        key("call");
                    return true;
                }
                return false;
            }
            delegate: PickRow {
                required property var modelData
                icon: modelData.who === "demon" ? "heartHorns" : modelData.who === "angel" ? "heart" : "phone"
                title: modelData.name
                sub: modelData.number
                onHit: list.key("call")
            }
        }
    }

    // ---- the call log ----
    Component {
        id: logApp
        Item {
            id: logView
            readonly property var soft: [I18n.t("Вызов", "Call"), "", I18n.t("Назад", "Back")]
            Component.onCompleted: PhoneLine.seenLog()
            function key(k) {
                if (calls.keyNav(k))
                    return true;
                const l = PhoneLine.log[calls.at];
                if ((k === "call" || k === "ok") && l) {
                    const c = PhoneLine.contacts.find(x => x.who === l.who);
                    if (c) {
                        const r = PhoneLine.dial(c.number);
                        if (r && r.kind !== "call")
                            root.go("info", {
                                "text": r.text
                            });
                        else
                            root.home();
                    }
                    return true;
                }
                return false;
            }
            PxText {
                visible: !PhoneLine.log.length
                anchors.centerIn: parent
                text: I18n.t("Вызовов нет", "No calls")
                kind: "tiny"
                color: root.dimInk
            }
            Pick {
                id: calls
                anchors.fill: parent
                model: PhoneLine.log
                delegate: PickRow {
                    required property var modelData
                    icon: "phone"
                    title: (modelData.kind === "missed" ? "✕ " : modelData.kind === "out" ? "↗ " : "↙ ") + modelData.name
                    sub: root.when(modelData.at)
                    strong: modelData.kind === "missed"
                    onHit: logView.key("call")
                }
            }
        }
    }

    // ---- messages ----
    Component {
        id: inboxApp
        Item {
            readonly property var soft: [I18n.t("Новое", "New"), I18n.t("Читать", "Read"), I18n.t("Назад", "Back")]
            function key(k) {
                if (box.keyNav(k))
                    return true;
                if (k === "call") {
                    root.go("write", {
                        "to": PhoneLine.who
                    });
                    return true;
                }
                const m = PhoneLine.sms[box.at];
                if (k === "ok" && m) {
                    root.go("read", {
                        "msg": m
                    });
                    return true;
                }
                return false;
            }
            PxText {
                visible: !PhoneLine.sms.length
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: I18n.t("Сообщений нет.\n◀ — написать", "No messages.\n◀ to write one")
                kind: "tiny"
                color: root.dimInk
            }
            Pick {
                id: box
                anchors.fill: parent
                model: PhoneLine.sms
                delegate: PickRow {
                    required property var modelData
                    icon: modelData.from ? (modelData.read ? "chat" : "bell") : "arrowRight"
                    title: modelData.from ? PhoneLine.nameOfMsg(modelData) : "→ " + PhoneLine.nameOfMsg(modelData)
                    sub: modelData.text
                    strong: !!modelData.from && !modelData.read
                    onHit: root.go("read", {
                        "msg": modelData
                    })
                }
            }
        }
    }
    Component {
        id: readApp
        Item {
            readonly property var msg: root.cur.msg || ({})
            // her messages are answered from a choice (replyApp); the voicemail's says to call 1
            readonly property bool her: msg.from === "angel" || msg.from === "demon"
            readonly property var soft: msg.from === "voicemail" ? [I18n.t("Вызов", "Call"), "", I18n.t("Назад", "Back")] : msg.from ? [I18n.t("Ответ", "Reply"), "", I18n.t("Назад", "Back")] : ["", "", I18n.t("Назад", "Back")]
            Component.onCompleted: if (msg.from)
                PhoneLine.readAll(msg.from)
            function key(k) {
                if ((k === "call" || k === "ok") && msg.from === "voicemail") {
                    PhoneLine.dial("1");
                    return true;
                }
                if ((k === "call" || k === "ok") && msg.from) {
                    root.go(her ? "reply" : "write", {
                        "to": msg.from,
                        "msg": msg
                    });
                    return true;
                }
                return false;
            }
            Column {
                width: parent.width
                spacing: root.k * 2
                PxText {
                    text: (msg.from ? PhoneLine.nameOfMsg(msg) : "→ " + PhoneLine.nameOfMsg(msg)) + "  " + (msg.at ? root.when(msg.at) : "")
                    kind: "tiny"
                    color: root.trim
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: msg.text || ""
                    kind: "tiny"
                    color: root.ink
                }
            }
        }
    }
    // her message answered: three lines to pick (PhoneLine.replyOptions) or your own words
    Component {
        id: replyApp
        Item {
            readonly property var msg: root.cur.msg || ({})
            readonly property var choices: PhoneLine.replyOptions(msg).concat([{
                    "text": I18n.t("Своими словами…", "In my own words…"),
                    "tag": "own"
                }])
            readonly property var soft: [I18n.t("Отпр.", "Send"), I18n.t("Выбор", "Pick"), I18n.t("Назад", "Back")]
            function pickIt(i) {
                const c = choices[i];
                if (!c)
                    return;
                if (c.tag === "own") {
                    root.back();
                    root.go("write", {
                        "to": msg.from,
                        "re": msg
                    });
                    return;
                }
                PhoneLine.send(msg.from, c.text, c.tag, msg);
                root.back();
                root.back();
                root.go("info", {
                    "text": I18n.t("Отправлено ♡", "Sent ♡")
                });
            }
            function key(k) {
                // the digits pick a line straight away; the arrows walk
                const n = "1234".indexOf(k);
                if (n >= 0 && n < choices.length) {
                    pickIt(n);
                    return true;
                }
                if (opts.keyNav(k))
                    return true;
                if (k === "ok" || k === "call") {
                    pickIt(opts.at);
                    return true;
                }
                return false;
            }
            PxText {
                id: replyHead
                width: parent.width
                elide: Text.ElideRight
                text: I18n.t("Ответ: ", "Reply: ") + PhoneLine.nameOfMsg(msg)
                kind: "tiny"
                color: root.trim
            }
            Pick {
                id: opts
                anchors.top: replyHead.bottom
                anchors.topMargin: root.k
                anchors.bottom: parent.bottom
                width: parent.width
                model: parent.choices
                delegate: Rectangle {
                    id: opt
                    required property var modelData
                    required property int index
                    readonly property bool lit: ListView.isCurrentItem
                    width: ListView.view ? ListView.view.width : 0
                    height: optText.implicitHeight + root.k * 3
                    color: lit ? root.trim : "transparent"
                    PxText {
                        id: optText
                        x: root.k
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - root.k * 2
                        wrapMode: Text.Wrap
                        text: (opt.index + 1) + ". " + opt.modelData.text
                        kind: "tiny"
                        color: opt.lit ? Theme.selectText : opt.modelData.tag === "own" ? root.dimInk : root.ink
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            opts.at = opt.index;
                            opt.ListView.view.parent.pickIt(opt.index);
                        }
                    }
                }
            }
        }
    }
    // multi-tap: each key's letters, ru and en
    readonly property var taps: ({
            "ru": {
                "1": ".,!?-1♡",
                "2": "абвг2",
                "3": "дежз3",
                "4": "ийкл4",
                "5": "мноп5",
                "6": "рсту6",
                "7": "фхцч7",
                "8": "шщъы8",
                "9": "ьэюя9",
                "0": " 0"
            },
            "en": {
                "1": ".,!?-1♡",
                "2": "abc2",
                "3": "def3",
                "4": "ghi4",
                "5": "jkl5",
                "6": "mno6",
                "7": "pqrs7",
                "8": "tuv8",
                "9": "wxyz9",
                "0": " 0"
            }
        })
    Component {
        id: writeApp
        Item {
            id: writer
            property string text: ""
            property string lang: I18n.english ? "en" : "ru"
            property bool caps: true
            // the key being tapped and which of its letters is up
            property string tapKey: ""
            property int tapAt: 0
            readonly property var soft: [I18n.t("Отпр.", "Send"), I18n.t("◀ стереть", "◀ erase"), I18n.t("Назад", "Back")]
            Timer {
                id: commit
                interval: 900
                onTriggered: writer.tapKey = ""
            }
            function put(ch) {
                text += caps ? ch.toUpperCase() : ch;
                if (caps && /[a-zа-яё]/i.test(ch))
                    caps = false;
                if (/[.!?]/.test(ch))
                    caps = true;
            }
            function key(k) {
                if (k.startsWith("t:")) {
                    tapKey = "";
                    const ch = k.slice(2);
                    if (ch === "\b")
                        text = text.slice(0, -1);
                    else
                        text += ch;
                    return true;
                }
                const letters = root.taps[lang][k];
                if (letters) {
                    if (tapKey === k) {
                        // the same key again: the next letter in place of the last, as big as it was
                        const was = text.slice(-1);
                        text = text.slice(0, -1);
                        tapAt = (tapAt + 1) % letters.length;
                        const ch = letters.charAt(tapAt);
                        text += was !== was.toLowerCase() ? ch.toUpperCase() : ch;
                    } else {
                        tapKey = k;
                        tapAt = 0;
                        put(letters.charAt(tapAt));
                    }
                    commit.restart();
                    return true;
                }
                if (k === "*") {
                    caps = !caps;
                    tapKey = "";
                    return true;
                }
                if (k === "#") {
                    lang = lang === "ru" ? "en" : "ru";
                    tapKey = "";
                    return true;
                }
                if (k === "left") {
                    tapKey = "";
                    text = text.slice(0, -1);
                    return true;
                }
                if (k === "call" || k === "ok") {
                    if (text.trim()) {
                        PhoneLine.send(root.cur.to, text, "", root.cur.re || null);
                        root.back();
                        root.go("info", {
                            "text": I18n.t("Отправлено ♡", "Sent ♡")
                        });
                    }
                    return true;
                }
                return false;
            }
            Column {
                width: parent.width
                spacing: root.k * 2
                PxText {
                    // who to, and the letters the keys type now (# ru/en, * capitals)
                    text: I18n.t("Кому: ", "To: ") + (root.cur.re ? PhoneLine.nameOfMsg(root.cur.re) : PhoneLine.nameOf(root.cur.to)) + "   " + (writer.lang === "ru" ? (writer.caps ? "АБВ" : "абв") : (writer.caps ? "ABC" : "abc"))
                    kind: "tiny"
                    color: root.trim
                }
                Rectangle {
                    width: parent.width
                    height: writer.height - root.k * 14
                    color: Qt.alpha(root.trim, 0.1)
                    PxText {
                        x: root.k
                        y: root.k
                        width: parent.width - root.k * 2
                        wrapMode: Text.WrapAnywhere
                        text: writer.text + (writer.tapKey ? "" : "▏")
                        kind: "tiny"
                        color: root.ink
                    }
                }
            }
        }
    }

    // ---- sound and system (the old pages) ----
    Component {
        id: soundApp
        PxScroll {
            id: soundScroll
            contentHeight: soundCol.implicitHeight
            Column {
                id: soundCol
                width: soundScroll.flick.width
                spacing: root.k * 3
                Repeater {
                    model: [
                        {
                            "icon": Audio.muted ? "speakerMute" : "speaker",
                            "label": Audio.sink ? Audio.nodeName(Audio.sink) : "",
                            "value": Audio.volume,
                            "ready": Audio.ready,
                            "set": v => Audio.setVolume(v),
                            "mute": () => Audio.toggleMute()
                        },
                        {
                            "icon": Audio.micMuted ? "micMute" : "mic",
                            "label": Audio.source ? Audio.nodeName(Audio.source) : "",
                            "value": Audio.micVolume,
                            "ready": !!Audio.source && !!Audio.source.audio,
                            "set": v => {
                                if (Audio.source && Audio.source.audio)
                                    Audio.source.audio.volume = v;
                            },
                            "mute": () => Audio.toggleMic()
                        }
                    ]
                    Column {
                        id: vol
                        required property var modelData
                        width: soundCol.width
                        spacing: root.k
                        enabled: modelData.ready
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: vol.modelData.label
                            kind: "tiny"
                            color: root.dimInk
                        }
                        Row {
                            width: parent.width
                            spacing: root.k * 2
                            PxButton {
                                compact: true
                                hell: root.hell
                                icon: vol.modelData.icon
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: vol.modelData.mute()
                            }
                            PxSlider {
                                width: vol.width - x
                                anchors.verticalCenter: parent.verticalCenter
                                from: 0
                                to: 1
                                stepSize: 0.01
                                value: vol.modelData.value
                                valueScale: 100
                                suffix: "%"
                                onMoved: v => vol.modelData.set(v)
                            }
                        }
                    }
                }
                MusicPlayer {
                    visible: Sidebar.has("media") && !!Lyrics.player && Lyrics.title !== ""
                    width: parent.width
                    height: visible ? implicitHeight : 0
                }
            }
        }
    }
    Component {
        id: systemApp
        PxScroll {
            id: sysScroll
            contentHeight: sysCol.implicitHeight
            Column {
                id: sysCol
                width: sysScroll.flick.width
                spacing: root.k * 4
                SysmonWidget {
                    width: parent.width
                    awake: Sidebar.open && root.phone.turn < 0.5
                    height: implicitHeight
                }
                Repeater {
                    model: Sidebar.has("ai") ? Plugins.sidebarWidgets : []
                    Column {
                        id: block
                        required property var modelData
                        width: sysCol.width
                        spacing: root.k * 2
                        PxText {
                            text: "✧ " + I18n.label(block.modelData.name)
                            kind: "tiny"
                            dim: true
                        }
                        Loader {
                            width: parent.width
                            Component.onCompleted: setSource(Plugins.url(block.modelData, block.modelData.sidebarWidget), {
                                "plugin": Plugins.context(block.modelData),
                                "width": block.width
                            })
                        }
                    }
                }
            }
        }
    }

    // ---- the camera: selfies with her, the album ----
    Component {
        id: cameraApp
        PhoneCamera {
            phone: root.phone
        }
    }

    // ---- games ----
    Component {
        id: gamesApp
        Pick {
            id: games
            readonly property var soft: ["", I18n.t("Играть", "Play"), I18n.t("Назад", "Back")]
            model: [["snake", I18n.t("Змейка", "Snake"), I18n.t("Рекорд ", "Best ") + (Story.phone ? Story.phone.snake || 0 : 0)], ["raid", I18n.t("Небесный рейд", "Heaven Raid"), I18n.t("Рекорд ", "Best ") + (PhoneLine.stats.raid || 0)]]
            function key(k) {
                if (keyNav(k))
                    return true;
                if (k === "ok" || k === "call" || k === "5") {
                    root.go(model[at][0]);
                    return true;
                }
                if (k === "1" || k === "3") {
                    root.go(model[k === "1" ? 0 : 1][0]);
                    return true;
                }
                return false;
            }
            delegate: PickRow {
                required property var modelData
                icon: "gamepad"
                title: modelData[1]
                sub: modelData[2]
                onHit: root.go(modelData[0])
            }
        }
    }
    Component {
        id: raidApp
        PhoneRaid {
            phone: root.phone
        }
    }

    // ---- tunes: hers by default, the ones she sent, yours; the green key rings with it ----
    Component {
        id: tunesApp
        Pick {
            id: tunes
            readonly property var soft: [I18n.t("На звонок", "Ring"), I18n.t("Слушать", "Play"), I18n.t("Назад", "Back")]
            readonly property string own: Config.phone.ringtone
            readonly property var list: {
                const l = [{
                        "id": "compose",
                        "name": I18n.t("Сочинить свою…", "Compose one…"),
                        "spec": ""
                    }, {
                        "id": "hers",
                        "name": I18n.t("Её мелодия", "Hers"),
                        "spec": ""
                    }].concat(PhoneLine.myTunes);
                if (own && !PhoneLine.myTunes.some(t => t.spec === own))
                    l.push({
                        "id": "mine",
                        "name": I18n.t("Твоя, из композитора", "Yours, from the composer"),
                        "spec": own
                    });
                return l;
            }
            model: list
            function specOf(t) {
                return t.id === "hers" ? PhoneLine.tunes[PhoneLine.who] : t.spec;
            }
            function key(k) {
                if (keyNav(k))
                    return true;
                const t = list[at];
                if (!t)
                    return false;
                if (t.id === "compose" && (k === "ok" || k === "call")) {
                    root.go("composer");
                    return true;
                }
                if (k === "ok") {
                    PhoneLine.playTune(specOf(t), 0.8);
                    return true;
                }
                if (k === "call") {
                    Config.phone.ringtone = t.id === "hers" ? "" : t.spec;
                    PhoneLine.play("sms", 0.5);
                    return true;
                }
                return false;
            }
            delegate: PickRow {
                required property var modelData
                icon: modelData.id === "compose" ? "pen" : "music"
                title: modelData.name + ((modelData.id === "hers" ? !tunes.own : modelData.spec && modelData.spec === tunes.own) ? "  ♪" : "")
                sub: modelData.id === "compose" ? I18n.t("композитор", "the composer") : modelData.who === "demon" ? I18n.t("от демоницы", "from the demon") : modelData.who === "angel" ? I18n.t("от ангела", "from the angel") : ""
                onHit: tunes.key("ok")
            }
        }
    }

    // ---- the tuning ----
    Component {
        id: tuningApp
        PhoneTuning {
            phone: root.phone
        }
    }

    // ---- the magic ball: think of a question, press 5 ----
    Component {
        id: ballApp
        Item {
            id: ballView
            property string said: ""
            property int shake: 0
            readonly property var soft: ["", I18n.t("Спросить", "Ask"), I18n.t("Назад", "Back")]
            function key(k) {
                if (k === "5" || k === "ok" || k === "call") {
                    said = "";
                    shake = 8;
                    shaker.restart();
                    return true;
                }
                return false;
            }
            Timer {
                id: shaker
                interval: 70
                repeat: true
                onTriggered: {
                    if (--ballView.shake <= 0) {
                        stop();
                        ballView.said = PhoneLine.ballAnswer();
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: root.k * 3
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    x: ballView.shake % 2 ? root.k * 2 : 0
                    width: root.k * 34
                    height: width
                    radius: width / 2
                    color: "#15111c"
                    border.width: root.k
                    border.color: root.trim
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.55
                        height: width
                        radius: width / 2
                        color: ballView.said ? Qt.alpha(root.trim, 0.35) : "#2a2236"
                        PxText {
                            anchors.centerIn: parent
                            width: parent.width * 1.4
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: ballView.said || "8"
                            kind: ballView.said ? "tiny" : "title"
                            color: "#ffffff"
                        }
                    }
                }
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: I18n.t("Загадай вопрос и нажми 5. Или раскрути закрытый телефон.", "Think of a question, press 5. Or spin the shut phone.")
                    kind: "tiny"
                    color: root.dimInk
                }
            }
        }
    }

    // ---- Snake ----
    Component {
        id: snakeApp
        PhoneSnake {
            phone: root.phone
        }
    }

    // ---- the composer ----
    Component {
        id: composerApp
        PhoneComposer {
            phone: root.phone
        }
    }
}
