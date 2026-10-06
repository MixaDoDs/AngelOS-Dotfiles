import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// NGO-style stats ("stats.exe"). The host draws the frame and handles dragging.
// macOS look (Skin.macWidgets, the Theme API): Activity-style rings, one inside the other, and the
// three numbers beside them in their rings' colours.
Item {
    id: root
    property var plugin
    property string screenName
    property var widget

    readonly property bool mac: Skin.macWidgets           // the Theme API: Settings → Widgets → style
    implicitWidth: mac ? macRow.implicitWidth : col.implicitWidth
    implicitHeight: mac ? macRow.implicitHeight : col.implicitHeight

    // ---- macOS look ----
    // Stress red like Move, the other two in the theme's own distinct accents
    readonly property var macRings: {
        const red = DesktopWidgets.macInk(Theme.danger);
        const t = DesktopWidgets.macTints(4).filter(c => !Qt.colorEqual(c, red));
        return [
            {
                "label": I18n.t("Стресс", "Stress"),
                "v": Stats.stress,
                "c": red
            },
            {
                "label": I18n.t("Тьма", "Darkness"),
                "v": Stats.darkness,
                "c": t[1] || Theme.accent2
            },
            {
                "label": I18n.t("Любовь", "Love"),
                "v": Stats.love,
                "c": t[0] || Theme.accent
            }
        ];
    }
    Row {
        id: macRow
        visible: root.mac
        spacing: DesktopWidgets.mpx(18)
        Item {
            id: rings
            readonly property int line: DesktopWidgets.mpx(13)
            readonly property int gap: DesktopWidgets.mpx(2)
            width: DesktopWidgets.mpx(118)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: root.macRings
                MacRing {
                    required property var modelData
                    required property int index
                    anchors.centerIn: parent
                    width: rings.width - index * (rings.line + rings.gap) * 2
                    height: width
                    lineWidth: rings.line
                    value: modelData.v
                    color: modelData.c
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: DesktopWidgets.mpx(6)
            Repeater {
                model: root.macRings
                Column {
                    required property var modelData
                    MacWidgetText {
                        text: modelData.label
                        size: 13
                        weight: Font.DemiBold
                        role: "secondary"
                    }
                    MacWidgetText {
                        text: Math.round(modelData.v * 100) + "%"
                        size: 22
                        weight: Font.DemiBold
                        color: modelData.c
                    }
                }
            }
        }
    }

    Column {
        id: col
        visible: !root.mac
        spacing: Theme.u * 4
        Repeater {
            // hell (manifest "realms"): the same stats as sins, skulls instead of hearts
            model: [
                {
                    "label": I18n.t("Стресс", "Stress"),
                    "hell": I18n.t("Гнев", "Wrath"),
                    "v": Stats.stress,
                    "c": Theme.danger,
                    "hc": Theme.hellBlood
                },
                {
                    "label": I18n.t("Тьма", "Darkness"),
                    "hell": I18n.t("Бездна", "Abyss"),
                    "v": Stats.darkness,
                    "c": Theme.accent4,
                    "hc": Theme.hellEmber
                },
                {
                    "label": I18n.t("Любовь", "Love"),
                    "hell": I18n.t("Одержимость", "Obsession"),
                    "v": Stats.love,
                    "c": Theme.accent,
                    "hc": Theme.hellFlame
                }
            ]
            Row {
                required property var modelData
                spacing: Theme.u * 4
                PxText {
                    width: Theme.u * 30
                    text: Theme.hell ? modelData.hell : modelData.label
                    font.family: Theme.hell && Theme.latin(text) ? Theme.fontHell : Theme.fontBody
                    font.pixelSize: Theme.hell && Theme.latin(text) ? Theme.hellPx(Theme.fs) : Theme.sizeBody
                    color: Theme.hell ? Theme.hellText : Theme.text
                }
                PxHearts {
                    count: 8
                    value: modelData.v
                    icon: Theme.hell ? "skull" : "heart"
                    fill: Theme.hell ? modelData.hc : modelData.c
                }
            }
        }
    }
}
