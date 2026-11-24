import QtQuick
import qs.config
import qs.services

// serp-skin: the polkit password dialog (modules/polkit/PolkitDialog) in Serpantinum's look.
// The password itself stays in the dialog's own field (PxField `field`, hidden under the skin,
// it keeps the keyboard): this only shows it — dots, or the text when polkit lets it be seen — and
// a click on it gives the field its focus back. `flow` is the agent's flow: its message,
// submit() and cancelAuthenticationRequest().
SerpDialog {
    id: root

    property var flow: null
    property var field: null
    readonly property string typed: field ? field.text : ""
    readonly property bool secret: !(flow && flow.responseVisible)

    icon: "lock"
    title: I18n.t("Нужен пароль", "Password required")
    body: flow ? flow.message : ""
    cardWidth: Serp.px(440)
    buttons: [
        {
            "label": I18n.t("Отмена", "Cancel")
        },
        {
            "label": "OK",
            "kind": "primary"
        }
    ]
    onPicked: i => {
        if (!flow)
            return;
        if (i === 1)
            flow.submit(root.typed);
        else
            flow.cancelAuthenticationRequest();
    }

    SText {
        visible: text !== ""
        width: parent.width
        text: root.flow ? root.flow.actionId : ""
        size: Serp.smallSize
        dim: true
        elide: Text.ElideMiddle
    }
    SText {
        width: parent.width
        text: root.flow ? (root.flow.inputPrompt || I18n.t("Пароль:", "Password:")) : ""
        color: Serp.subtext1
    }
    // the field's face
    Rectangle {
        id: box
        readonly property bool focused: !!root.field && !!root.field.input && root.field.input.activeFocus
        width: parent.width
        height: Serp.px(38)
        radius: height / 2
        color: Qt.alpha(Serp.crust, 0.55)
        border.width: focused ? Serp.px(2) : 1
        border.color: focused ? Qt.alpha(Serp.accent, 0.8) : Serp.line
        opacity: root.flow && root.flow.isResponseRequired ? 1 : 0.5
        SIcon {
            id: keyIcon
            x: Serp.px(14)
            anchors.verticalCenter: parent.verticalCenter
            name: "key-round"
            size: Serp.px(15)
            color: Serp.subtext0
        }
        Item {
            x: keyIcon.x + keyIcon.width + Serp.px(10)
            width: parent.width - x - Serp.px(14)
            height: parent.height
            clip: true
            Row {
                anchors.verticalCenter: parent.verticalCenter
                // a long password scrolls left, the end (where it is typed) stays in sight
                x: Math.min(0, parent.width - width)
                spacing: Serp.px(1)
                SText {
                    id: shown
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.secret ? "●".repeat(root.typed.length) : root.typed
                    size: root.secret ? Serp.px(11) : Serp.textSize
                    elide: Text.ElideNone
                    font.letterSpacing: root.secret ? Serp.px(2) : 0
                }
                Rectangle {
                    id: caret
                    anchors.verticalCenter: parent.verticalCenter
                    width: Serp.px(2)
                    height: Serp.px(16)
                    radius: 1
                    color: Serp.accent
                    visible: box.focused
                    SequentialAnimation on opacity {
                        running: caret.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0
                            duration: 530
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 1
                            duration: 530
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: if (root.field)
                root.field.focusField()
        }
    }
    SText {
        visible: text !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: root.flow ? root.flow.supplementaryMessage : ""
        color: root.flow && root.flow.supplementaryIsError ? Serp.red : Serp.subtext0
    }
}
