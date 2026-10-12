pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.config
import qs.services
import qs.widgets

// Polkit authentication agent.
Scope {
    id: root

    // re-created on demand so we can take over the session slot from a fallback agent
    LazyLoader {
        id: agentLoader
        active: true
        PolkitAgent {}
    }
    readonly property var agent: agentLoader.item
    readonly property var flow: agent ? agent.flow : null
    readonly property bool registered: agent ? agent.isRegistered : false

    function reregister() {
        agentLoader.active = false;
        Qt.callLater(() => agentLoader.active = true);
    }
    Component.onCompleted: Shell.polkitReregister = reregister
    onRegisteredChanged: Shell.polkitRegistered = registered
    // a password asked: the keys on screen keep quiet (services/KeyCast)
    readonly property bool asking: !!agent && agent.isActive && !!flow
    onAskingChanged: KeyCast.polkitOpen = asking

    PanelWindow {
        id: win

        screen: Shell.focusedScreen
        visible: !!root.agent && root.agent.isActive && !!root.flow
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Qt.alpha(Theme.shadow, 0.35)
        WlrLayershell.namespace: "angelos-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        // takes input: the password dialog
        WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) {
            field.text = "";
            field.focusField();
        }

        BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
        Region {
            id: blurRegion
            item: dialog
        }

        PxWindow {
            id: dialog
            anchors.centerIn: parent
            width: Theme.u * 200
            height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
            title: I18n.t("Нужен пароль", "Password required")
            icon: "lock"
            onCloseClicked: root.flow.cancelAuthenticationRequest()

            Column {
                id: col
                width: parent.width
                spacing: Theme.u * 5

                Row {
                    spacing: Theme.u * 5
                    width: parent.width
                    PxIcon {
                        name: "warn"
                        pixel: Theme.u * 2
                    }
                    PxText {
                        width: parent.width - Theme.u * 30
                        text: root.flow ? root.flow.message : ""
                        wrapMode: Text.Wrap
                    }
                }
                PxText {
                    visible: text !== ""
                    width: parent.width
                    text: root.flow ? root.flow.actionId : ""
                    kind: "tiny"
                    dim: true
                    elide: Text.ElideMiddle
                }
                PxText {
                    text: root.flow ? (root.flow.inputPrompt || I18n.t("Пароль:", "Password:")) : ""
                }
                PxField {
                    id: field
                    keepFocus: true
                    width: parent.width
                    password: !(root.flow && root.flow.responseVisible)
                    enabled: root.flow && root.flow.isResponseRequired
                    onAccepted: root.flow.submit(text)
                    onKeyPressed: e => {
                        if (e.key === Qt.Key_Escape) {
                            root.flow.cancelAuthenticationRequest();
                            e.accepted = true;
                        }
                    }
                }
                PxText {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? Theme.danger : Theme.textDim
                }
                Row {
                    anchors.right: parent.right
                    spacing: Theme.u * 4
                    PxButton {
                        text: I18n.t("Отмена", "Cancel")
                        onClicked: root.flow.cancelAuthenticationRequest()
                    }
                    PxButton {
                        text: "OK"
                        accent: true
                        onClicked: root.flow.submit(field.text)
                    }
                }
            }
        }

        RightClickGuard {}
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            field.text = "";
        }
    }
}
