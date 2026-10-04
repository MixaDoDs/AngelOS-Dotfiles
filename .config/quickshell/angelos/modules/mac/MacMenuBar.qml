pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.config
import qs.services
import qs.widgets

// The Golden Gate menu bar: 24 pt along the top of every screen, no band of its own (the
// wallpaper shows through; Config.mac.barBackground puts one under it), ink black or white by
// the wallpaper under it. Leading: angelOS's emblem where the Apple logo is (its menu: About,
// Settings, Force Quit, Sleep…), the focused app's name in bold and its menus (services/AppMenu).
// Trailing, right to left: the date and time (Notification Center), Control Center, Spotlight,
// the input source, sound, Bluetooth, Wi-Fi and the apps' tray icons. While the demon rules: hell's ink and her horns on the emblem.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property color ink: GoldenGate.barInk(screenName)
    readonly property bool menuHere: MacMenus.isOpen && MacMenus.screen === screenName
    readonly property real h: GoldenGate.barHeight

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: h
    exclusiveZone: h
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: "angelos-macbar"
    WlrLayershell.layer: WlrLayer.Top
    BackgroundEffect.blurRegion: Config.appearance.blur && Config.mac.barBackground ? blurRegion : null
    Region {
        id: blurRegion
        item: band
    }

    Rectangle {
        id: band
        anchors.fill: parent
        color: GoldenGate.barBand(win.screenName)
    }

    // ---- leading: the emblem, the app, its menus ----
    Row {
        id: titles
        x: GoldenGate.px(10)
        height: win.h
        spacing: 0
        clip: true
        width: Math.min(implicitWidth, status.x - x - GoldenGate.px(16))

        Repeater {
            id: titleRep
            model: MacMenus.barMenus

            Item {
                id: title
                required property var modelData
                required property int index
                readonly property bool isOpen: win.menuHere && MacMenus.index === index
                width: modelData.emblem ? GoldenGate.px(38) : label.implicitWidth + GoldenGate.px(20)
                height: win.h
                // where its menu hangs, for ←/→ (MacMenus.step)
                onXChanged: win.recordTitles()
                Component.onCompleted: win.recordTitles()

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: GoldenGate.px(2)
                    anchors.bottomMargin: GoldenGate.px(2)
                    radius: height / 2
                    color: Qt.alpha(win.ink, GoldenGate.dark || win.ink.r > 0.5 ? 0.22 : 0.1)
                    visible: title.isOpen
                }
                MacIcon {
                    visible: title.modelData.emblem === true
                    anchors.centerIn: parent
                    name: Angel.demon || Story.marked ? "angel-horns" : "angel"
                    size: GoldenGate.px(17)
                    color: win.ink
                }
                MacText {
                    id: label
                    visible: !title.modelData.emblem
                    anchors.centerIn: parent
                    text: title.modelData.title || ""
                    bold: title.modelData.bold === true
                    color: win.ink
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: MacMenus.toggle(win.screenName, title.index, win.titleLeft(title))
                    onEntered: if (win.menuHere && MacMenus.index >= 0 && MacMenus.index !== title.index)
                        MacMenus.open(win.screenName, title.index, win.titleLeft(title))
                }
            }
        }
    }
    function titleLeft(t) {
        return titles.x + t.x;
    }
    function recordTitles() {
        Qt.callLater(() => {
            const xs = [];
            for (let i = 0; i < titleRep.count; i++) {
                const t = titleRep.itemAt(i);
                xs.push(t ? titles.x + t.x : 0);
            }
            const all = Object.assign({}, MacMenus.titleX);
            all[win.screenName] = xs;
            MacMenus.titleX = all;
        });
    }

    // ---- trailing: status items ----
    component StatusButton: Item {
        id: sb
        property string kind: ""
        property bool active: win.menuHere && MacMenus.statusKind === kind && kind !== ""
        default property alias content: box.data
        signal clicked(var mouse)
        width: Math.max(GoldenGate.px(26), box.childrenRect.width + GoldenGate.px(12))
        height: win.h
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: GoldenGate.px(2)
            anchors.bottomMargin: GoldenGate.px(2)
            radius: height / 2
            color: Qt.alpha(win.ink, win.ink.r > 0.5 ? 0.22 : 0.1)
            visible: sb.active
        }
        Item {
            id: box
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: m => sb.clicked(m)
        }
    }
    function rightOf(item) {
        return item.mapToItem(null, item.width, 0).x;
    }

    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: GoldenGate.px(8)
        height: win.h
        layoutDirection: Qt.RightToLeft
        spacing: GoldenGate.px(2)

        // the date and time: "Вс 4 окт. 16:27" / "Sun Oct 4 4:27 PM"
        StatusButton {
            id: clock
            property date now: new Date()
            active: GoldenGate.panel === "nc" && GoldenGate.panelScreen === win.screenName
            onClicked: GoldenGate.togglePanel("nc", win.screenName)
            Timer {
                interval: 1000
                running: !Shell.hiddenScreen(win.screenName)
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.now = new Date()
            }
            MacText {
                text: {
                    const d = I18n.english ? I18n.locale.toString(clock.now, "ddd MMM d") : I18n.locale.toString(clock.now, "ddd d MMM");
                    return d.charAt(0).toUpperCase() + d.slice(1) + "  " + I18n.time(clock.now);
                }
                color: win.ink
            }
        }
        // Control Center
        StatusButton {
            active: GoldenGate.panel === "cc" && GoldenGate.panelScreen === win.screenName
            MacIcon {
                name: "control-center"
                color: win.ink
                stroke: 1.8
            }
            onClicked: GoldenGate.togglePanel("cc", win.screenName)
        }
        // Spotlight
        StatusButton {
            MacIcon {
                name: "search"
                color: win.ink
                stroke: 2
            }
            onClicked: Shell.toggleStart(win.screenName)
        }
        // the input source: the layout's short name in a rounded frame, like macOS's
        StatusButton {
            id: input
            kind: "input"
            visible: Niri.keyboardLayouts.length > 1
            Rectangle {
                width: inputLabel.implicitWidth + GoldenGate.px(8)
                height: GoldenGate.px(16)
                radius: GoldenGate.px(4)
                color: "transparent"
                border.width: Math.max(1, GoldenGate.px(1.3))
                border.color: win.ink
                MacText {
                    id: inputLabel
                    anchors.centerIn: parent
                    text: Niri.layoutShort.toUpperCase()
                    size: GoldenGate.px(10)
                    semibold: true
                    color: win.ink
                }
            }
            onClicked: MacMenus.toggleStatus(win.screenName, "input", win.rightOf(input))
        }
        StatusButton {
            id: sound
            kind: "sound"
            visible: Audio.ready
            MacIcon {
                name: Audio.muted || Audio.volume === 0 ? "volume-x" : Audio.volume < 0.34 ? "volume" : Audio.volume < 0.67 ? "volume-1" : "volume-2"
                color: win.ink
                stroke: 2
            }
            onClicked: MacMenus.toggleStatus(win.screenName, "sound", win.rightOf(sound))
        }
        StatusButton {
            id: bt
            kind: "bluetooth"
            visible: Bt.available
            MacIcon {
                name: "bluetooth"
                color: Bt.enabled ? win.ink : Qt.alpha(win.ink, 0.45)
                stroke: 2
            }
            onClicked: MacMenus.toggleStatus(win.screenName, "bluetooth", win.rightOf(bt))
        }
        StatusButton {
            id: wifi
            kind: "wifi"
            visible: Wifi.hasWifi
            MacIcon {
                name: !Wifi.enabled ? "wifi-off" : !Wifi.connected ? "wifi-zero" : Wifi.strength < 0.4 ? "wifi-low" : "wifi"
                color: win.ink
                stroke: 2
            }
            onClicked: MacMenus.toggleStatus(win.screenName, "wifi", win.rightOf(wifi))
        }
        // the apps' tray icons (menu bar extras): click — the app's action, right click — its menu
        Repeater {
            model: SystemTray.items
            StatusButton {
                id: extra
                required property var modelData
                kind: ""
                active: win.menuHere && MacMenus.statusKind === "tray" && MacMenus.trayItem === modelData
                Image {
                    width: GoldenGate.px(16)
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: extra.modelData.icon
                    smooth: true
                    mipmap: true
                }
                onClicked: m => {
                    if (m.button === Qt.MiddleButton)
                        extra.modelData.secondaryActivate();
                    else if ((m.button === Qt.RightButton || extra.modelData.onlyMenu) && extra.modelData.hasMenu)
                        MacMenus.toggleStatus(win.screenName, "tray", win.rightOf(extra), extra.modelData);
                    else
                        extra.modelData.activate();
                }
            }
        }
    }

    RightClickGuard {}
}
