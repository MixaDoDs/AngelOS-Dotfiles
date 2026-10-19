pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.gametune

// Settings → Maintenance → Games: every installed Steam game, how it runs on Linux and whether
// what we suggest is in; a row opens the game's note (modules/gametune/GameTuneCard) in place.
// The default Proton for all games is chosen here too.
Column {
    id: root

    property string open: ""
    spacing: Theme.u * 2

    PxText {
        width: parent.width
        visible: !GameTune.hasSteam
        wrapMode: Text.Wrap
        dim: true
        text: GameTune.data ? I18n.t("Steam не найден — поставь его, и здесь появятся игры с подобранными настройками.", "Steam isn't here — install it and the games show up with their settings picked.") : I18n.t("Смотрю игры…", "Looking at the games…")
    }
    PxText {
        width: parent.width
        visible: GameTune.hasSteam && !!GameTune.data.hardware
        wrapMode: Text.Wrap
        kind: "tiny"
        dim: true
        text: GameTune.data && GameTune.data.hardware ? I18n.t("Железо: ", "This machine: ") + (GameTune.data.hardware.gpu || GameTune.data.hardware.vendor) + (GameTune.data.hardware.ntsync ? " · ntsync" : "") + I18n.t(" — советы и варианты подбираются под него.", " — the suggestions and variants are picked for it.") : ""
    }
    SettingRow {
        width: parent.width
        visible: GameTune.hasSteam
        label: I18n.t("Без перезапуска Steam", "No Steam restart")
        hint: GameTune.instant === "on" ? I18n.t("включено: Proton и настройки игры меняются со следующего её запуска", "on: a game's Proton and settings change from its next start") : GameTune.instant === "waiting" ? I18n.t("закрой Steam один раз — дальше без перезапусков", "close Steam once — then no more restarts") : I18n.t("Steam видит один переключатель angelOS, а он перед каждым запуском берёт выбранный Proton и настройки игры. Твои параметры запуска в Steam остаются.", "Steam sees one angelOS switch that takes each game's chosen Proton and settings at every start. Your launch options in Steam stay.")
        PxToggle {
            checked: GameTune.instant !== "off"
            enabled: !GameTune.busy
            onToggled: v => GameTune.setInstant(v)
        }
    }
    SettingRow {
        width: parent.width
        visible: GameTune.hasSteam
        label: I18n.t("Proton для всех игр", "Proton for every game")
        hint: I18n.t("какой брать игре без своего; ★ — советуем", "what a game without its own takes; ★ — our pick")
        PxCombo {
            width: parent.width
            model: [
                {
                    "label": I18n.t("Как решит Steam", "Steam's own choice"),
                    "value": ""
                }
            ].concat(GameTune.tools.map(t => ({
                        "label": t.display + (t.kind === "cachyos" ? "  ★" : ""),
                        "value": t.name
                    })))
            currentValue: GameTune.data ? GameTune.data.default : ""
            onActivated: v => GameTune.apply("0", v, null)
        }
    }
    Repeater {
        model: GameTune.games.filter(g => g.installed)
        Column {
            id: row
            required property var modelData
            readonly property bool tuned: modelData.native || ((modelData.now.proton === modelData.rec.proton) && modelData.now.options === modelData.rec.options)
            width: root.width
            spacing: Theme.u * 2
            PxButton {
                width: parent.width
                flat: true
                icon: row.tuned ? "check" : "gamepad"
                checked: root.open === row.modelData.appid
                text: row.modelData.name + "  ·  " + ({
                        "platinum": I18n.t("платина", "platinum"),
                        "gold": I18n.t("золото", "gold"),
                        "silver": I18n.t("серебро", "silver"),
                        "bronze": I18n.t("бронза", "bronze"),
                        "borked": I18n.t("сломано", "borked")
                    }[row.modelData.rating.tier] || "—") + (row.modelData.pending ? I18n.t("  ·  ждёт Steam", "  ·  waits for Steam") : row.tuned ? "" : I18n.t("  ·  есть совет", "  ·  a suggestion"))
                onClicked: root.open = root.open === row.modelData.appid ? "" : row.modelData.appid
            }
            Loader {
                active: root.open === row.modelData.appid
                visible: active
                width: parent.width
                sourceComponent: GameTuneCard {
                    width: row.width
                    game: row.modelData
                }
            }
        }
    }
}
