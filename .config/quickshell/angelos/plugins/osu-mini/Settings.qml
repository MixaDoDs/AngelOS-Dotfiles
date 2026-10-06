import QtQuick
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    property var plugin
    width: parent ? parent.width : 400
    spacing: Theme.u * 5

    PxGroup {
        title: "osu!mini"
        icon: "heart"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Кликай по сердечкам, когда сжимающийся контур совпадает с ними (или жми Z / X, наведя курсор). 300 / 100 / 50 — по точности, промах разбивает сердце и сбрасывает комбо. Сердечки здоровья тают со временем и пополняются попаданиями.", "Click each heart when the shrinking outline meets it (or press Z / X with the cursor on it). 300 / 100 / 50 by timing; a miss breaks the heart and the combo. The health hearts drain over time and refill with hits.")
        }
        SettingRow {
            label: I18n.t("Музыка", "Music")
            hint: I18n.t("сердечки встают в такт тому, что играет: Spotify или весь звук компьютера (только слушаем, звук никуда не перенаправляется)", "Hearts follow the beat of what plays: Spotify or all the computer's sound (listen-only, nothing is rerouted)")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Свой ритм", "Own beat"),
                        "value": "off"
                    },
                    {
                        "label": "Spotify",
                        "value": "spotify"
                    },
                    {
                        "label": I18n.t("Звук системы", "System audio"),
                        "value": "system"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("music", "off") : "off"
                onActivated: v => root.plugin.set("music", v)
            }
        }
        SettingRow {
            label: I18n.t("Сдвиг нот", "Note offset")
            hint: I18n.t("если сердечки приходят раньше музыки — двигай вправо, позже — влево", "Hearts ahead of the music: move right; behind it: move left")
            PxSlider {
                width: parent.width
                from: -200
                to: 200
                stepSize: 10
                suffix: I18n.t(" мс", " ms")
                value: root.plugin ? root.plugin.get("offset", 0) : 0
                live: false
                onReleased: v => root.plugin.set("offset", v)
            }
        }
        SettingRow {
            label: I18n.t("Звуки попаданий", "Hit sounds")
            PxToggle {
                checked: root.plugin ? root.plugin.get("sound", true) : true
                onToggled: c => root.plugin.set("sound", c)
            }
        }
        Repeater {
            model: ["easy", "normal", "hard", "insane"]
            SettingRow {
                required property string modelData
                label: I18n.t("Рекорды · ", "Best · ") + modelData
                PxText {
                    text: [30, 45, 90].map(s => s + I18n.t(" с: ", " s: ") + (root.plugin ? root.plugin.get("best_" + modelData + "_" + s, 0) : 0)).join("   ")
                    dim: true
                }
            }
        }
        PxButton {
            text: I18n.t("Играть ♡", "Play ♡")
            icon: "play"
            accent: true
            onClicked: {
                Shell.settingsNavFor(root).settingsOpen = false;
                Shell.gameOpen = true;
            }
        }
    }
}
