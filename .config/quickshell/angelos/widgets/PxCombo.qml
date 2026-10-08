import QtQuick
import QtQuick.Templates as T
import qs.config
import qs.services
import "A11y.js" as A11y

// Dropdown. model: array of strings or {label, value, icon}.
Item {
    id: root

    property var model: []
    property var currentValue
    property string placeholder: "—"
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // the Golden Gate skin's System Settings: a Mac pop-up button (the value and ⌃⌄), a glass menu
    readonly property bool mac: settingsSkin === "goldengate"
    signal activated(var value)

    Accessible.role: Accessible.ComboBox
    Accessible.name: A11y.rowLabel(root)
    Accessible.description: currentLabel
    Accessible.focusable: true
    Accessible.onPressAction: popup.opened ? popup.close() : popup.open()

    readonly property var items: (model || []).map(m => typeof m === "object" ? m : {
                label: String(m),
                value: m
            })
    readonly property int currentIndex: items.findIndex(i => i.value === currentValue)
    readonly property string currentLabel: currentIndex >= 0 ? items[currentIndex].label : placeholder

    implicitWidth: Theme.u * 100
    implicitHeight: mac ? GoldenGate.px(28) : Theme.sizeBody + Theme.u * 10

    PxBox {
        anchors.fill: parent
        visible: root.settingsSkin === "classic"
        sunken: true
        color: Theme.sunken
    }
    Rectangle {
        visible: root.mac
        anchors.fill: parent
        radius: GoldenGate.px(7)
        color: GoldenGate.dark ? Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.18 : 0.12) : mouse.containsMouse ? "#fafafa" : "#ffffff"
        border.width: 1
        border.color: GoldenGate.separator
        Column {
            anchors.right: parent.right
            anchors.rightMargin: GoldenGate.px(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: -GoldenGate.px(4)
            MacIcon {
                name: "chevron-up"
                size: GoldenGate.px(11)
                stroke: 2.6
                color: GoldenGate.secondaryLabel
            }
            MacIcon {
                name: "chevron-down"
                size: GoldenGate.px(11)
                stroke: 2.6
                color: GoldenGate.secondaryLabel
            }
        }
    }
    Rectangle {
        visible: root.settingsSkin !== "classic" && !root.mac
        anchors.fill: parent
        radius: root.settingsSkin === "stream" ? Theme.u * 2 : 0
        color: root.settingsSkin === "stream" ? Theme.streamPanel : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseLine
    }
    PxText {
        anchors.left: parent.left
        anchors.right: arrow.left
        anchors.leftMargin: Theme.u * 5
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentLabel
        elide: Text.ElideRight
    }
    PxBox {
        id: arrow
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Theme.u * 2
        width: height
        sunken: mouse.pressed
        visible: root.settingsSkin === "classic"
        PxIcon {
            anchors.centerIn: parent
            name: "arrowDown"
            pixel: Math.max(1, Theme.u - 1)
        }
    }
    PxIcon {
        visible: root.settingsSkin !== "classic" && !root.mac
        anchors.centerIn: arrow
        name: "arrowDown"
        ink: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseInk
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.opened ? popup.close() : popup.open()
    }

    T.Popup {
        id: popup
        y: root.height
        width: root.width
        height: Math.min(list.contentHeight + Theme.u * 4, Theme.u * 150)
        padding: Theme.u * 2
        modal: false
        focus: true
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

        background: Item {
            PxBox {
                anchors.fill: parent
                visible: !root.mac
                color: Theme.face
                shadow: true
            }
            MacGlass {
                anchors.fill: parent
                visible: root.mac
                radius: GoldenGate.px(10)
                fill: GoldenGate.glass(0.3)
            }
        }
        contentItem: ListView {
            id: list
            clip: true
            model: root.items
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: opt
                required property var modelData
                required property int index
                width: list.width
                height: Theme.sizeBody + Theme.u * 7
                radius: root.mac ? GoldenGate.px(6) : 0
                color: optMouse.containsMouse ? (root.mac ? GoldenGate.accent : Theme.select) : index === root.currentIndex && !root.mac ? Theme.faceAlt : "transparent"
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.u * 4
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    spacing: Theme.u * 3
                    PxIcon {
                        visible: !!opt.modelData.icon
                        name: opt.modelData.icon || "heart"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PxText {
                        text: opt.modelData.label
                        color: optMouse.containsMouse ? Theme.selectText : Theme.text
                    }
                }
                MouseArea {
                    id: optMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // the owner's binding (currentValue: Config.x, onActivated: Config.x = v)
                        // updates it; assigning here first would break that binding and leave a
                        // stale pick when the value later changes elsewhere (issue #15)
                        const picked = opt.modelData.value;
                        root.activated(picked);
                        if (root.currentValue !== picked)
                            root.currentValue = picked;
                        popup.close();
                    }
                }
            }
        }
    }
}
