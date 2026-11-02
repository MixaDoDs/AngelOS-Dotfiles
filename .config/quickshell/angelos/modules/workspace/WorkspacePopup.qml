pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// Small NGO window that pops up on workspace switch.
PanelWindow {
    id: win

    property var ws: null
    property int serial: 0
    property bool shown: false
    readonly property string label: {
        if (!ws)
            return "";
        if (ws.idx === 0)
            return I18n.t("чистый стол", "clean desk");
        const names = Config.workspaces.names || {};
        return names[ws.output + ":" + ws.idx] || ws.name || ("workspace " + ws.idx);
    }
    readonly property var phrases: ["♡ welcome back ♡", I18n.t("работаем~", "Working~"), I18n.t("не забудь попить воды", "Remember to drink water"), "OMG kawaii", I18n.t("ты справишься ♡", "You can do it ♡"), I18n.t("стрим скоро?", "Streaming soon?"), "angel mode: ON", I18n.t("ещё чуть-чуть…", "Just a little more…"), "internet angel ✧", I18n.t("лайк, подписка ♡", "Like and subscribe ♡")]
    property string phrase: ""

    onSerialChanged: {
        if (Config.workspaces.popupMode !== "window" || !ws)
            return;
        phrase = phrases[Math.floor(Math.random() * phrases.length)];
        shown = true;
        popIn.restart();
        hideTimer.restart();
    }

    readonly property string pos: Config.workspaces.popupPosition || "bottom-center"
    visible: shown
    anchors.top: Place.top(pos)
    anchors.bottom: Place.bottom(pos)
    anchors.left: Place.left(pos)
    anchors.right: Place.right(pos)
    margins.top: Theme.u * 6
    margins.bottom: Theme.u * 6
    margins.left: Theme.u * 6
    margins.right: Theme.u * 6
    implicitWidth: frame.width * 1.1 + Theme.u * 4
    implicitHeight: frame.height * 1.1 + Theme.u * 4
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-workspace"
    WlrLayershell.layer: WlrLayer.Overlay

    BackgroundEffect.blurRegion: Config.appearance.blur && win.shown ? blurRegion : null
    Region {
        id: blurRegion
        item: frame
    }

    Timer {
        id: hideTimer
        interval: Config.workspaces.popupMs
        onTriggered: popOut.restart()
    }

    PxWindow {
        id: frame
        anchors.centerIn: parent
        width: Math.max(Theme.u * 80, content.implicitWidth + Theme.pad * 2 + Theme.u * 6)
        height: titleHeight + content.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: I18n.exe(win.label.replace(/\s+/g, "_"))
        icon: "layers"
        compact: true
        closable: false
        transformOrigin: Item.Center

        Column {
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 5
                PxIcon {
                    name: "sparkle"
                    fill: Theme.accent2
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: win.label
                    kind: "title"
                    color: Theme.dark ? Theme.text : Theme.edge
                }
                PxIcon {
                    name: "sparkle"
                    fill: Theme.accent3
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 3
                Repeater {
                    model: win.ws ? Niri.workspacesOn(win.ws.output) : []
                    WsSprite {
                        required property var modelData
                        lit: modelData.is_active
                        playful: false
                        hollow: !modelData.is_active && Niri.windowsOn(modelData.id).length === 0
                        pixel: modelData.is_active ? Theme.u + 1 : Theme.u
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    }
                }
            }
            PxText {
                visible: Config.workspaces.phrases
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.phrase
                kind: "tiny"
                dim: true
            }
        }

        // stepped "pixel" pop-in
        SequentialAnimation {
            id: popIn
            PropertyAction {
                target: frame
                property: "opacity"
                value: 1
            }
            PropertyAction {
                target: frame
                property: "scale"
                value: 0.6
            }
            PauseAnimation {
                duration: Motion.ms(35)
            }
            PropertyAction {
                target: frame
                property: "scale"
                value: 0.85
            }
            PauseAnimation {
                duration: Motion.ms(35)
            }
            PropertyAction {
                target: frame
                property: "scale"
                value: 1.08
            }
            PauseAnimation {
                duration: Motion.ms(50)
            }
            PropertyAction {
                target: frame
                property: "scale"
                value: 1
            }
        }
        SequentialAnimation {
            id: popOut
            PropertyAction {
                target: frame
                property: "scale"
                value: 0.9
            }
            PauseAnimation {
                duration: Motion.ms(40)
            }
            PropertyAction {
                target: frame
                property: "opacity"
                value: 0.6
            }
            PropertyAction {
                target: frame
                property: "scale"
                value: 0.7
            }
            PauseAnimation {
                duration: Motion.ms(40)
            }
            PropertyAction {
                target: frame
                property: "opacity"
                value: 0.3
            }
            PropertyAction {
                target: frame
                property: "scale"
                value: 0.5
            }
            PauseAnimation {
                duration: Motion.ms(40)
            }
            ScriptAction {
                script: win.shown = false
            }
        }
    }

    RightClickGuard {}
}
