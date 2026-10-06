pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Скриншоты и запись", "Screenshots and recording")
    subtitle: I18n.t("Как выглядит выделение области (Mod+Shift+S) и рамка записи (Mod+Shift+R).", "How the region selector (Mod+Shift+S) and the recording frame (Mod+Shift+R) look.")

    readonly property var skins: [
        {
            "id": "ropes",
            "label": I18n.t("Верёвочки", "Ropes"),
            "hint": I18n.t("физика верёвок, при записи превращаются в землю из Terraria", "rope physics; turn into Terraria dirt while recording")
        },
        {
            "id": "window",
            "label": I18n.exe("screenshot"),
            "hint": I18n.t("NGO-окошко: розовый заголовок, бегущий пунктир, сердечки по углам; при записи — «● REC " + I18n.exe("recording") + "» с таймером", "An NGO window: pink title bar, marching ants, corner hearts; while recording — “● REC " + I18n.exe("recording") + "” with a timer")
        },
        {
            "id": "stream",
            "label": I18n.t("Стрим Ame", "Ame stream"),
            "hint": I18n.t("цепочка бегущих сердечек, LIVE, «kawaii»-пузырь и сканлайны; при записи — зрители и таймер", "A chain of marching hearts, LIVE badge, a kawaii bubble and scanlines; while recording — viewers and a timer")
        }
    ]
    property int stamp: 0
    function renderPreviews() {
        previews.running = false;
        previews.running = true;
    }
    Component.onCompleted: renderPreviews()
    Process {
        id: previews
        command: ["sh", "-c", 'mkdir -p "$1" && for s in ropes window stream; do python3 "$2" --preview "$s" "$1/capture-$s.png"; done', "sh", Config.cacheDir, Quickshell.shellDir + "/scripts/capture_skins.py"]
        onExited: page.stamp++
    }
    Connections {
        target: Config.capture
        function onThemeColorsChanged() {
            page.renderPreviews();
        }
    }

    PxGroup {
        name: "skin"
        title: I18n.t("Скин", "Skin")
        icon: "image"
        width: parent.width
        Grid {
            width: parent.width
            columns: width > Theme.u * 360 ? 3 : 1
            spacing: Theme.u * 4
            Repeater {
                model: page.skins
                PxBox {
                    id: card
                    required property var modelData
                    readonly property bool current: (Config.capture.skin || "ropes") === modelData.id
                    width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                    height: cardCol.implicitHeight + Theme.u * 8
                    sunken: current
                    color: current ? Theme.mix(Theme.face, Theme.accent, 0.3) : cardMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
                    Column {
                        id: cardCol
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u * 2
                        Image {
                            width: parent.width
                            height: Math.round(width * 9 / 16)
                            // in the grimoire (or a dress): an engraving the right way round, not a negative
                            layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
                            layer.effect: GrimoirePhoto {}
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            cache: false
                            source: page.stamp > 0 ? "file://" + Config.cacheDir + "/capture-" + card.modelData.id + ".png?" + page.stamp : ""
                        }
                        PxText {
                            text: (card.current ? "♡ " : "") + card.modelData.label
                            font.bold: true
                        }
                        PxText {
                            width: parent.width
                            text: card.modelData.hint
                            kind: "tiny"
                            dim: true
                            wrapMode: Text.Wrap
                        }
                    }
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.capture.skin = card.modelData.id
                    }
                }
            }
        }
        // the picked skin in motion
        PxPreview {
            width: Math.min(parent.width, Theme.u * 200)
            scene: "CaptureSkin"
            variant: Config.capture.skin || "ropes"
            caption: (page.skins.find(s => s.id === (Config.capture.skin || "ropes")) || {}).label || ""
            closable: false
            sceneHeight: Theme.u * 62
        }
        SettingRow {
            visible: Config.capture.skin !== "ropes"
            label: I18n.t("Цвета темы", "Theme colours")
            hint: I18n.t("выключено — классическая NGO-палитра (розовый, фиолетовый, голубой)", "Off: the classic NGO palette (pink, purple, cyan)")
            PxToggle {
                checked: Config.capture.themeColors
                onToggled: c => Config.capture.themeColors = c
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Скриншот области", "Region screenshot")
                icon: "image"
                onClicked: {
                    page.nav.settingsOpen = false;
                    Capture.screenshot();
                }
            }
            PxButton {
                text: I18n.t("Запись области", "Region recording")
                icon: "play"
                onClicked: {
                    page.nav.settingsOpen = false;
                    Capture.record();
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Скин читают инструменты ~/.local/bin/niri-screenshot-region и niri-record-overlay из dotfiles. Снимки — в ~/Pictures/Screenshots, записи — в ~/Videos.", "The skin is used by ~/.local/bin/niri-screenshot-region and niri-record-overlay from the dotfiles. Shots go to ~/Pictures/Screenshots, recordings to ~/Videos.")
        }
    }
}
