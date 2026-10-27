import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The bar's Start button, in the look Settings → Bar → Start → Button picks (bar.startButtonStyle):
// classic (the bevelled face with the logo) or capsule (an XP-like "start" pill in the accent).
Item {
    id: root

    property bool above: true
    property bool small: false
    property string screenName: ""
    property var barWindow: null
    // the hell bar (BarItem binds it): the classic face goes flat, the capsule takes hell's colours
    property bool barInk: false
    // the bar's grid (BarItem): the emblem stands bare like the icons beside it, the face only
    // under the pointer or while Start is open
    property bool barGrid: false

    // in hell (Y2K → Angel or demon → Start in hell) the button is hers: the circle's dark
    // colours and the Hell wordmark, still
    readonly property bool hellish: Angel.demon && !!Config.y2k.hellStart
    readonly property bool capsule: Config.bar.startButtonStyle === "capsule"
    readonly property bool open: Shell.startScreen !== "" && Shell.startScreen === screenName

    implicitWidth: capsule ? cap.implicitWidth : btn.implicitWidth
    implicitHeight: btn.implicitHeight

    PxButton {
        id: btn
        visible: !root.capsule
        anchors.fill: parent
        // screen readers (widgets/A11y.js): what this icon is
        Accessible.name: I18n.t("Пуск", "Start")
        text: ""
        icon: ""
        hell: root.hellish
        barInk: root.barInk
        flat: root.barGrid
        // pushed in (or Start open): a darker face, not the accent tint the logo's own colours vanish into
        downColor: Theme.mix(Theme.face, Theme.lo, Theme.dark ? 0.6 : 0.45)
        implicitWidth: logo.implicitWidth + Theme.u * 8
        implicitHeight: Math.max(Theme.u * 15, logo.implicitHeight + Theme.u * 3)
        AngelLogo {
            id: logo
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: btn.down ? Theme.u : 0
            anchors.verticalCenterOffset: btn.down ? Theme.u : 0
            // Settings → Bar → Logo → "Wordmark on the Start button": off leaves the emblem
            emblemOnly: root.small || Config.bar.logoText === false
            hell: root.hellish || root.barInk
        }
        kind: root.small ? "body" : "title"
        checked: root.open
        compact: root.small
        onClicked: Shell.toggleStart(root.screenName)
    }

    // The capsule: a square left end, a stepped round right end, a one-pixel outline, a light
    // bevel top-left and a dark one bottom-right, the face in whole-pixel bands (no smooth
    // gradients). Drawn row by row so every edge lands on the art-pixel grid.
    Item {
        id: cap
        visible: root.capsule
        anchors.fill: parent

        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("Пуск", "Start")
        Accessible.focusable: true
        Accessible.onPressAction: Shell.toggleStart(root.screenName)

        readonly property int u: Theme.u
        readonly property bool down: mouse.pressed || root.open
        readonly property bool hell: root.hellish || root.barInk
        // a label of the user's own (bar.startLabel, e.g. hell's "hellOS") replaces "start"
        readonly property string label: Config.bar.startLabel && Config.bar.startLabel !== "angelOS" ? Config.bar.startLabel : I18n.t("пуск", "start")
        readonly property color base: hell ? (down ? Theme.mix(Theme.hellFace, Theme.hellBlood, 0.45) : mouse.containsMouse ? Theme.mix(Theme.hellBlood, Theme.hellEmber, 0.2) : Theme.hellBlood) : down ? Theme.mix(Theme.accent, "#000000", 0.22) : mouse.containsMouse ? Theme.mix(Theme.accent, "#ffffff", 0.12) : Theme.accent
        readonly property color edge: hell ? Theme.hellEdge : Theme.edge
        readonly property color hi: Theme.mix(base, "#ffffff", 0.5)
        readonly property color lo: Theme.mix(base, "#000000", 0.45)
        readonly property int cols: Math.floor(width / u)
        readonly property int rows: Math.floor(height / u)
        // the right end's step per row: a circle squashed to 0.8 of the half-height
        readonly property int maxInset: inset(0)
        function inset(r) {
            const R = rows / 2, d = Math.abs(r - (rows - 1) / 2);
            return Math.round(0.8 * (R - Math.sqrt(Math.max(0, R * R - d * d))));
        }
        // right ends, in art pixels: the outline, the bevel inside it, the face inside that
        function outer(r) {
            return r < 0 || r >= rows ? 0 : cols - inset(r);
        }
        function inner(r) {
            return r < 1 || r > rows - 2 ? 0 : Math.min(outer(r - 1), outer(r), outer(r + 1)) - 1;
        }
        function face(r) {
            return Math.min(inner(r - 1), inner(r), inner(r + 1)) - 1;
        }
        // stepped gloss: a lit top band, a softer one, the accent, a darker foot
        function band(r) {
            const t = (r - 2) / Math.max(1, rows - 5);
            return t < 0.15 ? Theme.mix(base, "#ffffff", 0.32) : t < 0.45 ? Theme.mix(base, "#ffffff", 0.16) : t < 0.8 ? base : Theme.mix(base, "#000000", 0.18);
        }

        implicitWidth: u * 3 + content.implicitWidth + u * (3 + inset(0))

        Repeater {
            model: cap.rows
            Item {
                id: line
                required property int index
                y: index * cap.u
                width: cap.width
                height: cap.u
                Rectangle {
                    width: cap.outer(line.index) * cap.u
                    height: cap.u
                    color: cap.edge
                }
                // the bevel: lo everywhere, hi over it short of the right end and the bottom row
                Rectangle {
                    visible: line.index > 0 && line.index < cap.rows - 1
                    x: cap.u
                    width: (cap.inner(line.index) - 1) * cap.u
                    height: cap.u
                    color: cap.down ? cap.hi : cap.lo
                }
                Rectangle {
                    visible: line.index > 0 && line.index < cap.rows - 2
                    x: cap.u
                    width: (cap.inner(line.index) - 2) * cap.u
                    height: cap.u
                    color: cap.down ? cap.lo : cap.hi
                }
                Rectangle {
                    visible: line.index > 1 && line.index < cap.rows - 2
                    x: cap.u * 2
                    width: Math.max(0, cap.face(line.index) - 2) * cap.u
                    height: cap.u
                    color: cap.band(line.index)
                }
            }
        }

        Row {
            id: content
            // emblem only (a side or compact bar): centred in the straight part
            x: (root.small ? Math.max(1, Math.floor((cap.width - width) / cap.u / 2) - Math.floor(cap.maxInset / 2)) * cap.u : cap.u * 3) + (cap.down ? cap.u : 0)
            y: Math.floor((cap.height - height) / 2 / cap.u) * cap.u + (cap.down ? cap.u : 0)
            spacing: cap.u * 2
            AngelLogo {
                anchors.verticalCenter: parent.verticalCenter
                emblemOnly: true
                hell: cap.hell
            }
            Item {
                visible: !root.small
                anchors.verticalCenter: parent.verticalCenter
                width: word.implicitWidth + cap.u
                height: word.implicitHeight + cap.u
                // a hard one-pixel drop so the word reads on every band
                PxText {
                    x: cap.u
                    y: cap.u
                    text: word.text
                    kind: word.kind
                    color: cap.lo
                }
                PxText {
                    id: word
                    text: cap.label
                    kind: "title"
                    color: cap.hell ? Theme.hellText : Theme.selectText
                }
            }
        }

        MouseArea {
            id: mouse
            enabled: root.capsule
            anchors.fill: parent
            hoverEnabled: true
            // right clicks are taken (and dropped) as on the classic button
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: e => {
                if (e.button === Qt.LeftButton)
                    Shell.toggleStart(root.screenName);
            }
        }
    }

    // the Start overlay opens right above/below this button
    Component.onCompleted: if (screenName && barWindow)
        Shell.registerStartButton(screenName, root, barWindow)
    Component.onDestruction: Shell.unregisterStartButton(screenName, root)
}
