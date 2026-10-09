pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Laptops (2026-10-08; services/Power, Laptop, Backlight): what happens when nobody touches it,
// on mains and on battery, and when the lid closes; the backlight and the keyboard light; the
// laptop's keys; a convertible's tablet mode; the fingerprint at the lock. Each group sits on
// its own page of the tree (Power, Display, Keyboard, Lock…).
PxPage {
    heading: I18n.t("Ноутбук", "Laptop")

    // a spin box per power source: mains | battery, side by side
    component Minutes: Row {
        id: mins
        property string acKey: ""               // "" = only the battery's (the lock's own is on its group)
        required property string batKey
        property int inherit: -1                // −1 on battery = as on mains: this shows instead
        spacing: Theme.u * 4
        PxText {
            visible: mins.acKey !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("от сети", "mains")
            kind: "tiny"
            dim: true
        }
        PxSpin {
            visible: mins.acKey !== ""
            from: 0
            to: 240
            stepSize: 5
            value: mins.acKey ? Config.power[mins.acKey] : 0
            suffix: I18n.t(" мин", " min")
            onMoved: v => Config.power[mins.acKey] = v
        }
        PxText {
            visible: Laptop.has("battery")
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("от батареи", "battery")
            kind: "tiny"
            dim: true
        }
        PxSpin {
            visible: Laptop.has("battery")
            from: 0
            to: 240
            stepSize: 1
            value: Config.power[mins.batKey] < 0 ? mins.inherit : Config.power[mins.batKey]
            suffix: I18n.t(" мин", " min")
            onMoved: v => Config.power[mins.batKey] = v
        }
    }

    PxGroup {
        name: "power-idle"
        title: I18n.t("Когда никто не трогает", "When left alone")
        icon: "moon"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: Laptop.has("battery") ? I18n.t("0 = никогда. От батареи обычно короче: экран — самое прожорливое в ноутбуке. Видео и игры на весь экран не дают этим таймерам сработать.", "0 = never. On battery usually shorter: the screen is what eats the most. Fullscreen video and games hold these timers off.") : I18n.t("0 = никогда. Видео и игры на весь экран не дают этим таймерам сработать.", "0 = never. Fullscreen video and games hold these timers off.")
        }
        SettingRow {
            label: I18n.t("Гасить экран", "Turn the screen off")
            Minutes {
                acKey: "screenOffMinutes"
                batKey: "batteryScreenOffMinutes"
            }
        }
        SettingRow {
            visible: Laptop.has("battery")
            label: I18n.t("Блокировать", "Lock")
            hint: I18n.t("от сети — в «Когда блокировать» ниже", "On mains: When to lock, below")
            Minutes {
                batKey: "batteryLockMinutes"
                inherit: Config.lock.idleMinutes
            }
        }
        SettingRow {
            label: I18n.t("Сон", "Sleep")
            Minutes {
                acKey: "sleepMinutes"
                batKey: "batterySleepMinutes"
            }
        }
        SettingRow {
            visible: Backlight.available
            label: I18n.t("Притушить перед этим", "Dim first")
            hint: I18n.t("за 30 секунд подсветка уходит на треть; шевельнёшь мышью — вернётся", "30 seconds before, the backlight drops to a third; move the mouse and it comes back")
            PxToggle {
                checked: Config.power.dim
                onToggled: v => Config.power.dim = v
            }
        }
    }

    // ---- the lid (Settings → System → Power) ----
    component LidCombo: PxCombo {
        model: [
            {
                "label": I18n.t("сон", "Sleep"),
                "value": "suspend"
            },
            {
                "label": I18n.t("гибернация", "Hibernate"),
                "value": "hibernate"
            },
            {
                "label": I18n.t("только заблокировать", "Lock only"),
                "value": "lock"
            },
            {
                "label": I18n.t("ничего", "Nothing"),
                "value": "nothing"
            }
        ]
    }
    PxGroup {
        name: "lid"
        visible: Laptop.has("lid")
        title: I18n.t("Крышка", "The lid")
        icon: "laptop"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Когда подключён второй экран, закрытая крышка просто гасит экран ноутбука — работа идёт дальше. Экран блокируется перед сном всегда (Настройки → Блокировка).", "With a second screen plugged in, closing the lid only turns the laptop's panel off and you keep working. The lock always comes up before sleep (Settings → Lock).") + (Laptop.lidOurs ? I18n.t(" Сейчас крышку обрабатывает angelOS.", " angelOS handles the lid now.") : "")
        }
        SettingRow {
            label: I18n.t("От батареи", "On battery")
            LidCombo {
                currentValue: Config.power.lidAction
                onActivated: v => Config.power.lidAction = v
            }
        }
        SettingRow {
            label: I18n.t("От сети", "On mains")
            LidCombo {
                currentValue: Config.power.lidActionAc
                onActivated: v => Config.power.lidActionAc = v
            }
        }
    }

    // ---- the backlight and the keyboard's light (Settings → System → Display) ----
    PxGroup {
        name: "backlight"
        visible: Laptop.has("backlight")
        title: I18n.t("Подсветка экрана", "Screen backlight")
        icon: "sun"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Настоящая подсветка ноутбука (клавиши яркости тоже работают). «Яркость и цвет» выше — это программная гамма для любых мониторов.", "The laptop panel's real backlight (the brightness keys work too). Brightness and colour above is software gamma for any monitor.")
        }
        SettingRow {
            visible: Backlight.available
            label: I18n.t("Яркость", "Brightness")
            PxSlider {
                width: Theme.u * 110
                from: 0
                to: 100
                stepSize: 1
                suffix: " %"
                value: Math.round(Backlight.level * 100)
                onMoved: v => Backlight.set(v / 100, true)
            }
        }
        SettingRow {
            visible: Backlight.available
            label: I18n.t("Шаг клавиш", "Key step")
            PxSpin {
                from: 1
                to: 25
                value: Config.laptop.brightnessStep
                suffix: " %"
                onMoved: v => Config.laptop.brightnessStep = v
            }
        }
        SettingRow {
            visible: Backlight.kbdAvailable
            label: I18n.t("Подсветка клавиатуры", "Keyboard light")
            PxSegmented {
                model: Array.from({
                    "length": Backlight.kbdMax + 1
                }, (_, i) => ({
                            "label": i === 0 ? I18n.t("выкл", "off") : String(i),
                            "value": i
                        }))
                currentValue: Backlight.kbd
                onActivated: v => Backlight.setKbd(v)
            }
        }
        SettingRow {
            visible: Backlight.kbdAvailable
            label: I18n.t("Гаснет вместе с экраном", "Goes out with the screen")
            PxToggle {
                checked: Config.laptop.kbdAuto
                onToggled: v => Config.laptop.kbdAuto = v
            }
        }
    }

    // ---- the laptop's own keys (Settings → Devices → Keyboard) ----
    PxGroup {
        name: "laptop-keys"
        visible: Laptop.has("laptop")
        title: I18n.t("Клавиши ноутбука", "Laptop keys")
        icon: "keyboard"
        width: parent.width
        SettingRow {
            label: I18n.t("Клавиши angelOS", "angelOS keys")
            hint: I18n.t("яркость, подсветка клавиатуры, тачпад, режим полёта, калькулятор и Mod+P — меню экранов", "Brightness, keyboard light, touchpad, airplane mode, calculator and Mod+P — the screens menu")
            PxToggle {
                checked: Config.laptop.keys
                onToggled: v => Config.laptop.keys = v
            }
        }
        PxText {
            visible: Laptop.keysSkipped.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("Оставлены твоими (назначены в твоих файлах niri): ", "Left as yours (bound in your own niri files): ") + Laptop.keysSkipped.join(", ")
        }
        PxText {
            visible: Laptop.keysLog !== ""
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            color: Theme.danger
            text: Laptop.keysLog
        }
    }

    // ---- a convertible (Settings → System → Display) ----
    PxGroup {
        name: "tablet"
        visible: Laptop.has("tablet")
        title: I18n.t("Планшет", "Tablet mode")
        icon: "rotate"
        width: parent.width
        SettingRow {
            label: I18n.t("Поворачивать экран", "Rotate the screen")
            hint: !Laptop.info.accel ? I18n.t("акселерометра нет", "no accelerometer") : !Laptop.info.rotateTool ? I18n.t("нужен iio-sensor-proxy", "needs iio-sensor-proxy") : I18n.t("в режиме планшета, по датчику", "In tablet mode, by the sensor")
            PxToggle {
                checked: Config.laptop.autoRotate
                onToggled: v => Config.laptop.autoRotate = v
            }
        }
        SettingRow {
            label: I18n.t("Закрепить поворот", "Lock rotation")
            PxToggle {
                checked: Config.laptop.rotationLock
                onToggled: v => Laptop.setRotationLock(v)
            }
        }
        SettingRow {
            label: I18n.t("Экранная клавиатура", "On-screen keyboard")
            hint: Laptop.info.osk ? Laptop.info.osk : I18n.t("нужен wvkbd или squeekboard", "needs wvkbd or squeekboard")
            PxToggle {
                checked: Config.laptop.tabletKeyboard
                onToggled: v => Config.laptop.tabletKeyboard = v
            }
        }
    }

    // ---- the finger at the lock (Settings → Personal → Lock screen) ----
    PxGroup {
        name: "fingerprint"
        visible: Laptop.has("fingerprint")
        title: I18n.t("Вход по отпечатку", "Fingerprint unlock")
        icon: "fingerprint"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: !Laptop.info.fprintTool ? I18n.t("Нужен fprintd.", "Needs fprintd.") : !Laptop.fprintReader ? I18n.t("Сканер отпечатков не найден.", "No fingerprint reader found.") : Laptop.fprintEnrolled ? I18n.t("Записано пальцев: " + Laptop.fprintEnrolled + ". На замке можно просто приложить палец, пароль тоже работает.", Laptop.fprintEnrolled + " finger(s) enrolled. At the lock just touch the reader; the password works too.") : I18n.t("Пальцы ещё не записаны.", "No finger enrolled yet.")
        }
        SettingRow {
            label: I18n.t("Отпечаток на замке", "Fingerprint at the lock")
            PxToggle {
                checked: Config.laptop.fingerprint
                onToggled: v => Config.laptop.fingerprint = v
            }
        }
        SettingRow {
            visible: Laptop.fprintReader
            label: I18n.t("Записать палец", "Enroll a finger")
            hint: I18n.t("откроется терминал: приложи палец несколько раз", "A terminal opens: touch the reader a few times")
            PxButton {
                icon: "fingerprint"
                text: I18n.t("Записать", "Enroll")
                onClicked: Shell.terminal("fprintd-enroll; echo; read -p '↵' _")
            }
        }
        SettingRow {
            visible: !!Laptop.info.fprintTool
            label: I18n.t("Проверить снова", "Check again")
            PxButton {
                icon: "refresh"
                text: I18n.t("Обновить", "Refresh")
                onClicked: Laptop.refreshFingers()
            }
        }
    }
}
