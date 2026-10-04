pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../../../services/AngelLines.js" as Lines

// Simple settings view, the first screen: everyday actions and eight big tiles, in the
// settings skin (Config.settingsUi.skin — Windose desktop or Stream studio with
// a LIVE header and a chat of tips on the side). Everything sits on an even grid: every
// "Everyday" button the same size (4 × 2), every tile the same size (4 × 2).
// Every section is in the sidebar; sub-pages open from the links on top of a page.
PxPage {
    id: page

    readonly property string skin: Config.settingsUi.skin === "stream" ? "stream" : "windose"
    readonly property bool stream: skin === "stream"
    // Windose: on lilac checks the heading is a pink sticker colour, the subtitle full ink
    headingColor: skin === "windose" ? Theme.windoseTitle : Theme.streamLive
    subtitleColor: Theme.textDim
    heading: stream ? "" : I18n.t("Что настроить?", "What would you like to change?")
    subtitle: stream ? "" : I18n.t("Нажми на плитку или напиши в поиске слева своими словами — «сделать крупнее», «обои», «звук». Подробности открываются стрелками «›» вверху страниц.", "Pick a tile or type in the search on the left in your own words — “bigger”, “wallpaper”, “sound”. Details open from the “›” links at the top of a page.")

    readonly property var tiles: [
        {
            "id": "wallpaper",
            "icon": "image",
            "label": I18n.t("Обои", "Wallpaper"),
            "hint": I18n.t("картинка на рабочем столе", "the desktop picture")
        },
        {
            "id": "appearance",
            "icon": "palette",
            "label": I18n.t("Цвета и тема", "Colours and theme"),
            "hint": I18n.t("светлая или тёмная, любимый цвет", "light or dark, your colour")
        },
        {
            "id": "bar",
            "icon": "window",
            "label": I18n.t("Панель", "Taskbar"),
            "hint": I18n.t("«Пуск», кнопки окон, часы", "Start, window buttons, clock")
        },
        {
            "id": "sound",
            "icon": "speaker",
            "label": I18n.t("Звук", "Sound"),
            "hint": I18n.t("громкость и микрофон", "volume and microphone")
        },
        {
            "id": "monitor",
            "icon": "monitor",
            "label": I18n.t("Экран", "Display"),
            "hint": I18n.t("разрешение, частота, мониторы", "resolution, refresh, monitors")
        },
        {
            "id": "keyboard",
            "icon": "keyboard",
            "label": I18n.t("Клавиатура и мышь", "Keyboard and mouse"),
            "hint": I18n.t("языки, скорость мыши", "languages, mouse speed")
        },
        {
            "id": "windows",
            "icon": "layers",
            "label": I18n.t("Окна", "Windows"),
            "hint": I18n.t("как закрываются и открываются", "how they open and close")
        },
        {
            "id": "more",
            "icon": "grid",
            "label": I18n.t("Ещё", "More"),
            "hint": I18n.t("все остальные разделы", "every other section")
        }
    ]

    readonly property var fallbackFrequent: [
        {
            "id": "sound",
            "icon": "speaker",
            "label": I18n.t("Громкость", "Volume")
        },
        {
            "id": "shortcuts",
            "icon": "keyboard",
            "label": I18n.t("Горячие клавиши", "Shortcuts")
        },
        {
            "id": "widgets",
            "icon": "layers",
            "label": I18n.t("Виджеты на столе", "Desktop widgets")
        }
    ]
    // the three most visited pages (not wallpaper or updates: they have their own buttons);
    // the defaults fill up while there is no history yet — always three, so the grid is even
    readonly property var frequent: {
        const usage = Config.settingsUi.usage || {};
        const all = Shell.settingsView ? Shell.settingsView.allPages : [];
        const top = Object.keys(usage).filter(id => id !== "wallpaper" && id !== "updates" && usage[id] >= 2 && all.some(p => p.id === id)).sort((a, b) => usage[b] - usage[a]).slice(0, 3).map(id => {
            const p = all.find(x => x.id === id);
            return {
                "id": id,
                "icon": p.icon,
                "label": p.label
            };
        });
        for (const f of fallbackFrequent)
            if (top.length < 3 && !top.some(t => t.id === f.id))
                top.push(f);
        return top;
    }
    readonly property var everyday: [
        {
            "icon": "image",
            "label": I18n.t("Сменить обои", "Change wallpaper"),
            "run": () => Shell.settingsPage = "wallpaper"
        },
        {
            "icon": Theme.dark ? "sun" : "moon",
            "label": Theme.dark ? I18n.t("Светлая тема", "Light theme") : I18n.t("Тёмная тема", "Dark theme"),
            "run": () => Config.appearance.mode = Theme.dark ? "light" : "dark"
        },
        {
            "icon": "plus",
            "label": I18n.t("Крупнее", "Bigger"),
            "off": Config.appearance.px >= 4,
            "run": () => Config.appearance.px = Math.min(4, Config.appearance.px + 1)
        },
        {
            "icon": "minus",
            "label": I18n.t("Мельче", "Smaller"),
            "off": Config.appearance.px <= 1,
            "run": () => Config.appearance.px = Math.max(1, Config.appearance.px - 1)
        },
        // Updates: one click away
        {
            "icon": "download",
            "label": Updates.available ? I18n.t("Обновление ♡", "Update ♡") : I18n.t("Обновление", "Update"),
            "accent": Updates.available,
            "run": () => Shell.settingsPage = "updates"
        }
    ].concat(frequent.map(f => ({
                "icon": f.icon,
                "label": f.label,
                "run": () => Shell.settingsPage = f.id
            })))

    // the stream's chat: tips from the angel, signed by viewers; a click opens the page
    readonly property var nicks: ["ame_fan_01", "kangel♡", "p-chan", "jine_user", "OMGkawaii", "angel_watcher", "pixel_heart", "2000s_kid", "needy_dev", I18n.exe("overdose")]
    readonly property var chatColors: [Theme.ngoPink, Theme.ngoLilac, Theme.ngoMint]
    property var chat: []
    function refillChat() {
        const tips = Lines.tips.slice();
        const out = [];
        while (out.length < 7 && tips.length) {
            const t = tips.splice(Math.floor(Math.random() * tips.length), 1)[0];
            out.push({
                "nick": nicks[Math.floor(Math.random() * nicks.length)],
                "text": I18n.t(t[0], t[1]),
                "page": t[2] || ""
            });
        }
        chat = out;
    }
    Component.onCompleted: refillChat()

    // ---- the first time: which skin? ----
    Column {
        visible: !Config.settingsUi.skinChosen
        width: parent.width
        spacing: Theme.u * 3
        PxText {
            text: I18n.t("Выбери, как будут выглядеть настройки", "Pick how Settings look")
            kind: "title"
            color: page.stream ? Theme.streamText : Theme.text
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Потом можно сменить в «Тема и цвета» → «Вид настроек».", "You can change it later in Theme and colours → Settings look.")
        }
        Row {
            spacing: Theme.u * 4
            Repeater {
                model: ["classic", "windose", "stream", "goldengate"]
                SettingsSkinCard {
                    required property string modelData
                    skin: modelData
                    width: Math.min(Theme.u * 100, (page.innerWidth - Theme.u * 12) / 4)
                }
            }
        }
    }

    // ---- stream: the LIVE header ----
    Rectangle {
        visible: page.stream
        width: parent.width
        height: Theme.u * 24
        radius: Theme.u * 3
        color: Theme.streamPanel
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.streamLive, 0.5)
        Row {
            x: Theme.u * 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 5
            Rectangle {
                width: liveText.implicitWidth + Theme.u * 10
                height: Theme.u * 13
                radius: height / 2
                color: Theme.streamLive
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    id: dot
                    x: Theme.u * 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.u * 3
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: page.visible && !Motion.still
                        alwaysRunToEnd: true
                        NumberAnimation {
                            to: 0.2
                            duration: Motion.ms(600)
                        }
                        NumberAnimation {
                            to: 1
                            duration: Motion.ms(600)
                        }
                    }
                }
                PxText {
                    id: liveText
                    x: Theme.u * 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "LIVE"
                    font.bold: true
                    color: "#ffffff"
                }
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("настраиваем angelOS вместе ♡", "setting up angelOS together ♡")
                kind: "title"
                color: Theme.streamText
            }
        }
        PxText {
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 6
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("студия настроек", "settings studio")
            color: Theme.streamDim
        }
    }

    // A little window on the Windose desktop: soft colours, misaligned stickers,
    // and a hint of the internet angel behind the settings folders.
    Rectangle {
        visible: page.skin === "windose"
        width: parent.width
        height: Theme.u * 55
        color: Theme.mix(Theme.windosePaper, Theme.windoseLavender, 0.1)
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.windoseLine
        clip: true

        Rectangle {
            x: Theme.u * 5
            y: Theme.u * 5
            width: parent.width - Theme.u * 10
            height: parent.height - Theme.u * 10
            color: Theme.windoseSticker
            border.width: Math.max(1, Theme.u / 2)
            border.color: Theme.windoseLine
            Rectangle {
                width: parent.width
                height: Theme.u * 8
                color: Theme.mix(Theme.windoseRose, Theme.windosePaper, 0.25)
                PxText {
                    x: Theme.u * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "♡  " + I18n.exe("p-chan")
                    kind: "tiny"
                    color: Theme.windoseInk
                }
                PxText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✦  □  ×"
                    kind: "tiny"
                    color: Theme.windoseInk
                }
            }
            Column {
                x: Theme.u * 6
                y: Theme.u * 13
                width: parent.width - Theme.u * (parent.width >= Theme.u * 260 ? 116 : 12)
                spacing: Theme.u * 3
                PxText {
                    width: parent.width
                    text: I18n.t("ИНТЕРНЕТ-АНГЕЛ В СЕТИ ♡", "INTERNET ANGEL ONLINE ♡")
                    kind: "big"
                    font.bold: true
                    color: Theme.windoseTitle
                    elide: Text.ElideRight
                }
                PxText {
                    width: parent.width
                    text: I18n.t("Открой окно. Поменяй реальность.", "Open a window. Change your reality.")
                    kind: "body"
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                visible: parent.width >= Theme.u * 260
                anchors.right: parent.right
                anchors.rightMargin: Theme.u * 9
                y: Theme.u * 12
                width: Theme.u * 76
                height: Theme.u * 35
                rotation: 5
                color: Theme.windosePaper
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.windoseLine
                Rectangle {
                    width: parent.width
                    height: Theme.u * 6
                    color: Theme.windoseLavender
                    PxText {
                        x: Theme.u * 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.exe("love") + "  ♡"
                        kind: "tiny"
                        color: Theme.windoseInk
                    }
                }
                PxIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Theme.u * 3
                    name: "heart"
                    pixel: Theme.u * 2
                    ink: Theme.windoseInk
                    fill: Theme.windoseRose
                    fill2: Theme.windoseLavender
                }
            }
            Rectangle {
                visible: parent.width >= Theme.u * 260
                anchors.right: parent.right
                anchors.rightMargin: Theme.u * 5
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.u * 2
                width: Theme.u * 48
                height: Theme.u * 12
                rotation: -5
                color: Theme.windoseRose
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.windoseLine
                PxText {
                    anchors.centerIn: parent
                    text: "✦  LOOK AT ME  ✦"
                    kind: "tiny"
                    font.bold: true
                    color: Theme.windoseInk
                }
            }
        }
    }

    // ---- the content: (the stream's chat on the right) ----
    Flow {
        width: parent.width
        spacing: Theme.u * 5

        Column {
            id: main
            width: page.stream && parent.width >= Theme.u * 380 ? Math.round(parent.width * 0.68) : parent.width
            spacing: Theme.u * 6

            // the chosen logo (Bar → Logo) greets you here too
            AngelLogo {
                visible: !page.stream
                pixel: Theme.u
            }

            PxText {
                text: page.stream ? I18n.t("Донаты-действия", "Quick actions") : "✧ " + I18n.t("Частое", "Everyday")
                kind: "title"
                color: page.stream ? Theme.streamText : Theme.text
            }
            Grid {
                id: quick
                width: parent.width
                columns: width >= Theme.u * 260 ? 4 : 2
                spacing: Theme.u * 3
                readonly property real cellW: Math.floor((width - (columns - 1) * spacing) / columns)
                Repeater {
                    model: page.everyday
                    SkinButton {
                        required property var modelData
                        required property int index
                        skin: page.skin
                        tint: index
                        width: quick.cellW
                        height: Theme.u * (page.skin === "windose" ? 17 : 16)
                        icon: modelData.icon
                        text: modelData.label
                        accent: !!modelData.accent
                        enabled: !modelData.off
                        onClicked: modelData.run()
                    }
                }
            }

            PxText {
                text: page.stream ? I18n.t("Суперчаты: разделы", "Super chats: sections") : "✧ " + I18n.t("Разделы", "Sections")
                kind: "title"
                color: page.stream ? Theme.streamText : Theme.text
            }
            Grid {
                id: grid
                width: parent.width
                columns: width >= Theme.u * 240 ? 4 : 2
                spacing: Theme.u * (page.skin === "windose" ? 6 : 4)
                readonly property real tileW: Math.floor((width - (columns - 1) * spacing) / columns)
                readonly property real tileH: Theme.u * (page.skin === "windose" ? 76 : page.stream ? 48 : 60)
                Repeater {
                    model: page.tiles
                    SkinTile {
                        required property var modelData
                        required property int index
                        skin: page.skin
                        tint: index
                        width: grid.tileW
                        height: grid.tileH
                        icon: modelData.icon
                        text: modelData.label
                        hint: modelData.hint
                        onClicked: Shell.settingsPage = modelData.id
                    }
                }
            }
        }

        // the chat: the angel's tips as viewers' messages; type to ask her
        Rectangle {
            visible: page.stream
            width: main.width === parent.width ? parent.width : parent.width - main.width - parent.spacing
            height: Math.max(main.height, Theme.u * 160)
            radius: Theme.u * 3
            color: Theme.streamPanel
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(Theme.ngoLilac, 0.5)
            clip: true
            Column {
                x: Theme.u * 4
                y: Theme.u * 4
                width: parent.width - Theme.u * 8
                spacing: Theme.u * 3
                Row {
                    spacing: Theme.u * 2
                    PxIcon {
                        name: "chat"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PxText {
                        text: I18n.t("чат", "chat")
                        font.bold: true
                        color: Theme.streamText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PxText {
                        text: "  ↻"
                        color: Theme.streamDim
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.u * 2
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.refillChat()
                        }
                    }
                }
                Repeater {
                    model: page.chat
                    Column {
                        id: msg
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: Theme.u
                        PxText {
                            text: msg.modelData.nick
                            kind: "tiny"
                            font.bold: true
                            color: page.chatColors[msg.index % page.chatColors.length]
                        }
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: msg.modelData.text
                            kind: "tiny"
                            color: msgMouse.containsMouse && msg.modelData.page ? Theme.ngoPink : Theme.streamText
                            MouseArea {
                                id: msgMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !!msg.modelData.page
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Shell.settingsPage = msg.modelData.page
                            }
                        }
                    }
                }
                PxField {
                    width: parent.width
                    icon: "heart"
                    placeholder: I18n.t("спросить ангела…", "ask the angel…")
                    onAccepted: {
                        const q = text;
                        text = "";
                        Angel.answer(q);
                    }
                }
            }
        }
    }
}
