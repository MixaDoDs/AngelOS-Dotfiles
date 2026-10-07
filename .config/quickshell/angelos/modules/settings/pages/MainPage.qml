pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Main (the flat settings list's first section, 2026-10-07): the things people come to Settings
// for, one click away — big tiles that open their place, and the switches changed most often
// right here. Typing anywhere in Settings searches every setting.
PxPage {
    id: page

    heading: I18n.t("Главная", "Home")
    subtitle: I18n.t("Самое частое — в один клик. Чтобы найти любую настройку, просто начни печатать.", "The everyday things, one click away. To find any setting, just start typing.")

    // a tile: the page it opens, and the group it scrolls to there
    readonly property var tiles: [
        {
            "icon": "image",
            "label": I18n.t("Обои", "Wallpaper"),
            "page": "wallpaper"
        },
        {
            "icon": "palette",
            "label": I18n.t("Тема и цвета", "Theme and colours"),
            "page": "theme"
        },
        {
            "icon": "speaker",
            "label": I18n.t("Звук", "Sound"),
            "page": "sound"
        },
        {
            "icon": "wifi",
            "label": "Wi-Fi",
            "page": "network"
        },
        {
            "icon": "bluetooth",
            "label": "Bluetooth",
            "page": "bluetooth"
        },
        {
            "icon": "keyboard",
            "label": I18n.t("Раскладки", "Layouts"),
            "page": "keyboard"
        },
        {
            "icon": "monitor",
            "label": I18n.t("Мониторы", "Displays"),
            "page": "display"
        },
        {
            "icon": "lock",
            "label": I18n.t("Блокировка", "Lock screen"),
            "page": "lock"
        },
        {
            "icon": "sparkleStar",
            "label": I18n.t("Звёзды и сундуки", "Stars and chests"),
            "page": "stars",
            "game": true
        },
        {
            "icon": "download",
            "label": Updates.available ? I18n.t("Обновление ♡", "Update ♡") : I18n.t("Обновления", "Updates"),
            "page": "updates"
        },
        {
            "icon": "refresh",
            "label": I18n.t("Восстановление", "Recovery"),
            "page": "account"
        },
        {
            "icon": "package",
            "label": I18n.t("Плагины", "Plugins"),
            "page": "plugins"
        }
    ].filter(t => !t.game || Story.enabled)
    function go(id) {
        if (page.nav)
            page.nav.settingsPage = id;
    }

    PxGroup {
        name: "tiles"
        width: parent.width
        title: I18n.t("Что хочешь сделать?", "What would you like to do?")
        icon: "star"
        Grid {
            id: grid
            width: parent.width
            columns: Math.max(2, Math.floor(width / (Theme.u * 70)))
            spacing: Theme.u * 3
            readonly property int cell: Math.floor((width - spacing * (columns - 1)) / columns)
            Repeater {
                model: page.tiles
                Item {
                    id: tile
                    required property var modelData
                    width: grid.cell
                    height: Theme.u * 34
                    PxBox {
                        anchors.fill: parent
                        color: tileMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.18) : Theme.face
                        sunken: tileMouse.pressed
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.u * 2
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: tile.modelData.icon
                            pixel: Math.max(1, Math.round(Theme.u * 1.2))
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: grid.cell - Theme.u * 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: tile.modelData.label
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.go(tile.modelData.page)
                    }
                }
            }
        }
    }

    PxGroup {
        name: "quick"
        width: parent.width
        title: I18n.t("Быстро поменять", "Quick switches")
        icon: "sparkle"
        SettingRow {
            label: I18n.t("Тема", "Theme")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Светлая", "Light"),
                        "value": "light"
                    },
                    {
                        "label": I18n.t("Тёмная", "Dark"),
                        "value": "dark"
                    },
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    }
                ]
                currentValue: Config.appearance.mode
                onActivated: v => Config.appearance.mode = v
            }
        }
        SettingRow {
            label: I18n.t("Громкость", "Volume")
            hint: Audio.ready ? "" : I18n.t("звук не найден", "no sound device")
            PxSlider {
                width: parent.width
                from: 0
                to: 150
                stepSize: 1
                value: Math.round(Audio.volume * 100)
                suffix: " %"
                enabled: Audio.ready
                onMoved: v => Audio.setVolume(v / 100)
            }
        }
        SettingRow {
            label: I18n.t("Анимации", "Animations")
            hint: I18n.t("«Спокойно» — без вспышек и тряски", "“Calm”: no flashes or shaking")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Все", "All"),
                        "value": "full"
                    },
                    {
                        "label": I18n.t("Спокойно", "Calm"),
                        "value": "calm"
                    },
                    {
                        "label": I18n.t("Без", "Off"),
                        "value": "off"
                    }
                ]
                currentValue: Motion.level
                onActivated: v => Motion.set(v)
            }
        }
        SettingRow {
            label: I18n.t("Не беспокоить", "Do not disturb")
            hint: I18n.t("уведомления не всплывают, копятся в истории", "notifications don't pop up, they wait in the history")
            PxToggle {
                checked: Config.notifications.dnd
                onToggled: v => Config.notifications.dnd = v
            }
        }
        SettingRow {
            label: I18n.t("Стрим-режим", "Stream mode")
            hint: StreamMode.active ? I18n.t("сейчас включён: angelOS не лезет в кадр", "on now: angelOS stays out of the picture") : I18n.t("сам включается, когда OBS выходит в эфир", "turns on by itself when OBS goes live")
            PxToggle {
                checked: StreamMode.active
                onToggled: v => StreamMode.set(v ? "on" : "auto")
            }
        }
    }
}
