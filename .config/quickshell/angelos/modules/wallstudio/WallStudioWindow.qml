pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// The wallpaper editor (services/WallStudio): on the left the wallpapers and the layers, in the middle
// the picture on the real scene engine, on the right what moves on it and from which sound; under it
// the music and «На обои».
FloatingWindow {
    id: root

    title: Shell.appTitle + " · " + I18n.t("Редактор обоев", "Wallpaper editor")
    visible: WallStudio.open
    color: "transparent"
    // niri's rule gives it most of the screen (.config/niri/cfg/rules.kdl)
    implicitWidth: 1500
    implicitHeight: 900
    minimumSize: Qt.size(1000, 500)
    onClosed: root.leave()
    onVisibleChanged: if (!visible)
        WallStudio.open = false

    function leave() {
        ed.flush();
        WallStudio.open = false;
    }

    StudioModel {
        id: ed
    }
    // (for the self-test: the state and the picture)
    readonly property alias model: ed
    readonly property alias stage: stage

    function openFirst() {
        const p = WallStudio.picture || Wallpapers.raw(Niri.focusedOutput, 1);
        const scene = Wallpapers.sceneOf(p);
        if (WallStudio.picture)
            ed.openPicture(WallStudio.picture);
        else if (scene)
            ed.open(scene);
    }
    Component.onCompleted: openFirst()
    Connections {
        target: WallStudio
        function onAsked(picture) {
            if (picture)
                ed.openPicture(picture);
        }
    }
    function pick() {
        picker.running = true;
    }
    Process {
        id: picker
        command: ["python3", Quickshell.shellDir + "/scripts/pick-file.py", "--remember", "wall-studio", I18n.t("Картинка для обоев", "A picture for the wallpaper"), I18n.t("Картинки", "Pictures"), "*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                ed.ask(text.trim())
        }
    }

    component Key: Shortcut {
        context: Qt.WindowShortcut
    }
    Key {
        sequences: ["Ctrl+Z", "Ctrl+Я"]
        onActivated: ed.undo()
    }
    Key {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Shift+Я", "Ctrl+Y", "Ctrl+Н"]
        onActivated: ed.redo()
    }
    Key {
        sequences: ["V", "М"]
        onActivated: ed.tool = "move"
    }
    Key {
        sequences: ["B", "И"]
        onActivated: ed.tool = "brush"
    }
    Key {
        sequences: ["E", "У"]
        onActivated: ed.tool = "erase"
    }
    Key {
        sequences: ["Delete"]
        enabled: ed.sel >= 0
        onActivated: ed.remove(ed.sel)
    }
    Key {
        sequence: "Escape"
        onActivated: ed.sel = -1
    }

    PxWindow {
        id: frame
        anchors.fill: parent
        anchors.rightMargin: Theme.u * 2
        anchors.bottomMargin: Theme.u * 2
        skin: ""
        translucent: false
        title: "angelOS · " + I18n.t("Редактор обоев", "Wallpaper editor")
        icon: "image"
        onCloseClicked: root.leave()
        onTitlePressed: root.startSystemMove()

        Item {
            id: body
            readonly property string settingsSkin: "classic"
            width: parent.width
            height: parent.height

            // ---- the wallpapers and the layers ----
            Column {
                id: left
                width: Theme.u * 72
                height: parent.height - strip.height - Theme.u * 3
                spacing: Theme.u * 2
                PxText {
                    kind: "title"
                    text: I18n.t("Обои", "Wallpapers")
                }
                PxButton {
                    width: parent.width
                    accent: true
                    text: I18n.t("Из картинки…", "From a picture…")
                    enabled: !ed.busy
                    onClicked: root.pick()
                }
                PxCombo {
                    width: parent.width
                    model: Object.keys(Wallpapers.scenes).sort().map(p => ({
                                "label": Wallpapers.scenes[p].split("/").slice(-2).join(" / "),
                                "value": Wallpapers.scenes[p]
                            }))
                    currentValue: ed.dir
                    placeholder: I18n.t("выбери сцену", "pick a scene")
                    onActivated: v => ed.open(v)
                }
                Item {
                    width: 1
                    height: Theme.u * 2
                }
                PxText {
                    kind: "title"
                    text: I18n.t("Слои", "Layers")
                }
                PxScroll {
                    id: layerScroll
                    width: parent.width
                    height: parent.height - y
                    contentHeight: layerList.height
                    Column {
                        id: layerList
                        width: layerScroll.width - Theme.u * 6
                        Repeater {
                            model: ed.scene ? ed.scene.layers.slice().sort((a, b) => b.z - a.z) : []
                            PxText {
                                required property var modelData
                                width: layerList.width
                                elide: Text.ElideRight
                                kind: "tiny"
                                text: modelData.label_ru || modelData.id
                            }
                        }
                    }
                }
            }

            // ---- the picture, the tools over it ----
            Item {
                id: middle
                anchors.left: left.right
                anchors.leftMargin: Theme.u * 3
                anchors.right: right.left
                anchors.rightMargin: Theme.u * 3
                height: left.height
                Row {
                    id: tools
                    spacing: Theme.u * 2
                    visible: ed.scene !== null
                    PxButton {
                        compact: true
                        text: I18n.t("Двигать", "Move")
                        checked: ed.tool === "move"
                        onClicked: ed.tool = "move"
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Кисть: не двигать", "Brush: keep still")
                        checked: ed.tool === "brush"
                        onClicked: ed.tool = "brush"
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Ластик", "Eraser")
                        checked: ed.tool === "erase"
                        onClicked: ed.tool = "erase"
                    }
                    PxSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 90
                        visible: ed.tool !== "move"
                        from: 2
                        to: 60
                        stepSize: 1
                        suffix: " px"
                        value: ed.brush
                        onMoved: v => ed.brush = Math.round(v)
                    }
                }
                StudioStage {
                    id: stage
                    ed: ed
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: tools.bottom
                    anchors.topMargin: Theme.u * 2
                    anchors.bottom: parent.bottom
                }
                // nothing open yet, or how to take an ordinary picture
                Column {
                    anchors.centerIn: stage
                    width: Math.min(stage.width, Theme.u * 170)
                    spacing: Theme.u * 3
                    visible: ed.scene === null || ed.asking !== null || ed.busy
                    PxText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: ed.busy ? I18n.t("Готовлю картинку…", "Preparing the picture…")
                            : ed.asking ? I18n.t("Это обычная картинка, не пиксель-арт. Как её взять?", "This is an ordinary picture, not pixel art. How should it be taken?")
                            : I18n.t("Перетащи сюда картинку или выбери «Из картинки…». Потом поставь на неё динамик.", "Drop a picture here or choose «From a picture…». Then put a speaker on it.")
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.u * 2
                        visible: ed.asking !== null && !ed.busy
                        PxButton {
                            accent: true
                            text: I18n.t("Сделать пиксельной", "Make it pixel art")
                            onClicked: ed.make(ed.asking.path, "pixel")
                        }
                        PxButton {
                            text: I18n.t("Оставить как есть", "Keep it as it is")
                            onClicked: ed.make(ed.asking.path, "keep")
                        }
                    }
                }
                DropArea {
                    anchors.fill: parent
                    onEntered: drag => drag.accepted = drag.hasUrls
                    onDropped: drop => {
                        const u = (drop.urls || []).map(String).filter(x => x.startsWith("file://")).map(x => decodeURIComponent(x.slice(7)));
                        if (u.length)
                            ed.ask(u[0]);
                        drop.accept(Qt.CopyAction);
                    }
                }
            }

            // ---- what moves, from which sound ----
            Column {
                id: right
                anchors.right: parent.right
                width: Theme.u * 122
                height: left.height
                spacing: Theme.u * 2
                PxText {
                    kind: "title"
                    text: I18n.t("Что двигается", "What moves")
                }
                Row {
                    spacing: Theme.u * 2
                    PxButton {
                        compact: true
                        accent: true
                        enabled: ed.scene !== null && ed.bulges < ed.maxBulges
                        text: I18n.t("Динамик", "Speaker")
                        onClicked: ed.addSpeaker()
                    }
                    PxButton {
                        compact: true
                        enabled: ed.scene !== null && ed.bulges < ed.maxBulges
                        text: "+ " + I18n.t("Толчок", "Push")
                        onClicked: ed.addBulge()
                    }
                    PxButton {
                        compact: true
                        enabled: ed.scene !== null
                        text: "+ " + I18n.t("Волна", "Wave")
                        onClicked: ed.addWave()
                    }
                }
                PxScroll {
                    id: modScroll
                    width: parent.width
                    height: parent.height - y
                    contentHeight: modList.height
                    Column {
                        id: modList
                        width: modScroll.width - Theme.u * 6
                        spacing: Theme.u * 2
                        PxText {
                            width: parent.width
                            visible: ed.scene !== null && ed.mods.length === 0 && ed.scene.builtin === false
                            wrapMode: Text.WordWrap
                            dim: true
                            text: I18n.t("Нажми «Динамик»: появится зона на картинке и волна из неё. Зону можно перетащить и растянуть за уголки.", "Press «Speaker»: a zone on the picture and a wave out of it. Drag the zone and stretch it by its grips.")
                        }
                        Repeater {
                            // the count, not the list: a slider held down must outlive its own change
                            model: ed.mods.length
                            ModCard {
                                width: modList.width
                            }
                        }
                        // the effects the scene has by itself (Settings → Wallpaper → Wallpaper sounds)
                        PxBox {
                            width: parent.width
                            height: built.height + Theme.u * 6
                            visible: ed.scene !== null && ed.scene.builtin !== false
                            sunken: true
                            Column {
                                id: built
                                x: Theme.u * 3
                                y: Theme.u * 3
                                width: parent.width - Theme.u * 6
                                spacing: Theme.u * 2
                                PxText {
                                    font.bold: true
                                    text: I18n.t("Встроено в эту сцену", "Built into this scene")
                                }
                                Repeater {
                                    model: [["sceneBass", I18n.t("Волна из телевизора", "A wave out of the TV")], ["sceneSnare", I18n.t("Срыв сигнала на снейр", "Signal drop on the snare")], ["sceneHats", I18n.t("Строка развёртки на хэт", "A scanline on the hat")], ["sceneEdges", I18n.t("Края на снейр", "The edges on the snare")], ["sceneBreath", I18n.t("Края дышат под бас", "The edges breathe with the bass")]]
                                    PxCheck {
                                        required property var modelData
                                        text: modelData[1]
                                        checked: Wallpapers.own(ed.dir, modelData[0]) === true
                                        onToggled: c => Wallpapers.setOwn(ed.dir, modelData[0], c)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- the music, undo, «На обои» ----
            Row {
                id: strip
                anchors.bottom: parent.bottom
                spacing: Theme.u * 2
                readonly property var sounds: [["kick", I18n.t("Бочка", "Kick")], ["snare", I18n.t("Снейр", "Snare")], ["hat", I18n.t("Хэт", "Hat")]]
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lyrics.isSong ? I18n.t("♪ играет музыка", "♪ music playing") : I18n.t("музыка молчит", "no music")
                    dim: !Lyrics.isSong
                }
                Repeater {
                    model: strip.sounds
                    PxButton {
                        required property var modelData
                        compact: true
                        enabled: ed.scene !== null
                        text: modelData[1]
                        onClicked: root.hit(modelData[0])
                    }
                }
                PxButton {
                    compact: true
                    icon: "arrowLeft"
                    enabled: ed.canUndo
                    onClicked: ed.undo()
                }
                PxButton {
                    compact: true
                    icon: "arrowRight"
                    enabled: ed.canRedo
                    onClicked: ed.redo()
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, body.width - x - applyRow.width - Theme.u * 2)
                    elide: Text.ElideRight
                    kind: "tiny"
                    dim: true
                    text: ed.note
                }
            }
            Row {
                id: applyRow
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.u * 2
                PxCombo {
                    id: screens
                    width: Theme.u * 56
                    model: [{
                            "label": I18n.t("Все экраны", "All screens"),
                            "value": ""
                        }].concat(Quickshell.screens.map(s => ({
                                "label": s.name,
                                "value": s.name
                            })))
                    // never the screen on the stream by itself
                    currentValue: {
                        const s = Quickshell.screens.find(s => !StreamMode.onStream(s.name));
                        return s ? s.name : "";
                    }
                    onActivated: v => currentValue = v
                }
                PxButton {
                    accent: true
                    enabled: ed.scene !== null
                    text: I18n.t("На обои", "Set as wallpaper")
                    onClicked: ed.apply(screens.currentValue)
                }
            }
        }
    }

    function hit(source) {
        const d = stage.drums;
        if (source === "kick")
            d.kicked(1, 0.6, 0);
        else if (source === "snare")
            d.snared(1, 0.5);
        else
            d.hatted(1);
    }

    // ---- one modifier ----
    component ModCard: PxBox {
        id: card
        required property int index
        readonly property var m: ed.mods[index] || ({})
        readonly property bool wave: m.type === "wave"
        readonly property var sources: [{
                "label": I18n.t("Бочка", "Kick"),
                "value": "kick"
            }, {
                "label": I18n.t("Снейр", "Snare"),
                "value": "snare"
            }, {
                "label": I18n.t("Хэт", "Hat"),
                "value": "hat"
            }]
        property bool more: false
        height: col.height + Theme.u * 6
        sunken: ed.sel === index
        MouseArea {
            anchors.fill: parent
            onPressed: e => {
                ed.sel = card.index;
                e.accepted = false;
            }
        }
        Column {
            id: col
            x: Theme.u * 3
            y: Theme.u * 3
            width: parent.width - Theme.u * 6
            spacing: Theme.u * 2
            Item {
                width: parent.width
                height: head.height
                PxCheck {
                    id: head
                    text: card.wave ? I18n.t("Волна", "Wave") + (card.m.zone ? " " + I18n.t("из зоны", "out of the zone") : "") : I18n.t("Толчок", "Push")
                    checked: card.m.on !== false
                    onToggled: c => ed.setMod(card.index, "on", c)
                }
                PxButton {
                    anchors.right: parent.right
                    compact: true
                    icon: "close"
                    onClicked: ed.remove(card.index)
                }
            }
            PxCombo {
                width: parent.width
                model: card.sources
                currentValue: card.m.source
                onActivated: v => ed.setMod(card.index, "source", v)
            }
            Labeled {
                label: I18n.t("Сила", "Strength")
                PxSlider {
                    width: parent.width
                    from: 0
                    to: 100
                    stepSize: 1
                    suffix: " %"
                    value: (card.m.strength === undefined ? 0.6 : card.m.strength) * 100
                    onMoved: v => ed.setMod(card.index, "strength", v / 100)
                }
            }
            Labeled {
                label: card.wave ? I18n.t("Скорость", "Speed") : I18n.t("Возврат", "Return")
                PxSlider {
                    width: parent.width
                    from: card.wave ? 40 : 60
                    to: card.wave ? 250 : 600
                    stepSize: card.wave ? 5 : 10
                    suffix: card.wave ? " %" : I18n.t(" мс", " ms")
                    value: card.wave ? (card.m.speed || 1) * 100 : (card.m.release || 0.18) * 1000
                    onMoved: v => ed.setMod(card.index, card.wave ? "speed" : "release", card.wave ? v / 100 : v / 1000)
                }
            }
            PxButton {
                compact: true
                flat: true
                text: card.more ? I18n.t("Меньше", "Less") : I18n.t("Ещё", "More")
                onClicked: card.more = !card.more
            }
            Labeled {
                visible: card.more
                label: I18n.t("Порог: слабее не срабатывает", "Threshold: softer hits do nothing")
                PxSlider {
                    width: parent.width
                    from: 0
                    to: 100
                    stepSize: 1
                    suffix: " %"
                    value: (card.m.threshold || 0) * 100
                    onMoved: v => ed.setMod(card.index, "threshold", v / 100)
                }
            }
            PxCheck {
                visible: card.more
                text: I18n.t("Все удары одинаково", "Every hit alike")
                checked: card.m.even === true
                onToggled: c => ed.setMod(card.index, "even", c)
            }
            PxCheck {
                visible: card.more && card.wave
                text: I18n.t("Гнёт и виджеты", "Bends the widgets too")
                checked: card.m.widgets !== false
                onToggled: c => ed.setMod(card.index, "widgets", c)
            }
            PxButton {
                visible: card.more && card.wave && !!card.m.zone
                compact: true
                text: I18n.t("Отвязать от зоны", "Detach from the zone")
                onClicked: ed.setMod(card.index, "center", stage.centerOf(card.m))
            }
        }
    }
    RightClickGuard {}

    component Labeled: Column {
        property alias label: name.text
        default property alias content: place.data
        width: parent.width
        spacing: Theme.u
        PxText {
            id: name
            kind: "tiny"
            dim: true
        }
        Item {
            id: place
            width: parent.width
            height: childrenRect.height
        }
    }
}
