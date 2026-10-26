// The settings once in LaptopPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Laptops (2026-10-08; services/Power, Laptop, Backlight): what happens when nobody touches it,
// on mains and on battery, and when the lid closes; the backlight and the keyboard light; the
// laptop's keys; a convertible's tablet mode; the fingerprint at the lock. Each group sits on
// its own page of the tree (Power, Display, Keyboard, Lock…).
CatPage {
    heading: I18n.t("Ноутбук", "Laptop")
    // a spin box per power source: mains | battery, side by side
    component Minutes: Row {
        id: mins
        property string acKey: ""               // "" = only the battery's
        property var acIn: Config.power         // where acKey lives (the lock's is Config.lock)
        property var acSet: v => Config.power[acKey] = v
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
            value: mins.acKey ? mins.acIn[mins.acKey] : 0
            suffix: I18n.t(" мин", " min")
            onMoved: v => mins.acSet(v)
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
    CatGroup {
        name: "power-idle"
        title: I18n.t("Когда отошёл от компьютера", "When you step away")
        icon: "moon"
        CatNote {
            dim: true
            text: I18n.t("По порядку, через сколько минут без мыши и клавиатуры. 0 = никогда. Видео и игры на весь экран не дают им сработать.", "In order: after how many minutes without the mouse and keyboard. 0 = never. Fullscreen video and games hold them off.")
        }
        // services/IdleWatch: the screensaver (modules/lock idle screen)
        CatSpin {
            label: I18n.t("Заставка", "Screensaver")
            from: 0
            to: 60
            stepSize: 1
            value: Config.idle.minutes
            suffix: I18n.t(" мин", " min")
            onMoved: v => Config.idle.minutes = v
        }
        CatCustom {
            label: I18n.t("Блокировать", "Lock")
            CatBox {
                Minutes {
                    acKey: "idleMinutes"
                    acIn: Config.lock
                    acSet: v => Config.lock.idleMinutes = v
                    batKey: "batteryLockMinutes"
                    inherit: Config.lock.idleMinutes
                }
            }
        }
        CatCustom {
            label: I18n.t("Гасить экран", "Turn the screen off")
            CatBox {
                Minutes {
                    acKey: "screenOffMinutes"
                    batKey: "batteryScreenOffMinutes"
                }
            }
        }
        CatCustom {
            label: I18n.t("Сон", "Sleep")
            CatBox {
                Minutes {
                    acKey: "sleepMinutes"
                    batKey: "batterySleepMinutes"
                }
            }
        }
        CatToggle {
            present: Backlight.available
            label: I18n.t("Притушить перед этим", "Dim first")
            hint: I18n.t("за 30 секунд подсветка уходит на треть; шевельнёшь мышью — вернётся", "30 seconds before, the backlight drops to a third; move the mouse and it comes back")
            checked: Config.power.dim
            onToggled: v => Config.power.dim = v
        }
        CatToggle {
            label: I18n.t("Блокировать перед сном", "Lock before sleep")
            hint: I18n.t("проснулся — сразу замок, а не рабочий стол", "Waking up shows the lock, never the desktop")
            checked: Config.lock.onSleep
            onToggled: c => Config.lock.onSleep = c
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
    CatGroup {
        name: "lid"
        title: I18n.t("Крышка", "The lid")
        icon: "laptop"
        present: Laptop.has("lid")
        CatNote {
            dim: true
            text: I18n.t("Когда подключён второй экран, закрытая крышка просто гасит экран ноутбука — работа идёт дальше. Блокировать ли перед сном — в карточке «Когда отошёл от компьютера».", "With a second screen plugged in, closing the lid only turns the laptop's panel off and you keep working. Whether to lock before sleep: the «When you step away» card.") + (Laptop.lidOurs ? I18n.t(" Сейчас крышку обрабатывает angelOS.", " angelOS handles the lid now.") : "")
        }
        CatCustom {
            label: I18n.t("От батареи", "On battery")
            CatBox {
                LidCombo {
                    currentValue: Config.power.lidAction
                    onActivated: v => Config.power.lidAction = v
                }
            }
        }
        CatCustom {
            label: I18n.t("От сети", "On mains")
            CatBox {
                LidCombo {
                    currentValue: Config.power.lidActionAc
                    onActivated: v => Config.power.lidActionAc = v
                }
            }
        }
    }
    // ---- the backlight and the keyboard's light (Settings → System → Display) ----
    CatGroup {
        name: "backlight"
        title: I18n.t("Подсветка экрана", "Screen backlight")
        icon: "sun"
        present: Laptop.has("backlight")
        CatNote {
            dim: true
            text: I18n.t("Настоящая подсветка экрана ноутбука. «Яркость и цвет» выше — программная, для любых мониторов.", "The laptop's real backlight. «Brightness and colour» above is software, for any monitor.")
        }
        CatSlider {
            present: Backlight.available
            label: I18n.t("Яркость", "Brightness")
            from: 0
            to: 100
            stepSize: 1
            suffix: " %"
            value: Math.round(Backlight.level * 100)
            onMoved: v => Backlight.set(v / 100, true)
        }
        CatSpin {
            present: Backlight.available
            label: I18n.t("Шаг клавиш", "Key step")
            hint: I18n.t("На сколько меняют яркость клавиши ноутбука за одно нажатие.", "How much the laptop's brightness keys change per press.")
            from: 1
            to: 25
            value: Config.laptop.brightnessStep
            suffix: " %"
            onMoved: v => Config.laptop.brightnessStep = v
        }
        CatChoice {
            present: Backlight.kbdAvailable
            label: I18n.t("Подсветка клавиатуры", "Keyboard light")
            model: Array.from({
                "length": Backlight.kbdMax + 1
            }, (_, i) => ({
                        "label": i === 0 ? I18n.t("выкл", "off") : String(i),
                        "value": i
                    }))
            currentValue: Backlight.kbd
            onActivated: v => Backlight.setKbd(v)
        }
        CatToggle {
            present: Backlight.kbdAvailable
            label: I18n.t("Гаснет вместе с экраном", "Goes out with the screen")
            hint: I18n.t("Подсветка клавиатуры гаснет и загорается вместе с экраном.", "The keyboard light goes off and on with the screen.")
            checked: Config.laptop.kbdAuto
            onToggled: v => Config.laptop.kbdAuto = v
        }
    }
    // ---- the laptop's own keys (Settings → Devices → Keyboard) ----
    CatGroup {
        name: "laptop-keys"
        title: I18n.t("Клавиши ноутбука", "Laptop keys")
        icon: "keyboard"
        present: Laptop.has("laptop")
        CatToggle {
            label: I18n.t("Клавиши angelOS", "angelOS keys")
            hint: I18n.t("яркость, подсветка клавиатуры, тачпад, режим полёта, калькулятор и Win+P — меню экранов", "Brightness, keyboard light, touchpad, airplane mode, calculator and Win+P — the screens menu")
            checked: Config.laptop.keys
            onToggled: v => Config.laptop.keys = v
        }
        CatNote {
            present: Laptop.keysSkipped.length > 0
            textKind: "tiny"
            dim: true
            text: I18n.t("Оставлены твоими (назначены в твоих файлах niri): ", "Left as yours (bound in your own niri files): ") + Laptop.keysSkipped.join(", ")
        }
        CatNote {
            present: Laptop.keysLog !== ""
            textKind: "tiny"
            text: Laptop.keysLog
        }
    }
    // ---- a convertible (Settings → System → Display) ----
    CatGroup {
        name: "tablet"
        title: I18n.t("Планшет", "Tablet mode")
        icon: "rotate"
        present: Laptop.has("tablet")
        CatToggle {
            label: I18n.t("Поворачивать экран", "Rotate the screen")
            hint: !Laptop.info.accel ? I18n.t("акселерометра нет", "no accelerometer") : !Laptop.info.rotateTool ? I18n.t("нужен iio-sensor-proxy", "needs iio-sensor-proxy") : I18n.t("в режиме планшета, по датчику", "In tablet mode, by the sensor")
            checked: Config.laptop.autoRotate
            onToggled: v => Config.laptop.autoRotate = v
        }
        CatToggle {
            label: I18n.t("Закрепить поворот", "Lock rotation")
            hint: I18n.t("Экран не поворачивается, как ни держи ноутбук.", "The screen stays put however you hold the laptop.")
            checked: Config.laptop.rotationLock
            onToggled: v => Laptop.setRotationLock(v)
        }
        CatToggle {
            label: I18n.t("Экранная клавиатура", "On-screen keyboard")
            hint: Laptop.info.osk ? Laptop.info.osk : I18n.t("нужен wvkbd или squeekboard", "needs wvkbd or squeekboard")
            checked: Config.laptop.tabletKeyboard
            onToggled: v => Config.laptop.tabletKeyboard = v
        }
    }
    // ---- the finger at the lock (Settings → Personal → Lock screen) ----
    CatGroup {
        name: "fingerprint"
        title: I18n.t("Вход по отпечатку", "Fingerprint unlock")
        icon: "fingerprint"
        present: Laptop.has("fingerprint")
        CatNote {
            dim: true
            text: !Laptop.info.fprintTool ? I18n.t("Нужен fprintd.", "Needs fprintd.") : !Laptop.fprintReader ? I18n.t("Сканер отпечатков не найден.", "No fingerprint reader found.") : Laptop.fprintEnrolled ? I18n.t("Записано пальцев: " + Laptop.fprintEnrolled + ". На замке можно просто приложить палец, пароль тоже работает.", Laptop.fprintEnrolled + " finger(s) enrolled. At the lock just touch the reader; the password works too.") : I18n.t("Пальцы ещё не записаны.", "No finger enrolled yet.")
        }
        CatToggle {
            label: I18n.t("Отпечаток на замке", "Fingerprint at the lock")
            hint: I18n.t("Разблокировать экран пальцем вместо пароля.", "Unlock the screen with a finger instead of the password.")
            checked: Config.laptop.fingerprint
            onToggled: v => Config.laptop.fingerprint = v
        }
        CatButton {
            present: Laptop.fprintReader
            label: I18n.t("Записать палец", "Enroll a finger")
            hint: I18n.t("откроется терминал: приложи палец несколько раз", "A terminal opens: touch the reader a few times")
            icon: "fingerprint"
            text: I18n.t("Записать", "Enroll")
            onClicked: Shell.terminal("fprintd-enroll; echo; read -p '↵' _")
        }
        CatButton {
            present: !!Laptop.info.fprintTool
            label: I18n.t("Проверить снова", "Check again")
            icon: "refresh"
            text: I18n.t("Обновить", "Refresh")
            onClicked: Laptop.refreshFingers()
        }
    }
}
