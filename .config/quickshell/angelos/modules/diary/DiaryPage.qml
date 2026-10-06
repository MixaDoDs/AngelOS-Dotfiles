pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// One page of the Angel's diary (story/diary.json, services/Diary): parchment, the date and
// the title over the text in her hand (Theme.fontScript, Caveat), a sketch in the corner, the
// page's number at the foot. The demon's pages are in red, slanted; a page not yet written is
// torn out (what it waits for in faint pencil). `page` null: an empty sheet (the end papers).
Item {
    id: root

    property var page: null
    property int number: 0                  // 1-based; 0: none
    property bool leftSide: false           // the spine on the right (the shadow goes there)
    readonly property bool written: !!page && Diary.isOpen(page.id)
    readonly property bool demon: written && page.hand === "demon"
    readonly property bool unread: written && !Diary.readMarks[page.id]
    readonly property real s: height / 600  // the page's scale: drawn for 600 px high

    readonly property color paper: Theme.hell ? "#d9c193" : "#efe2bf"
    readonly property color paperEdge: Theme.hell ? "#9a7347" : "#cbb27c"
    readonly property color ink: {
        if (!page)
            return "#3b2415";
        if (demon || page.ink === "red")
            return "#9b1022";
        if (page.ink === "blue")
            return "#22406e";
        if (page.ink === "gold")
            return "#8a6514";
        return "#33210f";
    }

    // ---- the sheet ----
    Rectangle {
        anchors.fill: parent
        color: root.paper
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: root.leftSide ? root.paper : Qt.darker(root.paper, 1.18)
            }
            GradientStop {
                position: 0.08
                color: root.paper
            }
            GradientStop {
                position: 0.92
                color: root.paper
            }
            GradientStop {
                position: 1
                color: root.leftSide ? Qt.darker(root.paper, 1.18) : root.paper
            }
        }
        border.width: Math.max(1, 2 * root.s)
        border.color: root.paperEdge
    }
    // ruled lines, faint
    Column {
        anchors.fill: parent
        anchors.topMargin: 118 * root.s
        anchors.leftMargin: 34 * root.s
        anchors.rightMargin: 34 * root.s
        spacing: 31 * root.s
        opacity: root.written ? 0.22 : 0.12
        Repeater {
            model: 14
            Rectangle {
                width: parent.width
                height: Math.max(1, root.s)
                color: "#7a8fb0"
            }
        }
    }
    // hell scorches the edges
    Rectangle {
        visible: Theme.hell
        anchors.fill: parent
        color: "transparent"
        border.width: 10 * root.s
        border.color: Qt.alpha("#2a0c05", 0.35)
    }

    // ---- a written page ----
    Item {
        visible: root.written
        anchors.fill: parent
        anchors.margins: 34 * root.s
        rotation: root.demon ? -1.5 : 0

        Text {
            id: date
            width: parent.width
            text: root.written ? Diary.text(root.page, "date") : ""
            color: Qt.alpha(root.ink, 0.7)
            font.family: Theme.fontScript
            font.pixelSize: 22 * root.s
            horizontalAlignment: root.leftSide ? Text.AlignLeft : Text.AlignRight
        }
        Text {
            id: title
            y: date.height + 4 * root.s
            width: parent.width - (sketch.visible ? sketch.width + 8 * root.s : 0)
            text: root.written ? Diary.text(root.page, "title") : ""
            color: root.ink
            font.family: root.demon ? Theme.fontHell : Theme.fontScript
            font.pixelSize: (root.demon ? 30 : 38) * root.s
            font.bold: true
            wrapMode: Text.Wrap
        }
        Flickable {
            id: flick
            y: Math.max(title.y + title.height + 14 * root.s, 108 * root.s)
            width: parent.width
            height: parent.height - y - 30 * root.s
            contentHeight: body.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Text {
                id: body
                width: flick.width
                text: root.written ? Diary.text(root.page, "text") : ""
                color: root.ink
                font.family: root.demon ? Theme.fontHellText : Theme.fontScript
                font.pixelSize: (root.demon ? 22 : 27) * root.s
                lineHeightMode: Text.FixedHeight
                lineHeight: 32 * root.s
                wrapMode: Text.Wrap
            }
        }
        // the sketch in the top corner: a pixel icon, or one of the diary thing's pictures
        PxIcon {
            id: sketch
            readonly property var tex: {
                const t = Diary.thing;
                const n = root.page ? root.page.sketch || "" : "";
                return n && t && t.textures && t.textures[n] ? t.textures[n] : null;
            }
            visible: root.written && !!root.page.sketch
            x: parent.width - width
            y: date.height + 2 * root.s
            name: !tex && root.page && root.page.sketch ? root.page.sketch : "heart"
            bitmap: tex ? tex.rows : null
            palette: tex ? tex.palette : ({})
            pixel: Math.max(1, Math.round(3 * root.s))
            ink: root.ink
            fill: root.demon ? "#c4182c" : "#d4708f"
            opacity: 0.85
            rotation: 8
        }
    }
    // the unread mark: a red wax dot by the title
    Rectangle {
        visible: root.unread
        width: 16 * root.s
        height: width
        radius: width / 2
        color: "#b3122a"
        border.width: Math.max(1, root.s)
        border.color: "#5a0610"
        x: root.leftSide ? parent.width - width - 14 * root.s : 14 * root.s
        y: 14 * root.s
    }

    // ---- not written yet: torn out ----
    Item {
        visible: !!root.page && !root.written
        anchors.fill: parent
        // the torn edge along the spine
        Repeater {
            model: 24
            Rectangle {
                required property int index
                width: (6 + (index * 7) % 9) * root.s
                height: root.height / 24 + 1
                x: root.leftSide ? root.width - width : 0
                y: index * root.height / 24
                color: Qt.darker(root.paper, 1.25)
            }
        }
        Pentagram {
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: width
            color: Qt.alpha("#7a5a3a", 0.25)
            glow: false
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.72
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.page ? Diary.lockText(root.page) : ""
            color: Qt.alpha("#5b4632", 0.75)
            font.family: Theme.fontScript
            font.pixelSize: 25 * root.s
        }
    }

    // ---- the foot: the page's number ----
    Text {
        visible: root.number > 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        text: "— " + root.number + " —"
        color: Qt.alpha("#5b4632", 0.7)
        font.family: Theme.fontScript
        font.pixelSize: 20 * root.s
    }
}
