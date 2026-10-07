import QtQuick
import qs.config
import qs.services
import qs.widgets

// The rule of a circle's menu toy, under the look (story/toys.json → hints), and the
// game's score below it (`status`). Only while the toys are on.
Column {
    id: hint

    required property var menu              // RadialMenu
    required property string rule           // the look's id in toys.json → hints
    property real below: 0                  // how far under the middle the look reaches
    property string status: ""
    readonly property real pad: Theme.u * 4
    visible: Config.desktop.menuToys !== false && menu.reveal > 0.8 && (ruleText.text !== "" || status !== "")
    opacity: Math.max(0, menu.reveal * 5 - 4)
    spacing: Theme.u
    x: Math.max(pad, Math.min((parent ? parent.width : 0) - width - pad, menu.cx - width / 2))
    y: Math.max(pad, Math.min((parent ? parent.height : 0) - height - pad, menu.cy + below + Theme.u * 6))
    z: 10

    PxText {
        id: ruleText
        anchors.horizontalCenter: parent.horizontalCenter
        kind: "tiny"
        color: Theme.hellTextDim
        style: Text.Outline
        styleColor: Theme.hellBody
        text: HellToys.hint(hint.rule)
    }
    PxText {
        visible: hint.status !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        kind: "tiny"
        font.bold: true
        color: Theme.hellAccent
        style: Text.Outline
        styleColor: Theme.hellBody
        text: hint.status
    }
}
