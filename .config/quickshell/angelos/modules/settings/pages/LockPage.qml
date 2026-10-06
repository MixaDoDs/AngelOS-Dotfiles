pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.idle

PxPage {
    id: lockPage
    heading: I18n.t("Блокировка и заставка", "Lock and idle screen")
    subtitle: I18n.t("Экран блокировки — NGO-стрим или небесные врата — и заставка-«простой» как в Omarchy: ASCII-арт с анимациями, любая клавиша возвращает рабочий стол.", "The lock screen — an NGO stream or heaven's gate — and an Omarchy-style idle screen: animated ASCII art, any key brings the desktop back.")

    PxGroup {
        name: "lock-screen"
        title: I18n.t("Экран блокировки", "Lock screen")
        icon: "lock"
        width: parent.width
        SettingRow {
            id: lookRow
            label: I18n.t("Облик", "Look")
            hint: I18n.t("NGO — пиксельный стрим с чатом; Небеса — экран входа как в Genshin Impact / ZZZ: врата над облаками, «нажмите любую клавишу», небо по времени суток", "NGO: a pixel stream with its chat; Heaven: a login screen like Genshin Impact / ZZZ — a gate above the clouds, “press any key”, the sky of the hour")
            preview: "LockScreen"
            PxSegmented {
                model: [
                    {
                        "label": "NGO",
                        "value": "ngo"
                    },
                    {
                        "label": I18n.t("Небеса", "Heaven"),
                        "value": "heaven"
                    }
                ]
                currentValue: Config.lock.style === "heaven" ? "heaven" : "ngo"
                onActivated: v => {
                    Config.lock.style = v;
                    lookRow.show(v === "heaven" ? "heaven" : "stream", v === "heaven" ? I18n.t("небеса", "heaven") : "NGO");
                }
            }
        }
        SettingRow {
            label: I18n.t("Размер окна входа", "Login window size")
            hint: I18n.t("крупнее остальной оболочки; пиксели остаются целыми", "bigger than the rest of the shell; the pixels stay whole")
            PxSegmented {
                model: [1, 1.5, 2].map(v => ({
                            "label": "×" + v,
                            "value": v
                        }))
                currentValue: Config.lock.size
                onActivated: v => Config.lock.size = v
            }
        }
        SettingRow {
            id: fxRow
            label: I18n.t("Разблокировка", "Unlock")
            hint: I18n.t("как экран блокировки уходит с рабочего стола: «Авто» — сердце у NGO, врата у Небес", "how the lock leaves the desktop: Auto is the heart for NGO, the gate for Heaven")
            preview: "LockScreen"
            PxCombo {
                width: Theme.u * 110
                model: [
                    {
                        "label": I18n.t("Авто (по облику)", "Auto (the look's own)"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Сердце", "Heart"),
                        "value": "heart"
                    },
                    {
                        "label": I18n.t("Пиксели", "Pixels"),
                        "value": "pixels"
                    },
                    {
                        "label": I18n.t("«Стрим окончен» (ТВ)", "“Stream ended” (TV)"),
                        "value": "crt"
                    },
                    {
                        "label": I18n.t("Небесные врата", "Heaven's gate"),
                        "value": "gate"
                    },
                    {
                        "label": I18n.t("Глитч", "Glitch"),
                        "value": "glitch"
                    },
                    {
                        "label": I18n.t("Без анимации", "None"),
                        "value": "none"
                    }
                ]
                currentValue: Config.lock.unlockFx
                onActivated: v => {
                    Config.lock.unlockFx = v;
                    const fx = v === "auto" ? (Config.lock.style === "heaven" ? "gate" : "heart") : v;
                    if (fx !== "none")
                        fxRow.show("fx:" + fx, I18n.t("разблокировка", "unlock"));
                }
            }
        }
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
            visible: Config.lock.style !== "heaven"
            label: I18n.t("NGO-стрим", "NGO stream")
            hint: I18n.t("LIVE, «зрители» и чат, который знает, что ты делал(а): программа (только название), трек, время, уведомления (только от кого), как печатаешь. Зрители растут с днями: в первый день никого, к 30-му — 1000–1500. Сейчас день %1. Всё выдумано локально.", "LIVE, “viewers” and a chat that knows what you did: the program (its name only), the song, the hour, notifications (who sent them only), how you type. The audience grows with the days: nobody on day 1, 1000–1500 by day 30. Today is day %1. All made up locally.").arg(LockStream.days)
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
            visible: Config.lock.stream && Config.lock.style !== "heaven"
            label: I18n.t("Название «стрима»", "Stream title")
            PxField {
                width: Theme.u * 130
                text: Config.lock.streamTitle
                placeholder: I18n.t("ангел ушёл на перерыв ♡ скоро вернусь", "angel is on a break ♡ be right back")
                onEdited: Config.lock.streamTitle = text
            }
        }
        SettingRow {
            visible: Config.lock.stream && Config.lock.style !== "heaven"
            label: I18n.t("Повтор эфира", "Replay")
            hint: I18n.t("через время на заднем плане идёт случайное видео с компьютера — без звука и в таком блюре, что ничего не прочесть (кадр ужимается до 32×18 точек). Не на экране, который сейчас стримится по-настоящему.", "after a while a random video from the computer plays behind the stream — silent, blurred past reading (each frame is shrunk to 32×18 dots). Never on a screen that is really being streamed.")
            PxToggle {
                checked: Config.lock.replay
                onToggled: c => Config.lock.replay = c
            }
        }
        SettingRow {
            visible: Config.lock.stream && Config.lock.replay && Config.lock.style !== "heaven"
            label: I18n.t("Повтор через", "Replay after")
            PxSpin {
                from: 10
                to: 600
                stepSize: 10
                value: Config.lock.replayDelay
                suffix: I18n.t(" с", " s")
                onMoved: v => Config.lock.replayDelay = v
            }
        }
        SettingRow {
            visible: Config.lock.stream && Config.lock.replay && Config.lock.style !== "heaven"
            label: I18n.t("Папка с видео", "Video folder")
            hint: I18n.t("пусто — ~/Videos (записи экрана, клипы); берутся и вложенные папки", "empty: ~/Videos (screen recordings, clips); folders inside count too")
            PxField {
                width: Theme.u * 130
                text: Config.lock.replayDir
                placeholder: "~/Videos"
                onEdited: Config.lock.replayDir = text
            }
        }
        SettingRow {
            visible: Config.lock.style !== "heaven" && Config.lock.stream
            label: I18n.t("Вебка с ангелом", "Webcam with the angel")
            hint: I18n.t("спит, пока тебя нет, просыпается от клавиш, закрывает глаза на пароле, плачет при ошибке", "sleeps while you are away, wakes at a key, shuts her eyes on the password, cries at a mistake")
            PxToggle {
                checked: Config.lock.streamCam
                onToggled: c => Config.lock.streamCam = c
            }
        }
        SettingRow {
            visible: Config.lock.style !== "heaven" && Config.lock.stream
            label: I18n.t("Шкалы как в NGO", "NGO stats")
            hint: I18n.t("подписчики, стресс (нагрузка процессора и аптайм), привязанность (дни с angelOS), тьма (ночь и ошибки)", "followers, stress (CPU load and uptime), affection (days with angelOS), darkness (night and mistakes)")
            PxToggle {
                checked: Config.lock.streamMeters
                onToggled: c => Config.lock.streamMeters = c
            }
        }
        SettingRow {
            visible: Config.lock.style !== "heaven" && Config.lock.stream
            label: I18n.t("Опросы и алерты", "Polls and alerts")
            hint: I18n.t("опрос в чате, донаты, рейды, подписки, рубежи зрителей", "a poll in the chat, donations, raids, follows, viewer milestones")
            PxToggle {
                checked: Config.lock.streamAlerts
                onToggled: c => Config.lock.streamAlerts = c
            }
        }
        SettingRow {
            visible: Config.lock.style !== "heaven" && Config.lock.stream
            label: I18n.t("Клипы и хайлайты", "Clips and highlights")
            hint: I18n.t("ошибки становятся клипами, при входе — короткие хайлайты стрима (клик или клавиша пропускают)", "mistakes become clips, the unlock shows the stream\u2019s highlights (a click or a key skips)")
            PxToggle {
                checked: Config.lock.highlights
                onToggled: c => Config.lock.highlights = c
            }
        }
        SettingRow {
            visible: Config.lock.style === "heaven"
            label: I18n.t("Ангел у врат", "The angel by the gate")
            hint: I18n.t("дремлет, просыпается, не подглядывает пароль, грустит при ошибке, радуется входу", "dozes, wakes up, never peeks at the password, is sad at a mistake, cheers at the unlock")
            PxToggle {
                checked: Config.lock.heavenAngel
                onToggled: c => Config.lock.heavenAngel = c
            }
        }
        SettingRow {
            label: I18n.t("Крутка при входе", "A wish at the unlock")
            hint: I18n.t("первый вход за день — бесплатная молитва (3★/4★/5★, гарант): на Небесах падает звезда, в NGO-стриме — гачапон-капсула. Дальше — за 160 ✦, если включено. Клик или клавиша пропускают", "the first unlock of a day prays for free (3★/4★/5★, pity): heaven drops a star, the NGO stream a gachapon capsule. After that 160 ✦ if switched on. A click or a key skips")
            PxToggle {
                checked: Config.lock.wish
                onToggled: c => Config.lock.wish = c
            }
        }
        SettingRow {
            visible: Config.lock.wish
            label: I18n.t("Платные крутки при входе", "Paid wishes at the unlock")
            hint: I18n.t("после бесплатной — каждый вход тратит 160 ✦, пока хватает звёзд", "past the free one, every unlock spends 160 ✦ while the stars last")
            PxToggle {
                checked: Config.lock.wishPaid
                onToggled: c => Config.lock.wishPaid = c
            }
        }
        SettingRow {
            label: I18n.t("Награда за вход", "Daily login reward")
            hint: I18n.t("звёзды ✦ при первом входе за день, цикл на 7 дней, серия дней — в обоих обликах", "stars ✦ with the first unlock of a day, a 7-day cycle, a streak — in both looks")
            PxToggle {
                checked: Config.lock.dailyReward
                onToggled: c => Config.lock.dailyReward = c
            }
        }
        SettingRow {
            visible: Config.lock.style === "heaven"
            label: I18n.t("Доска объявлений", "Notice board")
            hint: I18n.t("обновления angelOS, кто писал, пока тебя не было, музыка, достижения, время за компьютером", "angelOS updates, who wrote while you were away, music, achievements, time at the computer")
            PxToggle {
                checked: Config.lock.notices
                onToggled: c => Config.lock.notices = c
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Предпросмотр", "Preview")
                icon: "sparkle"
                onClicked: {
                    lockPage.nav.settingsOpen = false;
                    Shell.lockPreview = true;
                }
            }
            PxButton {
                text: I18n.t("Показать вход", "Show the unlock")
                icon: "heart"
                onClicked: {
                    lockPage.nav.settingsOpen = false;
                    Shell.lockPreviewDemo = "angel";
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
        id: sddmGroup
        name: "login-screen"
        title: I18n.t("Экран входа (SDDM)", "Login screen (SDDM)")
        icon: "monitor"
        width: parent.width
        property var info: ({})
        property string palette: "ngo"
        property string log: ""
        Component.onCompleted: sddmStatus.running = true
        Process {
            id: sddmStatus
            command: ["python3", Quickshell.shellDir + "/scripts/sddm-theme.py", "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        sddmGroup.info = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
        Process {
            id: sddmInstall
            command: ["python3", Quickshell.shellDir + "/scripts/sddm-theme.py", "install", "--palette", sddmGroup.palette, "--wallpaper", Wallpapers.loginWalls()[0] || "", "--tall", Wallpapers.loginWalls()[1] || ""]
            stderr: StdioCollector {
                onStreamFinished: if (text.trim() !== "")
                    sddmGroup.log = text.trim().split("\n").slice(-1)[0]
            }
            onExited: code => {
                sddmGroup.log = code === 0 ? I18n.t("готово: тема входа установлена ♡", "done: the login theme is installed ♡") : sddmGroup.log || I18n.t("не вышло (пароль не введён?)", "it did not work (no password given?)");
                sddmStatus.running = true;
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Тема angelOS для экрана входа: тот же NGO-стрим, только «скоро эфир» — пиксельные обои, сердечки вместо пароля, чат ждёт, кнопки питания. Устанавливается в систему, поэтому спросит пароль администратора.", "angelOS's theme for the login screen: the same NGO stream, “starting soon” — pixel wallpaper, hearts for the password, a waiting chat, power buttons. It goes into the system, so it asks for the admin password.")
        }
        SettingRow {
            label: I18n.t("Цвета", "Colours")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("NGO-розовый", "NGO pink"),
                        "value": "ngo"
                    },
                    {
                        "label": I18n.t("Как в системе", "As the desktop"),
                        "value": "system"
                    }
                ]
                currentValue: sddmGroup.palette
                onActivated: v => sddmGroup.palette = v
            }
        }
        SettingRow {
            label: I18n.t("Обои как на рабочем столе", "Wallpaper as on the desktop")
            hint: sddmGroup.info.installed && sddmGroup.info.walls === false ? I18n.t("тема поставлена раньше — обновите её, чтобы обои менялись без пароля", "the theme predates this: update it so the wallpaper can follow without a password") : I18n.t("сменили обои — экран входа подхватит их сам: горизонтальным экранам горизонтальные, вертикальным вертикальные", "change the wallpaper and the login screen takes it too: landscape screens the landscape one, portrait screens the portrait one")
            PxToggle {
                checked: Config.lock.sddmWalls
                onToggled: c => Config.lock.sddmWalls = c
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: sddmGroup.info.installed ? I18n.t("Обновить тему входа", "Update the login theme") : I18n.t("Установить тему входа", "Install the login theme")
                icon: "download"
                accent: true
                enabled: !sddmInstall.running && sddmGroup.info.sddm !== false
                onClicked: {
                    sddmGroup.log = I18n.t("ставлю… (спросит пароль)", "installing… (asks for the password)");
                    sddmInstall.running = true;
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: sddmGroup.log !== "" ? sddmGroup.log : sddmGroup.info.sddm === false ? I18n.t("SDDM не установлен", "SDDM is not installed") : I18n.t("сейчас: ", "now: ") + (sddmGroup.info.current || "—") + (sddmGroup.info.current === "angelos" ? " ♡" : "")
            dim: sddmGroup.log === ""
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
                    lockPage.nav.settingsOpen = false;
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
