pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Home (2026-10-07 rebuild, like Windows 11's): you and how the system is doing on one strip —
// the avatar, the name, the release, Wi-Fi, Bluetooth, sound and updates, each opening its
// page — then the pages you open most (SettingsView.frequent, the visits counted per page),
// topped up with the usual ones while there are few. Typing anywhere searches every setting.
PxPage {
    id: page

    heading: I18n.t("Главная", "Home")
    subtitle: I18n.t("Чтобы найти любую настройку, просто начни печатать.", "To find any setting, just start typing.")

    function go(id) {
        if (page.nav) {
            page.nav.settingsPage = id;
            page.nav.settingsSub = "";
        }
    }

    // ---- the status chips ----
    readonly property var chips: [
        {
            "icon": Wifi.enabled ? "wifi" : "wifiOff",
            "label": Wifi.connected ? (Wifi.connected.name || "Wi-Fi") : Wifi.online ? I18n.t("Кабель", "Cable") : Wifi.enabled ? I18n.t("Нет сети", "Offline") : I18n.t("Wi-Fi выключен", "Wi-Fi off"),
            "page": "network",
            "warn": !Wifi.online
        },
        {
            "icon": Bt.enabled ? "bluetooth" : "bluetoothOff",
            "label": !Bt.available ? I18n.t("Bluetooth нет", "No Bluetooth") : !Bt.enabled ? I18n.t("Bluetooth выключен", "Bluetooth off") : Bt.connectedDevices.length ? Bt.connectedDevices.map(d => d.name || d.deviceName).join(", ") : I18n.t("Bluetooth включён", "Bluetooth on"),
            "page": "bluetooth",
            "warn": false
        },
        {
            "icon": Audio.muted ? "speakerMute" : "speaker",
            "label": !Audio.ready ? I18n.t("Звука нет", "No sound") : Audio.muted ? I18n.t("Без звука", "Muted") : Math.round(Audio.volume * 100) + " %",
            "page": "sound",
            "warn": !Audio.ready
        },
        {
            "icon": "download",
            "label": Updates.available ? I18n.t("Есть обновление ♡", "An update is here ♡") : I18n.t("Обновлено", "Up to date"),
            "page": "updates",
            "warn": Updates.available
        }
    ].concat(Config.wellbeing.track ? [
            {
                "icon": "clock",
                "label": I18n.t("Сегодня ", "Today ") + Wellbeing.fmt(Wellbeing.todaySeconds),
                "page": "wellbeing",
                "warn": Config.wellbeing.dailyLimit > 0 && Wellbeing.todaySeconds >= Config.wellbeing.dailyLimit * 60
            }
        ] : [])

    // ---- the tiles: what you open most, then the usual places ----
    readonly property var usual: ["wallpaper", "theme", "sound", "network", "bluetooth", "display", "keyboard", "taskbar"]
    readonly property var tiles: {
        const v = page.view;
        if (!v || !v.frequent)
            return [];
        const out = v.frequent(8).filter(p => !!p && p.id !== "main");
        for (const id of usual) {
            if (out.length >= 8)
                break;
            const p = v.pageEntry(id);
            if (p && !out.some(x => x.id === id))
                out.push(p);
        }
        return out.slice(0, 8);
    }

    PxGroup {
        name: "profile"
        width: parent.width
        Item {
            width: parent.width
            height: Math.max(face.height, who.implicitHeight) + Theme.u * 4
            PxBox {
                id: face
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u * 30
                height: width
                color: Theme.accent
                Image {
                    id: avatarPic
                    anchors.fill: parent
                    anchors.margins: face.inset
                    source: StartPrefs.avatarUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Config.bar.avatarPixel ? Qt.size(20, 20) : Qt.size(width * 2, height * 2)
                    smooth: !Config.bar.avatarPixel
                    visible: status === Image.Ready
                }
                PxIcon {
                    visible: avatarPic.status !== Image.Ready
                    anchors.centerIn: parent
                    name: "heart"
                    fill: "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.go(SettingsTree.accountPage)
                }
            }
            Column {
                id: who
                anchors.left: face.right
                anchors.leftMargin: Theme.u * 5
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.u
                PxText {
                    width: parent.width
                    text: StartPrefs.userName
                    kind: "title"
                    elide: Text.ElideRight
                }
                PxText {
                    width: parent.width
                    text: Updates.release ? Wallpapers.releaseLabel(Updates.release) : "angelOS"
                    dim: true
                    elide: Text.ElideRight
                }
            }
        }
        Flow {
            id: chipFlow
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: page.chips
                Item {
                    id: chip
                    required property var modelData
                    width: Math.min(chipFlow.width, chipRow.implicitWidth + Theme.u * 8)
                    height: chipRow.implicitHeight + Theme.u * 4
                    PxBox {
                        anchors.fill: parent
                        color: chipMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.18) : chip.modelData.warn ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
                        sunken: chipMouse.pressed
                    }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.u * 2
                        PxIcon {
                            name: chip.modelData.icon
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PxText {
                            text: chip.modelData.label
                            width: Math.min(implicitWidth, chipFlow.width - Theme.u * 20)
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.go(chip.modelData.page)
                    }
                }
            }
        }
    }

    PxGroup {
        name: "tiles"
        width: parent.width
        title: I18n.t("Часто открываешь", "You open often")
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
                            name: tile.modelData.icon || "gear"
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
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (page.view && page.view.clickedNew && page.view.clickedNew(mouse, tile.modelData.id))
                                return;
                            page.go(tile.modelData.id);
                        }
                    }
                }
            }
        }
    }
}
