import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

Item {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: settingsSkin === "p5"

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    property string icon: ""
    property string kind: "body"
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // the P5 settings window draws like the classic look, in its own colours
    readonly property bool classicLike: settingsSkin === "classic" || settingsSkin === "p5"
    // the Golden Gate skin's System Settings: a Mac field (a capsule with a magnifier for the
    // search, rounded otherwise), the accent's ring while typing
    readonly property bool mac: settingsSkin === "goldengate"
    // Enter applies and leaves the field, Esc just leaves it (issue #9) — unless
    // the field is the whole point of its window (launcher, search, passwords)
    property bool keepFocus: false
    // underline misspelt words (PxSpell): for fields a sentence is typed in, not names or searches
    property bool spell: false
    signal accepted
    signal edited
    // Enter, or the field left any other way (a click elsewhere, Tab, the window closed): a
    // setting saved on `accepted` alone was lost unless Enter was pressed
    signal editingFinished
    signal keyPressed(var event)

    // in a box marked fixedWidth (SettingRow's control column) no wider than it, as PxSegmented
    implicitWidth: parent && parent.fixedWidth === true ? Math.min(Theme.u * 100, parent.width) : Theme.u * 100
    implicitHeight: mac ? input.font.pixelSize + GoldenGate.px(14) : input.font.pixelSize + Theme.u * 10

    function focusField() {
        input.forceActiveFocus();
    }

    Rectangle {
        visible: root.mac
        anchors.fill: parent
        anchors.margins: -GoldenGate.px(3)
        radius: height / 2
        color: "transparent"
        border.width: GoldenGate.px(3)
        border.color: Qt.alpha(GoldenGate.accent, 0.45)
        opacity: input.activeFocus ? 1 : 0
    }
    Rectangle {
        visible: root.mac
        anchors.fill: parent
        radius: root.icon === "search" ? height / 2 : GoldenGate.px(7)
        color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.1) : "#ffffff"
        border.width: 1
        border.color: GoldenGate.separator
    }
    PxBox {
        anchors.fill: parent
        visible: root.classicLike
        color: Theme.toneOf(root.settingsSkin, "sunken")
        edgeColor: input.activeFocus ? Theme.accent : Theme.toneOf(root.settingsSkin, "edge")
    }
    Rectangle {
        visible: !root.classicLike && !root.mac
        anchors.fill: parent
        radius: root.settingsSkin === "stream" ? Theme.u * 2 : 0
        color: root.settingsSkin === "stream" ? Theme.streamPanel : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: input.activeFocus ? Theme.accent : root.settingsSkin === "stream" ? Theme.mix(Theme.streamLive, Theme.streamPanel, 0.4) : Theme.windoseLine
    }

    MacIcon {
        visible: root.mac && root.icon !== ""
        anchors.centerIn: ico
        name: root.icon === "search" ? "search" : "circle-help"
        size: GoldenGate.px(15)
        stroke: 2
        color: GoldenGate.secondaryLabel
    }
    PxIcon {
        id: ico
        opacity: root.mac ? 0 : 1
        visible: root.icon !== ""
        name: root.icon || "search"
        x: Theme.u * 5
        anchors.verticalCenter: parent.verticalCenter
        ink: root.settingsSkin === "stream" ? Theme.streamLive : root.settingsSkin === "windose" ? Theme.windoseRose : Theme.dark ? Theme.toneOf(root.settingsSkin, "text") : Theme.toneOf(root.settingsSkin, "edge")
    }

    TextInput {
        id: input
        Accessible.name: A11y.name(A11y.rowLabel(root), null, root.placeholder)
        anchors.left: ico.visible ? ico.right : parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.u * 5
        anchors.rightMargin: Theme.u * 5
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.toneOf(root.settingsSkin, "text")
        selectionColor: Theme.select
        selectedTextColor: Theme.selectText
        // handwritten in the grimoire (Theme.scriptWindows), like PxText
        readonly property bool script: Theme.scriptWindows.length > 0 && Theme.scriptWindows.includes(Window.window)
        font.family: script ? Theme.fontScript : root.mac ? Theme.macFont : root.kind === "title" ? Theme.fontTitle : Theme.fontBody
        font.pixelSize: script ? Theme.scriptPx(root.kind === "title" ? Theme.sizeTitle : Theme.sizeBody) : root.mac ? GoldenGate.px(root.kind === "title" ? 15 : 13) : root.kind === "title" ? Theme.sizeTitle : Theme.sizeBody
        font.hintingPreference: root.mac ? Font.PreferVerticalHinting : Font.PreferFullHinting
        renderType: script || root.mac ? Text.QtRendering : Text.NativeRendering
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "♥"
        selectByMouse: true
        onAccepted: {
            root.accepted();
            if (!root.keepFocus)
                input.focus = false;
        }
        Keys.onPressed: e => {
            root.keyPressed(e);
            if (!e.accepted && !root.keepFocus && e.key === Qt.Key_Escape) {
                input.focus = false;
                e.accepted = true;
            }
        }
        onTextEdited: root.edited()
        onEditingFinished: root.editingFinished()

        property bool entered: false
        onActiveFocusChanged: if (activeFocus)
            entered = true
        Loader {
            anchors.fill: parent
            active: root.spell && !root.password && input.entered && Spell.on
            sourceComponent: PxSpell {
                target: input
            }
        }

        cursorDelegate: Rectangle {
            id: caret
            width: root.mac ? 1 : Theme.u * 2
            color: root.mac ? GoldenGate.label : Theme.accent
            visible: input.activeFocus
            onVisibleChanged: opacity = 1
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: input.activeFocus && !Motion.still
                onStopped: caret.opacity = 1
                PropertyAction {
                    value: 1
                }
                PauseAnimation {
                    duration: Motion.ms(480)
                }
                PropertyAction {
                    value: 0
                }
                PauseAnimation {
                    duration: Motion.ms(480)
                }
            }
        }
    }

    PxText {
        anchors.fill: input
        visible: input.text === "" && !input.inputMethodComposing
        text: root.placeholder
        dim: true
        font: input.font
        elide: Text.ElideRight
    }

    // a password typed here is never shown by the keys on screen (services/KeyCast)
    readonly property bool _secretHeld: root.password && input.activeFocus
    on_SecretHeldChanged: KeyCast.secretFields += _secretHeld ? 1 : -1
    Component.onDestruction: if (_secretHeld)
        KeyCast.secretFields -= 1
}
