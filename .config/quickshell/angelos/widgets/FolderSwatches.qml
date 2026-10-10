import QtQuick
import qs.config
import qs.services

// Pixora's folder colour (Config.appearance.folders → scripts/folder-tint.py through the theme
// render): as Pixora draws them, the accent, or one of the fixed colours — a folder of each.
Flow {
    id: root
    spacing: Theme.u * 3
    property int pixel: Math.max(1, Math.round(Theme.u * 0.75))
    signal picked(string value)

    readonly property var choices: [
        {
            "value": "theme",
            "label": I18n.t("как тема", "theme"),
            "color": Angel.demon ? Theme.hellAccent : Theme.mix(Theme.accent, "#ffffff", 0.35)
        },
        {
            "value": "pixora",
            "label": "Pixora",
            "color": "#e3c896"
        },
        {
            "value": "pink",
            "label": I18n.t("розовые", "pink"),
            "color": ThemeExport.folderColors.pink[0]
        },
        {
            "value": "lavender",
            "label": I18n.t("лавандовые", "lavender"),
            "color": ThemeExport.folderColors.lavender[0]
        },
        {
            "value": "mint",
            "label": I18n.t("мятные", "mint"),
            "color": ThemeExport.folderColors.mint[0]
        },
        {
            "value": "sky",
            "label": I18n.t("голубые", "sky"),
            "color": ThemeExport.folderColors.sky[0]
        },
        {
            "value": "gold",
            "label": I18n.t("золотые", "gold"),
            "color": ThemeExport.folderColors.gold[0]
        }
    ]

    Repeater {
        model: root.choices
        Item {
            id: cell
            required property var modelData
            readonly property bool on: (Config.appearance.folders || "theme") === modelData.value
            width: Math.max(icon.width, label.implicitWidth) + Theme.u * 6
            height: icon.height + label.implicitHeight + Theme.u * 7
            PxBox {
                anchors.fill: parent
                color: cell.on ? Theme.mix(Theme.face, Theme.accent, 0.25) : mouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
                sunken: cell.on
            }
            PxIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.u * 3
                name: "folder"
                iconStyle: "angelos"
                pixel: root.pixel * 3
                fill3: cell.modelData.color
            }
            PxText {
                id: label
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: icon.bottom
                anchors.topMargin: Theme.u * 2
                kind: "tiny"
                font.bold: cell.on
                text: cell.modelData.label
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Config.appearance.folders = cell.modelData.value;
                    root.picked(cell.modelData.value);
                }
            }
        }
    }
}
