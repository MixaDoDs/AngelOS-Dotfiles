import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: the font row — a dropdown that unfolds under the row: a search field and
// the families, each in its own face. Mono-looking ones by default, any family when searching.
SetRow {
    id: fp
    rowKey: "font"
    icon: "type"
    title: "Шрифт"
    desc: "Моноширинный по вкусу Serpantinum"
    readonly property var all: Qt.fontFamilies()
    readonly property var mono: all.filter(f => /mono|code|term|consol|courier|hack|iosevka|fixed|nerd|cascadia|victor|menlo|meslo|source code/i.test(f))
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        return q ? all.filter(f => f.toLowerCase().indexOf(q) >= 0) : mono;
    }

    Rectangle {
        width: Serp.px(210)
        height: Serp.px(32)
        radius: Serp.radiusSmall
        color: ma.containsMouse || fp.expanded ? Serp.surface2 : Serp.surface1
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
            text: Serp.font
            size: Serp.px(12)
        }
        SIcon {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: Serp.px(10)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-down"
            size: Serp.px(14)
            color: Serp.subtext0
            rotation: fp.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                fp.expanded = !fp.expanded;
                if (fp.expanded)
                    search.focusField();
            }
        }
    }

    below: Column {
        width: parent ? parent.width : 0
        spacing: Serp.px(8)
        SInput {
            id: search
            width: parent.width
            placeholder: "Найти шрифт (" + fp.mono.length + " моно, " + fp.all.length + " всего)"
            onEscaped: {
                if (text)
                    text = "";
                else
                    fp.expanded = false;
            }
            onAccepted: if (fp.shown.length) {
                Serp.cfg.font = fp.shown[0];
            }
        }
        ListView {
            width: parent.width
            height: Serp.px(220)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: fp.shown
            reuseItems: true
            delegate: Rectangle {
                id: fam
                required property string modelData
                readonly property bool cur: Serp.cfg.font === modelData
                width: ListView.view.width
                height: Serp.px(32)
                radius: Serp.radiusSmall
                color: cur ? Qt.alpha(Serp.accent, 0.16) : fma.containsMouse ? Qt.alpha(Serp.text, 0.06) : "transparent"
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Serp.px(10)
                    anchors.right: tick.left
                    anchors.rightMargin: Serp.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: fam.modelData
                    font.family: fam.modelData
                    font.pixelSize: Serp.px(13)
                    color: fam.cur ? Serp.accent : Serp.text
                    elide: Text.ElideRight
                }
                SIcon {
                    id: tick
                    visible: fam.cur
                    anchors.right: parent.right
                    anchors.rightMargin: Serp.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: Serp.px(14)
                    color: Serp.accent
                }
                MouseArea {
                    id: fma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Serp.cfg.font = fam.modelData
                }
            }
            SText {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: "Ничего не нашлось"
                color: Serp.subtext0
            }
        }
    }
}
