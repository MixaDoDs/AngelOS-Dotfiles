import QtQuick
import qs.config

// A card to pick the settings view (Config.settingsUi.view): a little drawing of the
// window laid out that way, its name and what it is. In the first-run wizard and in
// Appearance → Settings look, next to the skin cards (SettingsSkinCard).
Item {
    id: root

    property string view: "win11"
    readonly property bool checked: (Config.settingsUi.view || "win11") === view
    signal picked

    readonly property var names: ({
            "win11": [I18n.t("Как в Windows 11", "Like Windows 11"), I18n.t("категории слева, карточки справа", "categories on the left, cards on the right")],
            "sidebar": [I18n.t("Боковая панель", "Sidebar"), I18n.t("разделы слева, как в macOS", "sections on the left, like macOS")],
            "controlpanel": [I18n.t("Панель управления", "Control Panel"), I18n.t("папка значков, как в Win98", "a folder of icons, like Win98")],
            "properties": [I18n.t("Свойства", "Properties"), I18n.t("раздел сверху, страницы — вкладки", "a section on top, pages as tabs")],
            "tiles": [I18n.t("Плитки", "Tiles"), I18n.t("крупный поиск и большие плитки", "a big search, big tiles")]
        })
    // the sections' tints, for the little coloured squares
    readonly property var tints: ["#3a86ff", "#e94f96", "#6b5bd6", "#1fa7bd", "#e8930b", "#13a596", "#1fae55", "#b04cc8", "#ef6c1a", "#2f7de8", "#e8404f", "#0e95d6"]

    implicitWidth: Theme.u * 92
    implicitHeight: pic.height + caption.implicitHeight + hint.implicitHeight + Theme.u * 12

    PxBox {
        anchors.fill: parent
        color: root.checked ? Theme.mix(Theme.face, Theme.accent, 0.25) : mouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
        sunken: root.checked
    }

    // the little window, drawn on a 40 × 25 grid of whole pixels
    Item {
        id: pic
        readonly property int c: Math.max(1, Math.floor((root.width - Theme.u * 8) / 40))
        function g(n) {
            return Math.round(n * c);
        }
        x: Math.round((root.width - width) / 2)
        y: Theme.u * 4
        width: c * 40
        height: c * 25
        clip: true
        Rectangle {
            anchors.fill: parent
            color: Theme.face
            border.width: 1
            border.color: Theme.edge
        }
        Rectangle {
            x: 1
            y: 1
            width: parent.width - 2
            height: pic.g(3)
            color: Theme.menuHeader
        }

        // Windows 11: you, the search and the categories on the left; big crumbs and cards
        Item {
            visible: root.view === "win11"
            anchors.fill: parent
            Rectangle {
                x: pic.g(1)
                y: pic.g(4)
                width: pic.g(3)
                height: pic.g(3)
                color: Theme.accent
            }
            Rectangle {
                x: pic.g(5)
                y: pic.g(5)
                width: pic.g(6)
                height: pic.g(1)
                color: Theme.textDim
            }
            Rectangle {
                x: pic.g(1)
                y: pic.g(8)
                width: pic.g(10)
                height: pic.g(2)
                color: Theme.sunken
            }
            Repeater {
                model: 5
                Item {
                    required property int index
                    Rectangle {
                        x: pic.g(1)
                        y: pic.g(11 + index * 3)
                        width: pic.g(2)
                        height: pic.g(2)
                        color: root.tints[index]
                    }
                    Rectangle {
                        x: pic.g(4)
                        y: pic.g(11.5 + index * 3)
                        width: pic.g(7)
                        height: pic.g(1)
                        color: index === 1 ? Theme.accent : Theme.textDim
                    }
                }
            }
            Rectangle {
                x: pic.g(13)
                y: pic.g(4.5)
                width: pic.g(16)
                height: pic.g(2)
                color: Theme.text
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: pic.g(13)
                    y: pic.g(8 + index * 3.3)
                    width: pic.g(26)
                    height: pic.g(2.8)
                    color: Theme.mix(Theme.face, Theme.faceAlt, 0.6)
                    border.width: 1
                    border.color: Qt.alpha(Theme.lo, 0.6)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: pic.g(1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: pic.g(3)
                        height: pic.g(1.4)
                        color: index % 2 ? Theme.accent : Theme.sunken
                    }
                }
            }
        }

        // sidebar: the sections on the left, the page on the right
        Item {
            visible: root.view === "sidebar"
            anchors.fill: parent
            Rectangle {
                x: pic.g(1)
                y: pic.g(4)
                width: pic.g(11)
                height: pic.g(20)
                color: Theme.sunken
            }
            Rectangle {
                x: pic.g(2)
                y: pic.g(5)
                width: pic.g(9)
                height: pic.g(2)
                color: Theme.face
            }
            Repeater {
                model: 5
                Item {
                    required property int index
                    Rectangle {
                        x: pic.g(2)
                        y: pic.g(8 + index * 3)
                        width: pic.g(2)
                        height: pic.g(2)
                        color: index === 2 ? Theme.accent : root.tints[index]
                    }
                    Rectangle {
                        x: pic.g(5)
                        y: pic.g(8.5 + index * 3)
                        width: pic.g(5)
                        height: pic.c
                        color: Theme.textDim
                    }
                }
            }
            Rectangle {
                x: pic.g(13)
                y: pic.g(4)
                width: pic.g(26)
                height: pic.g(20)
                color: Theme.faceAlt
            }
            Rectangle {
                x: pic.g(15)
                y: pic.g(6)
                width: pic.g(11)
                height: pic.g(2)
                color: Theme.accent
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: pic.g(15)
                    y: pic.g(11 + index * 3)
                    width: pic.g(index % 2 ? 18 : 22)
                    height: pic.c
                    color: Theme.textDim
                }
            }
        }

        // control panel: the address bar, a folder of icons
        Item {
            visible: root.view === "controlpanel"
            anchors.fill: parent
            Rectangle {
                x: pic.g(6)
                y: pic.g(4)
                width: pic.g(22)
                height: pic.g(2)
                color: Theme.sunken
            }
            Rectangle {
                x: pic.g(30)
                y: pic.g(4)
                width: pic.g(9)
                height: pic.g(2)
                color: Theme.sunken
            }
            Rectangle {
                x: pic.g(1)
                y: pic.g(4)
                width: pic.g(4)
                height: pic.g(2)
                color: Theme.faceAlt
            }
            Rectangle {
                x: pic.g(1)
                y: pic.g(7)
                width: pic.g(38)
                height: pic.g(17)
                color: Theme.sunken
            }
            Repeater {
                model: 18
                Item {
                    required property int index
                    readonly property int col: index % 6
                    readonly property int row: Math.floor(index / 6)
                    Rectangle {
                        x: pic.g(3 + col * 6)
                        y: pic.g(9 + row * 5)
                        width: pic.g(3)
                        height: pic.g(3)
                        color: root.tints[index % root.tints.length]
                    }
                    Rectangle {
                        x: pic.g(2.5 + col * 6)
                        y: pic.g(12.5 + row * 5)
                        width: pic.g(4)
                        height: pic.c
                        color: Theme.textDim
                    }
                }
            }
        }

        // properties: a section box, tabs, the card, OK and Revert
        Item {
            visible: root.view === "properties"
            anchors.fill: parent
            Rectangle {
                x: pic.g(1)
                y: pic.g(4)
                width: pic.g(14)
                height: pic.g(2)
                color: Theme.sunken
            }
            Rectangle {
                x: pic.g(30)
                y: pic.g(4)
                width: pic.g(9)
                height: pic.g(2)
                color: Theme.sunken
            }
            Repeater {
                model: [[1, 7], [9, 6], [16, 6], [23, 5]]
                Rectangle {
                    required property var modelData
                    required property int index
                    x: pic.g(modelData[0])
                    y: pic.g(index === 0 ? 7 : 8)
                    width: pic.g(modelData[1])
                    height: pic.g(index === 0 ? 3 : 2)
                    color: index === 0 ? Theme.mix(Theme.face, Theme.text, 0.12) : Theme.faceAlt
                    border.width: 1
                    border.color: Theme.edge
                }
            }
            Rectangle {
                x: pic.g(1)
                y: pic.g(10)
                width: pic.g(38)
                height: pic.g(10)
                color: Theme.mix(Theme.face, Theme.text, 0.12)
                border.width: 1
                border.color: Theme.edge
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: pic.g(3)
                    y: pic.g(12 + index * 3)
                    width: pic.g(index === 1 ? 26 : 32)
                    height: pic.c
                    color: Theme.textDim
                }
            }
            Rectangle {
                x: pic.g(23)
                y: pic.g(21)
                width: pic.g(7)
                height: pic.g(3)
                color: Theme.accent
            }
            Rectangle {
                x: pic.g(31)
                y: pic.g(21)
                width: pic.g(8)
                height: pic.g(3)
                color: Theme.faceAlt
                border.width: 1
                border.color: Theme.edge
            }
        }

        // tiles: a big search field, a row of chips, big tiles
        Item {
            visible: root.view === "tiles"
            anchors.fill: parent
            Rectangle {
                x: pic.g(8)
                y: pic.g(4)
                width: pic.g(24)
                height: pic.g(3)
                color: Theme.sunken
                border.width: 1
                border.color: Theme.accent
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: pic.g(2 + index * 6)
                    y: pic.g(8.5)
                    width: pic.g(5)
                    height: pic.g(1.5)
                    color: Theme.faceAlt
                }
            }
            Repeater {
                model: 9
                Item {
                    required property int index
                    readonly property int col: index % 3
                    readonly property int row: Math.floor(index / 3)
                    Rectangle {
                        x: pic.g(2 + col * 12.5)
                        y: pic.g(11.5 + row * 4.5)
                        width: pic.g(11.5)
                        height: pic.g(3.5)
                        color: Theme.faceAlt
                    }
                    Rectangle {
                        x: pic.g(3 + col * 12.5)
                        y: pic.g(12.25 + row * 4.5)
                        width: pic.g(2)
                        height: pic.g(2)
                        color: root.tints[(index * 2) % root.tints.length]
                    }
                    Rectangle {
                        x: pic.g(6 + col * 12.5)
                        y: pic.g(12.75 + row * 4.5)
                        width: pic.g(5)
                        height: pic.c
                        color: Theme.textDim
                    }
                }
            }
        }
    }
    PxText {
        id: caption
        anchors.top: pic.bottom
        anchors.topMargin: Theme.u * 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width - Theme.u * 4)
        elide: Text.ElideRight
        text: (root.checked ? "♡ " : "") + (root.names[root.view] || [root.view])[0]
        font.bold: true
    }
    PxText {
        id: hint
        anchors.top: caption.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.u * 6
        horizontalAlignment: Text.AlignHCenter
        text: (root.names[root.view] || ["", ""])[1]
        kind: "tiny"
        dim: true
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Config.settingsUi.view = root.view;
            root.picked();
        }
    }
}
