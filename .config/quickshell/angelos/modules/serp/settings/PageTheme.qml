import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Тема — the wallpaper, the look (font, corners, opacity, blur) and the colours
SPage {
    id: pg
    title: "Тема"
    subtitle: "Внешний вид скина: обои, шрифт, скругления и палитра"
    readonly property string wallName: {
        const f = Serp.wallFile;
        return f ? decodeURIComponent(f.split("/").pop()) : "";
    }

    // the wallpaper as the page's header card
    Item {
        property string rowKey: "wall"
        width: parent.width
        height: Serp.px(220)
        Rectangle {
            anchors.fill: parent
            radius: Serp.radius
            color: Serp.surface0
            SText {
                anchors.centerIn: parent
                visible: !Serp.wallFile
                text: "Обои не найдены"
                color: Serp.subtext0
            }
        }
        RoundImage {
            anchors.fill: parent
            source: Serp.wallFile
            radius: Serp.radius
            sourceWidth: 1200
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Serp.px(64)
            radius: Serp.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.8)
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Serp.px(14)
            width: Math.min(implicitWidth, parent.width - Serp.px(28))
            text: pg.wallName
            font.family: Serp.font
            font.pixelSize: Serp.px(12)
            font.weight: Font.Bold
            color: "#ffffff"
            elide: Text.ElideMiddle
        }
    }

    Section {
        rowKey: "look"
        title: "Оформление"
    }
    FontPick {}
    SetRow {
        rowKey: "radius"
        icon: "maximize"
        title: "Скругление"
        desc: "Углы островов, панелей и карточек"
        SNumber {
            from: 0
            to: 24
            value: Serp.cfg.radius
            suffix: " px"
            onPicked: v => Serp.cfg.radius = v
        }
    }
    SetRow {
        rowKey: "opacity"
        icon: "contrast"
        title: "Непрозрачность"
        desc: "Насколько плотные острова и панели"
        SSlide {
            from: 50
            to: 100
            value: Math.round(Serp.cfg.opacity * 100)
            onMoved: v => Serp.cfg.opacity = v / 100
        }
    }
    SetRow {
        rowKey: "glass"
        icon: "sparkles"
        title: "Жидкое стекло"
        desc: "Стекло Serpantinum: острова, док и панели преломляют обои. В игре и в аду — плоско"
        STog {
            checked: Serp.cfg.glass
            onToggled: on => Serp.cfg.glass = on
        }
    }
    SetRow {
        rowKey: "glassTint"
        icon: "palette"
        title: "Тонировка стекла"
        desc: "Прозрачнее — видно обои, плотнее — легче читать"
        opacity: Serp.cfg.glass ? 1 : 0.4
        SSlide {
            from: 0
            to: 100
            value: Math.round(Serp.cfg.glassTint * 100)
            onMoved: v => Serp.cfg.glassTint = v / 100
        }
    }
    SetRow {
        rowKey: "blur"
        icon: "wind"
        title: "Размытие"
        desc: "Стекло под панелями (если размытие включено в angelOS)"
        STog {
            checked: Serp.cfg.blur
            onToggled: on => Serp.cfg.blur = on
        }
    }

    Section {
        rowKey: "colors"
        title: "Цвета"
    }
    SInput {
        id: find
        width: parent.width
        placeholder: "Найти палитру"
        onEscaped: text = ""
    }
    Grid {
        id: grid
        readonly property string q: find.text.trim().toLowerCase()
        width: parent.width
        columns: 3
        spacing: Serp.px(10)
        readonly property real cell: (width - spacing * (columns - 1)) / columns
        // the wallpaper, ours, then Serpantinum's presets by name
        readonly property var ids: ["wallpaper", "angel"].concat(Serp.paletteIds.filter(id => id !== "angel"))
        function hit(id) {
            return !q || (Serp.paletteOf(id).name || id).toLowerCase().indexOf(q) >= 0;
        }
        readonly property int hits: ids.filter(id => hit(id)).length
        Repeater {
            model: grid.ids
            delegate: PresetTile {
                required property string modelData
                pid: modelData
                width: grid.cell
                visible: grid.hit(modelData)
            }
        }
    }
    SText {
        visible: grid.hits === 0
        text: "Такой палитры нет"
        color: Serp.subtext0
    }
}
