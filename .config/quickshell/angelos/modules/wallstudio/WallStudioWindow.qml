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
            // one grid: a gap between the parts, a smaller one inside them
            readonly property int gap: Theme.u * 4
            readonly property int inner: Theme.u * 2

            // ---- the picture, the tools over it ----
            Item {
                id: middle
                anchors.left: parent.left
                anchors.right: right.left
                anchors.rightMargin: body.gap
                height: parent.height
                Column {
                    id: tools
                    width: parent.width
                    spacing: body.inner
                    visible: ed.scene !== null
                    Row {
                        spacing: body.inner
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
                    PxText {
                        width: parent.width
                        kind: "tiny"
                        dim: true
                        elide: Text.ElideRight
                        text: ed.tool === "brush" ? I18n.t("Закрась то, что должно стоять на месте, даже если рядом всё качается (корпус колонки, лицо).", "Paint over what must stay put even when all around it moves (a speaker's box, a face).")
                            : ed.tool === "erase" ? I18n.t("Сотри закраску — там снова можно двигаться.", "Rub the paint out — that part may move again.")
                            : I18n.t("Тащи зону мышью, уголки меняют её размер.", "Drag a zone with the mouse; its grips change its size.")
                    }
                }
                StudioStage {
                    id: stage
                    ed: ed
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: tools.visible ? tools.bottom : parent.top
                    anchors.topMargin: tools.visible ? body.inner : 0
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
                            : I18n.t("Перетащи сюда картинку или выбери её справа, в «1 · Картинка». Потом нажми заготовку — и картинка задвигается под музыку.", "Drop a picture here or pick one on the right, in «1 · Picture». Then press a preset — and the picture moves with the music.")
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: body.inner
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

            // ---- one column, in the order of the work: the picture, a preset, what moves, try and set ----
            Item {
                id: right
                anchors.right: parent.right
                width: Theme.u * 130
                height: parent.height
                PxScroll {
                    id: scroll
                    width: parent.width
                    anchors.top: parent.top
                    anchors.bottom: finish.top
                    anchors.bottomMargin: body.gap
                    contentHeight: steps.height
                    Column {
                        id: steps
                        // the bar takes its width from the view (PxScroll); a step in, for the tiles' shadow
                        width: scroll.flick.width - Theme.u
                        spacing: body.gap

                        Step {
                            title: I18n.t("1 · Картинка", "1 · Picture")
                            PxButton {
                                width: parent.width
                                accent: ed.scene === null
                                text: I18n.t("Взять свою картинку…", "Take a picture of yours…")
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
                                placeholder: I18n.t("или открыть готовые обои", "or open a ready wallpaper")
                                onActivated: v => ed.open(v)
                            }
                        }

                        Step {
                            title: I18n.t("2 · Заготовка", "2 · Preset")
                            hint: I18n.t("Нажми — эффект встанет на картинку и сразу покажется одним ударом. Не то — Ctrl+Z.", "Press one — it lands on the picture and shows itself with one hit. Not it — Ctrl+Z.")
                            enabled: ed.scene !== null
                            Grid {
                                id: presets
                                columns: 2
                                spacing: body.inner
                                readonly property int cell: (parent.width - spacing) / 2
                                Repeater {
                                    model: [["speaker", "speaker", I18n.t("Колонка", "Speaker"), I18n.t("выпучивается и пускает волну на бочку", "swells and sends a wave on the kick")], ["wave", "sparkle", I18n.t("Волна", "Wave"), I18n.t("по всей картинке на бочку", "over the whole picture on the kick")], ["shake", "bolt", I18n.t("Встряска", "Jolt"), I18n.t("место дёргается на малый барабан", "a spot jolts on the snare")], ["tick", "star", I18n.t("Дрожь", "Twitch"), I18n.t("лёгкое дрожание на тарелки", "a light twitch on the cymbals")]]
                                    PxTile {
                                        required property var modelData
                                        width: presets.cell
                                        small: true
                                        icon: modelData[1]
                                        text: modelData[2]
                                        hint: modelData[3]
                                        enabled: ed.scene !== null && (modelData[0] === "wave" || ed.bulges < ed.maxBulges)
                                        opacity: enabled ? 1 : 0.5
                                        onClicked: {
                                            const s = ed.addPreset(modelData[0]);
                                            if (s)
                                                Qt.callLater(root.hit, s);
                                        }
                                    }
                                }
                            }
                        }

                        Step {
                            title: I18n.t("3 · Что двигается", "3 · What moves")
                            hint: ed.scene !== null && ed.mods.length === 0 ? I18n.t("Пока ничего. Начни с заготовки выше или добавь сам:", "Nothing yet. Start from a preset above or add one yourself:") : I18n.t("Каждая карточка — одна реакция. Выбранная видна рамкой на картинке.", "Each card is one reaction. The chosen one shows framed on the picture.")
                            visible: ed.scene !== null
                            Row {
                                spacing: body.inner
                                PxButton {
                                    compact: true
                                    enabled: ed.bulges < ed.maxBulges
                                    text: "+ " + I18n.t("Толчок", "Push")
                                    onClicked: ed.addBulge()
                                }
                                PxButton {
                                    compact: true
                                    text: "+ " + I18n.t("Волна", "Wave")
                                    onClicked: ed.addWave()
                                }
                            }
                            Repeater {
                                // the count, not the list: a slider held down must outlive its own change
                                model: ed.mods.length
                                ModCard {
                                    width: steps.width
                                }
                            }
                            // the effects the scene has by itself (Settings → Music and rhythm → Wallpaper)
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
                                    spacing: body.inner
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
                // trying it and setting it stays in sight, whatever the cards above
                Step {
                    id: finish
                    anchors.bottom: parent.bottom
                    width: parent.width - Theme.u
                    title: I18n.t("4 · Проверить и поставить", "4 · Try it and set it")
                    hint: Lyrics.isSong ? I18n.t("Играет музыка — картинка уже двигается под неё. Удар можно дать и вручную:", "Music plays — the picture moves with it already. A hit can be given by hand too:") : I18n.t("Музыка молчит. Дай удар вручную:", "No music. Give a hit by hand:")
                    visible: ed.scene !== null
                    Row {
                        spacing: body.inner
                        Repeater {
                            model: [["kick", I18n.t("Бочка", "Kick")], ["snare", I18n.t("Снейр", "Snare")], ["hat", I18n.t("Хэт", "Hat")]]
                            PxButton {
                                required property var modelData
                                compact: true
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
                    }
                    Row {
                        spacing: body.inner
                        PxCombo {
                            id: screens
                            width: finish.width - setBtn.width - body.inner
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
                            id: setBtn
                            accent: true
                            text: I18n.t("На обои", "Set as wallpaper")
                            onClicked: ed.apply(screens.currentValue)
                        }
                    }
                    PxText {
                        width: parent.width
                        visible: ed.note !== ""
                        wrapMode: Text.WordWrap
                        kind: "tiny"
                        dim: true
                        text: ed.note
                    }
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
            PxText {
                width: parent.width
                wrapMode: Text.WordWrap
                kind: "tiny"
                dim: true
                text: card.wave ? I18n.t("от удара по картинке расходится кольцо и гнёт её", "a hit sends a ring out over the picture, bending it") : I18n.t("зона на картинке на миг выпучивается от удара", "the zone on the picture swells for a moment on a hit")
            }
            Labeled {
                label: I18n.t("От какого звука", "On which sound")
                hint: I18n.t("бочка — низкий удар, снейр — хлопок, хэт — тарелки", "kick — the low thump, snare — the clap, hat — the cymbals")
                PxCombo {
                    width: parent.width
                    model: card.sources
                    currentValue: card.m.source
                    onActivated: v => ed.setMod(card.index, "source", v)
                }
            }
            Labeled {
                label: I18n.t("Сила", "Strength")
                hint: card.wave ? I18n.t("насколько сильно волна гнёт картинку", "how hard the wave bends the picture") : I18n.t("насколько сильно выпучивается зона", "how far the zone swells")
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
                hint: card.wave ? I18n.t("как быстро кольцо бежит по картинке", "how fast the ring runs over the picture") : I18n.t("как быстро зона встаёт обратно: меньше — резче", "how fast the zone settles back: less is snappier")
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
                text: card.more ? I18n.t("Меньше", "Less") : I18n.t("Ещё: порог и тонкости", "More: threshold and finer bits")
                onClicked: card.more = !card.more
            }
            Labeled {
                visible: card.more
                label: I18n.t("Порог", "Threshold")
                hint: I18n.t("удары тише этого ничего не делают — чтобы не дёргалось на тихом", "Hits softer than this do nothing — so it doesn't twitch on the quiet bits")
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
                text: I18n.t("Все удары одинаково (иначе громкие сильнее)", "Every hit alike (else the loud ones harder)")
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

    // a control with its name over it and one line of what it does under it
    component Labeled: Column {
        property alias label: name.text
        property alias hint: what.text
        default property alias content: place.data
        width: parent.width
        spacing: Theme.u
        PxText {
            id: name
            kind: "tiny"
        }
        Item {
            id: place
            width: parent.width
            height: childrenRect.height
        }
        PxText {
            id: what
            width: parent.width
            visible: text !== ""
            wrapMode: Text.WordWrap
            kind: "tiny"
            dim: true
        }
    }
    // one step of the right column: its title, a line of what to do, then its controls
    component Step: Column {
        property alias title: head.text
        property alias hint: what.text
        default property alias content: place.data
        width: parent.width
        spacing: Theme.u * 2
        PxText {
            id: head
            kind: "title"
        }
        PxText {
            id: what
            width: parent.width
            visible: text !== ""
            wrapMode: Text.WordWrap
            kind: "tiny"
            dim: true
        }
        Column {
            id: place
            width: parent.width
            spacing: Theme.u * 2
        }
    }
}
