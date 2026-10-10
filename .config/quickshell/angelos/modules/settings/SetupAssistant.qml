pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "../y2k/AngelSpriteMini.js" as AngelMini

// The setup wizard's questions (SetupWizard.qml covers the screens with them). One question
// a screen, like a Windows 11 / macOS first run: the step's picture beside it, a big title,
// a line under it, the answer as big cards — or the group from Settings itself, found
// through the settings tree — and "Back" / "Continue" right under it. Changing steps breaks the
// question into pixel blocks and back, or jumps it in a few pixels (SetupFx); nothing moves while
// motion is off. Pixel gloss: a light rim on the cards, a stepped shine over a card or a button
// now and then, and now and then one random effect (SetupFx, its table data/setup-effects.json).
// Everything steps on SetupFx's clock; nothing glides. Enter continues.
Item {
    id: root

    property var wizard: null
    property string screenName: ""          // the screen it is on (SetupWizard): a quiet streamed one has no effects
    // held back while the first run's intro plays over it (SetupWizard: SetupIntro): no keys, no effects
    property bool held: false
    readonly property bool fxLive: !Motion.still && StreamMode.effectsOn(screenName) && !held
    readonly property var step: wizard ? wizard.cur : null
    readonly property int index: wizard ? wizard.step : 0
    readonly property int count: wizard ? wizard.steps.length : 1
    // the groups from Settings shown here wear Settings' Windows 11 look: cards
    readonly property bool fluent: true
    readonly property string settingsSkin: "classic"
    // the answer on screen (tests look into it)
    readonly property alias answer: body

    // the step on screen: it follows `step` under the transition's blocks (at once while motion
    // is off). After the change has settled: `wizard.step` and `cur` both moved by then
    property var shown: null
    property int dir: 1
    property int shownIndex: 0
    readonly property bool turning: fx.turning
    readonly property string stepId: step ? step.id : ""
    onStepIdChanged: turnSoon.restart()
    // (a timer, not Qt.callLater: it goes with the questions when they are unloaded)
    Timer {
        id: turnSoon
        interval: 0
        onTriggered: root.turn()
    }
    function turn() {
        if (!step || step === shown)
            return;
        if (!shown) {
            land();
            return;
        }
        dir = wizard.step >= shownIndex ? 1 : -1;
        if (!fx.transition(step.id, wizard.step, dir))
            land();
    }
    // `quiet`: under a transition (its moment comes once it is over: fx.over)
    function land(quiet) {
        if (!step)
            return;
        shown = step;
        shownIndex = wizard ? wizard.step : 0;
        touched = false;
        waited = false;
        lookedLong.restart();
        scroll.contentY = 0;
        if (fx.trStyle === "slide" && fx.moving) {
            slideIn.from = Theme.u * 5 + dir * Theme.u * 12;
            slideIn.restart();
        }
        if (!quiet)
            fx.landed(shown.id);
    }

    // "look here": a pulsing outline round what to do now — the answer until something is
    // picked (or it has been looked at a while: the default is fine too), then Continue
    property bool touched: false
    property bool waited: false
    Timer {
        id: lookedLong
        interval: 6000
        running: true
        onTriggered: root.waited = true
    }
    readonly property var gh: wizard ? wizard.github : null
    readonly property string attention: {
        if (!shown)
            return "";
        if (shown.id === "github")
            return gh && gh.state === "access" ? "answer" : gh && gh.state === "waiting" ? "" : "next";
        return shown.attention === "next" || touched || waited ? "next" : "answer";
    }

    // Full screen, like a Windows 11 / macOS first run: the step's picture on the left (it
    // follows the answer), the question on the right, Back / Continue right under it and the
    // progress beside them. A tall screen (or a window) stacks them: the picture on top.
    // Big screens with small art pixels get the whole stage doubled (tripled), pixel for
    // pixel: drawn once at its own size, then scaled up without smoothing.
    readonly property bool wide: width >= height * 1.15
    readonly property int zoom: Math.max(1, Math.min(3, Math.floor(Math.min(width / (Theme.u * (wide ? 760 : 420)), height / (Theme.u * (wide ? 440 : 680))))))

    Item {
        id: stage
        width: root.width / root.zoom
        height: root.height / root.zoom
        scale: root.zoom
        transformOrigin: Item.TopLeft
        layer.enabled: root.zoom > 1
        layer.smooth: false

        Item {
            id: block
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.u * 16, Theme.u * (root.wide ? 800 : 460))
            // as tall as the question needs (the picture beside it at least this tall), never
            // past the screen: past that the question scrolls
            readonly property real needs: (root.wide ? 0 : art.height + Theme.u * 8) + page.implicitHeight + Theme.u * 12 + footer.height
            height: Math.min(parent.height - Theme.u * 16, Math.max(root.wide ? Theme.u * 320 : 0, needs))

            // ---- the picture ----
            PxBox {
                id: art
                width: root.wide ? Math.round(block.width * 0.4) : block.width
                height: root.wide ? block.height : Math.min(Theme.u * 150, Math.round(stage.height * 0.2))
                color: Theme.mix(Theme.face, Theme.accent, Theme.dark ? 0.08 : 0.12)
                sunken: true
                clip: true
                // the shine passing now and then
                SetupGloss {
                    z: 3
                    anchors.fill: parent
                    host: fx
                }
                Loader {
                    anchors.centerIn: parent
                    readonly property real room: Math.min(art.width, art.height * 1.6)
                    sourceComponent: !root.shown ? null : ({
                            "hello": artHello,
                            "game": artGame,
                            "from": artFrom,
                            "windows": artWindows,
                            "look": artLook,
                            "wallpaper": artWallpaper,
                            "fastfetch": artFastfetch,
                            "motion": artMotion
                        })[root.shown.id] || artIcon
                }
            }

            // ---- the question ----
            Item {
                id: pane
                x: root.wide ? art.width + Theme.u * 20 : 0
                y: root.wide ? 0 : art.height + Theme.u * 8
                width: block.width - x
                height: block.height - y

                PxScroll {
                    id: scroll
                    anchors.top: parent.top
                    anchors.bottom: footer.top
                    anchors.bottomMargin: Theme.u * 4
                    width: parent.width
                    contentHeight: Math.max(height, page.implicitHeight + Theme.u * 4)

                    Item {
                        id: page
                        x: Theme.u * 5
                        width: scroll.width - Theme.u * 10
                        // centred while it fits, from the top once it scrolls
                        y: Math.max(0, (scroll.height - implicitHeight) / 2)
                        implicitHeight: col.implicitHeight
                        // the slide step change: in from the side the steps go (render thread)
                        XAnimator {
                            id: slideIn
                            target: page
                            to: Theme.u * 5
                            duration: 340
                            easing.type: Easing.OutCubic
                        }

                        Attention {
                            x: body.x
                            y: col.y + body.y
                            width: body.width
                            height: body.height
                            z: 5
                            shown: root.attention === "answer" && body.height > 0 && !root.turning
                            tag: I18n.t("сюда ♡", "here ♡")
                        }
                        Column {
                            id: col
                            width: parent.width
                            spacing: Theme.u * 4

                            PxText {
                                kind: "tiny"
                                dim: true
                                text: I18n.t("Шаг ", "Step ") + (root.shownIndex + 1) + I18n.t(" из ", " of ") + root.count
                            }
                            // the title: split red and blue for a blink — the copies a whole pixel or
                            // two aside, under it, unseen (opacity 0: not drawn) but while it splits:
                            // 2 px for two pixel steps, 1 px for one, gone (calm: 1 px for two).
                            // On the render thread, each step a whole number of frames (SetupFx)
                            Item {
                                width: parent.width
                                height: title.implicitHeight
                                PxText {
                                    id: red
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    kind: "big"
                                    color: "#ff4fa0"
                                    opacity: 0
                                    text: title.text
                                }
                                PxText {
                                    id: blue
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    kind: "big"
                                    color: "#4fe0ff"
                                    opacity: 0
                                    text: title.text
                                }
                                SequentialAnimation {
                                    id: split
                                    readonly property int far: Motion.calm ? 1 : 2
                                    onRunningChanged: fx.chroma = running
                                    ParallelAnimation {
                                        XAnimator {
                                            target: red
                                            to: -split.far
                                            duration: 1
                                        }
                                        XAnimator {
                                            target: blue
                                            to: split.far
                                            duration: 1
                                        }
                                        OpacityAnimator {
                                            target: red
                                            to: 0.7
                                            duration: 1
                                        }
                                        OpacityAnimator {
                                            target: blue
                                            to: 0.7
                                            duration: 1
                                        }
                                    }
                                    PauseAnimation {
                                        duration: fx.stepMs * 2
                                    }
                                    ParallelAnimation {
                                        XAnimator {
                                            target: red
                                            to: -1
                                            duration: 1
                                        }
                                        XAnimator {
                                            target: blue
                                            to: 1
                                            duration: 1
                                        }
                                    }
                                    PauseAnimation {
                                        duration: Motion.calm ? 0 : fx.stepMs
                                    }
                                    ParallelAnimation {
                                        OpacityAnimator {
                                            target: red
                                            to: 0
                                            duration: 1
                                        }
                                        OpacityAnimator {
                                            target: blue
                                            to: 0
                                            duration: 1
                                        }
                                    }
                                }
                                Connections {
                                    target: fx
                                    function onGlitched() {
                                        split.restart();
                                    }
                                }
                                PxText {
                                    id: title
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    kind: "big"
                                    color: Theme.dark ? Theme.accent : Theme.edge
                                    text: root.shown ? root.shown.title : ""
                                }
                            }
                            PxText {
                                width: parent.width
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
                                        "from": from,
                                        "mouse": mouse,
                                        "windows": windows,
                                        "github": github,
                                        "screens": screens,
                                        "look": look,
                                        "wallpaper": wallpaper,
                                        "who": who,
                                        "browser": browserStep,
                                        "apps": apps,
                                        "fastfetch": fastfetch,
                                        "widgets": widgetsStep,
                                        "motion": motion,
                                        "ready": ready
                                    })[root.shown.id] || (root.shown.blocks ? blocks : null)
                            }
                        }
                    }
                }

                // ---- progress · Back · Continue ----
                Item {
                    id: footer
                    anchors.bottom: parent.bottom
                    x: Theme.u * 5
                    width: parent.width - Theme.u * 10
                    height: Math.max(backButton.implicitHeight, nextButton.implicitHeight)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 2
                        Repeater {
                            model: root.count
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: index === root.shownIndex ? Theme.u * 8 : Theme.u * 3
                                height: Theme.u * 3
                                color: index === root.shownIndex ? Theme.accent : index < root.shownIndex ? Theme.mix(Theme.accent, Theme.face, 0.5) : Theme.mix(Theme.textDim, Theme.face, 0.4)
                            }
                        }
                    }
                    Attention {
                        x: buttons.x + nextButton.x
                        y: buttons.y + nextButton.y
                        width: nextButton.width
                        height: nextButton.height
                        shown: root.attention === "next" && !root.turning
                        tag: I18n.t("дальше ♡", "next ♡")
                    }
                    Row {
                        id: buttons
                        anchors.right: parent.right
                        spacing: Theme.u * 4
                        PxButton {
                            id: backButton
                            visible: root.shownIndex > 0
                            kind: "title"
                            icon: "arrowLeft"
                            text: I18n.t("Назад", "Back")
                            onClicked: root.wizard.back()
                        }
                        PxButton {
                            id: nextButton
                            SetupGloss {
                                anchors.fill: parent
                                hovered: nextButton.hovered
                                host: fx
                            }
                            kind: "title"
                            accent: true
                            text: root.shownIndex >= root.count - 1 ? I18n.t("Начать работу", "Start using angelOS") : root.shown && root.shown.id === "github" && root.gh && !root.gh.settled ? I18n.t("Пропустить", "Skip") : I18n.t("Продолжить", "Continue")
                            onClicked: root.wizard.next()
                        }
                    }
                }
            }
        }
        // the random effects and the step changes, over everything (no input)
        SetupFx {
            id: fx
            anchors.fill: parent
            z: 50
            area: block
            screen: root.screenName
            live: root.fxLive
            onSwap: root.land(true)
            onOver: if (root.shown)
                fx.landed(root.shown.id)
        }
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: !root.held
        onActivated: if (root.wizard)
            root.wizard.next()
    }
    Shortcut {
        sequence: "Alt+Left"
        enabled: !root.held
        onActivated: if (root.wizard)
            root.wizard.back()
    }

    // ---- the pictures (they follow the answer) ----
    Component {
        id: artIcon
        PxIcon {
            name: root.shown ? root.shown.icon : "heart"
            pixel: Theme.u * 7
        }
    }
    Component {
        id: artHello
        AngelLogo {
            pixel: Theme.u * 2
            fontSize: Theme.sizeHuge
        }
    }
    Component {
        id: artGame
        Item {
            implicitWidth: Config.game.enabled === false ? gameIcon.width : angel.width
            implicitHeight: Config.game.enabled === false ? gameIcon.height : angel.height
            PxIcon {
                id: angel
                visible: Config.game.enabled !== false
                anchors.centerIn: parent
                bitmap: AngelMini.up
                pixel: Theme.u * 5
                ink: Theme.dark ? Theme.text : Theme.edge
                body: "#ffd9c7"
                fill: Theme.accent
                fill2: "#3a1a46"
                fill3: Theme.dark ? "#ffe07a" : "#f5c542"
                light: "#ffffff"
                bad: "#d8203a"
            }
            PxIcon {
                id: gameIcon
                visible: Config.game.enabled === false
                anchors.centerIn: parent
                name: "window"
                pixel: Theme.u * 7
            }
        }
    }
    Component {
        id: artFrom
        Item {
            readonly property real room: parent ? parent.room : Theme.u * 200
            implicitWidth: Config.setup.from === "mac" ? Math.round(room * 0.8) : pic.width
            implicitHeight: Config.setup.from === "mac" ? Math.round(room * 0.5) : pic.height
            FromPic {
                id: pic
                visible: Config.setup.from !== "" && Config.setup.from !== "mac"
                anchors.centerIn: parent
                kind: Config.setup.from
                pixel: Theme.u * 6
            }
            GoldenGateMini {
                visible: Config.setup.from === "mac"
                anchors.fill: parent
            }
            PxIcon {
                visible: Config.setup.from === ""
                anchors.centerIn: parent
                name: "monitor"
                pixel: Theme.u * 7
            }
        }
    }
    Component {
        id: artWindows
        RibbonPic {
            readonly property real room: parent ? parent.room : Theme.u * 200
            implicitWidth: Math.round(room * 0.9)
            implicitHeight: Math.round(room * 0.45)
            share: WindowConfig.defaultWidth === "proportion 1.0" ? 1 : 0.5
        }
    }
    Component {
        id: artLook
        ThemePic {
            readonly property real room: parent ? parent.room : Theme.u * 200
            implicitWidth: Math.round(room * 0.8)
            implicitHeight: Math.round(room * 0.5)
            pal: Theme.paletteFor(Theme.dark)
        }
    }
    // the wallpaper step: the one on the desktop now, big
    Component {
        id: artWallpaper
        PxBox {
            readonly property real room: parent ? parent.room : Theme.u * 200
            implicitWidth: Math.round(room * 0.86)
            implicitHeight: Math.round(implicitWidth * 9 / 16)
            sunken: true
            color: Theme.sunken
            Image {
                anchors.fill: parent
                anchors.margins: Theme.u
                source: root.wallNow ? "file://" + Wallpapers.display(root.wallNow) : ""
                sourceSize: Qt.size(960, 540)
                fillMode: Image.PreserveAspectCrop
                smooth: false
                asynchronous: true
            }
        }
    }
    // the fastfetch step: what the picked style prints, run for real (scripts/fastfetch_style.py
    // preview), shrunk into the picture's box; "own" shows Compact, as Settings does
    Component {
        id: artFastfetch
        Item {
            id: ffArt
            readonly property string want: FastfetchLogo.style === "own" ? "compact" : FastfetchLogo.style
            readonly property real fit: Math.min(1, (art.width - Theme.u * 12) / Math.max(1, ffShot.implicitWidth), (art.height - Theme.u * 12) / Math.max(1, ffShot.implicitHeight))
            implicitWidth: Math.round(ffShot.implicitWidth * fit)
            implicitHeight: Math.round(ffShot.implicitHeight * fit)
            function run() {
                if (ffRun.running) {
                    ffRun.again = true;
                    return;
                }
                ffRun.command = FastfetchLogo.args("preview", want);
                ffRun.running = true;
            }
            onWantChanged: run()
            Component.onCompleted: run()
            Process {
                id: ffRun
                property bool again: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const r = JSON.parse(text);
                            if (r.lines)
                                ffShot.screen = r;
                        } catch (e) {}
                    }
                }
                onExited: if (again) {
                    again = false;
                    ffArt.run();
                }
            }
            FastfetchPreview {
                id: ffShot
                width: implicitWidth
                height: implicitHeight
                transformOrigin: Item.TopLeft
                scale: ffArt.fit
            }
            PxText {
                anchors.centerIn: parent
                visible: !(ffShot.screen.lines || []).length
                text: I18n.t("запускаю fastfetch…", "running fastfetch…")
                dim: true
            }
        }
    }
    Component {
        id: artMotion
        PxIcon {
            name: ({
                    "full": "sparkle",
                    "calm": "heart",
                    "off": "pause"
                })[Motion.level] || "sparkle"
            pixel: Theme.u * 7
        }
    }

    // the pulsing outline: breathing, a little tag on its corner; steady while motion is off
    component Attention: Item {
        id: att
        property bool shown: false
        property string tag: ""
        readonly property int pad: Theme.u * 2
        visible: shown
        Rectangle {
            id: ring
            anchors.fill: parent
            anchors.margins: -att.pad
            color: "transparent"
            border.width: Theme.u
            border.color: Theme.accent
            // breathing, on the render thread (steady while motion is off)
            SequentialAnimation {
                running: att.visible && !Motion.still
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    ring.opacity = 1
                OpacityAnimator {
                    target: ring
                    from: 1
                    to: 0.45
                    duration: 650
                    easing.type: Easing.InOutSine
                }
                OpacityAnimator {
                    target: ring
                    from: 0.45
                    to: 1
                    duration: 650
                    easing.type: Easing.InOutSine
                }
            }
        }
        Rectangle {
            visible: att.tag !== ""
            x: parent.width + att.pad - width + Theme.u * 2
            y: -att.pad - height + Theme.u
            width: tagText.implicitWidth + Theme.u * 4
            height: tagText.implicitHeight + Theme.u * 2
            color: Theme.accent
            PxText {
                id: tagText
                anchors.centerIn: parent
                kind: "tiny"
                font.bold: true
                color: Theme.dark ? Theme.desk : "#ffffff"
                text: att.tag
            }
        }
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
        // a thin light rim along its top (still), the shine passing now and then and on hover
        Rectangle {
            visible: !choice.checked
            x: Theme.u * 2
            y: Theme.u * 2
            width: parent.width - Theme.u * 4
            height: 1
            color: Qt.alpha("#ffffff", Theme.dark ? 0.16 : 0.6)
        }
        SetupGloss {
            anchors.fill: parent
            z: 2
            hovered: hover.containsMouse
            host: fx
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
            onClicked: {
                root.touched = true;
                choice.picked();
            }
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

    // where they come from: the look and the habits follow (Golden Gate for a Mac, Windows'
    // three window buttons for Windows); Settings change any of it later
    Component {
        id: from
        Column {
            spacing: Theme.u * 4
            readonly property var options: [["windows", "Windows", I18n.t("кнопки окон: свернуть, развернуть, закрыть", "window buttons: minimize, maximize, close")], ["mac", "macOS", I18n.t("вид как на Mac: строка меню, Dock, Spotlight", "a Mac's look: the menu bar, the Dock, Spotlight")], ["linux", "Linux", I18n.t("всё как есть, angelOS по-своему", "angelOS as it is")], ["new", I18n.t("Впервые", "First time"), I18n.t("подсказок будет побольше", "a few more hints")]]
            Repeater {
                model: 2
                Choices {
                    id: fromRow
                    required property int index
                    width: parent.width
                    n: 2
                    Repeater {
                        model: parent.parent.options.slice(fromRow.index * 2, fromRow.index * 2 + 2)
                        Choice {
                            required property var modelData
                            width: fromRow.cardWidth
                            label: modelData[1]
                            hint: modelData[2]
                            checked: Config.setup.from === modelData[0]
                            onPicked: root.pickFrom(modelData[0])
                            FromPic {
                                anchors.horizontalCenter: parent.horizontalCenter
                                kind: modelData[0]
                                pixel: Theme.u * 3
                            }
                        }
                    }
                }
            }
            // a Mac: Golden Gate on, offered to turn off right here, its keys only if asked for
            PxToggle {
                visible: Config.setup.from === "mac"
                width: parent.width
                text: I18n.t("Вид как на Mac (Golden Gate). Пиксельный angelOS всегда можно вернуть в Настройках", "A Mac's look (Golden Gate). The pixel angelOS is always one setting away")
                checked: Config.settingsUi.skin === "goldengate"
                onToggled: v => {
                    Config.settingsUi.skin = v ? "goldengate" : "classic";
                    Config.settingsUi.skinChosen = true;
                    root.wizard.macByWizard = v;
                }
            }
            PxToggle {
                visible: Config.setup.from === "mac" && Config.settingsUi.skin === "goldengate"
                width: parent.width
                // (spelt out: the pixel font has no ⌘)
                text: I18n.t("Сочетания клавиш как на Mac: Command — это клавиша Windows (Win+Q завершить, Win+W закрыть окно, Win+Пробел Spotlight…)", "Mac keyboard shortcuts: Command is the Windows key (Win+Q quit, Win+W close window, Win+Space Spotlight…)")
                checked: Config.mac.keys
                onToggled: v => Config.mac.keys = v
            }
        }
    }
    function pickFrom(id) {
        Config.setup.from = id;
        if (id === "mac") {
            if (Config.settingsUi.skin !== "goldengate") {
                Config.settingsUi.skin = "goldengate";
                wizard.macByWizard = true;
            }
            Config.settingsUi.skinChosen = true;
        } else if (wizard.macByWizard) {
            Config.settingsUi.skin = "classic";
            wizard.macByWizard = false;
        }
        if (id === "windows")
            Config.decor.gtkLayout = "minimize,maximize,close";
    }
    // a little picture of each system, drawn in pixels (no logos: shapes that recall them)
    component FromPic: Item {
        id: fp
        property string kind: ""
        property int pixel: Theme.u * 3
        implicitWidth: pixel * 12
        implicitHeight: pixel * 10
        width: implicitWidth
        height: implicitHeight
        // Windows: four panes
        Grid {
            visible: fp.kind === "windows"
            anchors.centerIn: parent
            columns: 2
            spacing: fp.pixel
            Repeater {
                model: 4
                Rectangle {
                    width: fp.pixel * 4
                    height: fp.pixel * 4
                    color: Theme.accent
                }
            }
        }
        // a Mac: a little Golden Gate desktop
        GoldenGateMini {
            visible: fp.kind === "mac"
            anchors.fill: parent
        }
        PxIcon {
            visible: fp.kind === "linux" || fp.kind === "new"
            anchors.centerIn: parent
            name: fp.kind === "linux" ? "terminal" : "heart"
            pixel: fp.pixel
        }
    }

    // the pointer: acceleration as cards, the speed, the touchpad's scrolling (input.kdl)
    Component {
        id: mouse
        Column {
            spacing: Theme.u * 5
            Choices {
                width: parent.width
                n: 2
                Repeater {
                    model: [["adaptive", I18n.t("С ускорением", "Accelerated"), I18n.t("как в Windows и macOS: резкое движение — курсор дальше", "like Windows and macOS: a quick flick sends the pointer further")], ["flat", I18n.t("Ровно", "Flat"), I18n.t("курсор идёт ровно за рукой — для игр и рисования", "the pointer follows your hand exactly — for games and drawing")]]
                    Choice {
                        required property var modelData
                        width: parent.cardWidth
                        label: modelData[1]
                        hint: modelData[2]
                        checked: InputConfig.accelProfile === modelData[0]
                        onPicked: InputConfig.save({
                            "accelProfile": modelData[0]
                        })
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData[0] === "flat" ? "cursor" : "mouse"
                            pixel: Theme.u * 3
                        }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: Theme.u * 2
                PxText {
                    text: I18n.t("Скорость курсора", "Pointer speed")
                }
                PxSlider {
                    width: parent.width
                    from: -1
                    to: 1
                    stepSize: 0.05
                    decimals: 2
                    value: InputConfig.accelSpeed
                    onReleased: v => {
                        root.touched = true;
                        InputConfig.save({
                            "accelSpeed": v
                        });
                    }
                }
            }
            PxToggle {
                visible: !!root.wizard && root.wizard.touchpad
                width: parent.width
                text: I18n.t("Естественная прокрутка на тачпаде — как на Mac: страница едет за пальцами", "Natural touchpad scrolling, like a Mac: the page follows your fingers")
                checked: InputConfig.naturalScroll
                onToggled: v => {
                    root.touched = true;
                    InputConfig.save({
                        "naturalScroll": v
                    });
                }
            }
        }
    }

    // niri's ribbon, the biggest difference for someone new: how wide new windows open
    Component {
        id: windows
        Column {
            spacing: Theme.u * 5
            Choices {
                width: parent.width
                n: 2
                Repeater {
                    model: [["proportion 0.5", 0.5, I18n.t("Рядом, по половине", "Side by side, half each"), I18n.t("два окна видно сразу, следующие ждут справа", "two windows at once, the next ones wait on the right")], ["proportion 1.0", 1, I18n.t("Во весь экран", "Full width"), I18n.t("как привык: одно окно — весь экран, остальные рядом в ленте", "as you're used to: one window fills the screen, the rest wait in the ribbon")]]
                    Choice {
                        required property var modelData
                        width: parent.cardWidth
                        label: modelData[2]
                        hint: modelData[3]
                        checked: WindowConfig.defaultWidth === modelData[0]
                        onPicked: WindowConfig.save({
                            "defaultWidth": modelData[0]
                        })
                        RibbonPic {
                            width: parent.width
                            height: Math.round(width * 0.42)
                            share: modelData[1]
                        }
                    }
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: Config.settingsUi.skin === "goldengate" && Config.mac.keys ? I18n.t("Листать ленту: Mod+Shift+колесо мыши. Окно на весь экран — двойной щелчок по заголовку.", "Scroll the ribbon: Mod+Shift+mouse wheel. Full screen: double-click the title bar.") : I18n.t("Листать ленту: Mod+← / Mod+→ или Mod+Shift+колесо мыши. Окно во всю ширину — Mod+Shift+F, во весь экран — Mod+F.", "Scroll the ribbon: Mod+← / Mod+→ or Mod+Shift+mouse wheel. Full width: Mod+Shift+F, full screen: Mod+F.")
            }
        }
    }
    // the ribbon: the screen's frame, windows `share` of it wide, the next ones past its edge
    component RibbonPic: Item {
        id: rib
        property real share: 0.5
        readonly property real screenW: width * 0.62
        readonly property real gap: Math.max(1, Theme.u)
        clip: true
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: (rib.width - rib.screenW) / 2 + index * rib.screenW * rib.share + rib.gap
                y: rib.height * 0.14
                width: rib.screenW * rib.share - rib.gap * 2
                height: rib.height * 0.72
                color: Theme.face
                opacity: x + width <= (rib.width + rib.screenW) / 2 + rib.gap ? 1 : 0.35
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.mix(Theme.text, Theme.face, 0.6)
                Rectangle {
                    width: parent.width
                    height: Math.max(2, parent.height * 0.14)
                    color: Theme.accent
                }
            }
        }
        // the screen
        Rectangle {
            x: (rib.width - rib.screenW) / 2
            width: rib.screenW
            height: rib.height
            color: "transparent"
            border.width: Theme.u
            border.color: Theme.dark ? Theme.text : Theme.edge
        }
    }

    // GitHub: gh's login (the device code, big, and a QR for a phone), then the author's tools
    Component {
        id: github
        Column {
            readonly property var gh: root.wizard ? root.wizard.github : null
            readonly property string st: gh ? gh.state : ""
            spacing: Theme.u * 4

            PxText {
                visible: parent.st === ""
                text: I18n.t("Смотрю, что с GitHub…", "Checking GitHub…")
                dim: true
            }
            PxButton {
                visible: parent.st === "no-login" || parent.st === "error"
                kind: "title"
                icon: "plug"
                text: parent.st === "error" ? I18n.t("Попробовать ещё раз", "Try again") : I18n.t("Войти через GitHub", "Log in with GitHub")
                onClicked: {
                    root.touched = true;
                    parent.gh.state === "error" && parent.gh.login ? parent.gh.fetch() : parent.gh.startLogin();
                }
            }
            PxText {
                visible: parent.st === "error" && !!parent.gh.error
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                color: Theme.danger
                text: parent.gh ? parent.gh.error : ""
            }
            // the code: a phone opens the page (the QR), types the code
            Row {
                visible: parent.st === "waiting"
                spacing: Theme.u * 6
                Image {
                    visible: !!parent.parent.gh && parent.parent.gh.qrReady
                    source: visible ? "file://" + parent.parent.gh.qrPath : ""
                    width: Theme.u * 60
                    height: width
                    smooth: false
                    cache: false
                }
                Column {
                    spacing: Theme.u * 3
                    width: parent.parent.width - (parent.children[0].visible ? Theme.u * 66 : 0)
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: I18n.t("1. На телефоне открой github.com/login/device (или наведи камеру на QR)", "1. On your phone, open github.com/login/device (or point the camera at the QR)")
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: I18n.t("2. Введи этот код:", "2. Type this code:")
                    }
                    PxText {
                        kind: "huge"
                        font.bold: true
                        color: Theme.accent
                        text: parent.parent.parent.gh && parent.parent.parent.gh.code ? parent.parent.parent.gh.code : "····-····"
                    }
                    PxText {
                        kind: "tiny"
                        dim: true
                        text: I18n.t("Жду подтверждения от GitHub…", "Waiting for GitHub…")
                    }
                    PxButton {
                        compact: true
                        flat: true
                        text: I18n.t("Отмена", "Cancel")
                        onClicked: parent.parent.parent.gh.cancel()
                    }
                }
            }
            PxText {
                visible: parent.st === "access" || parent.st === "no-access" || parent.st === "fetching" || parent.st === "ready"
                width: parent.width
                wrapMode: Text.Wrap
                text: !parent.gh ? "" : parent.st === "no-access" ? I18n.t("Вошли как ", "Logged in as ") + parent.gh.login + " ♡" : parent.st === "access" ? I18n.t("Вошли как ", "Logged in as ") + parent.gh.login + I18n.t(" — тебе открыты инструменты автора.", " — the author's tools are open to you.") : parent.st === "fetching" ? I18n.t("Скачиваю инструменты автора…", "Fetching the author's tools…") : I18n.t("Вошли как ", "Logged in as ") + parent.gh.login + " ♡ " + (Owner.enabled ? I18n.t("Админ-функции включены.", "The admin features are on.") : Owner.check === "denied" ? I18n.t("Инструменты автора на месте, но админ-прав на репозиторий у аккаунта нет.", "The author's tools are here, but this account has no admin rights on the repository.") : I18n.t("Инструменты автора на месте, проверяю админ-права…", "The author's tools are here, checking the admin rights…"))
            }
            PxButton {
                visible: parent.st === "access"
                kind: "title"
                accent: true
                icon: "download"
                text: I18n.t("Скачать и включить", "Fetch and switch on")
                onClicked: {
                    root.touched = true;
                    parent.gh.fetch();
                }
            }
            // Recovery: a save found on this account → bring it back; none → saving switches on
            Column {
                readonly property bool loggedIn: ["access", "no-access", "fetching", "ready"].includes(parent.st)
                visible: loggedIn
                width: parent.width
                spacing: Theme.u * 3
                onLoggedInChanged: if (loggedIn)
                    Recovery.refresh()
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Recovery.exists ? Theme.accent : Theme.text
                    text: !Recovery.checked || Recovery.login === "" ? I18n.t("Ищу твоё сохранение angelOS…", "Looking for your angelOS save…") : Recovery.exists ? I18n.t("Нашёл твоё сохранение: ", "Found your save: ") + (Recovery.last || "?") + I18n.t(". Вернуть прогресс и все настройки?", ". Bring back your progress and every setting?") : I18n.t("Сохранений пока нет. angelOS будет сам раз в день сохранять прогресс и настройки в твой приватный репозиторий angelos-save — на другом компьютере вернёшь их здесь же.", "No saves yet. angelOS will save your progress and settings into your private repository angelos-save once a day; on another computer you bring them back right here.")
                }
                PxButton {
                    visible: Recovery.exists
                    kind: "title"
                    accent: true
                    icon: "download"
                    enabled: Recovery.busy === ""
                    text: Recovery.busy === "pull" ? I18n.t("Восстанавливаю…", "Restoring…") : I18n.t("Восстановить и перезапустить", "Restore and restart")
                    onClicked: {
                        root.touched = true;
                        Config.setup.complete = true;
                        Recovery.pull();
                    }
                }
                PxText {
                    visible: Recovery.message !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    color: Recovery.failed ? Theme.danger : Theme.textDim
                    text: Recovery.message
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: I18n.t("Токен хранит gh, не angelOS. Позже — Настройки → Аккаунт → Восстановление.", "gh keeps the token, not angelOS. Later: Settings → Account → Recovery.")
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

    // the main screen (Outputs.setPrimary, as in Settings → Display): each screen drawn to scale;
    // under them how each stands (Outputs.turn: at once, back in 15 s unless kept — kept is saved)
    Component {
        id: screens
        Column {
            spacing: Theme.u * 4
            Choices {
                id: screensRow
                visible: Shell.screens.length > 1
                width: parent.width
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
            // how each screen stands
            Repeater {
                model: Shell.screens
                Column {
                    id: turnCol
                    required property var modelData
                    readonly property var d: Outputs.draft[modelData.name] || null
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        visible: Shell.screens.length > 1
                        text: turnCol.modelData.name + (turnCol.modelData.model && turnCol.modelData.model !== "Unknown" ? " · " + turnCol.modelData.model : "")
                        kind: "tiny"
                        dim: true
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        Repeater {
                            model: Outputs.turns
                            PxButton {
                                required property var modelData
                                icon: modelData.value === "0" ? "monitor" : "rotate"
                                text: modelData.label
                                checked: turnCol.d ? Outputs.turnOf(turnCol.d.transform) === modelData.value : modelData.value === "0"
                                enabled: !Outputs.busy && !!turnCol.d
                                onClicked: {
                                    root.touched = true;
                                    Outputs.turn(turnCol.modelData.name, Outputs.transformOf(modelData.value, Outputs.mirroredOf(turnCol.d.transform)));
                                }
                            }
                        }
                    }
                }
            }
            // turned: keep it (and remember it past a reboot) or it comes back by itself
            PxBox {
                visible: Outputs.undo !== null
                width: parent.width
                height: setupKeep.implicitHeight + Theme.u * 8
                color: Theme.mix(Theme.face, Theme.accent, 0.25)
                Row {
                    id: setupKeep
                    x: Theme.u * 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 3
                    PxText {
                        width: parent.width - setupKeepBtn.width - setupBackBtn.width - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.Wrap
                        text: I18n.t("Оставить так? Через ", "Keep this? Going back in ") + Outputs.confirmLeft + I18n.t(" с вернётся как было.", " s.")
                    }
                    PxButton {
                        id: setupKeepBtn
                        accent: true
                        icon: "check"
                        text: I18n.t("Оставить", "Keep")
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            Outputs.keep();
                            Outputs.save();
                        }
                    }
                    PxButton {
                        id: setupBackBtn
                        icon: "arrowLeft"
                        text: I18n.t("Вернуть", "Revert")
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Outputs.revert()
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
    // ---- the wallpaper step: this release's, then a few of ~/Pictures ----
    // one card per wallpaper: its day / night / 21:9 / 9:16 files are one (Wallpapers.heads), and
    // every screen gets the file for the theme and for how it stands (Wallpapers.pick)
    readonly property string wallScreen: Shell.primaryName || (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
    readonly property string wallNow: Wallpapers.resolve(wallScreen, 1)
    readonly property string wallPicked: Wallpapers.raw(wallScreen, 1)
    readonly property var wallChoices: {
        const out = [];
        const r = Wallpapers.latestRelease;
        for (const w of (r ? r.walls : [])) {
            const path = Theme.dark ? (w.night || w.day) : (w.day || w.night);
            out.push({
                "path": path,
                "label": w.name || Wallpapers.releaseLabel(r),
                "hint": I18n.t("обои ", "") + Wallpapers.releaseLabel(r) + I18n.t("", " wallpaper")
            });
        }
        const taken = out.map(o => o.path);
        const rest = Wallpapers.heads.filter(p => !taken.some(t => Wallpapers.sameSet(t, p)) && !(r && p.startsWith(r.dir + "/")));
        for (const p of rest.slice(0, Math.max(3, 9 - out.length)))
            out.push({
                "path": p,
                "label": Wallpapers.nameOf(p),
                "hint": p.slice(0, p.lastIndexOf("/")).replace(Config.home, "~")
            });
        return out;
    }
    Component {
        id: wallpaper
        Column {
            spacing: Theme.u * 4
            Grid {
                id: wallGrid
                width: parent.width
                columns: 3
                spacing: Theme.u * 4
                readonly property int cardWidth: Math.floor((width - spacing * (columns - 1)) / columns)
                Repeater {
                    model: root.wallChoices
                    Choice {
                        id: wallCard
                        required property var modelData
                        width: wallGrid.cardWidth
                        readonly property string file: Wallpapers.pick(modelData.path, root.wallScreen)
                        readonly property var tags: Wallpapers.variantTags(modelData.path)
                        label: modelData.label
                        hint: tags.length ? tags.join(" ") + "  ·  " + modelData.hint : modelData.hint
                        checked: Wallpapers.sameSet(root.wallPicked, modelData.path)
                        onPicked: Wallpapers.setEverywhere(modelData.path)
                        Image {
                            width: parent.width
                            height: Math.round(width * 9 / 16)
                            source: "file://" + Wallpapers.display(wallCard.file)
                            sourceSize: Qt.size(480, 270)
                            fillMode: Image.PreserveAspectCrop
                            smooth: false
                            asynchronous: true
                            onStatusChanged: if (status === Image.Error)
                                Wallpapers.fit(wallCard.file)
                        }
                    }
                }
            }
            // the picked wallpaper on every screen as it stands (wide, tall, turned): the file each gets
            Column {
                visible: Quickshell.screens.length > 1 || Wallpapers.members(root.wallPicked).length > 1
                width: parent.width
                spacing: Theme.u * 2
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    text: I18n.t("Как лягут на твои экраны — у обоев с вариантами каждый экран берёт свой: по теме (день или ночь) и по тому, как он стоит (широкий, вертикальный):", "On your screens: a wallpaper with variants gives each screen its own, by the theme (day or night) and by how the screen stands (wide, upright):")
                }
                Row {
                    id: screensRow
                    spacing: Theme.u * 4
                    readonly property real boxH: Theme.u * 34
                    Repeater {
                        model: Quickshell.screens
                        Column {
                            id: scrCol
                            required property var modelData
                            readonly property real aspect: Wallpapers.aspectOf(modelData.name)
                            readonly property string file: Wallpapers.resolve(modelData.name, 1)
                            readonly property var info: Wallpapers.meta[file] || {}
                            spacing: Theme.u
                            PxBox {
                                width: Math.round(screensRow.boxH * Math.min(scrCol.aspect, 3.6))
                                height: screensRow.boxH
                                sunken: true
                                color: Theme.sunken
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: parent.bevel
                                    source: scrCol.file ? "file://" + Wallpapers.display(scrCol.file) : ""
                                    sourceSize: Qt.size(320, 320)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            PxText {
                                kind: "tiny"
                                dim: true
                                text: scrCol.modelData.name + "  " + (scrCol.aspect >= 1 ? "▭" : "▯") + "  " + [scrCol.info.time === "night" ? "☾" : scrCol.info.time ? "☼" : "", Wallpapers.ratioLabel(scrCol.info.w, scrCol.info.h)].filter(x => x).join(" ")
                            }
                        }
                    }
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: I18n.t("Все картинки, свои папки, отдельные обои на каждый монитор и стол — Настройки → Обои. Повернуть монитор — Настройки → Экран.", "All the pictures, your own folders, a wallpaper per monitor and desk: Settings → Wallpaper. Turning a monitor: Settings → Display.")
            }
        }
    }
    // ---- the widgets: three sets (DesktopWidgets.sets), each on a little desktop ----
    // the size of each widget in the picture, in angelOS pixels (about what it takes on screen)
    readonly property var widgetBoxes: ({
            "clock": {
                "m": [130, 42],
                "l": [160, 80]
            },
            "sysmon": {
                "l": [150, 150]
            },
            "music": {
                "m": [150, 50],
                "l": [150, 82]
            },
            "disks": {
                "m": [124, 70]
            }
        })
    Component {
        id: widgetsStep
        Choices {
            n: 3
            Repeater {
                model: [["empty", I18n.t("Пусто", "Empty"), I18n.t("только обои — виджеты добавишь сам", "just the wallpaper; add widgets yourself")], ["minimum", I18n.t("Минимум", "Minimum"), I18n.t("часы и музыка", "a clock and music")], ["center", I18n.t("Командный центр", "Command centre"), I18n.t("часы, система, музыка и диски — всё на виду", "clock, system, music and disks, all in sight")]]
                Choice {
                    id: setCard
                    required property var modelData
                    width: parent.cardWidth
                    label: modelData[1]
                    hint: modelData[2]
                    checked: Config.desktop.widgetSet === modelData[0]
                    onPicked: DesktopWidgets.applySet(modelData[0])
                    // the main screen in small, its widgets as plates with their icons
                    Rectangle {
                        id: mini
                        readonly property var scr: Shell.primaryScreen || Quickshell.screens[0] || null
                        readonly property real k: scr ? width / Math.max(1, scr.width) * Theme.u : 0.1
                        width: parent.width
                        height: Math.round(width * 9 / 16)
                        color: Theme.desk
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: Theme.edge
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: parent.border.width
                            source: root.wallNow ? "file://" + Wallpapers.display(root.wallNow) : ""
                            sourceSize: Qt.size(320, 180)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.85
                        }
                        Repeater {
                            model: DesktopWidgets.sets[setCard.modelData[0]] || []
                            PxBox {
                                id: wbox
                                required property var modelData
                                readonly property var dims: (root.widgetBoxes[modelData[0]] || {})[modelData[1]] || [120, 60]
                                width: Math.max(Theme.u * 4, Math.round(dims[0] * mini.k))
                                height: Math.max(Theme.u * 3, Math.round(dims[1] * mini.k))
                                x: modelData[2] < 0 ? mini.width + modelData[2] * mini.k - width : modelData[2] * mini.k
                                y: modelData[3] < 0 ? mini.height + modelData[3] * mini.k - height : modelData[3] * mini.k
                                flat: true
                                color: Qt.alpha(Theme.panel, 0.92)
                                PxIcon {
                                    anchors.centerIn: parent
                                    name: (DesktopWidgets.typeInfo(wbox.modelData[0]) || {}).icon || "heart"
                                    pixel: Math.max(1, Math.round(Theme.u / 2))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // ---- who are you: four templates, each ticks its apps on the next step ----
    Component {
        id: who
        Grid {
            id: whoGrid
            width: parent.width
            columns: 2
            spacing: Theme.u * 4
            readonly property int cardWidth: Math.floor((width - spacing) / 2)
            Repeater {
                model: root.wizard ? root.wizard.catalog.personas : []
                Choice {
                    id: whoCard
                    required property var modelData
                    width: whoGrid.cardWidth
                    label: I18n.t(modelData.ru, modelData.en)
                    hint: I18n.t(modelData.hintRu, modelData.hintEn)
                    checked: Config.setup.persona === modelData.id
                    onPicked: root.wizard.pickPersona(modelData.id)
                    PxIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: whoCard.modelData.icon
                        pixel: Theme.u * 4
                    }
                }
            }
        }
    }
    // ---- which browser: one card each (the catalog's, then the ones installed some other way);
    // the picked one opens on Mod+B and links (scripts/apps-install.py browser) ----
    Component {
        id: browserStep
        Column {
            id: brCol
            width: parent.width
            spacing: Theme.u * 4
            readonly property var list: root.wizard ? root.wizard.browserList : []
            PxText {
                visible: brCol.list.length === 0
                kind: "tiny"
                dim: true
                text: I18n.t("смотрю, какие браузеры есть…", "looking at the browsers…")
            }
            Grid {
                id: brGrid
                width: parent.width
                columns: 4
                spacing: Theme.u * 4
                readonly property int cardWidth: Math.floor((width - spacing * (columns - 1)) / columns)
                readonly property real cardHeight: {
                    let h = 0;
                    for (const c of children)
                        if (c.picked !== undefined)
                            h = Math.max(h, c.implicitHeight);
                    return h;
                }
                Repeater {
                    model: brCol.list
                    Choice {
                        id: brCard
                        required property var modelData
                        // nowhere to get it from (no repository, AUR or Flathub has it here)
                        readonly property bool none: !modelData.installed && !modelData.via
                        width: brGrid.cardWidth
                        enabled: !none
                        opacity: none ? 0.45 : 1
                        label: I18n.t(modelData.ru, modelData.en) + (modelData.installed ? "  ✓" : "")
                        hint: modelData.installed ? I18n.t("уже стоит", "installed") : none ? I18n.t("нет в репозиториях", "not in your repositories") : I18n.t(modelData.hintRu, modelData.hintEn)
                        checked: root.wizard && root.wizard.browser === modelData.id
                        onPicked: {
                            root.touched = true;
                            root.wizard.pickBrowser(modelData.id);
                        }
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: brCard.modelData.icon || "search"
                            pixel: Theme.u * 3
                        }
                    }
                }
            }
        }
    }
    // ---- the apps: the catalog's groups (ticked by the template); a group opens to its apps ----
    Component {
        id: apps
        Column {
            id: appsCol
            spacing: Theme.u * 3
            readonly property var cat: root.wizard ? root.wizard.catalog : ({
                    "apps": [],
                    "groups": []
                })
            readonly property var byId: {
                const m = {};
                for (const a of cat.apps || [])
                    m[a.id] = a;
                return m;
            }
            property var open: ({})
            Repeater {
                model: appsCol.cat.groups || []
                Column {
                    id: grp
                    required property var modelData
                    width: appsCol.width
                    spacing: Theme.u * 2
                    // «Браузеры» shows the main browser too when the author's group doesn't hold it
                    readonly property string main: root.wizard && modelData.id === "browsers" && root.wizard.isCatalogBrowser(root.wizard.browser) ? root.wizard.browser : ""
                    readonly property var ids: (main && !modelData.apps.includes(main) ? modelData.apps.concat([main]) : modelData.apps).filter(i => !!appsCol.byId[i])
                    readonly property int on: ids.filter(i => (Config.setup.apps || []).includes(i)).length
                    readonly property bool expanded: !!appsCol.open[modelData.id]
                    Item {
                        width: parent.width
                        height: Math.max(grpTick.implicitHeight, grpOpen.implicitHeight) + Theme.u * 2
                        PxCheck {
                            id: grpTick
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t(grp.modelData.ru, grp.modelData.en) + "   " + grp.on + "/" + grp.ids.length
                            // ticked = the whole group; a part of it shows in the count
                            checked: grp.on === grp.ids.length && grp.ids.length > 0
                            onToggled: c => {
                                root.touched = true;
                                root.wizard.toggleGroup(grp.modelData.id, c);
                            }
                        }
                        PxText {
                            id: grpOpen
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "tiny"
                            dim: !grpOpenMouse.containsMouse
                            text: grp.expanded ? I18n.t("свернуть ▾", "fold ▾") : I18n.t("раскрыть ›", "open ›")
                            MouseArea {
                                id: grpOpenMouse
                                anchors.fill: parent
                                anchors.margins: -Theme.u * 2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const o = Object.assign({}, appsCol.open);
                                    o[grp.modelData.id] = !grp.expanded;
                                    appsCol.open = o;
                                }
                            }
                        }
                    }
                    PxText {
                        visible: !grp.expanded
                        width: parent.width
                        elide: Text.ElideRight
                        kind: "tiny"
                        dim: true
                        text: grp.ids.map(i => I18n.t(appsCol.byId[i].ru, appsCol.byId[i].en)).join(", ")
                    }
                    Flow {
                        visible: grp.expanded
                        width: parent.width
                        spacing: Theme.u * 3
                        Repeater {
                            model: grp.expanded ? grp.ids.map(i => appsCol.byId[i]) : []
                            AppChip {}
                        }
                    }
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: !root.wizard || !root.wizard.appsChecked ? I18n.t("проверяю, что уже стоит…", "checking what you have…") : root.wizard.appsToInstall.length ? I18n.t("поставлю: ", "to install: ") + root.wizard.appsToInstall.length + I18n.t(" — после «Начать работу», в терминале. Потом обновления доставят то, что автор добавит в отмеченные группы.", " — after “Start”, in a terminal. Later, updates bring what the author adds to the ticked groups.") : I18n.t("ставить нечего ♡", "nothing to install ♡")
            }
        }
    }
    // one app: a tick, its name and what it is; ✓ when it is installed already
    component AppChip: Item {
        id: chip
        required property var modelData
        readonly property var st: (root.wizard ? root.wizard.appStatus : {})[modelData.id] || {}
        readonly property bool have: !!st.installed
        readonly property bool none: root.wizard && root.wizard.appsChecked && !have && !st.via
        readonly property bool on: (Config.setup.apps || []).includes(modelData.id)
        readonly property bool main: !!root.wizard && root.wizard.browser === modelData.id
        width: parent ? Math.floor((parent.width - Theme.u * 3) / 2) : Theme.u * 112
        height: Theme.u * 22
        opacity: none ? 0.45 : 1
        PxBox {
            anchors.fill: parent
            color: chip.on ? Theme.mix(Theme.face, Theme.accent, 0.25) : chipMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
            sunken: chip.on
        }
        Item {
            id: chipIcon
            x: Theme.u * 4
            width: Theme.u * 14
            height: width
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            PxIcon {
                anchors.centerIn: parent
                // ✓ only for what is there: a ticked app is not installed yet (it looked as if it were)
                name: chip.have ? "check" : chip.modelData.icon
                pixel: Math.max(1, Math.round(Theme.u * 0.85))
            }
        }
        Column {
            x: chipIcon.x + chipIcon.width + Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - Theme.u * 3
            PxText {
                width: parent.width
                elide: Text.ElideRight
                font.bold: chip.on
                text: I18n.t(chip.modelData.ru, chip.modelData.en) + (chip.have ? "  ✓" : "")
            }
            PxText {
                width: parent.width
                elide: Text.ElideRight
                kind: "tiny"
                dim: true
                text: chip.main ? I18n.t("основной браузер (шаг «Какой браузер?»)", "the main browser (the «Which browser?» step)") : chip.have ? I18n.t("уже стоит", "installed") : chip.none ? I18n.t("нет в репозиториях", "not in your repositories") : I18n.t(chip.modelData.hintRu, chip.modelData.hintEn)
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !chip.none
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.touched = true;
                root.wizard.toggleApp(chip.modelData.id, !chip.on);
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
                    checked: Motion.chosen === modelData[0]
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

    // fastfetch: the styles of Settings → System → fastfetch, two to a row
    Component {
        id: fastfetch
        Column {
            spacing: Theme.u * 4
            Grid {
                id: ffGrid
                width: parent.width
                columns: 2
                spacing: Theme.u * 4
                readonly property int cardWidth: Math.floor((width - spacing) / 2)
                Repeater {
                    model: FastfetchLogo.styles
                    Choice {
                        required property var modelData
                        width: ffGrid.cardWidth
                        label: modelData.name
                        hint: modelData.hint
                        checked: FastfetchLogo.style === modelData.id
                        onPicked: Config.bar.fastfetchStyle = modelData.id
                    }
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: I18n.t("Цены — примерные, на старте продаж. Поменять потом: Настройки → О системе → fastfetch.", "The prices are rough launch prices. To change it later: Settings → System → fastfetch.")
            }
        }
    }

    // the three keys to start with, and the tour of the bar after the wizard
    Component {
        id: ready
        Column {
            spacing: Theme.u * 4
            Repeater {
                readonly property bool macKeys: Config.settingsUi.skin === "goldengate" && Config.mac.keys
                model: [[["Mod", "Space"], macKeys ? "Spotlight" : I18n.t("программы", "apps")], [["Mod", "S"], I18n.t("настройки", "Settings")], macKeys ? [["Mod", "W"], I18n.t("закрыть окно", "close a window")] : [["Mod", "Q"], I18n.t("закрыть окно", "close a window")], macKeys ? [["Mod", "Shift", I18n.t("колесо", "wheel")], I18n.t("листать ленту окон", "scroll the window ribbon")] : [["Mod", "←", "→"], I18n.t("листать ленту окон", "scroll the window ribbon")], [["Mod", "Shift", "Esc"], I18n.t("все сочетания клавиш", "every shortcut")]]
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
