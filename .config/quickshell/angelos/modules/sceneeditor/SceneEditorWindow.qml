pragma ComponentBehavior: Bound


import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The live wallpaper's scene editor (through the stub services/SceneEditor): a window of the
// shell. On the left the pictures, in the middle one of them with its layers over it, on the
// right what to do with it: paint the layers (what is sky, water, a waterfall …), switch
// effects off, put the places of the rare events and the rings, hand a request to Claude.
// Everything is written to <picture>.scene.json (scripts/live-wall.py reads it) through the
// editor's server (SceneModel → scene-editor.py → scene_core); Claude changes the same file
// over MCP (scene-mcp.py) and the window picks that up by itself.
// Opened by `angelos scene edit [picture]`, «Пуск», Settings → Wallpaper → Alive, Dotfiles →
// «Анимация…». The «Claude» tab is the author's only (SceneEditor.claude). The old page in a browser window: `angelos scene web`.
FloatingWindow {
    id: root

    title: Shell.appTitle + " · " + I18n.t("Редактор живых обоев", "Alive wallpaper editor")
    visible: SceneEditor.shown
    color: "transparent"
    implicitWidth: 1500
    implicitHeight: 920
    minimumSize: Qt.size(1040, 640)
    onClosed: root.leave()
    onVisibleChanged: if (!visible)
        SceneEditor.open = false

    // unsaved changes are written before the window (and the server behind it) goes
    function leave() {
        if (ed.dirty)
            ed.save(false, () => SceneEditor.open = false);
        else
            SceneEditor.open = false;
    }

    SceneModel {
        id: ed
        running: SceneEditor.shown
    }
    Connections {
        target: SceneEditor
        function onAsked(picture) {
            if (picture)
                ed.openPic(picture);
        }
    }

    // (for the self-test: the state and the picture's stage)
    readonly property alias model: ed
    readonly property alias stage: stage
    readonly property alias frame: frame

    property string tab: "paint"        // paint | fx | points | claude
    onTabChanged: {
        if (tab === "points" && ed.tool !== "ring")
            ed.tool = "points";
        else if (tab === "claude")
            ed.tool = "region";
        else if (tab === "paint" && !["brush", "rect", "lasso", "fill", "pick"].includes(ed.tool))
            ed.tool = "brush";
    }
    function selectLayer(id) {
        ed.inLayer = id;
        if (!["brush", "rect", "lasso", "fill"].includes(ed.tool))
            ed.tool = "brush";
    }

    // keys, on both layouts: the tools, the layers, undo, save
    component Key: Shortcut {
        context: Qt.WindowShortcut
    }
    Key {
        sequences: ["Ctrl+S", "Ctrl+Ы"]
        onActivated: ed.save()
    }
    Key {
        sequences: ["Ctrl+Z", "Ctrl+Я"]
        onActivated: ed.restore(true)
    }
    Key {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Shift+Я", "Ctrl+Y", "Ctrl+Н"]
        onActivated: ed.restore(false)
    }
    Key {
        sequences: ["B", "И"]
        onActivated: ed.tool = "brush"
    }
    Key {
        sequences: ["R", "К"]
        onActivated: ed.tool = "rect"
    }
    Key {
        sequences: ["L", "Д"]
        onActivated: ed.tool = "lasso"
    }
    Key {
        sequences: ["F", "А"]
        onActivated: ed.tool = "fill"
    }
    Key {
        sequences: ["I", "Ш"]
        onActivated: ed.tool = "pick"
    }
    Key {
        sequences: ["E", "У"]
        onActivated: root.selectLayer(-1)
    }
    Key {
        sequences: ["Return", "Enter"]
        enabled: ed.tool === "lasso"
        onActivated: stage.closeLasso()
    }
    Key {
        sequence: "Escape"
        enabled: !!stage.ghost
        onActivated: stage.cancel()
    }
    Key {
        sequences: ["[", "Х"]
        onActivated: ed.brush = Math.max(1, ed.brush - 1)
    }
    Key {
        sequences: ["]", "Ъ"]
        onActivated: ed.brush = Math.min(40, ed.brush + 1)
    }
    Repeater {
        model: 7
        Item {
            id: digit
            required property int index
            Key {
                sequence: String(digit.index)
                onActivated: root.selectLayer(digit.index)
            }
        }
    }

    PxWindow {
        id: frame
        anchors.fill: parent
        anchors.rightMargin: Theme.u * 2
        anchors.bottomMargin: Theme.u * 2
        skin: ""
        // a tool to read at a glance: no desktop showing through
        translucent: false
        title: "angelOS · " + I18n.t("Редактор живых обоев", "Alive wallpaper editor")
        icon: "layers"
        onCloseClicked: root.leave()
        onTitlePressed: root.startSystemMove()

        // the editor's own look: classic in every settings skin
        Item {
            id: body
            readonly property string settingsSkin: "classic"
            width: parent.width
            height: parent.height

            // ---- the picture's name, saving, what to do with the file ----
            Item {
                id: head
                width: parent.width
                height: headButtons.height
                PxText {
                    id: picName
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - headButtons.width - saveNote.width - Theme.u * 12)
                    elide: Text.ElideMiddle
                    font.bold: true
                    text: ed.pic ? ed.pic.replace(Config.home, "~") : I18n.t("выбери картинку слева", "pick a picture on the left")
                }
                PxText {
                    id: saveNote
                    anchors.left: picName.right
                    anchors.leftMargin: Theme.u * 5
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "tiny"
                    dim: true
                    text: ed.saveState
                }
                Row {
                    id: headButtons
                    anchors.right: parent.right
                    spacing: Theme.u * 2
                    PxCheck {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("автосохранение", "autosave")
                        checked: ed.autosave
                        onToggled: c => ed.autosave = c
                    }
                    PxButton {
                        compact: true
                        accent: enabled
                        enabled: ed.dirty && !ed.saving
                        text: I18n.t("Сохранить", "Save")
                        onClicked: ed.save()
                    }
                    PxButton {
                        compact: true
                        icon: "arrowLeft"
                        enabled: ed.undoStack.length > 0
                        onClicked: ed.restore(true)
                    }
                    PxButton {
                        compact: true
                        icon: "arrowRight"
                        enabled: ed.redoStack.length > 0
                        onClicked: ed.restore(false)
                    }
                    PxButton {
                        id: revert
                        compact: true
                        enabled: !!ed.pic
                        property bool sure: false
                        text: sure ? I18n.t("точно откатить?", "roll it back?") : I18n.t("откат файла", "file back")
                        danger: sure
                        onClicked: {
                            if (!sure) {
                                sure = true;
                                revertSure.restart();
                            } else {
                                sure = false;
                                ed.revertFile();
                            }
                        }
                        Timer {
                            id: revertSure
                            interval: 3000
                            onTriggered: revert.sure = false
                        }
                    }
                    // on a screen to look at it: not one the user streams (Settings → Stream mode →
                    // screens), unless there is no other
                    Repeater {
                        model: Quickshell.screens.filter(s => !(Config.stream.screens || []).includes(s.name) || Quickshell.screens.length === 1)
                        PxButton {
                            required property var modelData
                            compact: true
                            icon: "monitor"
                            enabled: !!ed.pic
                            text: modelData.name
                            onClicked: ed.showOn(modelData.name)
                        }
                    }
                    PxButton {
                        compact: true
                        icon: "folder"
                        enabled: !!ed.pic
                        onClicked: ed.openFolder()
                    }
                }
            }

            // someone else changed the scene under unsaved changes
            PxBox {
                id: banner
                visible: ed.banner !== ""
                anchors.top: head.bottom
                anchors.topMargin: visible ? Theme.u * 3 : 0
                width: parent.width
                height: visible ? bannerRow.height + Theme.u * 6 : 0
                color: Theme.mix(Theme.face, Theme.accent, 0.25)
                Row {
                    id: bannerRow
                    x: Theme.u * 4
                    y: Theme.u * 3
                    spacing: Theme.u * 4
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ed.banner
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Взять его версию", "Take theirs")
                        onClicked: ed.reload(I18n.t("взял чужую версию", "took theirs"))
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Оставить мою", "Keep mine")
                        onClicked: {
                            ed.banner = "";
                            ed.save(true);
                        }
                    }
                }
            }

            // ---- the pictures ----
            Item {
                id: left
                anchors.top: banner.bottom
                anchors.topMargin: Theme.u * 4
                anchors.bottom: parent.bottom
                width: Theme.u * 106
                PxField {
                    id: search
                    width: parent.width
                    icon: "search"
                    placeholder: I18n.t("поиск картинки…", "find a picture…")
                }
                PxBox {
                    anchors.top: search.bottom
                    anchors.topMargin: Theme.u * 2
                    anchors.bottom: parent.bottom
                    width: parent.width
                    sunken: true
                    color: Theme.sunken
                    ListView {
                        id: list
                        anchors.fill: parent
                        anchors.margins: Theme.u * 2
                        clip: true
                        spacing: Theme.u
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: Theme.u * 80
                        model: {
                            const s = search.text.trim().toLowerCase();
                            return s ? ed.pics.filter(p => p.path.toLowerCase().includes(s) || p.where.toLowerCase().includes(s)) : ed.pics;
                        }
                        delegate: Item {
                            id: picRow
                            required property var modelData
                            readonly property bool current: modelData.path === ed.pic
                            width: list.width
                            height: Theme.u * 22
                            Rectangle {
                                anchors.fill: parent
                                color: picRow.current ? Theme.select : rowMouse.containsMouse ? Theme.faceAlt : "transparent"
                            }
                            Image {
                                id: thumb
                                x: Theme.u
                                y: Theme.u
                                width: Theme.u * 34
                                height: parent.height - Theme.u * 2
                                source: ed.pictureUrl(picRow.modelData.path, 240)
                                sourceSize: Qt.size(240, 135)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: false
                            }
                            Column {
                                anchors.left: thumb.right
                                anchors.leftMargin: Theme.u * 3
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.u
                                anchors.verticalCenter: parent.verticalCenter
                                PxText {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    kind: "tiny"
                                    color: picRow.current ? Theme.selectText : Theme.text
                                    text: picRow.modelData.path.slice(picRow.modelData.path.lastIndexOf("/") + 1)
                                }
                                PxText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    kind: "tiny"
                                    color: picRow.current ? Theme.selectText : Theme.textDim
                                    text: (picRow.modelData.scene ? "✦ " + I18n.t("сцена", "scene") + " · " : "") + picRow.modelData.where
                                }
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ed.openPic(picRow.modelData.path)
                            }
                        }
                    }
                }
            }

            // ---- the picture ----
            SceneStage {
                id: stage
                ed: ed
                anchors.top: left.top
                anchors.bottom: parent.bottom
                anchors.left: left.right
                anchors.leftMargin: Theme.u * 4
                anchors.right: right.left
                anchors.rightMargin: Theme.u * 4
            }

            // ---- what to do with it ----
            Item {
                id: right
                anchors.top: left.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: Theme.u * 146

                Row {
                    id: tabs
                    spacing: Theme.u
                    Repeater {
                        // «Claude»: the author's MCP server only (services/SceneEditor.claude)
                        model: [["paint", I18n.t("Слои", "Layers")], ["fx", I18n.t("Эффекты", "Effects")], ["points", I18n.t("Места", "Places")]].concat(SceneEditor.claude ? [["claude", "Claude" + (ed.openRequests ? " · " + ed.openRequests : "")]] : [])
                        PxButton {
                            required property var modelData
                            compact: true
                            text: modelData[1]
                            checked: root.tab === modelData[0]
                            onClicked: root.tab = modelData[0]
                        }
                    }
                }

                PxScroll {
                    id: scroll
                    anchors.top: tabs.bottom
                    anchors.topMargin: Theme.u * 3
                    anchors.bottom: statusLine.top
                    anchors.bottomMargin: Theme.u * 2
                    width: parent.width
                    contentHeight: panel.implicitHeight + Theme.u * 4

                    Column {
                        id: panel
                        width: scroll.width - Theme.u * 8
                        spacing: Theme.u * 3

                        // (inline components do not see this file's ids: they take the width of
                        // the column they are put in)
                        component Hint: PxText {
                            width: parent ? parent.width : 0
                            wrapMode: Text.Wrap
                            kind: "tiny"
                            dim: true
                        }
                        component Head: PxText {
                            width: parent ? parent.width : 0
                            font.bold: true
                            topPadding: Theme.u * 2
                        }
                        // "label [slider]": a slider with its name before it. The value is the
                        // model's: the slider reports a move and is moved by the answer, so a
                        // key or an undo that changes the value moves it too
                        component Slide: Item {
                            id: slide
                            property string label
                            property alias from: slider.from
                            property alias to: slider.to
                            property alias stepSize: slider.stepSize
                            property alias value: slider.value
                            property alias suffix: slider.suffix
                            property alias sliderEnabled: slider.enabled
                            readonly property alias dragging: slider.dragging
                            signal moved(real value)
                            signal released(real value)
                            width: parent ? parent.width : 0
                            height: slider.height
                            PxText {
                                id: slideLabel
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.u * 44
                                elide: Text.ElideRight
                                kind: "tiny"
                                dim: true
                                text: slide.label
                            }
                            PxSlider {
                                id: slider
                                anchors.left: slideLabel.right
                                anchors.right: parent.right
                                live: false
                                opacity: enabled ? 1 : 0.4
                                onMoved: v => slide.moved(v)
                                onReleased: v => slide.released(v)
                            }
                        }

                        // ======== the layers ========
                        Column {
                            visible: root.tab === "paint"
                            width: panel.width
                            spacing: Theme.u * 3
                            Hint {
                                text: I18n.t("Закрась, что чем является — так и будет двигаться. «Как найдено» стирает твой рисунок: там решает автоматика.", "Paint what is what: that is how it will move. “As found” wipes your painting: the look decides there.")
                            }
                            Column {
                                width: panel.width
                                spacing: Theme.u
                                Repeater {
                                    model: [{
                                            "id": -1,
                                            "name": I18n.t("Как найдено", "As found"),
                                            "what": I18n.t("стереть рисунок — решает автоматика", "wipe the painting: the look decides"),
                                            "rgb": null
                                        }].concat(ed.meta ? ed.meta.layers : [])
                                    Item {
                                        id: layerRow
                                        required property var modelData
                                        readonly property bool current: ed.inLayer === modelData.id
                                        width: panel.width
                                        height: Math.max(Theme.u * 11, layerText.implicitHeight + Theme.u * 3)
                                        Rectangle {
                                            anchors.fill: parent
                                            color: layerRow.current ? Theme.select : layerMouse.containsMouse ? Theme.faceAlt : "transparent"
                                        }
                                        PxText {
                                            id: layerKey
                                            x: Theme.u * 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Theme.u * 5
                                            kind: "mono"
                                            color: layerRow.current ? Theme.selectText : Theme.textDim
                                            text: layerRow.modelData.id < 0 ? "E" : layerRow.modelData.id
                                        }
                                        Rectangle {
                                            id: swatch
                                            anchors.left: layerKey.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Theme.u * 7
                                            height: Theme.u * 7
                                            color: layerRow.modelData.rgb ? Qt.rgba(layerRow.modelData.rgb[0] / 255, layerRow.modelData.rgb[1] / 255, layerRow.modelData.rgb[2] / 255, 1) : Theme.sunken
                                            border.color: Theme.edge
                                            border.width: Theme.u
                                            // "as found": a cross, nothing of its own
                                            PxIcon {
                                                visible: !layerRow.modelData.rgb
                                                anchors.centerIn: parent
                                                name: "close"
                                                pixel: Math.max(1, Math.floor(Theme.u / 2))
                                            }
                                        }
                                        PxText {
                                            id: layerText
                                            anchors.left: swatch.right
                                            anchors.leftMargin: Theme.u * 3
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            wrapMode: Text.Wrap
                                            kind: "tiny"
                                            textFormat: Text.StyledText
                                            color: layerRow.current ? Theme.selectText : Theme.text
                                            text: "<b>" + layerRow.modelData.name + "</b> — " + layerRow.modelData.what
                                        }
                                        MouseArea {
                                            id: layerMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectLayer(layerRow.modelData.id)
                                        }
                                    }
                                }
                            }
                            PxSegmented {
                                width: panel.width
                                model: [["brush", I18n.t("кисть B", "brush B")], ["rect", I18n.t("прямоуг. R", "rect R")], ["lasso", I18n.t("лассо L", "lasso L")], ["fill", I18n.t("заливка F", "fill F")], ["pick", I18n.t("пипетка I", "pick I")]].map(t => ({
                                            "label": t[1],
                                            "value": t[0]
                                        }))
                                currentValue: ed.tool
                                onActivated: v => ed.tool = v
                            }
                            Hint {
                                visible: ed.tool === "lasso"
                                text: I18n.t("лассо: клики по точкам, двойной клик или Enter замыкает, Esc отменяет", "the lasso: click the points, a double click or Enter closes it, Esc drops it")
                            }
                            Slide {
                                label: I18n.t("кисть", "brush")
                                from: 1
                                to: 40
                                stepSize: 1
                                value: ed.brush
                                onMoved: v => ed.brush = Math.round(v)
                            }
                            Slide {
                                label: I18n.t("допуск заливки", "fill tolerance")
                                from: 1
                                to: 40
                                stepSize: 1
                                value: ed.tolerance
                                onMoved: v => ed.tolerance = Math.round(v)
                            }
                            PxSegmented {
                                width: panel.width
                                model: [["final", I18n.t("итог", "result")], ["found", I18n.t("найденное", "found")], ["paint", I18n.t("мой рисунок", "my paint")], ["picture", I18n.t("без слоёв", "no layers")]].map(t => ({
                                            "label": t[1],
                                            "value": t[0]
                                        }))
                                currentValue: ed.view
                                onActivated: v => ed.view = v
                            }
                            Slide {
                                label: I18n.t("прозрачность", "opacity")
                                from: 0
                                to: 100
                                stepSize: 5
                                suffix: " %"
                                value: Math.round(ed.overlay * 100)
                                onMoved: v => ed.overlay = v / 100
                            }
                            Slide {
                                label: I18n.t("масштаб", "zoom")
                                from: 100
                                to: 800
                                stepSize: 25
                                suffix: " %"
                                value: Math.round(ed.zoom * 100)
                                onMoved: v => ed.zoom = v / 100
                            }
                            Hint {
                                text: I18n.t("Ctrl + колесо — масштаб, колесо — прокрутка, Shift + колесо — вбок", "Ctrl + wheel zooms, the wheel scrolls, Shift + wheel goes sideways")
                            }
                            Flow {
                                width: parent.width
                                spacing: Theme.u * 2
                                PxCombo {
                                    id: foundLayer
                                    width: Theme.u * 44
                                    model: ed.meta ? ed.meta.layers.map(l => ({
                                                "label": l.name,
                                                "value": l.id
                                            })) : []
                                    currentValue: 1
                                    onActivated: v => currentValue = v
                                }
                                PxButton {
                                    compact: true
                                    enabled: !!ed.paint
                                    text: I18n.t("найденное → выбранный слой", "found → the chosen layer")
                                    onClicked: ed.foundToLayer(foundLayer.currentValue)
                                }
                            }
                            PxButton {
                                id: wipe
                                compact: true
                                enabled: !!ed.paint
                                property bool sure: false
                                danger: true
                                text: sure ? I18n.t("точно стереть весь рисунок?", "wipe the whole painting?") : I18n.t("стереть весь рисунок", "wipe the whole painting")
                                onClicked: {
                                    if (!sure) {
                                        sure = true;
                                        wipeSure.restart();
                                    } else {
                                        sure = false;
                                        ed.clearPaint();
                                    }
                                }
                                Timer {
                                    id: wipeSure
                                    interval: 3000
                                    onTriggered: wipe.sure = false
                                }
                            }
                            Hint {
                                text: I18n.t("Клетка редактора — один пиксель арта (сетка ", "A cell of the editor is one art pixel (the grid is ") + (ed.gw ? ed.gw + "×" + ed.gh + (ed.info.pixelArt ? I18n.t(", пиксель-арт", ", pixel art") : I18n.t(", фото", ", a photo")) : "—") + ")."
                            }
                        }

                        // ======== the effects ========
                        Column {
                            visible: root.tab === "fx"
                            width: panel.width
                            spacing: Theme.u * 3
                            Hint {
                                text: I18n.t("Что эти обои не делают никогда (остальное — как в Настройках → Обои → Живые).", "What this wallpaper never does (the rest is as in Settings → Wallpaper → Alive).")
                            }
                            Repeater {
                                model: ed.meta ? ed.meta.effects : []
                                PxCheck {
                                    required property var modelData
                                    text: modelData.name
                                    checked: {
                                        ed.rev;
                                        return (ed.scene.effects || {})[modelData.key] !== false;
                                    }
                                    onToggled: c => ed.setEffect(modelData.key, c)
                                }
                            }
                            Head {
                                text: I18n.t("Небо и вода", "Sky and water")
                            }
                            PxCheck {
                                id: nightAuto
                                text: I18n.t("ночь: сама", "night: by itself")
                                checked: typeof ed.scene.night !== "number"
                                onToggled: c => ed.setValue("night", c ? undefined : (ed.info.night || 0), I18n.t("ночь", "the night"))
                            }
                            Slide {
                                label: I18n.t("ночь", "night")
                                from: 0
                                to: 100
                                stepSize: 5
                                suffix: " %"
                                sliderEnabled: !nightAuto.checked
                                value: Math.round((typeof ed.scene.night === "number" ? ed.scene.night : ed.info.night || 0) * 100)
                                onDraggingChanged: if (dragging)
                                    ed.snapshot()
                                onMoved: v => ed.setScene("night", v / 100)
                                onReleased: ed.changed(I18n.t("ночь", "the night"))
                            }
                            Hint {
                                text: I18n.t("звёзды выходят с 50 %", "the stars come out from 50 %")
                            }
                            PxCheck {
                                id: axisAuto
                                text: I18n.t("линия воды: сама", "the waterline: by itself")
                                checked: typeof ed.scene.axis !== "number"
                                onToggled: c => ed.setValue("axis", c ? undefined : ((ed.info.water && ed.info.water.axis) || 0.65), I18n.t("линия воды", "the waterline"))
                            }
                            Slide {
                                label: I18n.t("линия воды", "waterline")
                                from: 0
                                to: 100
                                stepSize: 1
                                suffix: " %"
                                sliderEnabled: !axisAuto.checked
                                value: Math.round((typeof ed.scene.axis === "number" ? ed.scene.axis : (ed.info.water && ed.info.water.axis) || 0.65) * 100)
                                onDraggingChanged: if (dragging)
                                    ed.snapshot()
                                onMoved: v => ed.setScene("axis", v / 100)
                                onReleased: ed.changed(I18n.t("линия воды", "the waterline"))
                            }
                            Hint {
                                text: I18n.t("отражение в воде", "the reflection in the water")
                            }
                            PxSegmented {
                                width: panel.width
                                model: [["auto", I18n.t("как найдено", "as found")], ["on", I18n.t("есть", "yes")], ["off", I18n.t("нет", "no")]].map(t => ({
                                            "label": t[1],
                                            "value": t[0]
                                        }))
                                currentValue: typeof ed.scene.mirror === "boolean" ? (ed.scene.mirror ? "on" : "off") : "auto"
                                onActivated: v => ed.setValue("mirror", v === "auto" ? undefined : v === "on", I18n.t("отражение", "the reflection"))
                            }
                            Head {
                                text: I18n.t("Посмотреть на рабочем столе", "See it on the desktop")
                            }
                            Flow {
                                width: panel.width
                                spacing: Theme.u * 2
                                Repeater {
                                    model: [["glint", I18n.t("блик", "glint")], ["pebble", I18n.t("камешек", "pebble")], ["gust", I18n.t("ветер", "gust")], ["eye", I18n.t("глаз", "eye")], ["rings", I18n.t("круги", "rings")]]
                                    PxButton {
                                        required property var modelData
                                        compact: true
                                        text: modelData[1]
                                        onClicked: ed.poke(modelData[0])
                                    }
                                }
                            }
                            Hint {
                                text: I18n.t("событие сразу на всех экранах, где у сцены оно есть", "the event at once on every screen whose scene has it")
                            }
                        }

                        // ======== the places ========
                        Column {
                            visible: root.tab === "points"
                            width: panel.width
                            spacing: Theme.u * 3
                            Hint {
                                text: I18n.t("Где случаются редкие события. Клик — поставить, правый клик — убрать ближайшее. Пока своих нет, берутся найденные (бледные).", "Where the rare events happen. A click puts one, a right click takes the nearest away. Until there are own ones the found ones (pale) are used.")
                            }
                            PxSegmented {
                                width: panel.width
                                model: [["rims", I18n.t("камешек", "pebble")], ["eyes", I18n.t("глаз", "eye")], ["ponds", I18n.t("круги", "rings")], ["lights", I18n.t("огонёк", "light")]].map(t => ({
                                            "label": t[1],
                                            "value": t[0]
                                        }))
                                currentValue: ed.tool === "points" ? ed.pointKind : ""
                                onActivated: v => {
                                    ed.pointKind = v;
                                    ed.tool = "points";
                                    ed.rev++;
                                }
                            }
                            Hint {
                                text: {
                                    ed.rev;
                                    const own = Array.isArray(ed.scene[ed.pointKind]);
                                    return (ed.meta ? ed.meta.points[ed.pointKind] + ": " : "") + (own ? I18n.t("своих ", "own ") + ed.scene[ed.pointKind].length : I18n.t("найденных ", "found ") + (ed.places[ed.pointKind] || []).length);
                                }
                            }
                            Flow {
                                width: panel.width
                                spacing: Theme.u * 2
                                PxButton {
                                    compact: true
                                    enabled: !!ed.paint
                                    text: I18n.t("взять найденные как свои", "take the found ones as own")
                                    onClicked: ed.setValue(ed.pointKind, (ed.places[ed.pointKind] || []).slice(), I18n.t("места", "the places"))
                                }
                                PxButton {
                                    compact: true
                                    danger: true
                                    enabled: !!ed.paint
                                    text: I18n.t("убрать свои", "drop own ones")
                                    onClicked: ed.setValue(ed.pointKind, undefined, I18n.t("места", "the places"))
                                }
                            }
                            Head {
                                text: I18n.t("Кольца в небе", "Rings in the sky")
                            }
                            Hint {
                                text: I18n.t("Инструмент «кольцо»: тяни от центра. Камень кольца найдётся в этой полосе сам (наклон тоже). Правый клик по кольцу — убрать.", "The ring tool: drag from the centre. The ring's stone is found in that band by itself (its tilt too). A right click on a ring takes it away.")
                            }
                            PxButton {
                                compact: true
                                checked: ed.tool === "ring"
                                text: I18n.t("кольцо", "a ring")
                                onClicked: ed.tool = "ring"
                            }
                            Slide {
                                label: I18n.t("толщина", "thickness")
                                from: 2
                                to: 30
                                stepSize: 1
                                value: ed.ringT
                                onMoved: v => ed.ringT = Math.round(v)
                            }
                            Hint {
                                text: {
                                    ed.rev;
                                    const n = (ed.scene.rings || []).length;
                                    return n ? I18n.t("колец: ", "rings: ") + n : I18n.t("колец нет", "no rings");
                                }
                            }
                        }

                        // ======== Claude ========
                        Column {
                            visible: root.tab === "claude" && SceneEditor.claude
                            width: panel.width
                            spacing: Theme.u * 3
                            Hint {
                                text: I18n.t("Обведи места и напиши, что сделать. Claude видит запрос через MCP (angelos-scene), правит ту же сцену — изменения появятся здесь сами.", "Mark the places and write what to do. Claude sees the request over MCP (angelos-scene) and changes the same scene: what it does shows up here by itself.")
                            }
                            Flow {
                                width: panel.width
                                spacing: Theme.u * 2
                                PxButton {
                                    compact: true
                                    checked: ed.tool === "region"
                                    text: I18n.t("обвести для Claude", "mark for Claude")
                                    onClicked: ed.tool = "region"
                                }
                                PxButton {
                                    compact: true
                                    enabled: ed.regions.length > 0
                                    text: I18n.t("очистить", "clear")
                                    onClicked: ed.regions = []
                                }
                                PxText {
                                    kind: "tiny"
                                    dim: true
                                    text: ed.regions.length ? I18n.t("областей: ", "regions: ") + ed.regions.length : ""
                                }
                            }
                            PxTextArea {
                                id: note
                                width: panel.width
                                height: Theme.u * 50
                                placeholder: I18n.t("например: «облака справа должны плыть, а гора — стоять; глаз только в левом облаке»", "for example: the clouds on the right should drift and the mountain stand; an eye only in the left cloud")
                            }
                            PxButton {
                                accent: true
                                enabled: !!ed.pic
                                text: I18n.t("Отдать Claude", "Hand to Claude")
                                onClicked: ed.sendRequest(note.text, () => note.text = "")
                            }
                            Head {
                                text: I18n.t("Запросы", "Requests")
                            }
                            Hint {
                                visible: ed.requests.length === 0
                                text: I18n.t("пока ничего", "nothing yet")
                            }
                            Repeater {
                                model: ed.requests
                                PxBox {
                                    id: req
                                    required property var modelData
                                    width: panel.width
                                    height: reqCol.implicitHeight + Theme.u * 6
                                    color: Theme.faceAlt
                                    Column {
                                        id: reqCol
                                        x: Theme.u * 3
                                        y: Theme.u * 3
                                        width: parent.width - Theme.u * 6
                                        spacing: Theme.u
                                        PxText {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            kind: "tiny"
                                            color: req.modelData.status === "done" ? Theme.ok : req.modelData.status === "working" ? Theme.accent : Theme.textDim
                                            text: (({
                                                        "new": I18n.t("ждёт", "waiting"),
                                                        "working": I18n.t("Claude работает", "Claude is on it"),
                                                        "done": I18n.t("готово", "done")
                                                    })[req.modelData.status] || req.modelData.status) + " · " + req.modelData.created + " · " + req.modelData.picture.slice(req.modelData.picture.lastIndexOf("/") + 1)
                                        }
                                        PxText {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: req.modelData.note || I18n.t("(без текста)", "(no text)")
                                        }
                                        PxText {
                                            visible: (req.modelData.regions || []).length > 0
                                            kind: "tiny"
                                            dim: true
                                            text: I18n.t("областей: ", "regions: ") + (req.modelData.regions || []).length
                                        }
                                        PxText {
                                            visible: !!req.modelData.reply
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            color: Theme.accent
                                            text: "✦ " + (req.modelData.reply || "")
                                        }
                                        Row {
                                            spacing: Theme.u * 2
                                            PxButton {
                                                compact: true
                                                text: I18n.t("показать", "show")
                                                onClicked: ed.openRequest(req.modelData)
                                            }
                                            PxButton {
                                                compact: true
                                                visible: req.modelData.status !== "done"
                                                text: I18n.t("закрыть", "close")
                                                onClicked: ed.closeRequest(req.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // the last thing done
                PxText {
                    id: statusLine
                    anchors.bottom: parent.bottom
                    width: parent.width
                    kind: "tiny"
                    dim: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: ed.status
                }
            }
        }
    }

    RightClickGuard {}
}
