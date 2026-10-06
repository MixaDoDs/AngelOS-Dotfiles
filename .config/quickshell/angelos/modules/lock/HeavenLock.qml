pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// The heaven lock (Settings → Lock → Look: Heaven): a gacha game's login screen in pixels.
// A gate over a sea of clouds; the sky follows the shell's theme — light: dawn, day,
// dusk or a pastel twilight by the hour; dark: a night of stars in the same hours.
//   the angel   stands by the gate (LockAngel): dozes, wakes when you type, shuts her
//               eyes on the password, cries at a mistake, cheers at the unlock
//   the prayer  the unlock is a wish (HeavenStars): free once a day, then 160 ✦; a falling
//               star, 3★ / 4★ / 5★ with pity, a card for the album or one of her skins
//   rewards     the daily login reward in stars ✦, the day's three tasks, the heavenly pass
//   notices     the notice board: angelOS updates, who wrote while you were away, the
//               song, achievements, time at the computer, the prayer's pity
// A key or a click wakes it ("press any key"); the login plate rises over the gate (the
// key already counts). A wrong password clouds the sky with lightning; the right one
// opens the gate (the unlock style "gate" carries the light on over the desktop).
Item {
    id: root

    required property string screenName
    required property bool primary
    required property var lockScope
    required property date now
    property bool preview: false

    readonly property bool reactions: Config.lock.reactions
    readonly property real boxScale: Math.max(1, Math.round(Theme.u * (Config.lock.size || 1)) / Theme.u)
    readonly property point fxOrigin: Qt.point(0.5, (gate.y + gate.height * 0.55) / Math.max(1, height))
    property bool awake: false
    readonly property string user: Quickshell.env("USER") || "angel"
    property string uid: ""
    // the side panels need room: a landscape screen
    readonly property bool roomy: width >= 1500 && width > height

    // ---- light or dark, from the shell's theme ----
    readonly property bool dark: Theme.dark
    readonly property color ink: dark ? "#e8ecff" : "#2f3d6e"
    readonly property color dim: dark ? "#a9b3e0" : "#6a7aa8"
    readonly property color outline: dark ? "#0a0d22" : "#2f3d6e"
    readonly property color gold: "#e8b84a"
    readonly property real hour: now.getHours() + now.getMinutes() / 60
    readonly property var palette: {
        const h = hour;
        if (dark) {
            if (h >= 5 && h < 9)
                return {
                    "top": "#1b2457",
                    "bottom": "#7a5a8a",
                    "cloud": "#8b86c4",
                    "shade": "#3f3f86",
                    "sun": "#f4f1d0",
                    "night": 1
                };
            if (h >= 9 && h < 17)
                return {
                    "top": "#162660",
                    "bottom": "#3f5c9e",
                    "cloud": "#8fa0d8",
                    "shade": "#3a4a8a",
                    "sun": "#f4f1d0",
                    "night": 1
                };
            if (h >= 17 && h < 22)
                return {
                    "top": "#141a4a",
                    "bottom": "#5a3f8f",
                    "cloud": "#8a7cc4",
                    "shade": "#3c3580",
                    "sun": "#f4f1d0",
                    "night": 1
                };
            return {
                "top": "#070b26",
                "bottom": "#28306e",
                "cloud": "#6f74b8",
                "shade": "#2c2f6e",
                "sun": "#f4f1d0",
                "night": 1
            };
        }
        if (h >= 5 && h < 9)
            return {
                "top": "#6a7fd6",
                "bottom": "#ffc7a6",
                "cloud": "#fff1e6",
                "shade": "#e2a6bd",
                "sun": "#fff0b0",
                "night": 0
            };
        if (h >= 9 && h < 17)
            return {
                "top": "#3d8ef0",
                "bottom": "#c4ecff",
                "cloud": "#ffffff",
                "shade": "#b7d3f3",
                "sun": "#fff6c0",
                "night": 0
            };
        if (h >= 17 && h < 21)
            return {
                "top": "#4b4fa6",
                "bottom": "#ffb28c",
                "cloud": "#ffe2d2",
                "shade": "#c48aa9",
                "sun": "#ffd28a",
                "night": 0.1
            };
        // a light theme at night: a pastel twilight, never black
        return {
            "top": "#7b74c9",
            "bottom": "#f6c3d8",
            "cloud": "#fff0f6",
            "shade": "#c9a3cf",
            "sun": "#fff3c4",
            "night": 0.3
        };
    }
    readonly property point sunPos: {
        if (palette.night > 0.5)
            return Qt.point(0.8, 0.15);
        const k = Math.max(0, Math.min(1, (hour - 5) / 16));
        return Qt.point(0.12 + k * 0.76, 0.12 + 0.14 * (1 - Math.sin(Math.PI * k)));
    }

    Process {
        running: true
        command: ["id", "-u"]
        stdout: StdioCollector {
            onStreamFinished: root.uid = String(text).trim()
        }
    }

    // ---- sky ----
    property real time: 0
    property real storm: 0
    property real glow: 0
    Timer {
        // stepped like the art: 12 moves a second
        interval: 83
        repeat: true
        running: !Motion.still && root.visible
        onTriggered: root.time += 0.083
    }
    ShaderEffect {
        anchors.fill: parent
        property real time: root.time
        property real cell: Theme.u * 3
        property real night: root.palette.night
        property real storm: root.storm
        property real glow: root.glow
        property size resolution: Qt.size(width, height)
        property point sunPos: root.sunPos
        property point gatePos: root.fxOrigin
        property color skyTop: root.palette.top
        property color skyBottom: root.palette.bottom
        property color cloud: root.palette.cloud
        property color cloudShade: root.palette.shade
        property color sun: root.palette.sun
        fragmentShader: Qt.resolvedUrl("../../shaders/heaven_sky.frag.qsb")
    }

    // sparkles drifting down
    Repeater {
        model: Config.lock.hearts ? 18 : 0
        PxIcon {
            required property int index
            name: index % 3 ? "sparkle" : "sparkleStar"
            pixel: Math.max(1, Theme.u * (index % 4 === 0 ? 2 : 1))
            ink: "#ffffff"
            fill: index % 2 ? "#fff6c8" : "#ffffff"
            property real baseX: (index * 0.137 + 0.05) % 1
            property real phase: index * 0.61
            x: Math.round((baseX * root.width + Math.sin(root.time * 0.5 + phase) * Theme.u * 10) / Theme.u) * Theme.u
            y: Math.round(((root.time * (14 + index % 5 * 5) * Theme.u + phase * root.height) % (root.height + 40)) - 20)
            opacity: (Math.floor(root.time * 3 + index) % 4 === 0 ? 0.35 : 0.85) * (root.dark ? 0.75 : 1)
        }
    }

    // ---- the gate, and the angel by it ----
    HeavenGate {
        id: gate
        cell: Math.max(Theme.u * 2, Math.floor(Math.min(root.height * 0.52 / rows, root.width * 0.5 / cols)))
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.29)
        heart: Theme.accent
    }
    LockAngel {
        id: angel
        visible: Config.lock.heavenAngel && root.primary
        lockScope: root.lockScope
        // a portrait screen has less room beside the gate: she is smaller there
        px: Math.max(1, Math.round(Math.min(root.height, root.width * 0.75) * 0.26 / 120))
        // the login plate rises over the gate: she steps aside, next to it
        x: Math.round(Math.max(-width * 0.1, root.awake && root.primary ? Math.min(gate.x - width * 0.74, cardHolder.x - width * 0.82) : gate.x - width * 0.74))
        y: Math.round(gate.y + gate.height - height - gate.cell * 3)
        Behavior on x {
            NumberAnimation {
                duration: Motion.ms(320)
                easing.type: Easing.OutQuad
            }
        }
    }
    // what she says
    Item {
        visible: angel.visible && angel.say !== ""
        x: Math.round(angel.x + angel.width * 0.5 - width / 2)
        y: Math.round(angel.y - height - Theme.u * 2)
        width: bubbleText.implicitWidth + Theme.u * 14
        height: bubbleText.implicitHeight + Theme.u * 10
        HeavenPlate {
            anchors.fill: parent
            pill: true
            dark: root.dark
        }
        PxText {
            id: bubbleText
            anchors.centerIn: parent
            text: angel.say
            color: root.ink
        }
    }

    // ---- corners: the logo, the indicators, who and where ----
    Column {
        x: Theme.u * 12
        y: Theme.u * 10
        spacing: Theme.u * 3
        AngelLogo {
            visible: Config.lock.logo
            pixel: Theme.u * 2
            fontSize: Theme.sizeHuge
        }
        PxText {
            text: I18n.t("НЕБЕСНЫЕ ВРАТА", "HEAVEN'S GATE")
            kind: "title"
            color: root.gold
            style: Text.Outline
            styleColor: root.outline
            font.bold: true
        }
    }
    LockIndicators {
        id: indicators
        visible: Config.lock.indicators
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.u * 10
        lockScope: root.lockScope
        now: root.now
        heaven: true
        dark: root.dark
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Theme.u * 8, gate.y - height - Theme.u * 10)
        spacing: Theme.u * 2
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH") + (root.now.getSeconds() % 2 || !root.reactions ? ":" : " ") + Qt.formatTime(root.now, "mm")
            font.family: Theme.fontTitle
            font.pixelSize: Theme.fontPx(72, Theme.fontTitle)
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.outline
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale(Config.appearance.language === "en" ? "en_US" : "ru_RU").toString(root.now, "dddd, d MMMM")
            kind: "title"
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.outline
        }
    }
    PxText {
        visible: root.primary
        x: Theme.u * 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 8
        text: "UID " + (root.uid || "—") + " · " + root.user
        color: "#ffffff"
        style: Text.Outline
        styleColor: root.outline
    }
    PxText {
        visible: root.primary
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 8
        text: "angelOS · " + I18n.t("сервер: Небеса", "server: Heaven") + " · " + I18n.t("день ", "day ") + LockStream.days
        color: "#ffffff"
        style: Text.Outline
        styleColor: root.outline
    }

    // ---- left: the daily login reward ----
    Item {
        id: rewards
        visible: Config.lock.dailyReward && root.primary && root.roomy
        x: Theme.u * 12
        y: Math.round(root.height * 0.3)
        width: Theme.u * 7 * 26 + Theme.u * 20
        height: rewardCol.implicitHeight + Theme.u * 22
        property int justClaimed: -1
        HeavenPlate {
            anchors.fill: parent
            dark: root.dark
            corner: 3
        }
        Column {
            id: rewardCol
            x: Theme.u * 10
            y: Theme.u * 10
            spacing: Theme.u * 5
            PxText {
                text: I18n.t("✦ НАГРАДА ЗА ВХОД ✦", "✦ DAILY LOGIN ✦")
                kind: "title"
                color: root.dark ? root.gold : "#b5832f"
                font.bold: true
            }
            PxText {
                text: LockStream.claimable ? I18n.t("сегодняшняя — при входе · серия: %1", "today's comes with the unlock · streak: %1").arg(LockStream.streak) : I18n.t("получено сегодня ♡ · серия: %1", "claimed today ♡ · streak: %1").arg(LockStream.streak)
                kind: "tiny"
                color: root.dim
            }
            Row {
                spacing: Theme.u * 2
                Repeater {
                    model: LockStream.rewards
                    Item {
                        id: cell
                        required property int index
                        required property var modelData
                        readonly property int week: Math.floor((LockStream.claimable ? LockStream.claims : LockStream.claims - 1) / 7) * 7
                        readonly property bool taken: week + index < LockStream.claims
                        readonly property bool today: index === LockStream.cycleDay
                        width: Theme.u * 24
                        height: Theme.u * 34
                        property real pop: 1
                        scale: pop
                        HeavenPlate {
                            anchors.fill: parent
                            dark: root.dark
                            shadow: false
                            corner: 2
                            rim: cell.today ? (LockStream.claimable ? "#ffe07a" : "#9ad08a") : root.dark ? "#4a5a9a" : "#d9c79a"
                            fill: cell.taken ? (root.dark ? Qt.rgba(0.06, 0.08, 0.18, 0.95) : Qt.rgba(0.94, 0.92, 0.86, 0.95)) : root.dark ? Qt.rgba(0.11, 0.14, 0.3, 0.95) : Qt.rgba(1, 0.99, 0.95, 0.97)
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.u * 2
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.t("д", "d") + (cell.index + 1)
                                kind: "tiny"
                                color: root.dim
                            }
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: cell.modelData.icon
                                fill: cell.index === 6 ? root.gold : Theme.accent
                                opacity: cell.taken ? 0.45 : 1
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.taken ? "✓" : cell.modelData.n + "✦"
                                kind: "tiny"
                                color: cell.taken ? "#5aa860" : root.ink
                                font.bold: true
                            }
                        }
                        // today's, waiting: it glows
                        SequentialAnimation on opacity {
                            running: cell.today && LockStream.claimable && !Motion.still && rewards.visible
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 0.7
                                duration: 600
                            }
                            NumberAnimation {
                                to: 1
                                duration: 600
                            }
                        }
                        Connections {
                            target: rewards
                            function onJustClaimedChanged() {
                                if (rewards.justClaimed === cell.index)
                                    claimPop.restart();
                            }
                        }
                        SequentialAnimation {
                            id: claimPop
                            NumberAnimation {
                                target: cell
                                property: "pop"
                                to: 1.35
                                duration: Motion.ms(140)
                            }
                            NumberAnimation {
                                target: cell
                                property: "pop"
                                to: 1
                                duration: Motion.ms(200)
                                easing.type: Easing.OutBounce
                            }
                        }
                    }
                }
            }
            // the day's three tasks
            PxText {
                text: I18n.t("✦ ЗАДАНИЯ ДНЯ ✦", "✦ TODAY'S TASKS ✦")
                kind: "title"
                color: root.dark ? root.gold : "#b5832f"
                font.bold: true
            }
            Repeater {
                model: HeavenStars.tasks
                Column {
                    id: task
                    required property var modelData
                    width: Theme.u * 7 * 26 - Theme.u * 2
                    spacing: Theme.u
                    Row {
                        width: parent.width
                        PxText {
                            width: parent.width - reward.width
                            text: (task.modelData.done ? "✓ " : "") + I18n.t(task.modelData.ru, task.modelData.en)
                            color: task.modelData.done ? "#5aa860" : root.ink
                            elide: Text.ElideRight
                        }
                        PxText {
                            id: reward
                            text: task.modelData.have + "/" + task.modelData.goal + "  +" + HeavenStars.taskReward + "✦"
                            kind: "tiny"
                            color: root.dim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: Theme.u * 3
                        color: root.dark ? "#121735" : "#efe6cf"
                        Rectangle {
                            width: Math.round(parent.width * task.modelData.have / task.modelData.goal / Theme.u) * Theme.u
                            height: parent.height
                            color: task.modelData.done ? "#5aa860" : root.gold
                        }
                    }
                }
            }
            // the heavenly pass
            Row {
                spacing: Theme.u * 4
                PxText {
                    text: I18n.t("✦ ПРОПУСК · сезон %1 ✦", "✦ PASS · season %1 ✦").arg(HeavenStars.season)
                    kind: "title"
                    color: root.dark ? root.gold : "#b5832f"
                    font.bold: true
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("ещё %1 дн.", "%1 days left").arg(Math.ceil(HeavenStars.seasonDaysLeft))
                    kind: "tiny"
                    color: root.dim
                }
            }
            Row {
                spacing: Theme.u * 4
                PxText {
                    text: I18n.t("ур. ", "lv ") + HeavenStars.level
                    color: root.ink
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.u * 120
                    height: Theme.u * 5
                    color: root.dark ? "#121735" : "#efe6cf"
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: root.dark ? "#4a5a9a" : "#d9c79a"
                    Rectangle {
                        width: Math.round(parent.width * (HeavenStars.level >= 30 ? 1 : (HeavenStars.xp % HeavenStars.levelXp) / HeavenStars.levelXp) / Theme.u) * Theme.u
                        height: parent.height
                        color: Theme.accent
                    }
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var next: HeavenStars.level < 30 ? HeavenStars.passReward(HeavenStars.level + 1) : null
                    text: !next ? "MAX ♡" : next.kind === "frame" ? I18n.t("→ рамка", "→ a frame") : "→ +" + next.stars + "✦"
                    kind: "tiny"
                    color: root.dim
                }
            }
        }
    }

    // ---- right: the notice board ----
    property int missedNow: Notifs.history.filter(h => h.time > root.lockScope.lockedAt).length
    property string uptime: ""
    Timer {
        interval: 60000
        repeat: true
        running: root.primary
        triggeredOnStart: true
        onTriggered: root.uptime = Story.uptimeText()
    }
    readonly property var notices: {
        const out = [];
        out.push(Updates.available ? {
            "icon": "download",
            "title": I18n.t("Обновление angelOS", "angelOS update"),
            "text": I18n.t("доступно: %1 изм. — Настройки → Обновления", "available: %1 changes — Settings → Updates").arg(Updates.behind)
        } : {
            "icon": "check",
            "title": I18n.t("angelOS обновлён", "angelOS is up to date"),
            "text": I18n.t("последняя версия", "the latest version")
        });
        const apps = LockStream.notified.filter((a, i, all) => all.indexOf(a) === i);
        out.push({
            "icon": "bell",
            "title": I18n.t("Пока тебя не было", "While you were away"),
            "text": root.missedNow > 0 ? I18n.t("уведомлений: %1", "notifications: %1").arg(root.missedNow) + (apps.length ? " · " + apps.slice(0, 3).join(", ") : "") : I18n.t("тишина ♡", "all quiet ♡")
        });
        if (Lyrics.title)
            out.push({
                "icon": "music",
                "title": I18n.t("Сейчас играет", "Now playing"),
                "text": Lyrics.title + (Lyrics.artist ? " — " + Lyrics.artist : "")
            });
        if (Story.enabled)
            out.push({
                "icon": "star",
                "title": I18n.t("Достижения", "Achievements"),
                "text": Achievements.earned + " / " + Achievements.list.length
            });
        out.push({
            "icon": "monitor",
            "title": I18n.t("Сегодня за компьютером", "At the computer today"),
            "text": root.uptime
        });
        if (Config.lock.wish)
            out.push({
                "icon": "sparkleStar",
                "title": I18n.t("Звёзды и альбом", "Stars and the album"),
                "text": I18n.t("✦ %1 · карточек %2/%3 · скинов %4/3", "✦ %1 · cards %2/%3 · skins %4/3").arg(HeavenStars.stars).arg(HeavenStars.albumHave).arg(HeavenStars.cards.length).arg((HeavenStars.owned.skins || []).length)
            });
        out.push(LockStream.streak >= 7 ? {
            "icon": "heart",
            "title": I18n.t("Событие: неделя на небесах", "Event: a week in heaven"),
            "text": I18n.t("серия входов %1 дней ♡", "a %1-day login streak ♡").arg(LockStream.streak)
        } : {
            "icon": "heart",
            "title": I18n.t("Небесный день %1", "Heaven day %1").arg(LockStream.days),
            "text": I18n.t("спасибо, что ты здесь", "thank you for being here")
        });
        return out;
    }
    Item {
        id: board
        visible: Config.lock.notices && root.primary && root.roomy
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 12
        y: indicators.y + indicators.height + Theme.u * 10
        width: Theme.u * 190
        height: boardCol.implicitHeight + Theme.u * 22
        HeavenPlate {
            anchors.fill: parent
            dark: root.dark
            corner: 3
        }
        Column {
            id: boardCol
            x: Theme.u * 10
            y: Theme.u * 10
            width: parent.width - Theme.u * 20
            spacing: Theme.u * 5
            PxText {
                text: I18n.t("✦ ОБЪЯВЛЕНИЯ ✦", "✦ NOTICES ✦")
                kind: "title"
                color: root.dark ? root.gold : "#b5832f"
                font.bold: true
            }
            Repeater {
                model: root.notices
                Row {
                    id: notice
                    required property var modelData
                    width: boardCol.width
                    spacing: Theme.u * 4
                    PxIcon {
                        name: notice.modelData.icon
                        ink: root.ink
                        fill: root.gold
                    }
                    Column {
                        width: notice.width - Theme.u * 14
                        spacing: Theme.u
                        PxText {
                            width: parent.width
                            text: notice.modelData.title
                            color: root.ink
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        PxText {
                            width: parent.width
                            text: notice.modelData.text
                            kind: "tiny"
                            color: root.dim
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // stars that come in while locked
    PxText {
        id: toast
        visible: opacity > 0
        opacity: 0
        x: rewards.visible ? rewards.x : Theme.u * 12
        y: rewards.visible ? rewards.y + rewards.height + Theme.u * 6 : Theme.u * 60
        kind: "title"
        color: root.gold
        style: Text.Outline
        styleColor: root.outline
        SequentialAnimation {
            id: toastAnim
            NumberAnimation {
                target: toast
                property: "opacity"
                to: 1
                duration: Motion.ms(150)
            }
            PauseAnimation {
                duration: 2600
            }
            NumberAnimation {
                target: toast
                property: "opacity"
                to: 0
                duration: Motion.ms(400)
            }
        }
    }
    Connections {
        target: HeavenStars
        function onRewarded(text) {
            if (!root.primary || text.endsWith("· "))
                return;
            toast.text = text;
            toastAnim.restart();
        }
    }

    // ---- "press any key": a slanted ribbon ----
    Item {
        id: ribbon
        visible: root.primary && !root.awake && !root.lockScope.unlocking
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Math.min(root.height - height - Theme.u * 24, gate.y + gate.height + Theme.u * 10))
        width: ribbonText.implicitWidth + Theme.u * 60
        height: ribbonText.implicitHeight + Theme.u * 10
        opacity: Math.floor(root.time * 1.6) % 3 === 2 ? 0.55 : 1
        Rectangle {
            anchors.fill: parent
            color: root.dark ? Qt.rgba(0.09, 0.11, 0.24, 0.92) : Qt.rgba(1, 1, 1, 0.92)
            border.width: Theme.u
            border.color: root.dark ? root.gold : root.ink
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -0.3, 0, ribbon.height * 0.15, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            Repeater {
                model: 8
                Rectangle {
                    required property int index
                    x: index < 4 ? Theme.u * (3 + index * 6) : parent.width - Theme.u * (6 + (index - 4) * 6)
                    y: Theme.u
                    width: Theme.u * 3
                    height: parent.height - Theme.u * 2
                    color: root.gold
                }
            }
        }
        PxText {
            id: ribbonText
            anchors.centerIn: parent
            text: I18n.t("НАЖМИТЕ ЛЮБУЮ КЛАВИШУ ✦", "PRESS ANY KEY ✦")
            kind: "title"
            color: root.ink
            font.bold: true
        }
    }

    // ---- the login plate ----
    Item {
        id: cardHolder
        // stays visible while hidden: the field inside keeps the keys
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(gate.y + gate.height * 0.42 - height / 2) + (root.awake ? 0 : Theme.u * 24)
        width: card.width * root.boxScale
        height: card.height * root.boxScale
        opacity: root.awake && !root.lockScope.unlocking ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(220)
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Motion.ms(260)
                easing.type: Easing.OutBack
            }
        }
        property real shakeX: 0
        transform: Translate {
            x: cardHolder.shakeX
        }
        Keys.onEscapePressed: if (root.preview)
            Shell.lockPreview = false

        Item {
            id: card
            transformOrigin: Item.TopLeft
            scale: root.boxScale
            layer.enabled: root.boxScale !== 1
            layer.smooth: false
            width: Theme.u * 190
            height: cardCol.implicitHeight + Theme.u * 24

            HeavenPlate {
                anchors.fill: parent
                corner: 3
                dark: root.dark
                // the pass's frames: rose gold, or a hologram running through the colours
                rim: HeavenStars.frame === "rose" ? "#f0a8a0" : HeavenStars.frame === "holo" ? Qt.hsla((root.time * 0.15) % 1, 0.75, 0.68, 1) : root.dark ? "#d9a94a" : "#e8b84a"
                edge: HeavenStars.frame === "rose" ? "#9a4a52" : HeavenStars.frame === "holo" ? Qt.hsla((root.time * 0.15 + 0.5) % 1, 0.6, 0.35, 1) : root.dark ? "#5a3c12" : "#9a6a24"
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: Theme.u * 4
                    height: width
                    rotation: 45
                    color: root.gold
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: "#9a6a24"
                    x: index % 2 ? card.width - Theme.u * 10 : Theme.u * 6
                    y: index < 2 ? Theme.u * 6 : card.height - Theme.u * 10
                }
            }
            Column {
                id: cardCol
                x: Theme.u * 14
                y: Theme.u * 12
                width: card.width - Theme.u * 28
                spacing: Theme.u * 6

                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("✦ ВХОД НА НЕБЕСА ✦", "✦ ENTER HEAVEN ✦")
                    kind: "title"
                    color: root.dark ? root.gold : "#b5832f"
                    font.bold: true
                }
                Row {
                    spacing: Theme.u * 6
                    Item {
                        width: Theme.u * 34
                        height: Theme.u * 28
                        HeavenPlate {
                            anchors.fill: parent
                            pill: true
                            corner: 4
                            shadow: false
                            dark: root.dark
                            fill: root.dark ? "#1b2452" : "#eaf4ff"
                        }
                        AngelLogo {
                            anchors.centerIn: parent
                            emblemOnly: true
                            pixel: Theme.u
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u
                        PxText {
                            text: root.user
                            kind: "title"
                            color: root.ink
                            font.bold: true
                        }
                        PxText {
                            text: I18n.t("путник небес · день ", "a traveller of heaven · day ") + LockStream.days
                            color: root.dim
                        }
                    }
                }
                HeartPassword {
                    id: field
                    width: parent.width
                    heaven: true
                    dark: root.dark
                    busy: root.lockScope.busy
                    reactions: root.reactions
                    placeholder: I18n.t("пароль", "password")
                    onAccepted: root.lockScope.submit(text)
                    onHurried: root.lockScope.hurry()
                    onTyped: (length, added) => {
                        root.awake = true;
                        doze.restart();
                        root.lockScope.typed(length, added);
                    }
                    onBroke: (x, y) => {
                        const p = field.mapToItem(root, x, y);
                        burst.drop(p.x, p.y);
                    }
                    Component.onCompleted: focusField()
                }
                Item {
                    width: parent.width
                    height: Theme.u * 20
                    HeavenPlate {
                        anchors.fill: parent
                        pill: true
                        corner: 3
                        dark: root.dark
                        fill: enter.containsMouse ? "#ffe39a" : root.dark ? "#d9a94a" : "#fff0c4"
                        rim: root.gold
                    }
                    PxText {
                        anchors.centerIn: parent
                        text: root.lockScope.busy ? I18n.t("ОТКРЫВАЮ ВРАТА…", "OPENING THE GATE…") : root.willWish ? I18n.t("ВОЙТИ · МОЛИТВА ✦", "ENTER · WISH ✦") : I18n.t("ВОЙТИ", "ENTER")
                        kind: "title"
                        color: "#2f3d6e"
                        font.bold: true
                    }
                    MouseArea {
                        id: enter
                        anchors.fill: parent
                        enabled: root.awake
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.lockScope.submit(field.text);
                            field.focusField();
                        }
                    }
                }
                // the stars, and what the unlock's prayer will cost
                Row {
                    visible: Config.lock.wish
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.u * 4
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦ " + HeavenStars.stars
                        color: root.dark ? root.gold : "#b5832f"
                        font.bold: true
                    }
                    Rectangle {
                        width: wishLine.implicitWidth + Theme.u * 8
                        height: wishLine.implicitHeight + Theme.u * 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: wishMouse.containsMouse ? Qt.alpha(root.gold, 0.25) : "transparent"
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: Qt.alpha(root.gold, 0.6)
                        PxText {
                            id: wishLine
                            anchors.centerIn: parent
                            text: HeavenStars.freeWishToday ? I18n.t("молитва сегодня бесплатно ✧", "today's prayer is free ✧") : !Config.lock.wishPaid ? I18n.t("☐ молиться при входе (%1 ✦)", "☐ pray at the unlock (%1 ✦)").arg(HeavenStars.wishCost) : HeavenStars.stars >= HeavenStars.wishCost ? I18n.t("☑ молиться при входе (%1 ✦)", "☑ pray at the unlock (%1 ✦)").arg(HeavenStars.wishCost) : I18n.t("нужно %1 ✦ на молитву", "a prayer takes %1 ✦").arg(HeavenStars.wishCost)
                            kind: "tiny"
                            color: root.dim
                        }
                        MouseArea {
                            id: wishMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.awake && !HeavenStars.freeWishToday
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.lock.wishPaid = !Config.lock.wishPaid;
                                field.focusField();
                            }
                        }
                    }
                }
                PxText {
                    visible: Config.lock.wish
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("гарант 4★ через %1 · 5★ через %2", "4★ sure in %1 · 5★ sure in %2").arg(10 - LockStream.pity4).arg(90 - LockStream.pity5)
                    kind: "tiny"
                    color: root.dim
                }
                Row {
                    spacing: Theme.u * 4
                    visible: Config.lock.indicators && (root.lockScope.caps || Niri.layoutShort !== "")
                    Rectangle {
                        visible: root.lockScope.caps
                        width: capsText.implicitWidth + Theme.u * 8
                        height: Theme.u * 11
                        color: "#e86a7a"
                        PxText {
                            id: capsText
                            anchors.centerIn: parent
                            text: "CAPS LOCK"
                            kind: "tiny"
                            color: "#ffffff"
                            font.bold: true
                        }
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Niri.layoutShort !== ""
                        text: I18n.t("раскладка: ", "layout: ") + Niri.layoutShort
                        kind: "tiny"
                        color: root.dim
                    }
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    text: root.lockScope.status || (root.preview ? I18n.t("предпросмотр: пароль не проверяется, Esc — выход", "preview: the password is not checked, Esc to exit") : "")
                    color: root.lockScope.fails > 0 ? "#e86a7a" : root.dim
                }
            }
        }
    }

    // ---- the prayer: a falling star, its rarity, the gate opens ----
    property int stars: 0
    property real wishT: 0
    readonly property color starColor: stars >= 5 ? "#ffd25a" : stars === 4 ? "#c48bff" : "#7fb2ff"
    readonly property point star0: Qt.point(width * 0.86, height * 0.04)
    readonly property point star1: Qt.point(fxOrigin.x * width, fxOrigin.y * height)
    readonly property real fly: Math.min(1, wishT / 0.42)
    property string claimedText: ""
    property var got: null                  // what the prayer gave (HeavenStars.pull)
    readonly property bool willWish: Config.lock.wish && (root.preview || HeavenStars.canWish)
    Item {
        id: wish
        anchors.fill: parent
        visible: root.stars > 0 && root.wishT > 0
        // the trail
        Repeater {
            model: 16
            Rectangle {
                required property int index
                readonly property real k: Math.max(0, root.fly - index * 0.025)
                visible: root.fly < 1 && k > 0
                width: Theme.u * Math.max(1, 6 - index / 3)
                height: width
                x: Math.round((root.star0.x + (root.star1.x - root.star0.x) * k) / Theme.u) * Theme.u - width / 2
                y: Math.round((root.star0.y + (root.star1.y - root.star0.y) * k * k) / Theme.u) * Theme.u - height / 2
                color: index < 3 ? "#ffffff" : root.starColor
                opacity: 1 - index / 16
            }
        }
        // a 5★ is a pillar of gold light, a 4★ a purple glow
        Rectangle {
            visible: root.wishT >= 0.42 && root.stars >= 4
            width: gate.width * (root.stars >= 5 ? 0.5 : 0.3) * Math.min(1, (root.wishT - 0.42) * 6)
            height: root.height
            x: Math.round(root.star1.x - width / 2)
            opacity: Math.max(0, 1 - (root.wishT - 0.42) * 1.4)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Qt.alpha(root.starColor, 0.85)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
        // the result on a plate over the gate: the stars one after another, the rarity
        Item {
            id: result
            visible: root.wishT >= 0.46
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(gate.y + gate.height * 0.38 - height / 2)
            width: resultCol.implicitWidth + Theme.u * 40
            height: resultCol.implicitHeight + Theme.u * 22
            scale: Math.min(1, (root.wishT - 0.46) * 14) * root.boxScale
            HeavenPlate {
                anchors.fill: parent
                corner: 3
                dark: root.dark
                rim: root.starColor
            }
            Column {
                id: resultCol
                anchors.centerIn: parent
                spacing: Theme.u * 4
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.u * 3
                    Repeater {
                        model: root.stars
                        PxIcon {
                            required property int index
                            name: "star"
                            pixel: Theme.u * 2
                            ink: root.outline
                            fill: root.starColor
                            fill3: root.starColor
                            opacity: root.wishT >= 0.5 + index * 0.05 ? 1 : 0.15
                        }
                    }
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.stars >= 5 ? I18n.t("ЛЕГЕНДАРНАЯ МОЛИТВА", "LEGENDARY WISH") : root.stars === 4 ? I18n.t("РЕДКАЯ МОЛИТВА", "RARE WISH") : I18n.t("молитва услышана", "the wish is heard")
                    kind: "title"
                    color: root.stars >= 4 ? root.starColor : root.ink
                    style: Text.Outline
                    styleColor: root.dark ? "#0a0d22" : (root.stars >= 4 ? "#2f3d6e" : "transparent")
                    font.bold: true
                }
                // what it gave: a card for the album or a skin
                Row {
                    visible: root.got !== null && root.wishT >= 0.62
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.u * 4
                    PxIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.got ? root.got.icon : "heart"
                        pixel: Theme.u * 2
                        ink: root.outline
                        fill: root.starColor
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !root.got ? "" : (root.got.kind === "skin" ? I18n.t("скин ангела: ", "the angel's skin: ") : I18n.t("карточка: ", "card: ")) + root.got.name + (root.got.fresh ? I18n.t("  · НОВОЕ!", "  · NEW!") : I18n.t("  · повтор +%1 ✦", "  · duplicate +%1 ✦").arg(root.got.refund))
                        color: root.ink
                        font.bold: root.got && root.got.fresh
                    }
                }
                PxText {
                    visible: root.claimedText !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.claimedText
                    color: root.dark ? root.gold : "#b5832f"
                }
            }
        }
    }
    // without the prayer, the reward is said on its own
    PxText {
        visible: root.claimedText !== "" && root.stars === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(gate.y + gate.height * 0.3)
        text: root.claimedText
        kind: "title"
        color: root.gold
        style: Text.Outline
        styleColor: root.outline
    }
    NumberAnimation {
        id: wishAnim
        target: root
        property: "wishT"
        from: 0
        to: 1
        easing.type: Easing.Linear
    }
    Timer {
        id: impact
        onTriggered: {
            flashAnim.restart();
            burst.burst(root.star1.x, root.star1.y, root.stars >= 5 ? 56 : root.stars === 4 ? 36 : 22, Theme.u * (root.stars >= 5 ? 14 : 9));
        }
    }
    Timer {
        id: openLater
        onTriggered: openAnim.restart()
    }

    // a wrong password: a flash of lightning
    Rectangle {
        id: lightning
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
    }
    HeartBurst {
        id: burst
        anchors.fill: parent
        poolSize: 72
        shapes: ["sparkle", "sparkleStar", "heartSmall"]
        colors: root.stars >= 5 ? ["#ffffff", "#ffd25a", "#ffe9a0"] : root.stars === 4 ? ["#ffffff", "#c48bff", "#e2c8ff"] : ["#ffffff", "#fff2b8", "#e8b84a", "#a9cdf2"]
        gravity: 0.2
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.lockScope.hurry();
            root.awake = true;
            doze.restart();
            angel.poke();
            field.focusField();
        }
    }
    // nothing typed for a while: back to "press any key"
    Timer {
        id: doze
        interval: 25000
        onTriggered: if (field.text === "" && !root.lockScope.busy)
            root.awake = false
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 3
        NumberAnimation {
            target: cardHolder
            property: "shakeX"
            to: Theme.u * 6
            duration: Motion.ms(40)
        }
        NumberAnimation {
            target: cardHolder
            property: "shakeX"
            to: -Theme.u * 6
            duration: Motion.ms(40)
        }
        NumberAnimation {
            target: cardHolder
            property: "shakeX"
            to: 0
            duration: Motion.ms(40)
        }
    }
    SequentialAnimation {
        id: stormAnim
        NumberAnimation {
            target: root
            property: "storm"
            to: 1
            duration: Motion.ms(120)
        }
        PauseAnimation {
            duration: Motion.ms(500)
        }
        NumberAnimation {
            target: root
            property: "storm"
            to: 0
            duration: Motion.ms(700)
        }
    }
    SequentialAnimation {
        id: flashAnim
        PropertyAction {
            target: lightning
            property: "opacity"
            value: 0.65
        }
        PauseAnimation {
            duration: 50
        }
        PropertyAction {
            target: lightning
            property: "opacity"
            value: 0
        }
        PauseAnimation {
            duration: 70
        }
        PropertyAction {
            target: lightning
            property: "opacity"
            value: 0.4
        }
        PauseAnimation {
            duration: 40
        }
        PropertyAction {
            target: lightning
            property: "opacity"
            value: 0
        }
    }
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: gate
            property: "open"
            from: 0
            to: 1
            duration: Motion.ms(600)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "glow"
            from: 0
            to: 1
            duration: Motion.ms(700)
            easing.type: Easing.InQuad
        }
    }

    Timer {
        id: demoKeys
        interval: 85
        repeat: true
        property string pending: ""
        onTriggered: {
            if (pending === "") {
                stop();
                root.lockScope.submit(field.text);
                return;
            }
            field.text += pending[0];
            pending = pending.slice(1);
        }
    }
    Connections {
        target: root.lockScope
        function onDemo(text) {
            if (!root.primary)
                return;
            root.awake = true;
            field.clear();
            demoKeys.pending = text;
            demoKeys.restart();
        }
        function onShake() {
            shakeAnim.restart();
            if (!root.reactions || !root.primary) {
                field.clear();
                return;
            }
            field.fail();
            stormAnim.restart();
            flashAnim.restart();
        }
        function onSuccess() {
            if (!root.reactions)
                return;
            field.win();
            // the day's login reward and the prayer: the lock already took them (Lock.qml)
            root.claimedText = "";
            const r = root.lockScope.claimed;
            if (root.primary && r) {
                rewards.justClaimed = -1;
                rewards.justClaimed = LockStream.cycleDay;
                root.claimedText = I18n.t("награда за вход: +%1 ✦", "login reward: +%1 ✦").arg(r.n);
            }
            if (root.primary && root.lockScope.wished) {
                root.got = root.lockScope.wished;
                root.stars = root.got.stars;
                const d = root.stars >= 5 ? 2600 : root.stars === 4 ? 1900 : 1500;
                wishAnim.duration = d;
                wishAnim.restart();
                impact.interval = Math.round(d * 0.42);
                impact.restart();
                openLater.interval = Math.round(d * 0.72);
                openLater.restart();
                root.lockScope.hold = Math.max(root.lockScope.hold, d + 250);
                return;
            }
            openAnim.restart();
            const p = Qt.point(root.fxOrigin.x * root.width, root.fxOrigin.y * root.height);
            burst.burst(p.x, p.y, root.primary ? 40 : 16, Theme.u * 9);
        }
        function onTyped(length, added) {
            if (!root.reactions || !root.primary || !added)
                return;
            const p = field.mapToItem(root, field.caretX, 0);
            burst.pop(p.x, p.y);
        }
    }
}
