import QtQuick
import qs.config
import qs.services
import qs.widgets

// The thin strip at the bar's end, as in Windows: every window of the desktop in front on this
// screen goes; a click again brings them back (services/DeskMenu.showDesktop, Mod+D too).
Item {
    id: root
    property string screenName: ""
    property bool vertical: false

    Accessible.role: Accessible.Button
    Accessible.name: I18n.t("Показать рабочий стол", "Show the desktop")

    implicitWidth: vertical ? Theme.u * 14 : Theme.u * 3
    implicitHeight: vertical ? Theme.u * 3 : Theme.u * 14

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.u
        color: Theme.accent
        opacity: area.containsMouse ? 0.6 : 0.18
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: DeskMenu.showDesktop(root.screenName)
    }
}
