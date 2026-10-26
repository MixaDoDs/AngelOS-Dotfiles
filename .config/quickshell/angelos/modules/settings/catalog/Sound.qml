// The settings once in SoundPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    heading: I18n.t("Звук", "Sound")
    subtitle: I18n.t("Меняется только то, что ты трогаешь здесь. Маршрутизацию пульта angelOS не касается.", "Only controls you change here are applied. Audio routing is preserved.")
    CatGroup {
        name: "output"
        title: I18n.t("Динамики и наушники", "Speakers and headphones")
        icon: "speaker"
        CatChoice {
            label: I18n.t("Устройство по умолчанию", "Default device")
            combo: true
            model: Audio.sinks.map(n => ({
                        "label": Audio.nodeName(n),
                        "value": n.id
                    }))
            currentValue: Audio.sink ? Audio.sink.id : -1
            onActivated: v => Audio.setDefaultSink(Audio.sinks.find(n => n.id === v))
        }
        CatSlider {
            label: I18n.t("Громкость", "Volume")
            from: 0
            to: 1.5
            value: Audio.volume
            valueScale: 100
            suffix: "%"
            onMoved: v => Audio.setVolume(v)
            CatButton {
                lead: true
                compact: true
                icon: Audio.muted ? "speakerMute" : "speaker"
                onClicked: Audio.toggleMute()
            }
        }
    }
    CatGroup {
        name: "input"
        title: I18n.t("Микрофон", "Microphone")
        icon: "mic"
        CatChoice {
            label: I18n.t("Микрофон по умолчанию", "Default microphone")
            combo: true
            model: Audio.sources.map(n => ({
                        "label": Audio.nodeName(n),
                        "value": n.id
                    }))
            currentValue: Audio.source ? Audio.source.id : -1
            onActivated: v => Audio.setDefaultSource(Audio.sources.find(n => n.id === v))
        }
        CatSlider {
            label: I18n.t("Уровень", "Level")
            from: 0
            to: 1.5
            value: Audio.micVolume
            valueScale: 100
            suffix: "%"
            onMoved: v => {
                if (Audio.source && Audio.source.audio)
                    Audio.source.audio.volume = v;
            }
            CatButton {
                lead: true
                compact: true
                icon: Audio.micMuted ? "micMute" : "mic"
                onClicked: Audio.toggleMic()
            }
        }
        CatCustom {
            label: I18n.t("Сейчас", "Live level")
            hint: I18n.t("скажи что-нибудь ♡ зелёный — норм, жёлтый — громко, красный — перегруз", "Say something ♡ green is fine, yellow is loud, red clips")
            CatBox {
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
                        color: pageMeter.clipping ? Theme.danger : Theme.toneFor("textDim", parent)
                        text: Audio.micMuted ? I18n.t("выкл", "muted") : pageMeter.db > -90 ? Math.round(pageMeter.db) + " dB" : "—"
                    }
                }
            }
        }
    }
    CatGroup {
        name: "applications"
        title: I18n.t("Громкость приложений", "App volume")
        icon: "music"
        CatNote {
            present: Audio.appStreams.length === 0
            text: I18n.t("сейчас ничего не звучит", "No audio is playing")
            dim: true
        }
        CatRepeat {
            model: Audio.appStreams
            delegate: Component {
                CatCustom {
                    id: r
                    required property var modelData
                    label: Audio.streamName(modelData)
                    hint: modelData.properties["media.name"] || ""
                    CatBox {
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
        }
    }
    CatGroup {
        name: "osd"
        title: I18n.t("Индикаторы на экране", "On-screen indicators")
        advanced: true
        icon: "heart"
        // one place for where volume and brightness show: services/Halo takes them while
        // halo.osd is on and the Halo is there, modules/osd/Osd otherwise
        CatChoice {
            label: I18n.t("Громкость и яркость", "Volume and brightness")
            hint: I18n.t("«В Нимбе» — полоской в нём, на его экране", "In the Halo: a bar in it, on its screen")
            model: [["box", "Окошко", "A box"], ["halo", "В Нимбе", "In the Halo"], ["off", "Нигде", "Nowhere"]].filter(c => c[0] !== "halo" || Config.halo.enabled).map(c => ({
                        "label": I18n.t(c[1], c[2]),
                        "value": c[0]
                    }))
            currentValue: !Config.osd.enabled ? "off" : Config.halo.enabled && Config.halo.osd !== false ? "halo" : "box"
            onActivated: v => {
                Config.osd.enabled = v !== "off";
                Config.halo.osd = v === "halo";
            }
        }
        CatSlider {
            label: I18n.t("Сколько висит", "Display duration")
            from: 400
            to: 2500
            stepSize: 50
            value: Config.osd.ms
            suffix: I18n.t(" мс", " ms")
            onMoved: v => Config.osd.ms = v
        }
        CatCustom {
            label: I18n.t("Где показывать", "Show on")
            hint: I18n.t("клик по месту на мониторе", "Click a position on the display")
            CatBox {
                PxPositionPicker {
                    value: Config.osd.position
                    onPicked: v => Config.osd.position = v
                }
            }
        }
    }
    // the keyboard's own badges (Settings → Keyboard → More)
    CatGroup {
        name: "keyboard-osd"
        title: I18n.t("Раскладка на экране", "The layout on screen")
        advanced: true
        icon: "keyboard"
        CatToggle {
            label: I18n.t("Показывать смену раскладки", "Show layout changes")
            hint: I18n.t("маленький бейдж RU/EN", "Small RU/EN badge")
            checked: Config.osd.layout
            onToggled: c => Config.osd.layout = c
        }
        CatToggle {
            label: I18n.t("Показывать Caps Lock", "Show Caps Lock")
            hint: I18n.t("стрелка на панели рядом с раскладкой, пока он включён", "An arrow on the bar next to the layout while it is on")
            checked: Config.osd.caps
            onToggled: c => Config.osd.caps = c
        }
    }
    CatGroup {
        name: "voice-typing-voxtype"
        title: I18n.t("Голосовой ввод", "Voice typing")
        advanced: true
        icon: "mic"
        CatNote {
            dim: true
            text: I18n.t("Win+Shift+V — начать и закончить диктовку: что скажешь, напечатается там, где курсор.", "Win+Shift+V starts and stops dictation: what you say is typed where the cursor is.")
        }
        CatChoice {
            label: I18n.t("Индикатор", "Indicator")
            hint: I18n.t("«angelOS» — окошко " + I18n.exe("voice") + ", «Старый» — прежний кружок", "“angelOS”: a " + I18n.exe("voice") + " window, “Classic”: the old circle")
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
        CatCustom {
            present: Config.voxtype.indicator === "angelos"
            label: I18n.t("Где показывать", "Position")
            CatBox {
                PxPositionPicker {
                    value: Config.voxtype.position
                    onPicked: v => Config.voxtype.position = v
                }
            }
        }
    }
}
