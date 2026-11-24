import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

Item {
    id: root
    property var plugin
    property string screenName
    property var barWindow
    property int hpad: -1
    property bool barInk: false
    property bool hellBar: false
    readonly property string icon: "note"
    readonly property string text: ""
    readonly property bool barOpen: popup.visible
    implicitWidth: Skin.mac ? Skin.px(24) : Theme.u * 16
    implicitHeight: Skin.mac ? Skin.px(18) : Theme.u * 14
    // Use the same button face and hover bevel as the built-in bar controls.
    PxButton {
        id: hot
        anchors.fill: parent
        flat: true
        compact: true
        checked: popup.visible
        // Let the shell draw the pixel icon, its palette and alternative icon sets.
        icon: Skin.mac ? "" : root.icon
        hell: Theme.hell
        barInk: root.barInk || root.hellBar
        hpad: root.hpad
        onClicked: popup.toggle()
        Accessible.name: "Быстрая заметка Typer"
    }
    // A TextEdit's QML focus alone cannot receive keys on a non-focusable
    // layer surface. Borrow keyboard focus only while this composer is open.
    Binding {
        target: root.barWindow ? root.barWindow.WlrLayershell : null
        property: "keyboardFocus"
        when: popup.visible && !!root.barWindow
        value: WlrKeyboardFocus.Exclusive
        restoreMode: Binding.RestoreBindingOrValue
    }
    TyperGlyph {
        visible: Skin.mac
        anchors.centerIn: parent
        ink: Skin.mac ? Skin.ink(root.screenName) : root.hellBar ? Theme.hellBarIcon : Skin.text
        scale: hot.pressed ? 0.92 : 1
        rotation: popup.visible ? -5 : 0
        Behavior on scale { NumberAnimation { duration: Skin.ms(150); easing.type: Easing.OutCubic } }
        Behavior on rotation { NumberAnimation { duration: Skin.ms(180); easing.type: Easing.OutCubic } }
    }
    Rectangle {
        visible: TyperNotes.papers.length > 0
        width: Skin.mac ? Skin.px(2) : Theme.u; height: width
        radius: Skin.mac ? width / 2 : 0
        color: Skin.mac ? Skin.ink(root.screenName) : Skin.accent
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: Skin.px(3)
    }
    LazyPopup {
        id: popup
        panelId: "typer-note"
        anchorItem: root
        warm: hot.hovered
        BarPopup {
            id: panel
            panelId: "typer-note"
            anchorItem: root
            above: BarLayout.bottom && !Skin.mac
            title: Skin.title("Заметка")
            icon: "note"
            contentWidth: Skin.px(300)
            contentHeight: composer.implicitHeight
            property real reveal: 1
            Binding { target: panel.contentItem; property: "opacity"; value: panel.reveal }
            Binding { target: panel.contentItem; property: "scale"; value: 0.96 + panel.reveal * 0.04 }
            Binding { target: panel.contentItem; property: "transformOrigin"; value: panel.above ? Item.Bottom : Item.Top }
            NumberAnimation { id: appear; target: panel; property: "reveal"; from: 0; to: 1; duration: Skin.ms(180); easing.type: Easing.OutCubic }
            Connections {
                target: panel
                function onVisibleChanged() {
                    if (panel.visible) { appear.restart(); Qt.callLater(() => composer.focusInput()); }
                }
            }
            TyperComposer {
                id: composer
                anchors.fill: parent
                screenName: root.screenName
                onPinned: popup.close()
                onOpenEditor: {
                    popup.close();
                    Qt.callLater(() => Quickshell.execDetached(["angelos-typer"]));
                }
            }
        }
    }
}
