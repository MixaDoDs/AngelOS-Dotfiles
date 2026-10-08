pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// Battery (laptops, 2026-10-08; services/Power, Laptop): the charge and the battery's wear,
// the bar's hearts, the low-battery notifications and what happens at the critical level, the
// eco mode, the charge limit. The tree shows the page only where there is a battery.
PxPage {
    id: page
    property string helperLog: ""
    heading: I18n.t("Батарея", "Battery")
    subtitle: I18n.t("Заряд, предупреждения, режим экономии и бережная зарядка.", "The charge, the warnings, the eco mode and gentle charging.")

    PxGroup {
        name: "status"
        title: I18n.t("Заряд", "Charge")
        icon: "battery"
        width: parent.width
        Row {
            spacing: Theme.u * 6
            PxHearts {
                anchors.verticalCenter: parent.verticalCenter
                count: 10
                pixel: Theme.u + 1
                value: Power.percent / 100
                icon: Theme.realm === "hell" ? "coal" : "heart"
                fill: Power.discharging && Power.percent <= Config.power.lowAt ? Theme.danger : Theme.realm === "hell" ? Theme.hellAccent : Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                PxText {
                    text: Power.hasBattery ? Power.percent + " %" : I18n.t("батареи нет", "no battery")
                    kind: "title"
                }
                PxText {
                    text: Power.statusText
                    dim: true
                }
            }
        }
        PxText {
            visible: Power.health > 0 || Power.cycles > 0
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: (Power.health > 0 ? I18n.t("Ёмкость: " + Power.health + " % от новой. ", "Capacity: " + Power.health + "% of a new one. ") : "") + (Power.cycles > 0 ? I18n.t("Циклов зарядки: " + Power.cycles + ". ", "Charge cycles: " + Power.cycles + ". ") : "") + (Laptop.battery && Laptop.battery.technology ? Laptop.battery.technology + (Laptop.battery.model ? " · " + Laptop.battery.model : "") : "")
        }
        SettingRow {
            label: I18n.t("Батарея на панели", "Battery on the bar")
            hint: I18n.t("пять сердечек: каждое — 20 %; в аду — угли", "Five hearts, 20% each; coals in hell")
            PxToggle {
                checked: Config.power.showBattery
                onToggled: v => Config.power.showBattery = v
            }
        }
        SettingRow {
            label: I18n.t("Проценты рядом", "Percentage next to it")
            PxToggle {
                checked: Config.power.barPercent
                onToggled: v => Config.power.barPercent = v
            }
        }
        SettingRow {
            label: I18n.t("Звук зарядки", "Charger sound")
            hint: I18n.t("щелчок, когда зарядку подключают и вынимают", "A click when the charger goes in and out")
            PxToggle {
                checked: Config.power.plugSound
                onToggled: v => Config.power.plugSound = v
            }
        }
    }

    PxGroup {
        name: "eco"
        title: I18n.t("Режим экономии", "Eco mode")
        icon: "leaf"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("angelOS перестаёт двигаться ради красоты: без анимаций, размытия и адских эффектов, niri тоже без анимаций. Ангел остаётся, но дышит тише. Сейчас: ", "angelOS stops moving for looks: no animations, no blur, no hell effects, and niri without animations too. The angel stays, breathing quieter. Now: ") + (Power.eco ? I18n.t("включён (", "on (") + Power.ecoWhy + ")" : I18n.t("выключен", "off"))
        }
        SettingRow {
            label: I18n.t("Когда включать", "When")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Всегда", "Always"),
                        "value": "on"
                    },
                    {
                        "label": I18n.t("Никогда", "Never"),
                        "value": "off"
                    }
                ]
                currentValue: Config.power.eco
                onActivated: v => Config.power.eco = v
            }
        }
        SettingRow {
            visible: Config.power.eco === "auto"
            label: I18n.t("На батарее с", "On battery from")
            hint: I18n.t("100 % = всегда, когда зарядка вынута", "100% = whenever the charger is out")
            PxSpin {
                from: 5
                to: 100
                stepSize: 5
                value: Config.power.ecoAt
                suffix: " %"
                onMoved: v => Config.power.ecoAt = v
            }
        }
        SettingRow {
            visible: Config.power.eco === "auto" && Power.profilesAvailable
            label: I18n.t("И с профилем «Экономия»", "And with the power-saver profile")
            PxToggle {
                checked: Config.power.ecoWithSaver
                onToggled: v => Config.power.ecoWithSaver = v
            }
        }
        SettingRow {
            visible: Power.profilesAvailable
            label: I18n.t("Переключать профиль питания", "Switch the power profile")
            hint: I18n.t("на время экономии — «Экономия», потом прежний", "Power saver while it lasts, the old one after")
            PxToggle {
                checked: Config.power.ecoSaverProfile
                onToggled: v => Config.power.ecoSaverProfile = v
            }
        }
    }

    PxGroup {
        name: "alerts"
        title: I18n.t("Когда батарея садится", "When the battery runs low")
        icon: "warn"
        width: parent.width
        SettingRow {
            label: I18n.t("Предупреждать", "Warn me")
            hint: I18n.t("уведомление один раз на каждом пороге", "One notification at each step")
            PxToggle {
                checked: Config.power.alerts
                onToggled: v => Config.power.alerts = v
            }
        }
        SettingRow {
            label: I18n.t("Низкий заряд", "Low")
            PxSpin {
                from: 10
                to: 50
                stepSize: 5
                value: Config.power.lowAt
                suffix: " %"
                onMoved: v => Config.power.lowAt = Math.max(v, Config.power.veryLowAt + 1)
            }
        }
        SettingRow {
            label: I18n.t("Очень низкий", "Very low")
            PxSpin {
                from: 3
                to: 30
                value: Config.power.veryLowAt
                suffix: " %"
                onMoved: v => Config.power.veryLowAt = Math.min(Math.max(v, Config.power.criticalAt + 1), Config.power.lowAt - 1)
            }
        }
        SettingRow {
            label: I18n.t("Критический", "Critical")
            PxSpin {
                from: 1
                to: 15
                value: Config.power.criticalAt
                suffix: " %"
                onMoved: v => Config.power.criticalAt = Math.min(v, Config.power.veryLowAt - 1)
            }
        }
        SettingRow {
            label: I18n.t("На критическом", "At critical")
            hint: I18n.t("через минуту после предупреждения; зарядка отменяет", "A minute after the warning; the charger cancels it")
            PxCombo {
                model: [
                    {
                        "label": I18n.t("сон", "Sleep"),
                        "value": "suspend"
                    },
                    {
                        "label": I18n.t("гибернация", "Hibernate") + (Laptop.canHibernate ? "" : I18n.t(" (нет swap — будет сон)", " (no swap — sleeps)")),
                        "value": "hibernate"
                    },
                    {
                        "label": I18n.t("выключить", "Shut down"),
                        "value": "poweroff"
                    },
                    {
                        "label": I18n.t("ничего", "Nothing"),
                        "value": "nothing"
                    }
                ]
                currentValue: Config.power.criticalAction
                onActivated: v => Config.power.criticalAction = v
            }
        }
        SettingRow {
            label: Angel.demon ? I18n.t("Демоница замечает", "The demon notices") : I18n.t("Ангел замечает", "The angel notices")
            hint: I18n.t("устаёт на 20 %, опускает крылья на 10 %, засыпает на 5 %, радуется зарядке; молчит в играх и на стриме", "Tired at 20%, wings down at 10%, asleep at 5%, glad of the charger; quiet in games and on stream")
            PxToggle {
                checked: Config.power.angel
                onToggled: v => Config.power.angel = v
            }
        }
    }

    PxGroup {
        name: "charge-limit"
        title: I18n.t("Бережная зарядка", "Gentle charging")
        icon: "heartSmall"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: !Laptop.limitSupported ? I18n.t("Этот ноутбук не даёт ограничить заряд из Linux (нет charge_control_end_threshold).", "This laptop doesn't let Linux limit the charge (no charge_control_end_threshold).") : I18n.t("Батарея, которая всё время стоит на 100 % у розетки, стареет быстрее. С лимитом зарядка останавливается раньше; angelOS ставит его заново при каждом входе.", "A battery kept at 100% on the charger ages faster. With a limit charging stops earlier; angelOS sets it again at every login.")
        }
        SettingRow {
            visible: Laptop.limitSupported
            label: I18n.t("Заряжать до", "Charge up to")
            hint: Config.power.chargeLimit >= 100 ? I18n.t("100 % — без лимита", "100% — no limit") : I18n.t("сейчас в прошивке: ", "in the firmware now: ") + Laptop.limitNow + " %"
            PxSegmented {
                model: [60, 80, 90, 100].map(v => ({
                            "label": v + " %",
                            "value": v
                        }))
                currentValue: [60, 80, 90, 100].includes(Config.power.chargeLimit) ? Config.power.chargeLimit : 100
                onActivated: v => Config.power.chargeLimit = v
            }
        }
        // the sysfs file is root's: a small helper, allowed for the active session without a
        // password (extras/charge-limit), installed once — with the password, through polkit
        SettingRow {
            visible: Laptop.limitSupported && !Laptop.limitSettable
            label: I18n.t("Помощник лимита", "Limit helper")
            hint: I18n.t("один раз, с паролем: дальше лимит ставится сам", "Once, with your password: then the limit sets itself")
            PxButton {
                icon: "lock"
                text: helper.running ? I18n.t("Ставлю…", "Installing…") : I18n.t("Установить", "Install")
                enabled: !helper.running
                onClicked: helper.running = true
            }
        }
        PxText {
            visible: Laptop.limitStatus !== "" && Laptop.limitStatus !== "nohelper" || page.helperLog !== ""
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            color: Theme.danger
            text: page.helperLog || Laptop.limitStatus
        }
        Process {
            id: helper
            command: ["pkexec", "sh", Quickshell.shellDir + "/extras/charge-limit/install.sh"]
            stderr: StdioCollector {
                onStreamFinished: page.helperLog = text.trim().split("\n").slice(-1)[0] || ""
            }
            onExited: code => {
                if (code === 0)
                    page.helperLog = "";
                Laptop.refresh();
                Qt.callLater(Laptop.applyLimit);
            }
        }
    }
}
