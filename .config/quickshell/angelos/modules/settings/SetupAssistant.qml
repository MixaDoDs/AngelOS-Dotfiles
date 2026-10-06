pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "../y2k/AngelSpriteMini.js" as AngelMini

// The setup wizard's questions (SetupWizard.qml hosts them: every screen on the first run,
// a window afterwards). One question a screen, like macOS's Setup Assistant: a picture, a
// big title, a line under it, the answer as big cards — or the group from Settings itself,
// found through the settings tree — and "Back" / "Continue" under it. Changing steps fades
// and slides a little; nothing moves while motion is off. Enter continues.
Item {
    id: root

    property var wizard: null
    readonly property var step: wizard ? wizard.cur : null
    readonly property int index: wizard ? wizard.step : 0
    readonly property int count: wizard ? wizard.steps.length : 1
    // the groups from Settings shown here wear Settings' Windows 11 look: cards
    readonly property bool fluent: true
    readonly property string settingsSkin: "classic"
    // the answer on screen (tests look into it)
    readonly property alias answer: body

    // the step on screen: it follows `step` once the old one has faded out
    property var shown: null
    property int dir: 1
    property int shownIndex: 0
    readonly property string stepId: step ? step.id : ""
    onStepIdChanged: {
        if (!step)
            return;
        if (!shown) {
            shown = step;
            shownIndex = index;
            return;
        }
        dir = index >= shownIndex ? 1 : -1;
        swap.restart();
    }
    SequentialAnimation {
        id: swap
        NumberAnimation {
            target: page
            property: "opacity"
            to: 0
            duration: Motion.ms(140)
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                root.shown = root.step;
                root.shownIndex = root.index;
                slide.x = root.dir * Theme.u * 12;
                scroll.contentY = 0;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: page
                property: "opacity"
                to: 1
                duration: Motion.ms(300)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: slide
                property: "x"
                to: 0
                duration: Motion.ms(340)
                easing.type: Easing.OutCubic
            }
        }
    }

    readonly property int column: Math.min(width - Theme.u * 24, Theme.u * 300)

    // ---- the question ----
    PxScroll {
        id: scroll
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.u * 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.column + Theme.u * 8
        contentHeight: Math.max(height, page.implicitHeight + Theme.u * 16)

        Item {
            id: page
            width: root.column
            x: Theme.u * 4
            // centred while it fits, from the top once it scrolls
            y: Math.max(Theme.u * 8, (scroll.height - implicitHeight) / 2)
            implicitHeight: col.implicitHeight
            transform: Translate {
                id: slide
            }

            Column {
                id: col
                width: parent.width
                spacing: Theme.u * 6

                // the picture: angelOS itself on the first screen, the step's icon after
                AngelLogo {
                    visible: !!root.shown && root.shown.id === "hello"
                    anchors.horizontalCenter: parent.horizontalCenter
                    pixel: Theme.u * 2
                    fontSize: Theme.sizeHuge
                }
                PxIcon {
                    visible: !!root.shown && root.shown.id !== "hello"
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.shown ? root.shown.icon : "heart"
                    pixel: Theme.u * 4
                }
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    kind: "big"
                    color: Theme.dark ? Theme.accent : Theme.edge
                    text: root.shown ? root.shown.title : ""
                }
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    dim: true
                    text: root.shown ? root.shown.text : ""
                }
                Item {
                    width: 1
                    height: Theme.u * 2
                }
                Loader {
                    id: body
                    width: parent.width
                    sourceComponent: !root.shown ? null : ({
                            "hello": hello,
                            "game": game,
                            "mac": mac,
                            "screens": screens,
                            "look": look,
                            "motion": motion,
                            "ready": ready
                        })[root.shown.id] || (root.shown.blocks ? blocks : null)
                }
            }
        }
    }

    // ---- Back · progress · Continue ----
    Item {
        id: footer
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.column
        height: Math.max(backButton.implicitHeight, nextButton.implicitHeight)

        PxButton {
            id: backButton
            anchors.left: parent.left
            visible: root.index > 0
            kind: "title"
            icon: "arrowLeft"
            text: I18n.t("Назад", "Back")
            onClicked: root.wizard.back()
        }
        Row {
            anchors.centerIn: parent
            spacing: Theme.u * 2
            Repeater {
                model: root.count
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: index === root.index ? Theme.u * 8 : Theme.u * 3
                    height: Theme.u * 3
                    color: index === root.index ? Theme.accent : index < root.index ? Theme.mix(Theme.accent, Theme.face, 0.5) : Theme.mix(Theme.textDim, Theme.face, 0.4)
                    Behavior on width {
                        NumberAnimation {
                            duration: Motion.ms(200)
                        }
                    }
                }
            }
        }
        PxButton {
            id: nextButton
            anchors.right: parent.right
            kind: "title"
            accent: true
            text: root.index >= root.count - 1 ? I18n.t("Начать работу", "Start using angelOS") : I18n.t("Продолжить", "Continue")
            onClicked: root.wizard.next()
        }
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: if (root.wizard)
            root.wizard.next()
    }
    Shortcut {
        sequence: "Alt+Left"
        onActivated: if (root.wizard)
            root.wizard.back()
    }

    // ---- the answers ----

    // a big card to pick: a picture on top, its name, a line about it
    component Choice: Item {
        id: choice
        property string label: ""
        property string hint: ""
        property bool checked: false
        default property alias picture: pic.data
        signal picked
        implicitHeight: pic.height + name.implicitHeight + about.implicitHeight + Theme.u * 16
        // as tall as the tallest card of its row
        height: parent && parent.cardHeight ? parent.cardHeight : implicitHeight
        PxBox {
            anchors.fill: parent
            color: choice.checked ? Theme.mix(Theme.face, Theme.accent, 0.25) : hover.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
            sunken: choice.checked
        }
        Item {
            id: pic
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.u * 5
            width: parent.width - Theme.u * 10
            height: childrenRect.height
        }
        PxText {
            id: name
            anchors.top: pic.bottom
            anchors.topMargin: Theme.u * 4
            x: Theme.u * 5
            width: parent.width - Theme.u * 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            kind: "title"
            font.bold: choice.checked
            text: (choice.checked ? "♡ " : "") + choice.label
        }
        PxText {
            id: about
            anchors.top: name.bottom
            anchors.topMargin: Theme.u * 2
            x: Theme.u * 5
            width: parent.width - Theme.u * 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: choice.hint
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }
    // a row of cards as wide as the column, all the same height
    component Choices: Row {
        id: row
        property int n: 2
        readonly property int cardWidth: Math.floor((width - spacing * (n - 1)) / n)
        readonly property real cardHeight: {
            let h = 0;
            for (const c of children)
                if (c.picked !== undefined)
                    h = Math.max(h, c.implicitHeight);
            return h;
        }
        spacing: Theme.u * 4
    }

    Component {
        id: hello
        Choices {
            n: 2
            Repeater {
                model: [["ru", "Русский", "интерфейс по-русски"], ["en", "English", "the interface in English"]]
                Choice {
                    required property var modelData
                    width: parent.cardWidth
                    label: modelData[1]
                    hint: modelData[2]
                    checked: Config.appearance.language === modelData[0]
                    onPicked: Config.appearance.language = modelData[0]
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        kind: "huge"
                        text: modelData[0] === "ru" ? "Аа" : "Aa"
                    }
                }
            }
        }
    }

    // coming from a Mac: the Golden Gate skin, and its Mac shortcuts only if asked for
    Component {
        id: mac
        Column {
            spacing: Theme.u * 6
            Choices {
                width: parent.width
                n: 2
                Choice {
                    width: parent.cardWidth
                    label: I18n.t("Да, как на Mac", "Yes, like a Mac")
                    hint: I18n.t("Golden Gate: строка меню, Dock, Spotlight, «Системные настройки», шрифт и курсор как на Mac. Игра остаётся.", "Golden Gate: the menu bar, the Dock, Spotlight, System Settings, a Mac's font and pointer. The game stays.")
                    checked: Config.settingsUi.skin === "goldengate"
                    onPicked: {
                        Config.settingsUi.skin = "goldengate";
                        Config.settingsUi.skinChosen = true;
                    }
                    GoldenGateMini {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.u * 64
                        height: Theme.u * 40
                    }
                }
                Choice {
                    width: parent.cardWidth
                    label: I18n.t("Нет, angelOS как есть", "No, angelOS as it is")
                    hint: I18n.t("Пиксельный стол, панель задач и «Пуск» angelOS.", "angelOS's pixel desktop, taskbar and Start.")
                    checked: Config.settingsUi.skin !== "goldengate"
                    onPicked: {
                        if (Config.settingsUi.skin === "goldengate")
                            Config.settingsUi.skin = "classic";
                        Config.settingsUi.skinChosen = true;
                    }
                    AngelLogo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        pixel: Theme.u
                        fontSize: Theme.sizeBig
                    }
                }
            }
            // offered, never imposed: off unless switched on here or in Settings
            PxToggle {
                visible: Config.settingsUi.skin === "goldengate"
                width: parent.width
                // (spelt out: the pixel font has no ⌘)
                text: I18n.t("Сочетания клавиш как на Mac: Command — это клавиша Windows (Win+Q завершить, Win+W закрыть окно, Win+Пробел Spotlight, Ctrl+↑ Mission Control…)", "Mac keyboard shortcuts: Command is the Windows key (Win+Q quit, Win+W close window, Win+Space Spotlight, Ctrl+↑ Mission Control…)")
                checked: Config.mac.keys
                onToggled: v => Config.mac.keys = v
            }
        }
    }

    // the game over the desktop, or plain dotfiles (Story.setEnabled; the installer asks too)
    Component {
        id: game
        Choices {
            n: 2
            Choice {
                width: parent.cardWidth
                label: I18n.t("С игрой", "With the game")
                hint: I18n.t("В углу живёт ангел, а что будет дальше, зависит от твоих выборов. За достижения открываются райские вещи (Крылья, Арфа, Glitter…). Выйти можно в любой момент: angelos game off или Mod+Ctrl+Shift+Escape.", "An angel lives in the corner, and what happens next depends on your choices. Achievements open heaven's things (Wings, Harp, Glitter…). Leave any time: angelos game off or Mod+Ctrl+Shift+Escape.")
                checked: Config.game.enabled !== false
                onPicked: Story.setEnabled(true)
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    bitmap: AngelMini.up
                    pixel: Math.max(1, Theme.u * 2)
                    ink: Theme.dark ? Theme.text : Theme.edge
                    body: "#ffd9c7"
                    fill: Theme.accent
                    fill2: "#3a1a46"
                    fill3: Theme.dark ? "#ffe07a" : "#f5c542"
                    light: "#ffffff"
                    bad: "#d8203a"
                }
            }
            Choice {
                width: parent.cardWidth
                label: I18n.t("Просто рабочий стол", "Just the desktop")
                hint: I18n.t("Панель, окна и темы — без ангела, демоницы, новеллы и ада, а всё райское открыто сразу. Игру можно включить потом.", "The bar, windows and themes — no angel, demon, novel or hell, and all of heaven's things open at once. The game can be turned on later.")
                checked: Config.game.enabled === false
                onPicked: Story.setEnabled(false)
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "window"
                    pixel: Theme.u * 4
                }
            }
        }
    }

    // the main screen (Outputs.setPrimary, as in Settings → Display): each screen drawn to scale
    Component {
        id: screens
        Choices {
            id: screensRow
            n: Math.max(1, Shell.screens.length)
            readonly property real tallest: Math.max(...Shell.screens.map(s => s.height / Math.max(1, s.width)))
            Repeater {
                model: Shell.screens
                Choice {
                    id: screenCard
                    required property var modelData
                    width: screensRow.cardWidth
                    label: modelData.name
                    hint: modelData.width + " × " + modelData.height + (modelData.model && modelData.model !== "Unknown" ? " · " + modelData.model : "")
                    checked: Shell.primaryName === modelData.name
                    onPicked: {
                        Outputs.setPrimary(modelData.name);
                        // the first run's fresh desk goes along (later on, a desk set by hand stays)
                        if (Shell.setupFirstRun)
                            DesktopWidgets.moveAllTo(modelData.name);
                    }
                    Item {
                        readonly property real box: Math.min(parent.width, Theme.u * 70)
                        width: parent.width
                        height: box * screensRow.tallest
                        PxBox {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.box * Math.min(1, 1 / Math.max(1, screenCard.modelData.height / screenCard.modelData.width / screensRow.tallest))
                            height: width * screenCard.modelData.height / Math.max(1, screenCard.modelData.width)
                            color: screenCard.checked ? Theme.mix(Theme.face, Theme.accent, 0.45) : Theme.sunken
                            PxIcon {
                                anchors.centerIn: parent
                                name: screenCard.checked ? "star" : "monitor"
                                pixel: Theme.u * 2
                            }
                        }
                    }
                }
            }
        }
    }

    // groups straight from Settings (the step's `blocks`), found through the settings tree
    Component {
        id: blocks
        Column {
            spacing: Theme.u * 6
            Repeater {
                model: root.shown ? root.shown.blocks : []
                Loader {
                    id: part
                    required property string modelData
                    readonly property var info: SettingsTree.blockPart(modelData)
                    width: parent.width
                    Component.onCompleted: setSource(info.file, {
                        "embedded": true,
                        "only": info.only,
                        "loose": false,
                        "partOf": "setup",
                        "unfold": info.only
                    })
                }
            }
            // where the rest of it is: the page the tree puts these groups on
            PxText {
                readonly property var where: root.shown && root.shown.blocks ? SettingsTree.blockPart(root.shown.blocks[0]).page : ""
                readonly property var cat: where ? SettingsTree.categoryOf(where) : null
                visible: !!where
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: I18n.t("Остальное — в Настройках: ", "The rest is in Settings: ") + (cat ? cat.label + " › " : "") + (where && SettingsTree.page(where) ? SettingsTree.page(where).label : "")
            }
        }
    }

    // light, dark or by the time of day: the mode, each card drawn in its own palette
    Component {
        id: look
        Choices {
            n: 3
            Repeater {
                model: [["light", I18n.t("Светлая", "Light"), I18n.t("днём и при ярком свете", "for daylight")], ["dark", I18n.t("Тёмная", "Dark"), I18n.t("вечером и в темноте", "for evenings and dim rooms")], ["auto", I18n.t("Авто", "Auto"), I18n.t("днём светлая, вечером тёмная", "light by day, dark by night")]]
                Choice {
                    id: lookCard
                    required property var modelData
                    width: parent.cardWidth
                    label: modelData[1]
                    hint: modelData[2]
                    checked: Config.appearance.mode === modelData[0]
                    onPicked: Config.appearance.mode = modelData[0]
                    Item {
                        width: parent.width
                        height: Math.round(width * 0.6)
                        ThemePic {
                            anchors.fill: parent
                            pal: Theme.paletteFor(lookCard.modelData[0] !== "light")
                        }
                        // auto: the light half over the dark one
                        Item {
                            visible: lookCard.modelData[0] === "auto"
                            width: Math.round(parent.width / 2)
                            height: parent.height
                            clip: true
                            ThemePic {
                                width: lookCard.width - Theme.u * 10
                                height: parent.height
                                pal: Theme.paletteFor(false)
                            }
                        }
                    }
                }
            }
        }
    }
    // a little desktop in a palette: the desk, a window with its title, text, the bar
    component ThemePic: Item {
        id: pic
        property var pal: ({})
        clip: true
        Rectangle {
            anchors.fill: parent
            color: pic.pal.desk || "#000000"
            border.width: 1
            border.color: Qt.alpha(pic.pal.text || "#ffffff", 0.3)
        }
        Rectangle {
            x: parent.width * 0.14
            y: parent.height * 0.14
            width: parent.width * 0.62
            height: parent.height * 0.56
            color: pic.pal.face || "#202020"
            Rectangle {
                width: parent.width
                height: Math.max(2, parent.height * 0.18)
                color: pic.pal.accent || "#ff69b4"
            }
            Column {
                x: parent.width * 0.1
                y: parent.height * 0.32
                spacing: Math.max(1, parent.height * 0.08)
                Repeater {
                    model: [0.7, 0.5, 0.6]
                    Rectangle {
                        required property real modelData
                        width: pic.width * 0.62 * 0.8 * modelData
                        height: Math.max(1, pic.height * 0.04)
                        color: pic.pal.text || "#ffffff"
                        opacity: 0.8
                    }
                }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(2, parent.height * 0.12)
            color: pic.pal.faceAlt || "#303030"
        }
    }

    // how much moves (Motion.set — Settings → Theme → Motion, `angelos motion`)
    Component {
        id: motion
        Choices {
            n: 3
            Repeater {
                model: [["full", "sparkle", I18n.t("Полное", "Full"), I18n.t("всё как задумано: переходы, эффекты, ад во всей красе", "everything as designed: transitions, effects, hell in all its glory")], ["calm", "heart", I18n.t("Спокойное", "Calm"), I18n.t("без вспышек, тряски экрана и резких звуков", "no flashes, screen shaking or sudden loud sounds")], ["off", "pause", I18n.t("Выключено", "Off"), I18n.t("никаких анимаций — для слабых машин и тех, кого укачивает", "no animation at all — for slow machines and anyone motion makes queasy")]]
                Choice {
                    required property var modelData
                    width: parent.cardWidth
                    label: modelData[2]
                    hint: modelData[3]
                    checked: Motion.level === modelData[0]
                    onPicked: Motion.set(modelData[0])
                    PxIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: modelData[1]
                        pixel: Theme.u * 3
                    }
                }
            }
        }
    }

    // the three keys to start with, and the tour of the bar after the wizard
    Component {
        id: ready
        Column {
            spacing: Theme.u * 4
            Repeater {
                model: [[["Mod", "Space"], I18n.t("программы", "apps")], [["Mod", "S"], I18n.t("настройки", "Settings")], [["Mod", "Shift", "Esc"], I18n.t("все сочетания клавиш", "every shortcut")]]
                Item {
                    id: keyRow
                    required property var modelData
                    width: parent.width
                    height: keys.height
                    Row {
                        id: keys
                        anchors.right: parent.horizontalCenter
                        anchors.rightMargin: Theme.u * 4
                        spacing: Theme.u * 2
                        Repeater {
                            model: keyRow.modelData[0]
                            PxBox {
                                id: keyCap
                                required property string modelData
                                width: keyText.implicitWidth + Theme.u * 8
                                height: keyText.implicitHeight + Theme.u * 5
                                color: Theme.faceAlt
                                PxText {
                                    id: keyText
                                    anchors.centerIn: parent
                                    font.bold: true
                                    text: keyCap.modelData
                                }
                            }
                        }
                    }
                    PxText {
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: Theme.u * 4
                        anchors.verticalCenter: keys.verticalCenter
                        text: "— " + keyRow.modelData[1]
                    }
                }
            }
            Item {
                width: 1
                height: Theme.u * 4
            }
            PxCheck {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("Показать после этого, что где на панели", "Then show me what's where on the bar")
                checked: root.wizard ? root.wizard.tipsAfter : true
                onToggled: c => root.wizard.tipsAfter = c
            }
        }
    }
}
