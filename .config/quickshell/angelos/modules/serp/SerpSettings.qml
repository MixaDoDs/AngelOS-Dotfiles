pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets
import qs.modules.serp.settings

// serp-skin: the skin's settings window in the shape of Serpantinum's Guide — a centred card,
// a sidebar of pages on the left (with a search), the page on the right. Built only while open
// (SerpWindows: LazyLoader on Serp.settingsOpen); Esc or a click outside closes it. The page
// lives in Serp.settingsPage, so it opens where it was left. Everything reads Serp.*, so a
// palette picked here re-colours the window at once.
PanelWindow {
    id: win
    // the wallpaper in screen space, for the liquid glass (Serp.glassOn)
    SerpBackdrop {
        id: glassBack
        origin: Qt.point(0, 0)
    }

    readonly property var pages: ["welcome", "theme", "bar", "dock", "widgets", "about"]
    readonly property string page: pages.indexOf(Serp.settingsPage) >= 0 ? Serp.settingsPage : "theme"
    property bool built: false
    Component.onCompleted: built = true

    function close() {
        Serp.settingsOpen = false;
    }
    // a page and, maybe, a row on it to scroll to and light up
    property string pendingKey: ""
    function jump(p, key) {
        Serp.settingsPage = p;
        pendingKey = key || "";
        if (pendingKey)
            flashLater.restart();
    }
    Timer {
        id: flashLater
        interval: 60
        onTriggered: {
            if (content.item && win.pendingKey)
                content.item.flash(win.pendingKey);
            win.pendingKey = "";
        }
    }

    screen: Shell.focusedScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-serpsettings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    BackgroundEffect.blurRegion: Serp.blurOn ? blurRegion : null
    Region {
        id: blurRegion
        item: card
        radius: card.radius
    }

    // takes input: the whole screen on purpose, it only exists while open and a click outside
    // the card closes the window
    MouseArea {
        anchors.fill: parent
        onPressed: win.close()
    }

    SGlass {
        id: card
        width: Math.min(Serp.px(1200), win.width - Serp.px(80))
        height: Math.min(Serp.px(750), win.height - Serp.px(80))
        anchors.centerIn: parent
        radius: Math.min(Serp.px(24), Serp.radius * 1.4)
        // opaque enough to read even when the islands are thin
        backdrop: glassBack
        tintAmount: Math.max(Serp.cfg.glassTint, 0.75)  // text-heavy: readable over any wallpaper
        frost: 6  // frosted harder: the picture behind becomes light, not shapes
        opacity: win.built ? 1 : 0
        scale: win.built ? 1 : 0.95
        Behavior on opacity {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutExpo
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutExpo
            }
        }

        // a click inside never closes it; it gives the keys back to the window
        MouseArea {
            anchors.fill: parent
            onPressed: keys.forceActiveFocus()
        }

        // typing anywhere starts the search, "/" too; Esc closes
        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.close()
            Keys.onPressed: e => {
                const t = e.text;
                if (!t || (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                    return;
                if (t === "/") {
                    side.startSearch("");
                    e.accepted = true;
                } else if (t.length === 1 && t.charCodeAt(0) > 32 && t.charCodeAt(0) !== 127) {
                    side.startSearch(t);
                    e.accepted = true;
                }
            }
        }

        SideBar {
            id: side
            x: Serp.px(10)
            y: Serp.px(10)
            width: Serp.px(232)
            height: parent.height - Serp.px(20)
            page: win.page
            onJump: (p, key) => win.jump(p, key)
            onSearchClosed: keys.forceActiveFocus()
            // a beat after the card
            opacity: win.built ? 1 : 0
            transform: Translate {
                x: win.built ? 0 : -Serp.px(12)
                Behavior on x {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 30
                        }
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutExpo
                        }
                    }
                }
            }
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: 30
                    }
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }

        Item {
            id: pane
            anchors.left: side.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Serp.px(4)
            clip: true
            // the content comes in last on open, and slides in softly on each page change
            opacity: win.built ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: 90
                    }
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Loader {
                id: content
                width: parent.width
                height: parent.height
                sourceComponent: {
                    switch (win.page) {
                    case "welcome":
                        return pWelcome;
                    case "bar":
                        return pBar;
                    case "dock":
                        return pDock;
                    case "widgets":
                        return pWidgets;
                    case "about":
                        return pAbout;
                    default:
                        return pTheme;
                    }
                }
                onLoaded: swap.restart()
                ParallelAnimation {
                    id: swap
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: content
                        property: "y"
                        from: Serp.px(10)
                        to: 0
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Component {
        id: pWelcome
        PageWelcome {}
    }
    Component {
        id: pTheme
        PageTheme {}
    }
    Component {
        id: pBar
        PageBar {}
    }
    Component {
        id: pDock
        PageDock {}
    }
    Component {
        id: pWidgets
        PageWidgets {}
    }
    Component {
        id: pAbout
        PageAbout {}
    }

    RightClickGuard {}
}
