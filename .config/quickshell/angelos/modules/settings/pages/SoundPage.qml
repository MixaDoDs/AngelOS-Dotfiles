pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

PxPage {
    heading: I18n.t("Звук", "Sound")
    subtitle: I18n.t("Меняется только то, что ты трогаешь здесь. Маршрутизацию пульта angelOS не касается.", "Only controls you change here are applied. Audio routing is preserved.")

    PxGroup {
        name: "output"
        title: I18n.t("Выход", "Output")
        icon: "speaker"
        width: parent.width
        SettingRow {
            label: I18n.t("Устройство по умолчанию", "Default device")
            PxCombo {
                width: parent.width
                model: Audio.sinks.map(n => ({
                            "label": Audio.nodeName(n),
                            "value": n.id
                        }))
                currentValue: Audio.sink ? Audio.sink.id : -1
                onActivated: v => Audio.setDefaultSink(Audio.sinks.find(n => n.id === v))
            }
        }
        SettingRow {
            label: I18n.t("Громкость", "Volume")
            Row {
                width: parent.width
                spacing: Theme.u * 3
                PxButton {
                    compact: true
                    icon: Audio.muted ? "speakerMute" : "speaker"
                    onClicked: Audio.toggleMute()
                }
                PxSlider {
                    width: parent.width - Theme.u * 20
                    from: 0
                    to: 1.5
                    value: Audio.volume
                    valueScale: 100
                    suffix: "%"
                    onMoved: v => Audio.setVolume(v)
                }
            }
        }
    }

    PxGroup {
        name: "input"
        title: I18n.t("Вход", "Input")
        icon: "mic"
        width: parent.width
        SettingRow {
            label: I18n.t("Микрофон по умолчанию", "Default microphone")
            PxCombo {
                width: parent.width
                model: Audio.sources.map(n => ({
                            "label": Audio.nodeName(n),
                            "value": n.id
                        }))
                currentValue: Audio.source ? Audio.source.id : -1
                onActivated: v => Audio.setDefaultSource(Audio.sources.find(n => n.id === v))
            }
        }
        SettingRow {
            label: I18n.t("Уровень", "Level")
            Row {
                width: parent.width
                spacing: Theme.u * 3
                PxButton {
                    compact: true
                    icon: Audio.micMuted ? "micMute" : "mic"
                    onClicked: Audio.toggleMic()
                }
                PxSlider {
                    width: parent.width - Theme.u * 20
                    from: 0
                    to: 1.5
                    value: Audio.micVolume
                    valueScale: 100
                    suffix: "%"
                    onMoved: v => {
                        if (Audio.source && Audio.source.audio)
                            Audio.source.audio.volume = v;
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Сейчас", "Live level")
            hint: I18n.t("скажи что-нибудь ♡ зелёный — норм, жёлтый — громко, красный — перегруз", "Say something ♡ green is fine, yellow is loud, red clips")
            Row {
                width: parent.width
                spacing: Theme.u * 3
                PxLevelMeter {
                    id: pageMeter
                    width: parent.width - Theme.u * 23
                    anchors.verticalCenter: parent.verticalCenter
                    node: Audio.source
                    opacity: Audio.micMuted ? 0.4 : 1
                }
                PxText {
                    width: Theme.u * 20
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    kind: "tiny"
                    color: pageMeter.clipping ? Theme.danger : Theme.textDim
                    text: Audio.micMuted ? I18n.t("выкл", "muted") : pageMeter.db > -90 ? Math.round(pageMeter.db) + " dB" : "—"
                }
            }
        }
    }

    PxGroup {
        name: "applications"
        title: I18n.t("Приложения", "Applications")
        icon: "music"
        width: parent.width
        PxText {
            visible: Audio.appStreams.length === 0
            text: I18n.t("сейчас ничего не звучит", "No audio is playing")
            dim: true
        }
        Repeater {
            model: Audio.appStreams
            SettingRow {
                id: r
                required property var modelData
                label: Audio.streamName(modelData)
                hint: modelData.properties["media.name"] || ""
                PxSlider {
                    width: parent.width
                    from: 0
                    to: 1.5
                    value: r.modelData.audio ? r.modelData.audio.volume : 0
                    valueScale: 100
                    suffix: "%"
                    onMoved: v => r.modelData.audio.volume = v
                }
            }
        }
    }

    PxGroup {
        name: "osd"
        title: "OSD"

        advanced: true
        icon: "heart"
        width: parent.width
        SettingRow {
            label: I18n.t("Показывать громкость", "Show volume")
            PxToggle {
                checked: Config.osd.enabled
                onToggled: c => Config.osd.enabled = c
            }
        }
        SettingRow {
            label: I18n.t("Показывать смену раскладки", "Show layout changes")
            hint: I18n.t("маленький бейдж RU/EN", "Small RU/EN badge")
            PxToggle {
                checked: Config.osd.layout
                onToggled: c => Config.osd.layout = c
            }
        }
        SettingRow {
            label: I18n.t("Сколько висит", "Display duration")
            PxSlider {
                width: parent.width
                from: 400
                to: 2500
                stepSize: 50
                value: Config.osd.ms
                suffix: I18n.t(" мс", " ms")
                onMoved: v => Config.osd.ms = v
            }
        }
        SettingRow {
            label: I18n.t("Где показывать", "Show on")
            hint: I18n.t("клик по месту на мониторе", "Click a position on the display")
            PxPositionPicker {
                value: Config.osd.position
                onPicked: v => Config.osd.position = v
            }
        }
    }

    PxGroup {
        name: "voice-typing-voxtype"
        title: I18n.t("Голосовой ввод (VoxType)", "Voice typing (VoxType)")

        advanced: true
        icon: "mic"
        width: parent.width
        SettingRow {
            label: I18n.t("Индикатор", "Indicator")
            hint: I18n.t("«angelOS» — окошко " + I18n.exe("voice") + " в стиле райса, «старый» — прежний кружок", "“angelOS” — a " + I18n.exe("voice") + " window in the rice style, “classic” — the old circle")
            PxSegmented {
                model: [
                    {
                        "label": "angelOS",
                        "value": "angelos"
                    },
                    {
                        "label": I18n.t("Старый", "Classic"),
                        "value": "classic"
                    },
                    {
                        "label": I18n.t("Нет", "Off"),
                        "value": "off"
                    }
                ]
                currentValue: Config.voxtype.indicator
                onActivated: v => Config.voxtype.indicator = v
            }
        }
        SettingRow {
            visible: Config.voxtype.indicator === "angelos"
            label: I18n.t("Где показывать", "Position")
            PxPositionPicker {
                value: Config.voxtype.position
                onPicked: v => Config.voxtype.position = v
            }
        }
    }
}
