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
// The first run's intro also plays alone (Shell.introOpen: once after an update, `angelos intro`):
// the same covers over a still of the desktop, no questions.
Scope {
    id: root

    SetupFlow {
        id: flow
    }
    // the first run's intro: its sounds and its clock (the screens draw it)
    SetupIntro {
        id: introCtl
    }

    // ---- every screen covered, the questions on one of them ----
    Variants {
        model: Shell.setupLocked ? Shell.screens : []

        PanelWindow {
            id: cover

            required property var modelData
            readonly property bool hosting: modelData === flow.host
            Component.onCompleted: Shell.setupCovers++
            Component.onDestruction: Shell.setupCovers--

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

            // what the screen shows (the first run's intro draws it through its waking up: SetupWake)
            Item {
                id: scene
                anchors.fill: parent

                // a calm ground: the theme's desk fading into its accent, a few hearts drifting up
                Rectangle {
                    anchors.fill: parent
                    visible: !still.shown
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
                    id: hearts
                    anchors.fill: parent
                    count: 12
                    maxOpacity: 0.22
                    // gliding, frame by frame with the screen (render thread)
                    glide: true
                    running: !Motion.still && !still.shown
                    visible: !still.shown
                }
                // the intro alone: the desktop as it was (grim, just before), woken up at the cut
                Image {
                    id: still
                    readonly property bool shown: introCtl.alone && status === Image.Ready
                    anchors.fill: parent
                    visible: shown
                    source: introCtl.alone ? introCtl.shotUrl(cover.modelData.name) : ""
                    cache: false
                    asynchronous: true
                    smooth: false
                }

                // the intro alone: dimmed behind its question, and on into the minute
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: introCtl.alone ? introCtl.askDim * (introCtl.phase === "reveal" ? 1 - introCtl.reveal : introCtl.askIn) : 0
                    visible: opacity > 0
                }

                // the questions (their own file: when it fails, the screens are let go)
                Loader {
                    id: questions
                    anchors.fill: parent
                    active: cover.hosting && Shell.setupOpen
                    source: "SetupAssistant.qml"
                    onLoaded: {
                        item.held = Qt.binding(() => introCtl.active);
                        item.wizard = flow;
                        item.screenName = cover.modelData.name;
                        flow.assistant = item;
                    }
                    onStatusChanged: if (status === Loader.Error) {
                        console.warn("setup wizard: the questions did not load — the desktop is let go");
                        flow.close();
                    }
                }

                // another screen: where the questions are, and a way to bring them here
                Column {
                    visible: !cover.hosting && Shell.setupOpen
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
                    visible: Shell.setupOpen && !Shell.setupFirstRun
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

                // the first run's minute before the questions (SetupIntro), over all of it
                SetupIntroScreen {
                    anchors.fill: parent
                    intro: introCtl
                    hosting: cover.hosting
                    here: cover.modelData
                    host: flow.host
                }
            }
            SetupWake {
                anchors.fill: parent
                intro: introCtl
                source: scene
            }

            // the intro alone asks first: «Обновление скачано — продолжить?». Either answer goes on;
            // «Нет» says «Да» for ten frames first
            PxBox {
                id: ask
                visible: cover.hosting && introCtl.asking
                opacity: introCtl.askIn
                anchors.centerIn: parent
                width: Math.min(parent.width - Theme.u * 24, Theme.u * 170)
                height: askBody.implicitHeight + askBar.height + Theme.u * 16
                color: Theme.face
                shadow: true
                Rectangle {
                    id: askBar
                    x: ask.inset
                    y: ask.inset
                    width: ask.width - ask.inset * 2
                    height: askBarText.implicitHeight + Theme.u * 4
                    color: Theme.accent
                    PxText {
                        id: askBarText
                        x: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        font.bold: true
                        color: Theme.dark ? Theme.desk : "#ffffff"
                        text: I18n.t("angelOS — обновление", "angelOS — update")
                    }
                }
                Column {
                    id: askBody
                    x: Theme.u * 8
                    y: askBar.y + askBar.height + Theme.u * 6
                    width: ask.width - Theme.u * 16
                    spacing: Theme.u * 6
                    PxText {
                        kind: "title"
                        text: I18n.t("Обновление скачано", "The update is downloaded")
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: I18n.t("Вы хотите продолжить?", "Do you want to continue?")
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: Theme.u * 4
                        PxButton {
                            accent: true
                            text: I18n.t("Да", "Yes")
                            onClicked: introCtl.answer()
                        }
                        PxButton {
                            id: no
                            property bool lying: false
                            text: lying ? I18n.t("Да", "Yes") : I18n.t("Нет", "No")
                            onClicked: if (!lying) {
                                lying = true;
                                frames.n = 0;
                                frames.start();
                            }
                            // ten frames of this screen, then «Нет» again — and on all the same
                            FrameAnimation {
                                id: frames
                                property int n: 0
                                onTriggered: if (++n >= 10) {
                                    stop();
                                    no.lying = false;
                                    introCtl.answer();
                                }
                            }
                        }
                    }
                }
            }
            Shortcut {
                sequences: ["Return", "Enter"]
                enabled: cover.hosting && introCtl.asking
                onActivated: introCtl.answer()
            }

            // the intro's way out: space five times
            Shortcut {
                sequence: "Space"
                enabled: cover.hosting && introCtl.phase === "run"
                onActivated: introCtl.press()
            }
            Shortcut {
                sequence: "Escape"
                enabled: cover.hosting && Shell.setupOpen && !Shell.setupFirstRun
                onActivated: flow.close()
            }
            Shortcut {
                sequence: "Escape"
                enabled: cover.hosting && introCtl.alone
                onActivated: introCtl.skip()
            }
            RightClickGuard {}
            // no pointer at all while the intro plays (alone: until the desktop is back)
            MouseArea {
                anchors.fill: parent
                visible: introCtl.active
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                cursorShape: Qt.BlankCursor
                onWheel: wheel => wheel.accepted = true
            }
        }
    }
}
