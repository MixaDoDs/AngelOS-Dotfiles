pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Снимки и запись", "Screenshots and recording")
    subtitle: I18n.t("Снимок области — Mod+Shift+S, запись области — Mod+Shift+R (ещё раз — стоп).", "A region screenshot is Mod+Shift+S, recording a region is Mod+Shift+R (again to stop).")

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
        // only pictures that were drawn (no python-cairo: none, and no broken images)
        onExited: code => {
            if (code === 0)
                page.stamp++;
        }
    }
    Connections {
        target: Config.capture
        function onThemeColorsChanged() {
            page.renderPreviews();
        }
    }

    // a folder from the desktop's file chooser (scripts/pick-file.py --dir) into a capture key
    property string pickKey: ""
    function pickDir(key, title) {
        pickKey = key;
        dirPicker.command = ["python3", Quickshell.shellDir + "/scripts/pick-file.py", "--dir", title];
        dirPicker.running = true;
    }
    Process {
        id: dirPicker
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                if (d && page.pickKey)
                    Config.capture[page.pickKey] = d;
            }
        }
    }
    component DirRow: SettingRow {
        id: dirRow
        property string key: ""
        property string fallback: ""
        property string pickTitle: ""
        Row {
            spacing: Theme.u * 3
            PxText {
                width: Math.min(implicitWidth, Theme.u * 110)
                anchors.verticalCenter: parent.verticalCenter
                text: Config.capture[dirRow.key] || dirRow.fallback
                elide: Text.ElideMiddle
                dim: !Config.capture[dirRow.key]
            }
            PxButton {
                compact: true
                icon: "folder"
                text: I18n.t("Выбрать…", "Choose…")
                onClicked: page.pickDir(dirRow.key, dirRow.pickTitle)
            }
            PxButton {
                compact: true
                visible: !!Config.capture[dirRow.key]
                icon: "refresh"
                onClicked: Config.capture[dirRow.key] = ""
            }
        }
    }

    PxGroup {
        name: "shots"
        title: I18n.t("Снимки", "Screenshots")
        icon: "camera"
        width: parent.width
        DirRow {
            label: I18n.t("Папка для снимков", "Screenshots folder")
            key: "shotDir"
            fallback: "~/Pictures/Screenshots"
            pickTitle: I18n.t("Куда сохранять снимки", "Where screenshots go")
        }
        SettingRow {
            label: I18n.t("Копировать в буфер", "Copy to the clipboard")
            hint: I18n.t("снимок сразу можно вставить в чат", "paste the shot into a chat right away")
            PxToggle {
                checked: Config.capture.shotCopy
                onToggled: v => Config.capture.shotCopy = v
            }
        }
        SettingRow {
            label: I18n.t("Открывать после снимка", "Open after the shot")
            hint: I18n.t("в просмотрщике картинок", "in the image viewer")
            PxToggle {
                checked: Config.capture.shotOpen
                onToggled: v => Config.capture.shotOpen = v
            }
        }
    }
    PxGroup {
        name: "shots-more"
        title: I18n.t("Формат снимка", "Screenshot format")
        icon: "image"
        width: parent.width
        SettingRow {
            label: I18n.t("Формат", "Format")
            hint: I18n.t("PNG — без потерь, JPG — меньше весит", "PNG is lossless, JPG is smaller")
            PxSegmented {
                model: [
                    {
                        "label": "PNG",
                        "value": "png"
                    },
                    {
                        "label": "JPG",
                        "value": "jpg"
                    }
                ]
                currentValue: Config.capture.shotFormat
                onActivated: v => Config.capture.shotFormat = v
            }
        }
        SettingRow {
            label: I18n.t("Курсор на снимке", "The pointer in the shot")
            PxToggle {
                checked: Config.capture.shotCursor
                onToggled: v => Config.capture.shotCursor = v
            }
        }
    }
    PxGroup {
        name: "recording"
        title: I18n.t("Запись экрана", "Screen recording")
        icon: "play"
        width: parent.width
        DirRow {
            label: I18n.t("Папка для записей", "Recordings folder")
            key: "recordDir"
            fallback: "~/Videos"
            pickTitle: I18n.t("Куда сохранять записи", "Where recordings go")
        }
        SettingRow {
            label: I18n.t("Звук в записи", "Sound in the recording")
            hint: I18n.t("«Система» — то, что ты слышишь", "“System” is what you hear")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Без звука", "None"),
                        "value": "none"
                    },
                    {
                        "label": I18n.t("Система", "System"),
                        "value": "system"
                    },
                    {
                        "label": I18n.t("Микрофон", "Microphone"),
                        "value": "mic"
                    }
                ]
                currentValue: Config.capture.recordAudio === "both" ? "system" : Config.capture.recordAudio
                onActivated: v => Config.capture.recordAudio = v
            }
        }
        SettingRow {
            label: I18n.t("Кадров в секунду", "Frames per second")
            PxSegmented {
                model: [30, 60, 120].map(n => ({
                            "label": String(n),
                            "value": n
                        }))
                currentValue: Config.capture.recordFps
                onActivated: v => Config.capture.recordFps = v
            }
        }
    }
    PxGroup {
        name: "recording-more"
        title: I18n.t("Кодек записи", "Recording codec")
        icon: "chip"
        width: parent.width
        SettingRow {
            label: I18n.t("Кодек", "Codec")
            hint: I18n.t("«Авто»: NVENC на NVIDIA, иначе VA-API, иначе x264 на процессоре", "“Auto”: NVENC on NVIDIA, else VA-API, else x264 on the CPU")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": "NVENC",
                        "value": "nvenc"
                    },
                    {
                        "label": "VA-API",
                        "value": "vaapi"
                    },
                    {
                        "label": "x264",
                        "value": "x264"
                    }
                ]
                currentValue: Config.capture.recordCodec
                onActivated: v => Config.capture.recordCodec = v
            }
        }
    }

    PxGroup {
        name: "skin"
        title: I18n.t("Вид рамки", "Frame look")
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
