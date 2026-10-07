pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The setup wizard, like macOS's Setup Assistant: one question a screen, big and centred,
// "Back" and "Continue", calm transitions (SetupAssistant.qml, the course in SetupFlow.qml).
// Only what one can't start without; everything else lives in Settings.
//
// Always full screen: it covers every screen (layer shell, overlay), takes the keyboard and
// holds the desktop (Shell.setupLocked: no Start, launcher, Settings, menus or shell hotkeys)
// and niri's own keys too (a shortcut inhibitor: Mod+T, Mod+Q, workspaces… wait; only the
// binds marked allow-inhibiting=false — media keys, Mod+Escape — still go to niri).
// The first run has no way out on screen: the questions to the end. The way out for when it
// is broken: `angelos setup skip` from a text console, and when the questions themselves
// fail to load, the screens are let go at once. Opened again from Settings or `angelos
// setup` it is the same full screen, with "Close" and Esc.
Scope {
    id: root

    SetupFlow {
        id: flow
    }

    // ---- every screen covered, the questions on one of them ----
    Variants {
        model: Shell.setupLocked ? Shell.screens : []

        PanelWindow {
            id: cover

            required property var modelData
            readonly property bool hosting: modelData === flow.host

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.desk
            WlrLayershell.namespace: "angelos-setup"
            WlrLayershell.layer: WlrLayer.Overlay
            // takes input: the wizard holds the desktop until it is done (or closed, opened again);
            // the keys go to the questions (dev runs sit next to a live session: on demand)
            WlrLayershell.keyboardFocus: hosting ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

            // niri's own keys wait too (Mod+T would open a terminal nobody sees under the
            // cover). Mod+Escape (toggle-keyboard-shortcuts-inhibit) switches the inhibitor
            // off; it is asked for again at once — a frozen shell can't, so there Mod+Escape
            // still gives niri back (dev runs sit next to a live session: never)
            ShortcutInhibitor {
                id: inhibitor
                property bool seen: false
                property bool rearming: false
                window: cover
                enabled: cover.hosting && !Shell.dev && !rearming
                onActiveChanged: {
                    if (active)
                        seen = true;
                    else if (seen && enabled)
                        rearm();
                }
                onCancelled: rearm()
                function rearm() {
                    seen = false;
                    rearming = true;
                    rearmTimer.restart();
                }
            }
            Timer {
                id: rearmTimer
                interval: 300
                onTriggered: inhibitor.rearming = false
            }

            // a calm ground: the theme's desk fading into its accent, a few hearts drifting up
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Theme.desk
                    }
                    GradientStop {
                        position: 1
                        color: Theme.mix(Theme.desk, Theme.accent, Theme.dark ? 0.14 : 0.1)
                    }
                }
            }
            FloatingHearts {
                anchors.fill: parent
                count: 12
                maxOpacity: 0.22
                running: !Motion.still
            }

            // the questions (their own file: when it fails, the screens are let go)
            Loader {
                id: questions
                anchors.fill: parent
                active: cover.hosting
                source: "SetupAssistant.qml"
                onLoaded: {
                    item.wizard = flow;
                    flow.assistant = item;
                }
                onStatusChanged: if (status === Loader.Error) {
                    console.warn("setup wizard: the questions did not load — the desktop is let go");
                    flow.close();
                }
            }

            // another screen: where the questions are, and a way to bring them here
            Column {
                visible: !cover.hosting
                anchors.centerIn: parent
                width: Math.min(parent.width - Theme.u * 24, Theme.u * 200)
                spacing: Theme.u * 8
                AngelLogo {
                    anchors.horizontalCenter: parent.horizontalCenter
                    pixel: Theme.u * 2
                    fontSize: Theme.sizeHuge
                }
                PxText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    kind: "title"
                    text: I18n.t("Настройка идёт на экране ", "Setting up on screen ") + (flow.host ? flow.host.name : "")
                }
                PxButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "monitor"
                    text: I18n.t("Продолжить на этом экране", "Continue on this screen")
                    onClicked: flow.hostName = cover.modelData.name
                }
            }

            // opened again (from Settings, `angelos setup`): "Close" and Esc, on every screen.
            // The first run has none — only `angelos setup skip` from a text console
            PxButton {
                visible: !Shell.setupFirstRun
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.u * 8
                compact: true
                flat: true
                icon: "close"
                text: I18n.t("Закрыть", "Close")
                onClicked: flow.close()
            }
            PxText {
                visible: Shell.setupFirstRun
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.u * 6
                kind: "tiny"
                dim: true
                opacity: 0.7
                text: I18n.t("Мастер не отвечает? Ctrl+Alt+F3, войди и набери: angelos setup skip", "Wizard stuck? Ctrl+Alt+F3, log in and type: angelos setup skip")
            }
            Shortcut {
                sequence: "Escape"
                enabled: cover.hosting && !Shell.setupFirstRun
                onActivated: flow.close()
            }
            RightClickGuard {}
        }
    }
}
