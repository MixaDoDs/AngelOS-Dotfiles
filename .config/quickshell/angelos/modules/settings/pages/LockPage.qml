pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.idle

PxPage {
    heading: I18n.t("Блокировка и заставка", "Lock and idle screen")
    subtitle: I18n.t("Экран блокировки с сердечками и заставка-«простой» как в Omarchy: ASCII-арт с анимациями, любая клавиша возвращает рабочий стол.", "A heart-filled lock screen and an Omarchy-style idle screen: animated ASCII art, any key brings the desktop back.")

    PxGroup {
        name: "lock-screen"
        title: I18n.t("Экран блокировки", "Lock screen")
        icon: "lock"
        width: parent.width
        SettingRow {
            label: I18n.t("Блокировать после простоя", "Lock when idle")
            hint: I18n.t("0 = никогда", "0 = never")
            PxSpin {
                from: 0
                to: 120
                stepSize: 5
                value: Config.lock.idleMinutes
                suffix: I18n.t(" мин", " min")
                onMoved: v => Config.lock.idleMinutes = v
            }
        }
        SettingRow {
            label: I18n.t("Блокировать перед сном", "Lock before sleep")
            hint: I18n.t("экран блокируется до ухода в сон, после пробуждения сразу виден замок, а не рабочий стол; также срабатывает на loginctl lock-session", "The lock comes up before the system sleeps, so waking up shows the lock, never the desktop; loginctl lock-session works too")
            PxToggle {
                checked: Config.lock.onSleep
                onToggled: c => Config.lock.onSleep = c
            }
        }
        // each look below plays as a small gif when it is switched on
        SettingRow {
            id: pixelRow
            label: I18n.t("Пикселизовать обои", "Pixelate the wallpaper")
            preview: "LockScreen"
            PxToggle {
                checked: Config.lock.pixelate
                onToggled: c => {
                    Config.lock.pixelate = c;
                    if (c)
                        pixelRow.show("pixelate", I18n.t("пиксели", "pixels"));
                }
            }
        }
        SettingRow {
            id: heartsRow
            label: I18n.t("Летающие сердечки", "Floating hearts")
            preview: "LockScreen"
            PxToggle {
                checked: Config.lock.hearts
                onToggled: c => {
                    Config.lock.hearts = c;
                    if (c)
                        heartsRow.show("hearts", I18n.t("сердечки", "hearts"));
                }
            }
        }
        SettingRow {
            id: reactRow
            label: I18n.t("Реакции на ввод", "Typing reactions")
            hint: I18n.t("сердечко на каждый символ, разбитое сердце при ошибке, фейерверк при входе", "A heart per character, a broken heart on a mistake, a burst on unlock")
            preview: "LockScreen"
            PxToggle {
                checked: Config.lock.reactions
                onToggled: c => {
                    Config.lock.reactions = c;
                    if (c)
                        reactRow.show("reactions", I18n.t("реакции", "reactions"));
                }
            }
        }
        SettingRow {
            id: indRow
            label: I18n.t("Индикаторы", "Indicators")
            hint: I18n.t("Caps Lock, раскладка, заряд, сколько заблокировано, новые уведомления (только число)", "Caps Lock, layout, battery, time locked, new notifications (count only)")
            preview: "LockScreen"
            PxToggle {
                checked: Config.lock.indicators
                onToggled: c => {
                    Config.lock.indicators = c;
                    if (c)
                        indRow.show("indicators", I18n.t("индикаторы", "indicators"));
                }
            }
        }
        SettingRow {
            label: I18n.t("Логотип", "Logo")
            hint: I18n.t("логотип angelOS над часами (какой — Панель → Логотип)", "the angelOS logo above the clock (pick one in Bar → Logo)")
            PxToggle {
                checked: Config.lock.logo
                onToggled: c => Config.lock.logo = c
            }
        }
        SettingRow {
            id: streamRow
            label: I18n.t("NGO-стрим", "NGO stream")
            hint: I18n.t("LIVE, «зрители» и милый чат, который реагирует на ввод. Всё выдумано локально.", "LIVE badge, “viewers” and a cute chat reacting to typing. All made up locally.")
            preview: "LockScreen"
            PxToggle {
                checked: Config.lock.stream
                onToggled: c => {
                    Config.lock.stream = c;
                    if (c)
                        streamRow.show("stream", "LIVE");
                }
            }
        }
        SettingRow {
            visible: Config.lock.stream
            label: I18n.t("Название «стрима»", "Stream title")
            PxField {
                width: Theme.u * 130
                text: Config.lock.streamTitle
                placeholder: I18n.t("ангел ушёл на перерыв ♡ скоро вернусь", "angel is on a break ♡ be right back")
                onEdited: Config.lock.streamTitle = text
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Предпросмотр", "Preview")
                icon: "sparkle"
                onClicked: {
                    Shell.settingsOpen = false;
                    Shell.lockPreview = true;
                }
            }
            PxButton {
                text: I18n.t("Заблокировать", "Lock now")
                icon: "lock"
                onClicked: Shell.lock()
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("В предпросмотре пароль не проверяется: пустой Enter показывает ошибку, любой текст — вход. Esc закрывает.", "The preview never checks a password: an empty Enter shows the mistake, any text the unlock. Esc closes it.")
        }
    }

    PxGroup {
        name: "idle-screen"
        title: I18n.t("Заставка (Idle)", "Idle screen")
        advanced: true
        icon: "moon"
        width: parent.width
        SettingRow {
            label: I18n.t("Включать после простоя", "Start when idle")
            hint: I18n.t("0 = только вручную: «Пуск», меню выключения или angelos idle", "0 = by hand only: Start, the power menu or `angelos idle`")
            PxSpin {
                from: 0
                to: 60
                stepSize: 1
                value: Config.idle.minutes
                suffix: I18n.t(" мин", " min")
                onMoved: v => Config.idle.minutes = v
            }
        }
        SettingRow {
            label: I18n.t("Эффект", "Effect")
            PxCombo {
                width: Theme.u * 100
                model: [{
                        "label": I18n.t("Случайный", "Random"),
                        "value": "random"
                    }].concat(Idle.effects.map(e => ({
                            "label": ({
                                    "decrypt": I18n.t("Расшифровка", "Decrypt"),
                                    "rain": I18n.t("Дождь", "Rain"),
                                    "beams": I18n.t("Лучи", "Beams"),
                                    "wave": I18n.t("Волна", "Wave"),
                                    "typewriter": I18n.t("Печатная машинка", "Typewriter"),
                                    "hearts": I18n.t("Сердечки", "Hearts"),
                                    "glitch": I18n.t("Глитч", "Glitch")
                                })[e],
                            "value": e
                        })))
                currentValue: Config.idle.effect
                onActivated: v => Config.idle.effect = v
            }
        }
        SettingRow {
            label: I18n.t("Цвета", "Colours")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Тема", "Theme"),
                        "value": "accent"
                    },
                    {
                        "label": I18n.t("Белый", "White"),
                        "value": "mono"
                    },
                    {
                        "label": I18n.t("Радуга", "Rainbow"),
                        "value": "rainbow"
                    }
                ]
                currentValue: Config.idle.colors
                onActivated: v => Config.idle.colors = v
            }
        }
        SettingRow {
            label: I18n.t("Часы под текстом", "Clock below")
            PxToggle {
                checked: Config.idle.clock
                onToggled: c => Config.idle.clock = c
            }
        }
        SettingRow {
            label: I18n.t("На всех экранах", "On every screen")
            PxToggle {
                checked: Config.idle.allScreens
                onToggled: c => Config.idle.allScreens = c
            }
        }
        PxText {
            text: I18n.t("Текст или ASCII-арт (пусто — логотип angelOS):", "Text or ASCII art (empty = angelOS logo):")
        }
        PxTextArea {
            width: parent.width
            implicitHeight: Theme.u * 70
            monospace: true
            text: Config.idle.text
            placeholder: Idle.defaultArt
            onEdited: Config.idle.text = text
        }
        PxBox {
            width: parent.width
            height: Theme.u * 90
            sunken: true
            color: Theme.mix(Qt.color("#000000"), Theme.accent, 0.035)
            clip: true
            AsciiArt {
                anchors.centerIn: parent
                text: Idle.text
                maxWidth: parent.width - Theme.u * 10
                maxHeight: parent.height - Theme.u * 10
                effect: Config.idle.effect
                palette: Config.idle.colors
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Запустить", "Start now")
                icon: "sparkle"
                accent: true
                onClicked: {
                    Shell.settingsOpen = false;
                    Idle.start();
                }
            }
            PxButton {
                visible: Config.idle.text !== ""
                text: I18n.t("Вернуть логотип", "Restore logo")
                icon: "refresh"
                onClicked: Config.idle.text = ""
            }
        }
    }
}
