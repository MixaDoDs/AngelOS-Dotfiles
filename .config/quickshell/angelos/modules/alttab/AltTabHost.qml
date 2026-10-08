pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The Alt+Tab switcher (services/AltTab) on the screen Alt+Tab was pressed on.
// It exists only while it is shown, so a quick Alt+Tab tap never takes the
// keyboard from the app. Keys: Tab / arrows move, Enter or letting Alt go
// picks, Esc cancels, Delete closes the highlighted window; the mouse picks too, and a
// click beside the switcher (on any screen) cancels it.
// ⌘Tab (AltTab.mode "apps") shows the apps the Mac way (AltTabMac); letting ⌘ go picks.
Scope {
    LazyLoader {
        active: AltTab.shown
        PanelWindow {
            id: win

            screen: Shell.screenByName(AltTab.screenName) || Shell.focusedScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // takes input: the whole screen — a click beside the switcher cancels it (`outside`);
            // the settings' preview (demo) takes clicks on the switcher only
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            mask: AltTab.demo ? stageOnly : null
            Region {
                id: stageOnly
                item: stage
            }
            WlrLayershell.namespace: "angelos-alttab"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: AltTab.demo ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

            function appName(w) {
                const e = w && w.app_id ? DesktopEntries.heuristicLookup(w.app_id) : null;
                return e ? e.name : (w && w.app_id ? w.app_id : "?");
            }
            function place(w) {
                const ws = w ? Niri.workspaceById(w.workspace_id) : null;
                if (!ws)
                    return "";
                const names = Config.workspaces.names || {};
                const name = names[ws.output + ":" + ws.idx] || ws.name || "";
                return (name ? name : I18n.t("стол ", "desk ") + ws.idx) + (Quickshell.screens.length > 1 ? " · " + ws.output : "");
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: e => {
                    const k = e.key;
                    if (k === Qt.Key_Escape)
                        AltTab.cancel();
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                        AltTab.commit();
                    else if (k === Qt.Key_Tab || k === Qt.Key_Right || k === Qt.Key_Down)
                        AltTab.select((AltTab.index + 1) % AltTab.items.length);
                    else if (k === Qt.Key_Backtab || k === Qt.Key_Left || k === Qt.Key_Up)
                        AltTab.select((AltTab.index - 1 + AltTab.items.length) % AltTab.items.length);
                    else if (k === Qt.Key_Delete && AltTab.current && AltTab.mode === "windows") {
                        // close the highlighted window, stay in the switcher
                        const id = AltTab.current.id;
                        Niri.closeWindow(id);
                        const rest = AltTab.items.filter(w => w.id !== id);
                        if (!rest.length) {
                            AltTab.cancel();
                        } else {
                            AltTab.items = rest;
                            AltTab.index = Math.min(AltTab.index, rest.length - 1);
                        }
                    } else
                        return;
                    e.accepted = true;
                }
                // the fallback when the keyboard watcher is not allowed to read keys
                Keys.onReleased: e => {
                    const mod = AltTab.mode === "apps" ? [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R] : [Qt.Key_Alt, Qt.Key_AltGr];
                    if (mod.includes(e.key)) {
                        if (!AltTab.demo)
                            AltTab.commit();
                        e.accepted = true;
                    }
                }
            }

            // while the demon rules (Y2K → Angel or demon → Alt+Tab in hell): "hell" — hell's
            // own switcher (AltTabHell), "skin" — the chosen style re-inked in hell's palette
            // (shaders/hell_ink.frag) with the circle's rim, "" — untouched
            readonly property bool hellOwn: Angel.demon && Config.y2k.hellAltTab === "hell"
            readonly property bool hellSkin: Angel.demon && Config.y2k.hellAltTab === "skin"
            readonly property int skinPad: 0
            // Golden Gate's ⌘Tab panel is Liquid Glass: niri blurs under its rounded slab
            BackgroundEffect.blurRegion: AltTab.mode === "apps" && GoldenGate.on && GoldenGate.blurOn ? atBlur : null
            Region {
                id: atBlur
                item: stage
                radius: GoldenGate.px(26)
            }

            MouseArea {
                id: outside
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: AltTab.cancel()
            }
            Item {
                id: stage
                anchors.centerIn: parent
                width: Math.min(implicitWidth, win.width - Theme.u * 16)
                height: implicitHeight
                implicitWidth: view.item ? view.item.implicitWidth : 0
                implicitHeight: (view.item ? view.item.implicitHeight : 0) + win.skinPad
                opacity: 0
                scale: 0.94
                Component.onCompleted: {
                    opacity = 1;
                    scale = 1;
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.ms(110)
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(140)
                        easing.type: Easing.OutBack
                    }
                }
                // a click on the switcher between its cards is not one beside it
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }
                Loader {
                    id: view
                    anchors.fill: parent
                    anchors.topMargin: win.skinPad
                    sourceComponent: AltTab.mode === "apps" ? mac : win.hellOwn ? hell : AltTab.style === "ngo" ? ngo : AltTab.style === "y2k" ? y2k : angelos
                    layer.enabled: win.hellSkin
                    layer.effect: ShaderEffect {
                        property real keep: 0.35
                        fragmentShader: Qt.resolvedUrl("../../shaders/hell_ink.frag.qsb")
                        property color plate: Theme.hellPlate
                        property color face: Theme.mix(Theme.hellRim, Theme.hellFace, 0.4)
                        property color dim: Theme.hellTextDim
                        property color text: Theme.hellText
                        property color accent: Theme.hellAccent
                    }
                }
                // the hell version: the circle's rim on the switcher's edges
                HellEdge {
                    visible: win.hellSkin
                    anchors.fill: view
                    seed: 4
                }
            }
            Component {
                id: angelos
                AltTabAngel {
                    host: win
                }
            }
            Component {
                id: ngo
                AltTabNgo {
                    host: win
                }
            }
            Component {
                id: y2k
                AltTabY2k {
                    host: win
                }
            }
            Component {
                id: hell
                AltTabHell {
                    host: win
                }
            }
            Component {
                id: mac
                AltTabMac {
                    host: win
                }
            }

            RightClickGuard {}
        }
    }
    // the other screens: a click there cancels it too (nothing drawn, gone with the switcher)
    Variants {
        model: AltTab.shown && !AltTab.demo ? Shell.screens.filter(s => s !== (Shell.screenByName(AltTab.screenName) || Shell.focusedScreen)) : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // takes input: a click anywhere here cancels the switcher
            WlrLayershell.namespace: "angelos-alttab-outside"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: AltTab.cancel()
            }
            RightClickGuard {}
        }
    }
}
