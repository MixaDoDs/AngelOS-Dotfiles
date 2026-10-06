pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/MacIcons.js" as MacIcons

// "Achievement earned": a card slides down at the top of the main screen (under the bar),
// stays a few seconds and goes; the next one in the line follows (services/Achievements).
// Pixel: a raised box with a big pixel icon; Golden Gate: a glass banner (SkinCard). Hell
// (while the demon rules, or an achievement marked "hell"): a charred card with a burning
// pentagram, blackletter and embers. A thing the achievement gives (story/items.json) lies in a
// slot of the card with «Open» — the diary key opens the Angel's diary. A new page of the diary
// comes as a card too. A click opens Settings → Achievements (a diary card: the diary); a
// hovered card stays. Not on screens the stream shows (StreamMode).
Scope {
    id: root

    readonly property var card: Achievements.current
    readonly property bool hell: !!card && (!!card.hell || Theme.hell)
    readonly property bool diary: !!card && card.kind === "diary"
    readonly property bool hasThing: !!card && !!card.thing && !!card.texture
    readonly property bool mac: Skin.mac && !hell
    // where: the main screen, or the first one the stream does not show
    readonly property var screen: {
        const all = [Shell.primaryScreen].concat(Quickshell.screens.filter(s => s !== Shell.primaryScreen));
        return all.find(s => s && StreamMode.effectsOn(s.name)) || null;
    }
    property real shownT: 0                  // 0 hidden … 1 in place
    readonly property int stay: hasThing ? 10000 : card && card.reward ? 7000 : 5200
    readonly property bool still: Motion.level === "off"

    onCardChanged: {
        if (!card)
            return;
        shownT = 0;
        if (!screen) {
            // nowhere to show it (all screens on stream): it counts, the line goes on
            gone.restart();
            return;
        }
        slideIn.restart();
        hold.interval = stay;
        hold.restart();
    }
    NumberAnimation {
        id: slideIn
        target: root
        property: "shownT"
        to: 1
        duration: root.still ? 0 : root.hell ? 520 : 320
        easing.type: root.hell ? Easing.OutQuart : Easing.OutBack
    }
    NumberAnimation {
        id: slideOut
        target: root
        property: "shownT"
        to: 0
        duration: root.still ? 0 : 240
        easing.type: Easing.InQuad
        onFinished: root.close()
    }
    Timer {
        id: hold
        onTriggered: slideOut.restart()
    }
    Timer {
        id: gone
        interval: 400
        onTriggered: root.close()
    }
    function close() {
        hold.stop();
        if (card)
            Achievements.shown();
    }
    function dismiss(open) {
        if (open) {
            if (diary)
                Diary.open(card.page);
            else
                Shell.openSettings("achievements");
        }
        hold.stop();
        slideOut.restart();
    }
    function useThing() {
        const c = card;
        if (!c)
            return;
        if (c.kind === "diary")
            Diary.open(c.page);
        else
            Heaven.use(c.thing);
        hold.stop();
        slideOut.restart();
    }
    function header() {
        if (!card)
            return "";
        if (diary)
            return hell ? I18n.t("Кто-то дописал дневник", "Someone wrote in the diary") : I18n.t("Новая запись в дневнике", "A new page in the diary");
        const what = hell ? (card.secret ? I18n.t("Тайный грех", "A secret sin") : I18n.t("Грех засчитан", "A sin counted")) : card.secret ? I18n.t("Тайное достижение", "Secret achievement") : I18n.t("Достижение получено", "Achievement earned");
        return what + " · " + (card.plugin ? card.plugin : Achievements.tierName(card.tier));
    }

    LazyLoader {
        active: !!root.card && !!root.screen

        PanelWindow {
            id: win
            screen: root.screen
            anchors.top: true
            margins.top: root.mac ? GoldenGate.px(8) : Theme.u * 4
            implicitWidth: Math.max(body.implicitWidth, Skin.px(300)) + pad * 2
            implicitHeight: body.implicitHeight + pad * 2 + (root.hell ? Theme.u * 6 : 0)
            readonly property int pad: root.mac ? GoldenGate.px(14) : Theme.u * 3
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-achievement"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // the card: hover holds it, a click opens the page (or the diary)
            MouseArea {
                id: cardMouse
                anchors.fill: frame
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => root.dismiss(m.button === Qt.LeftButton)
                onContainsMouseChanged: {
                    if (containsMouse)
                        hold.stop();
                    else if (root.shownT > 0.99)
                        hold.restart();
                }
            }

            Item {
                id: frame
                x: win.pad
                y: win.pad - (1 - root.shownT) * (height + win.pad * 2)
                opacity: Math.min(1, root.shownT * 1.6)
                width: win.width - win.pad * 2
                height: body.implicitHeight

                // ---- pixel and Golden Gate ----
                SkinCard {
                    visible: !root.hell
                    anchors.fill: parent
                    padding: 0
                }

                // ---- hell: charred obsidian, a blood rim, a gold hairline, fire underneath ----
                Item {
                    visible: root.hell
                    anchors.fill: parent
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.hellBody
                        border.width: Theme.u
                        border.color: Theme.hellBlood
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.u * 2
                        color: "transparent"
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: Qt.alpha(Theme.hellGold, 0.7)
                    }
                    // the fire at the bottom, breathing
                    Rectangle {
                        id: fire
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.u
                        height: parent.height * 0.55
                        property real heat: 0.6
                        opacity: heat
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }
                            GradientStop {
                                position: 0.7
                                color: Qt.alpha(Theme.hellBlood, 0.35)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Theme.hellGold, 0.35)
                            }
                        }
                        SequentialAnimation on heat {
                            running: root.hell && !root.still && frame.visible
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 1
                                duration: 380
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                to: 0.45
                                duration: 520
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                to: 0.8
                                duration: 300
                            }
                            NumberAnimation {
                                to: 0.55
                                duration: 640
                            }
                        }
                    }
                    // hell's own pixel flames along the bottom edge
                    HellFlames {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.u
                        height: Theme.u * 7
                        rows: 7
                        live: root.hell && !root.still && frame.visible
                        opacity: 0.85
                    }
                    // embers: square sparks rising out of the fire
                    Repeater {
                        model: root.hell && !root.still ? 9 : 0
                        Rectangle {
                            id: ember
                            required property int index
                            width: Theme.u * (1 + index % 2)
                            height: width
                            color: index % 3 === 0 ? Theme.hellGold : Theme.hellBlood
                            x: frame.width * ((index * 0.137 + 0.06) % 1)
                            property real t: 0
                            y: frame.height - t * frame.height * 0.9
                            opacity: 1 - t
                            NumberAnimation on t {
                                from: 0
                                to: 1
                                duration: 1600 + ember.index * 230
                                loops: Animation.Infinite
                            }
                        }
                    }
                    // the corners: small pentagrams
                    Repeater {
                        model: 4
                        PxIcon {
                            required property int index
                            name: "pentagram"
                            pixel: Math.max(1, Math.round(Theme.u / 2))
                            fill: Theme.hellGold
                            ink: Theme.hellBlood
                            opacity: 0.8
                            x: index % 2 ? frame.width - width - Theme.u * 4 : Theme.u * 4
                            y: index < 2 ? Theme.u * 4 : frame.height - height - Theme.u * 4
                        }
                    }
                }

                Item {
                    id: body
                    // the controls and words inside take the Mac look in Golden Gate (SkinCard is only the backing)
                    readonly property string settingsSkin: root.mac ? "goldengate" : Theme.settingsSkinFor(frame)
                    readonly property int pad: root.mac ? GoldenGate.px(14) : root.hell ? Theme.u * 7 : Theme.u * 4
                    readonly property int spacing: root.mac ? GoldenGate.px(10) : Theme.u * 3
                    width: parent.width
                    height: parent.height
                    implicitHeight: content.implicitHeight + pad * 2
                    // the card's own width: from the words, inside bounds
                    implicitWidth: plate.width + texts.width + (root.mac ? GoldenGate.px(12) : Theme.u * 4) + pad * 2

                    Column {
                        id: content
                        x: body.pad
                        y: body.pad
                        width: parent.width - body.pad * 2
                        spacing: body.spacing

                        Row {
                            spacing: root.mac ? GoldenGate.px(12) : Theme.u * 4

                            // the icon on a plate: the accent, or hell's burning seal
                            Item {
                                id: plate
                                width: root.mac ? GoldenGate.px(44) : root.hell ? Theme.u * 24 : Theme.u * 18
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    visible: !root.hell
                                    anchors.fill: parent
                                    radius: root.mac ? width / 2 : 0
                                    color: root.mac ? Skin.accent : Theme.mix(Theme.face, Theme.accent, 0.35)
                                    border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
                                    border.color: Theme.edge
                                }
                                Rectangle {
                                    visible: root.hell
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Theme.mix(Theme.hellBody, Theme.hellBlood, 0.55)
                                }
                                Pentagram {
                                    visible: root.hell
                                    anchors.fill: parent
                                    color: Theme.hellGold
                                    glowColor: Theme.hellBlood
                                    spin: true
                                    animate: !root.still
                                }
                                PxIcon {
                                    visible: !root.mac
                                    anchors.centerIn: parent
                                    name: root.card ? root.card.icon : "star"
                                    pixel: Math.max(1, Theme.u)
                                    fill: root.hell ? Theme.hellGold : Theme.accent
                                    ink: root.hell ? Theme.hellBody : (Theme.dark ? Theme.text : Theme.edge)
                                }
                                MacIcon {
                                    visible: root.mac
                                    anchors.centerIn: parent
                                    name: root.card ? MacIcons.fromPixel(root.card.icon) || "star" : "star"
                                    color: "#ffffff"
                                    size: GoldenGate.px(22)
                                }
                            }
                            Column {
                                id: texts
                                width: Math.max(Skin.px(220), Math.min(Skin.px(380), Math.max(title.implicitWidth, desc.implicitWidth, reward.implicitWidth)))
                                spacing: root.mac ? GoldenGate.px(2) : Theme.u
                                anchors.verticalCenter: parent.verticalCenter
                                PxText {
                                    width: parent.width
                                    kind: "tiny"
                                    color: root.hell ? Theme.hellGold : Theme.textDim
                                    font.letterSpacing: root.hell ? 1.5 : 0
                                    elide: Text.ElideRight
                                    text: root.hell ? root.header().toUpperCase() : root.header()
                                }
                                PxText {
                                    id: title
                                    width: parent.width
                                    kind: "title"
                                    font.bold: !root.hell
                                    font.family: root.hell ? Theme.fontHell : mac ? Theme.macFont : Theme.fontTitle
                                    font.pixelSize: root.hell ? Math.round(basePx * 1.35) : basePx
                                    color: root.hell ? Theme.hellText : Theme.text
                                    wrapMode: Text.Wrap
                                    text: root.card ? root.card.name : ""
                                }
                                PxText {
                                    id: desc
                                    visible: text !== ""
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    color: root.hell ? Theme.hellTextDim : Theme.text
                                    font.family: root.hell ? Theme.fontHellText : mac ? Theme.macFont : Theme.fontBody
                                    text: root.card ? root.card.desc : ""
                                }
                                PxText {
                                    id: reward
                                    visible: text !== "" && !root.hasThing
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    color: root.hell ? Theme.hellGold : root.mac ? Skin.accent : Theme.text
                                    font.bold: true
                                    text: root.card && root.card.reward ? (root.hell ? I18n.t("✠ Взято из рая: ", "✠ Taken from heaven: ") : I18n.t("✧ Открыто в раю: ", "✧ Opened in heaven: ")) + root.card.reward : ""
                                }
                            }
                        }

                        // ---- the thing in its slot ----
                        Item {
                            visible: root.hasThing
                            width: parent.width
                            height: visible ? slotRow.height : 0
                            Row {
                                id: slotRow
                                width: parent.width
                                spacing: root.mac ? GoldenGate.px(12) : Theme.u * 4
                                // the slot: a sunken square, the thing in it bobbing
                                Rectangle {
                                    id: slot
                                    width: root.mac ? GoldenGate.px(64) : Theme.u * 26
                                    height: width
                                    radius: root.mac ? GoldenGate.px(12) : 0
                                    color: root.hell ? Qt.alpha(Theme.hellBlood, 0.25) : root.mac ? Qt.rgba(0, 0, 0, GoldenGate.dark ? 0.25 : 0.06) : Theme.sunken
                                    border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
                                    border.color: root.hell ? Theme.hellGold : Theme.edge
                                    // a glint across the slot
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.8
                                        height: width
                                        radius: width / 2
                                        color: root.hell ? Theme.hellGold : Theme.accent
                                        opacity: 0.12 + bob.t * 0.1
                                    }
                                    PxIcon {
                                        id: thingPic
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: (parent.height - height) / 2 - bob.t * Theme.u * 1.5
                                        readonly property var tex: root.card ? root.card.texture : null
                                        bitmap: tex ? tex.rows : null
                                        palette: tex ? tex.palette : ({})
                                        pixel: {
                                            const rows = tex && tex.rows ? tex.rows : [];
                                            const n = Math.max(rows.length, rows.reduce((m, r) => Math.max(m, r.length), 0), 1);
                                            return Math.max(1, Math.round(slot.width * 0.82 / n));
                                        }
                                    }
                                    QtObject {
                                        id: bob
                                        property real t: 0
                                        property SequentialAnimation anim: SequentialAnimation {
                                            running: root.hasThing && !root.still
                                            loops: Animation.Infinite
                                            NumberAnimation {
                                                target: bob
                                                property: "t"
                                                to: 1
                                                duration: 900
                                                easing.type: Easing.InOutSine
                                            }
                                            NumberAnimation {
                                                target: bob
                                                property: "t"
                                                to: 0
                                                duration: 900
                                                easing.type: Easing.InOutSine
                                            }
                                        }
                                    }
                                }
                                Column {
                                    width: slotRow.width - slot.width - slotRow.spacing
                                    spacing: Theme.u * 2
                                    PxText {
                                        width: parent.width
                                        font.bold: true
                                        wrapMode: Text.Wrap
                                        color: root.hell ? Theme.hellGold : Theme.text
                                        text: root.diary ? Diary.title() : root.card && root.card.thing ? I18n.t("В карточке лежит: ", "Left in the card: ") + Heaven.label(root.card.thing) : ""
                                    }
                                    PxText {
                                        visible: text !== ""
                                        width: parent.width
                                        kind: "tiny"
                                        color: root.hell ? Theme.hellTextDim : Theme.textDim
                                        wrapMode: Text.Wrap
                                        text: root.card ? root.card.thingDesc || "" : ""
                                    }
                                    PxButton {
                                        compact: true
                                        accent: !root.hell
                                        hell: root.hell
                                        icon: root.diary || (root.card && Heaven.thing(root.card.thing) && Heaven.thing(root.card.thing).opens === "diary") ? "document" : "arrowRight"
                                        text: root.diary ? I18n.t("Читать", "Read") : I18n.t("Открыть", "Open")
                                        onClicked: root.useThing()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            RightClickGuard {}
        }
    }
}
