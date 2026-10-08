import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxButton {
    id: root

    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Пуск", "Start")

    property bool above: true
    property bool small: false
    property string screenName: ""
    property var barWindow: null

    text: ""
    icon: ""
    // in hell (Y2K → Angel or demon → Start in hell) the button is hers: the circle's dark
    // colours and the Hell wordmark, still
    readonly property bool hellish: Angel.demon && !!Config.y2k.hellStart
    hell: hellish
    // pushed in (or Start open): a darker face, not the accent tint the logo's own colours vanish into
    downColor: Theme.mix(Theme.face, Theme.lo, Theme.dark ? 0.6 : 0.45)
    implicitWidth: logo.implicitWidth + Theme.u * 8
    implicitHeight: Math.max(Theme.u * 15, logo.implicitHeight + Theme.u * 3)
    AngelLogo {
        id: logo
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.down ? Theme.u : 0
        anchors.verticalCenterOffset: root.down ? Theme.u : 0
        // Settings → Bar → Logo → "Wordmark on the Start button": off leaves the emblem
        emblemOnly: root.small || Config.bar.logoText === false
        hell: root.hellish || root.barInk
    }
    kind: small ? "body" : "title"
    checked: Shell.startScreen !== "" && Shell.startScreen === screenName
    compact: small
    onClicked: Shell.toggleStart(screenName)

    // the Start overlay opens right above/below this button
    Component.onCompleted: if (screenName && barWindow)
        Shell.registerStartButton(screenName, root, barWindow)
    Component.onDestruction: Shell.unregisterStartButton(screenName, root)
}
