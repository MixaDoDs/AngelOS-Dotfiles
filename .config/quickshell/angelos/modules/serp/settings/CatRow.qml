pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp
import "../../../widgets/MacIcons.js" as MacIcons

// serp-skin settings: one row of angelOS's settings catalog (CatalogPage's Entry, kinds toggle,
// choice, slider, spin and a labelled button) drawn as Serpantinum's SettingsRow — a soft card,
// a 32 px icon box, the title and its hint, the control on the right (under the texts when it
// doesn't fit beside them). Bound both ways to the entry as CatalogPage's own rows are: the
// entry's value in, its signals out, never assigned. A choice of up to four short options is a
// segmented switch, a longer one a dropdown that unfolds under the row (as FontPick).
Item {
    id: row
    required property var entry
    readonly property string kind: entry ? entry.kind : ""
    readonly property string title: entry ? entry.label : ""
    readonly property string desc: entry ? entry.hint : ""
    property bool expanded: false

    visible: !entry || entry.present
    enabled: !entry || entry.enabled
    opacity: entry ? entry.fade : 1
    width: parent ? parent.width : 0
    implicitHeight: card.height + (gif.item ? gif.item.implicitHeight + Serp.px(8) : 0)

    readonly property int padH: Serp.px(14)
    readonly property int padV: Serp.px(12)

    // ---- what the page wants of a row (SettingRow's): the «new» star and the preview ----
    readonly property bool isNew: {
        if (!SettingsNews.news.count || !title)
            return false;
        let group = null, src = "";
        for (let p = row.parent; p; p = p.parent) {
            if (!group && p.advanced !== undefined && p.name !== undefined && p.title !== undefined)
                group = p;
            if (p.srcName !== undefined) {
                src = p.srcName;
                break;
            }
        }
        return !!group && SettingsNews.rowNew(src, group.name, title);
    }
    property string previewVariant: ""
    property string previewCaption: ""
    property bool previewOpen: false
    function show(value, caption) {
        if (!entry || !entry.preview)
            return;
        previewVariant = String(value);
        previewCaption = caption || "";
        previewOpen = true;
        if (gif.item)
            gif.item.restart();
    }
    Connections {
        target: row.entry
        function onShowPreview(value, caption) {
            row.show(value, caption);
        }
    }

    // ---- the choice: its options' names; a switch while they are few and short ----
    function labelOf(i) {
        return i && i.label !== undefined && i.label !== null && String(i.label) !== "" ? String(i.label) : String(i ? i.value : "");
    }
    readonly property var items: kind === "choice" && entry.items ? entry.items : []
    readonly property int current: kind === "choice" ? entry.currentIndex : -1
    readonly property bool useSwitch: kind === "choice" && !entry.combo && items.length >= 2 && items.length <= 4 && current >= 0 && items.every(i => labelOf(i).length <= 16)
    readonly property bool dropdown: kind === "choice" && !useSwitch

    readonly property string iconName: {
        if (kind === "button" && entry.icon) {
            const n = MacIcons.fromPixel(entry.icon);
            if (n)
                return n;
        }
        return ({
                "toggle": "toggle-right",
                "choice": "list-filter",
                "slider": "sliders-horizontal",
                "spin": "gauge",
                "button": "zap"
            })[kind] || "settings";
    }

    // the row's extra buttons (CatButton), before or after its control
    component Acts: Repeater {
        id: acts
        property var entry: null
        property bool lead: false
        model: entry ? entry.actions.filter(a => a.lead === acts.lead) : []
        PillButton {
            required property var modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            visible: modelData.present
            enabled: modelData.enabled
            opacity: enabled ? 1 : 0.45
            label: modelData.text
            icon: modelData.icon ? MacIcons.fromPixel(modelData.icon) : ""
            primary: modelData.accent || modelData.checked
            implicitHeight: Serp.px(30)
            onClicked: modelData.clicked()
        }
    }

    Rectangle {
        id: card
        width: parent.width
        height: head.height + (row.expanded && row.dropdown ? belowBox.height + row.padV : 0)
        clip: true
        radius: Serp.radius
        color: hov.hovered ? Qt.alpha(Serp.surface1, 0.4) : Qt.alpha(Serp.surface0, 0.4)
        Behavior on color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
        HoverHandler {
            id: hov
        }

        Item {
            id: head
            readonly property real textH: Math.max(Serp.px(32), texts.implicitHeight)
            // the control under the texts when it would squeeze them under ~160 px
            readonly property bool stacked: ctl.implicitWidth > card.width - row.padH * 2 - Serp.px(44) - Serp.px(160)
            width: parent.width
            height: stacked ? row.padV + textH + Serp.px(10) + ctl.implicitHeight + row.padV : Math.max(textH, ctl.implicitHeight) + row.padV * 2

            Rectangle {
                id: iconBox
                x: row.padH
                y: head.stacked ? row.padV + (head.textH - height) / 2 : (head.height - height) / 2
                width: Serp.px(32)
                height: width
                radius: Serp.radiusSmall
                color: Qt.alpha(Serp.surface1, 0.6)
                SIcon {
                    anchors.centerIn: parent
                    name: row.iconName
                    size: Serp.px(16)
                    color: row.kind === "toggle" && row.entry.checked ? Serp.accent : Serp.subtext0
                }
            }
            Column {
                id: texts
                x: iconBox.x + iconBox.width + Serp.px(12)
                y: head.stacked ? row.padV + (head.textH - implicitHeight) / 2 : (head.height - implicitHeight) / 2
                width: (head.stacked ? card.width - row.padH : ctl.x - Serp.px(12)) - x
                spacing: Serp.px(2)
                Item {
                    width: parent.width
                    height: titleText.implicitHeight
                    SText {
                        id: titleText
                        width: Math.min(implicitWidth, parent.width - (star.visible ? star.width + Serp.px(6) : 0))
                        text: row.title
                        size: Serp.px(13)
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    NewStar {
                        id: star
                        visible: row.isNew
                        x: titleText.width + Serp.px(6)
                        anchors.verticalCenter: titleText.verticalCenter
                    }
                }
                SText {
                    width: parent.width
                    visible: text !== ""
                    text: row.desc
                    size: Serp.px(11)
                    color: Serp.subtext0
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
            }
            Row {
                id: ctl
                x: head.stacked ? texts.x : card.width - row.padH - implicitWidth
                y: head.stacked ? row.padV + head.textH + Serp.px(10) : (head.height - implicitHeight) / 2
                spacing: Serp.px(8)
                Acts {
                    entry: row.entry
                    lead: true
                }
                Loader {
                    id: control
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: ({
                            "toggle": togC,
                            "choice": row.useSwitch ? switchC : dropC,
                            "slider": slideC,
                            "spin": numC,
                            "button": buttonC
                        })[row.kind] || null
                }
                Acts {
                    entry: row.entry
                }
            }
        }
        // what unfolds under the row: a long choice's options
        Item {
            id: belowBox
            x: row.padH
            y: head.height
            width: parent.width - row.padH * 2
            height: list.height
            visible: row.dropdown && (row.expanded || card.height > head.height + 1)
            Rectangle {
                id: list
                width: parent.width
                height: Math.min(Serp.px(240), opts.implicitHeight + Serp.px(8))
                radius: Serp.radiusSmall
                color: Qt.alpha(Serp.base, 0.6)
                border.width: 1
                border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                Flickable {
                    anchors.fill: parent
                    anchors.margins: Serp.px(4)
                    contentHeight: opts.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: opts
                        width: parent.width
                        spacing: Serp.px(2)
                        Repeater {
                            model: row.dropdown ? row.items : []
                            Rectangle {
                                id: opt
                                required property var modelData
                                required property int index
                                readonly property bool on: index === row.current
                                width: opts.width
                                height: Serp.px(30)
                                radius: Serp.radiusSmall
                                color: on ? Serp.selected : oma.containsMouse ? Serp.hover : "transparent"
                                SText {
                                    x: Serp.px(10)
                                    width: parent.width - Serp.px(40)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.labelOf(opt.modelData)
                                    size: Serp.px(12)
                                    color: opt.on ? Serp.accent : Serp.text
                                }
                                SIcon {
                                    visible: opt.on
                                    anchors.right: parent.right
                                    anchors.rightMargin: Serp.px(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "check"
                                    size: Serp.px(14)
                                    color: Serp.accent
                                }
                                MouseArea {
                                    id: oma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        row.expanded = false;
                                        row.entry.activated(opt.modelData.value);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // a looping preview under the row (widgets/previews/<scene>.qml), as SettingRow's
    Loader {
        id: gif
        active: !!row.entry && row.entry.preview !== "" && row.previewOpen
        y: card.height + Serp.px(8)
        x: row.padH
        width: Math.min(row.width - x, Theme.u * 230)
        sourceComponent: PxPreview {
            width: gif.width
            height: implicitHeight
            scene: row.entry.preview
            variant: row.previewVariant
            caption: row.previewCaption
            onCloseClicked: row.previewOpen = false
        }
    }

    // ---- the controls ----
    Component {
        id: togC
        Row {
            spacing: Serp.px(8)
            SText {
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Serp.px(220))
                text: row.entry.text
                size: Serp.px(12)
                color: Serp.subtext1
            }
            STog {
                anchors.verticalCenter: parent.verticalCenter
                checked: row.entry.checked
                onToggled: on => {
                    Sounds.play("toggle");
                    row.entry.toggled(on);
                }
            }
        }
    }
    Component {
        id: switchC
        SSwitch {
            width: Math.min(implicitWidth, Math.max(Serp.px(180), card.width * 0.5))
            options: row.items.map(i => row.labelOf(i))
            currentIndex: Math.max(0, row.current)
            onPicked: i => row.entry.activated(row.items[i].value)
        }
    }
    Component {
        id: dropC
        Rectangle {
            width: Serp.px(200)
            height: Serp.px(32)
            radius: Serp.radiusSmall
            color: dma.containsMouse || row.expanded ? Serp.surface2 : Serp.surface1
            Behavior on color {
                ColorAnimation {
                    duration: Serp.quick
                }
            }
            SText {
                anchors.left: parent.left
                anchors.leftMargin: Serp.px(10)
                anchors.right: chev.left
                anchors.rightMargin: Serp.px(6)
                anchors.verticalCenter: parent.verticalCenter
                text: row.current >= 0 ? row.labelOf(row.items[row.current]) : row.entry.placeholder
                size: Serp.px(12)
                color: row.current >= 0 ? Serp.text : Serp.subtext0
            }
            SIcon {
                id: chev
                anchors.right: parent.right
                anchors.rightMargin: Serp.px(10)
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron-down"
                size: Serp.px(14)
                color: Serp.subtext0
                rotation: row.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                id: dma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: row.items.length > 0
                onClicked: row.expanded = !row.expanded
            }
        }
    }
    Component {
        id: slideC
        CatRowSlide {
            width: Math.min(Serp.px(260), Math.max(Serp.px(150), card.width * 0.36))
            from: row.entry.from
            to: row.entry.to
            value: row.entry.value
            stepSize: row.entry.stepSize
            live: row.entry.live
            suffix: row.entry.suffix
            decimals: row.entry.decimals
            showValue: row.entry.showValue
            valueScale: row.entry.valueScale
            fill: Qt.colorEqual(row.entry.fill, Theme.accent) ? Serp.accent : row.entry.fill
            onMoved: v => row.entry.moved(v)
            onReleased: v => row.entry.released(v)
        }
    }
    Component {
        id: numC
        CatRowNum {
            value: row.entry.value
            from: row.entry.from
            to: row.entry.to
            stepSize: row.entry.stepSize
            decimals: row.entry.decimals
            suffix: row.entry.suffix
            onMoved: v => row.entry.moved(v)
        }
    }
    Component {
        id: buttonC
        PillButton {
            implicitHeight: Serp.px(30)
            label: row.entry.text
            icon: row.entry.icon ? MacIcons.fromPixel(row.entry.icon) : ""
            primary: row.entry.accent || row.entry.checked
            onClicked: row.entry.clicked()
        }
    }
}
