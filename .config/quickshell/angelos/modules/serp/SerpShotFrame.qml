import QtQuick
import qs.config
import qs.services

// serp-skin: a pixel PxWindow (the screenshot editor, the share sheet, Quick Look) worn as a
// rounded serp plate. Laid as a SIBLING of the PxWindow, over it (z), filling it: under Serp.on
// the window's own drawing (its bevelled frame, title bar, by-day rule…: every child but the body)
// goes see-through, a plate (Serp.solid, the radius, a hair of Serp.line) is put under the body,
// and a title strip of the skin's is drawn where the pixel bar was — SText title, SIcon buttons;
// a press on the strip is the window's own titlePressed (the host moves its window), × its own
// closeClicked. Off the skin it draws nothing and gives the window back as it was.
Item {
    id: root

    property Item win: null                  // the PxWindow
    property string title: win ? win.title : ""
    property string icon: "app-window"       // a Lucide name (widgets/MacIcons.js)
    property bool closable: true
    property bool movable: true              // a press on the strip: win.titlePressed
    property color plate: Serp.solid
    readonly property real stripH: win ? win.titleBar.y + win.titleBar.height + Math.round(win.bodyPadding / 2) : 0

    visible: Serp.on && !!win
    x: win ? win.x : 0
    y: win ? win.y : 0
    width: win ? win.width : 0
    height: stripH
    z: 2

    // the window's own drawing steps aside (opacity: nothing it binds is broken, it comes back)
    function dress() {
        if (!win)
            return;
        for (const c of win.children)
            if (c !== win.bodyItem && c !== under)
                c.opacity = Serp.on ? 0 : 1;
    }
    Connections {
        target: Serp
        function onOnChanged() {
            root.dress();
        }
    }
    onWinChanged: dress()
    Component.onCompleted: dress()

    // the plate under the body: inside the window, at the bottom
    Rectangle {
        id: under
        parent: root.win
        z: -1
        visible: Serp.on
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, Serp.px(24))
        color: root.plate
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }

    // the strip: drag it to move the window
    MouseArea {
        anchors.fill: parent
        enabled: root.movable
        onPressed: m => {
            if (root.win)
                root.win.titlePressed(m);
        }
    }
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Serp.px(14)
        anchors.right: buttons.left
        anchors.rightMargin: Serp.px(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Serp.px(8)
        SIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            color: Serp.accent
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            text: root.title
            size: Serp.px(14)
            bold: true
        }
    }
    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: Serp.px(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Serp.px(4)
        SButton {
            visible: root.closable
            width: Serp.px(28)
            height: Serp.px(28)
            radius: height / 2
            onClicked: if (root.win)
                root.win.closeClicked()
            SIcon {
                name: "x"
                size: Serp.px(14)
                color: Serp.subtext1
            }
        }
    }
}
