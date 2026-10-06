pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.y2k

// What the novel shows (services/Novel): the dialogue box beside the corner helper —
// her sprite from ~/AngelOs-Nov/sprites/<who>/<sprite>.png (.webp .gif .jpg), her name, the line typed out,
// up to a few answers (keys 1–9, Enter/Space goes on); a crumpled paper on the desk (on the
// wallpaper, under the windows), or dropped by her; and the paper unfolded, in handwriting.
Scope {
    id: host

    readonly property var line: Novel.line
    readonly property bool demon: line ? Novel.isDemon(line.who) : Angel.demon

    // ---- the dialogue box ----
    LazyLoader {
        active: Novel.line !== null && !!Angel.screen

        PanelWindow {
            id: box
            screen: Angel.screen
            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: Theme.u * 4
                right: Theme.u * 84
            }
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            implicitWidth: Theme.u * 250
            implicitHeight: frame.height + Theme.u * 2
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "angelos-novel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            readonly property var l: Novel.line || ({
                    "who": "angel",
                    "sprite": "",
                    "text": "",
                    "choices": []
                })
            // the demon's lines, and the narrator's while the demon rules, in the circle's colours
            readonly property bool hell: Novel.isDemon(l.who) || (l.who === "narrator" && Angel.demon)
            property int shown: 0
            readonly property bool typed: shown >= l.text.length
            onLChanged: {
                shown = 0;
                Sounds.play(hell ? "demon" : "angel");
                keys.forceActiveFocus();
            }
            Timer {
                interval: 26
                repeat: true
                running: !box.typed
                onTriggered: box.shown = Math.min(box.l.text.length, box.shown + 1)
            }
            function go() {
                if (!typed)
                    shown = l.text.length;
                else if (!l.choices.length)
                    Novel.advance();
            }

            // the sprite file (Novel.sprites lists the folder); none — the box goes on without it
            readonly property string spriteFile: l.who === "narrator" ? "" : Novel.spriteFile(l.who, l.sprite)

            PxBox {
                id: frame
                width: parent.width
                height: Math.max(portrait.visible ? portrait.height + Theme.u * 8 : 0, col.implicitHeight + Theme.u * 10)
                anchors.bottom: parent.bottom
                color: box.hell ? Theme.hellPanel : Theme.menuSurface
                edgeColor: box.hell ? Theme.hellHi : Theme.menuBorder
                shadow: Config.appearance.shadows
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.ms(160)
                    }
                }

                Image {
                    id: portrait
                    x: Theme.u * 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.u * 4
                    height: Theme.u * 80
                    width: status === Image.Ready ? Math.min(Theme.u * 80, implicitWidth * height / Math.max(1, implicitHeight)) : 0
                    visible: status === Image.Ready && box.l.who !== "narrator"
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    mipmap: false
                    source: box.spriteFile ? "file://" + box.spriteFile : ""
                }

                Column {
                    id: col
                    x: portrait.visible ? portrait.x + portrait.width + Theme.u * 5 : Theme.u * 6
                    y: Theme.u * 5
                    width: parent.width - x - Theme.u * 6
                    spacing: Theme.u * 3
                    PxText {
                        visible: box.l.who !== "narrator"
                        kind: "title"
                        color: box.hell ? Theme.hellEmber : Theme.accent
                        text: Novel.whoName(box.l.who)
                    }
                    ShakyText {
                        width: parent.width
                        text: box.l.text
                        color: box.hell ? Theme.hellText : Theme.text
                        shown: box.shown
                        twitch: Config.y2k.textShake === "off" || Story.calm ? 0 : 0.04
                    }
                    Column {
                        width: parent.width
                        spacing: Theme.u * 2
                        visible: box.typed && box.l.choices.length > 0
                        // every answer looks the same: no colour, mark or icon tells which one
                        // makes things worse — the tone stays in the data, for the story only
                        Repeater {
                            model: box.l.choices
                            PxButton {
                                required property var modelData
                                required property int index
                                width: parent.width
                                hell: box.hell
                                icon: "chat"
                                text: (index + 1) + ". " + modelData.text
                                onClicked: Novel.choose(index)
                            }
                        }
                    }
                    PxText {
                        visible: box.typed && !box.l.choices.length
                        anchors.right: parent.right
                        kind: "tiny"
                        dim: true
                        color: box.hell ? Theme.hellTextDim : Theme.textDim
                        text: I18n.t("▶ клик — дальше", "▶ click to go on")
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: box.go()
                }
            }
            Item {
                id: keys
                focus: true
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        box.go();
                        e.accepted = true;
                    } else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && box.typed) {
                        Novel.choose(e.key - Qt.Key_1);
                        e.accepted = true;
                    }
                }
            }
            RightClickGuard {}
        }
    }

    // ---- the crumpled paper: on the desk, or falling from her ----
    LazyLoader {
        active: Novel.paper !== null && !Novel.noteOpen && !!Angel.screen

        PanelWindow {
            id: deskNote
            screen: Angel.screen
            readonly property bool fromHer: Novel.paper && Novel.paper.from === "angel"
            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: fromHer ? Theme.u * 6 : Math.round((screen ? screen.height : 1080) * 0.18)
                right: fromHer ? Theme.u * 150 : Math.round((screen ? screen.width : 1920) * 0.42)
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: Theme.u * 30
            implicitHeight: Theme.u * 90
            WlrLayershell.layer: fromHer ? WlrLayer.Top : WlrLayer.Bottom
            WlrLayershell.namespace: "angelos-novel-paper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                item: ball
            }

            // falling: from her height down to the floor with a little bounce
            property real drop: fromHer ? 0 : 1
            NumberAnimation on drop {
                running: deskNote.fromHer
                from: 0
                to: 1
                duration: Motion.ms(900)
                easing.type: Easing.OutBounce
            }
            property int tick: 0
            Timer {
                interval: 450
                repeat: true
                running: true
                onTriggered: deskNote.tick++
            }

            PxIcon {
                id: ball
                x: (parent.width - width) / 2
                y: (parent.height - height) * deskNote.drop + (mouse.containsMouse ? -Theme.u : 0)
                rotation: deskNote.tick % 4 === 0 ? -6 : deskNote.tick % 4 === 2 ? 4 : 0
                pixel: Theme.u * 2
                ink: "#5a4a3a"
                palette: ({
                        "p": "#f3ead2",
                        "s": "#d8c9a4",
                        "d": "#b9a77c"
                    })
                bitmap: ["....####......", "..##pppp##....", ".#ppspppps#...", "#pppsppspps##.", "#psppppsppppp#", "#ppsppdpppsps#", ".#ppppddpppp#.", "#pspppppspps#.", "#ppppsppppps#.", ".#pppppsppp#..", "..##ppppp##...", "....#####....."]
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    anchors.margins: -Theme.u * 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sounds.play("open");
                        Novel.noteOpen = true;
                    }
                }
            }
            // a sparkle now and then, so it is noticed
            PxIcon {
                visible: deskNote.tick % 3 === 0 && deskNote.drop >= 1
                x: ball.x + ball.width - width / 2
                y: ball.y - height / 2
                name: "sparkle"
                pixel: Math.max(1, Theme.u)
                fill: "#fff3b0"
            }
            RightClickGuard {}
        }
    }

    // ---- the paper unfolded ----
    LazyLoader {
        active: Novel.noteOpen && Novel.paper !== null && !!Angel.screen

        PanelWindow {
            id: reader
            screen: Angel.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-novel-note"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property var p: Novel.paper || ({
                    "title": "",
                    "text": ""
                })
            // a demon's note: another hand, red ink
            readonly property color ink: Novel.isDemon(p.who) ? "#7a1410" : "#3b2415"
            property real open: 0
            Component.onCompleted: open = 1
            Behavior on open {
                NumberAnimation {
                    duration: Motion.ms(380)
                    easing.type: Easing.OutBack
                }
            }
            function close() {
                Sounds.play("toggle");
                Novel.noteRead();
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha("#000000", 0.45 * reader.open)
                MouseArea {
                    anchors.fill: parent
                    onClicked: reader.close()
                }
            }
            // parchment with creases, written by hand (Theme.fontScript)
            Rectangle {
                id: sheet
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.8, Theme.u * 230)
                height: noteCol.implicitHeight + Theme.u * 28
                color: "#efe1bd"
                rotation: -1.5
                transform: Scale {
                    origin.y: sheet.height / 2
                    yScale: Math.max(0.02, reader.open)
                }
                border.width: Math.max(1, Theme.u / 2)
                border.color: "#c9b27e"
                // creases of the crumple
                Repeater {
                    model: [[0.1, 0.32, 0.8, 0.28], [0.25, 0.7, 0.9, 0.76], [0.55, 0.05, 0.45, 0.95]]
                    Rectangle {
                        required property var modelData
                        x: sheet.width * modelData[0]
                        y: sheet.height * modelData[1]
                        width: Math.hypot((modelData[2] - modelData[0]) * sheet.width, (modelData[3] - modelData[1]) * sheet.height)
                        height: Math.max(1, Theme.u / 2)
                        transformOrigin: Item.TopLeft
                        rotation: Math.atan2((modelData[3] - modelData[1]) * sheet.height, (modelData[2] - modelData[0]) * sheet.width) * 180 / Math.PI
                        color: Qt.alpha("#8a6a3a", 0.18)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                }
                Column {
                    id: noteCol
                    x: Theme.u * 14
                    y: Theme.u * 12
                    width: parent.width - Theme.u * 28
                    spacing: Theme.u * 4
                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: reader.p.title || ""
                        color: reader.ink
                        font.family: Theme.fontScript
                        font.pixelSize: Theme.scriptPx(Theme.sizeTitle)
                        font.bold: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                    Text {
                        width: parent.width
                        text: reader.p.text || ""
                        color: reader.ink
                        font.family: Theme.fontScript
                        font.pixelSize: Math.round(Theme.scriptPx(Theme.sizeTitle) * 0.95)
                        wrapMode: Text.Wrap
                        lineHeight: 1.1
                        textFormat: Text.PlainText
                    }
                    Item {
                        width: parent.width
                        height: fold.height
                        PxButton {
                            id: fold
                            anchors.right: parent.right
                            icon: "check"
                            text: I18n.t("Сложить", "Fold it")
                            onClicked: reader.close()
                        }
                    }
                }
            }
            Item {
                focus: true
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape || e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        reader.close();
                        e.accepted = true;
                    }
                }
            }
            RightClickGuard {}
        }
    }
}
