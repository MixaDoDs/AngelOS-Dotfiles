pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// The owner's debug page (Author → Debug, tree.json "owner": true): the layered wallpaper's
// night run by hand (services/SceneDebug: the meteor's timeline, its speed and colour, the hour of
// the day), what its sounds hear and decide (services/SceneSound), and the checks that used to
// live only behind `angelos …` commands. Nothing here is saved: a restart gives the clock back.
CatPage {
    id: page
    heading: I18n.t("Отладка", "Debug")
    subtitle: I18n.t("Только у автора. Ничего не сохраняется: после рестарта всё снова по часам.", "The author's only. Nothing is saved: after a restart it all runs by the clock again.")

    function clock(age) {
        const a = Math.abs(Math.round(age));
        const hh = Math.floor(a / 3600), mm = Math.floor(a % 3600 / 60), ss = a % 60;
        return (age < 0 ? "−" : "+") + (hh ? hh + ":" + ("0" + mm).slice(-2) : mm) + ":" + ("0" + ss).slice(-2);
    }
    function hhmm(hour) {
        const m = Math.round(hour * 60);
        return ("0" + Math.floor(m / 60)).slice(-2) + ":" + ("0" + m % 60).slice(-2);
    }

    CatGroup {
        id: meteor
        name: "meteor"
        title: I18n.t("Метеорит", "Meteor")
        icon: "sparkle"
        CatToggle {
            label: I18n.t("Вести вручную", "Run by hand")
            hint: SceneDebug.eventOn ? I18n.t("Сейчас ", "Now ") + page.clock(SceneDebug.eventAge) + I18n.t(" от удара", " from the impact") : I18n.t("Выключено — по часам: приближение с 03:20, удар в 04:00, следы до 20:00", "Off — by the clock: coming from 03:20, the impact at 04:00, traces till 20:00")
            checked: SceneDebug.eventOn
            onToggled: c => c ? SceneDebug.jump(SceneDebug.eventAge) : SceneDebug.eventOn = false
        }
        CatSlider {
            label: I18n.t("Время события", "Event time")
            hint: I18n.t("от −40 мин до +16 ч от удара; первые два часа — подробно", "From −40 min to +16 h from the impact; the first two hours in detail")
            // the first two hours get most of the slider: a square root past the impact
            from: -1000
            to: 1000
            showValue: false
            value: SceneDebug.eventAge < 0 ? SceneDebug.eventAge / 2.4 : Math.sqrt(SceneDebug.eventAge / SceneDebug.afterEnd) * 1000
            onMoved: v => SceneDebug.jump(v < 0 ? v * 2.4 : Math.pow(v / 1000, 2) * SceneDebug.afterEnd)
        }
        CatButton {
            text: I18n.t("Начало", "Start")
            icon: "play"
            onClicked: SceneDebug.jump(-2400)
        }
        CatButton {
            text: I18n.t("За минуту", "A minute before")
            onClicked: SceneDebug.jump(-60)
        }
        CatButton {
            text: I18n.t("Удар", "Impact")
            onClicked: SceneDebug.jump(-2)
        }
        CatButton {
            text: I18n.t("+1 час", "+1 hour")
            onClicked: SceneDebug.jump(3600)
        }
        CatButton {
            text: SceneDebug.playing ? I18n.t("Пауза", "Pause") : I18n.t("Дальше", "Go on")
            onClicked: SceneDebug.playing = !SceneDebug.playing
        }
        CatChoice {
            label: I18n.t("Скорость", "Speed")
            model: [1, 10, 60, 600].map(v => ({
                        "label": "×" + v,
                        "value": v
                    }))
            currentValue: SceneDebug.speed
            onActivated: v => SceneDebug.speed = v
        }
        CatChoice {
            label: I18n.t("Цвет", "Colour")
            hint: I18n.t("«Свой у ночи»: обычно огонь, иногда другой — по дате", "The night's own: mostly fire, now and then another, by the date")
            model: [[-1, "Свой у ночи", "The night's own"], [0, "Огонь", "Fire"], [1, "Багровый", "Crimson"], [2, "Изумрудный", "Emerald"], [3, "Лазурный", "Azure"], [4, "Фиолетовый", "Violet"], [5, "Белое золото", "White gold"]].map(c => ({
                        "label": I18n.t(c[1], c[2]),
                        "value": c[0]
                    }))
            currentValue: SceneDebug.variant
            onActivated: v => SceneDebug.variant = v
        }
        CatButton {
            text: I18n.t("Всё по часам", "All by the clock")
            icon: "refresh"
            onClicked: SceneDebug.reset()
        }
    }

    CatGroup {
        name: "night"
        title: I18n.t("Время суток", "Time of day")
        icon: "image"
        CatSlider {
            label: I18n.t("Время суток", "Time of day")
            hint: (SceneDebug.hour < 0 ? I18n.t("По часам. ", "By the clock. ") : I18n.t("Сейчас ", "Now ") + page.hhmm(SceneDebug.hour) + ". ") + I18n.t("Закат 20–21, ночь 21–22, рассвет 06–07, день с 07–08", "Dusk 20–21, night 21–22, dawn 06–07, day from 07–08")
            from: 0
            to: 1435
            stepSize: 5
            showValue: false
            value: (SceneDebug.hour < 0 ? new Date().getHours() + new Date().getMinutes() / 60 : SceneDebug.hour) * 60
            onMoved: v => SceneDebug.hour = v / 60
        }
        CatRepeat {
            model: [[13, "Полдень", "Noon"], [20.5, "Закат", "Dusk"], [21.5, "Сумерки", "Nightfall"], [1, "Ночь", "Night"], [6.5, "Рассвет", "Dawn"], [7.5, "Утро", "Morning"]]
            delegate: CatButton {
                required property var modelData
                text: I18n.t(modelData[1], modelData[2]) + " " + page.hhmm(modelData[0])
                onClicked: SceneDebug.hour = modelData[0]
            }
        }
        CatButton {
            text: I18n.t("По часам", "By the clock")
            icon: "refresh"
            onClicked: SceneDebug.hour = -1
        }
        CatButton {
            text: I18n.t("Порыв ветра", "A gust")
            onClicked: SceneWind.pulse = 1
        }
    }

    CatGroup {
        name: "sound"
        title: I18n.t("Звуки обоев", "Wallpaper sounds")
        icon: "volume"
        CatNote {
            text: I18n.t("Сейчас: ", "Now: ") + SceneSound.why + (SceneSound.dir ? " · " + SceneSound.dir.split("/").slice(-2).join("/") : "") + I18n.t(" · воздух ", " · air ") + Math.round(SceneSound.airDuck * 100) + " %" + (SceneSound.music ? I18n.t(" · музыка", " · music") : "") + (SceneSound.video ? I18n.t(" · видео", " · video") : "")
        }
        CatButton {
            text: I18n.t("Свист", "Whistle")
            onClicked: SceneSound.cue("whistle")
        }
        CatButton {
            text: I18n.t("Удар", "Impact")
            onClicked: SceneSound.cue("impact")
        }
        CatButton {
            text: I18n.t("Сирена", "Siren")
            onClicked: SceneSound.cue("siren")
        }
        CatButton {
            text: I18n.t("Помехи ЭЛТ", "CRT static")
            onClicked: SceneSound.cue("static")
        }
    }

    CatGroup {
        name: "tools"
        title: I18n.t("Проверки", "Checks")
        icon: "chip"
        CatButton {
            text: I18n.t("Уведомление", "Notification")
            onClicked: Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Привет ♡", "Hello ♡"), I18n.t("тестовое уведомление", "test notification")])
        }
        CatButton {
            text: I18n.t("Громкость (OSD)", "Volume (OSD)")
            onClicked: Audio.changed("volume")
        }
        CatButton {
            text: I18n.t("Экран загрузки", "Boot screen")
            onClicked: Shell.bootOpen = true
        }
        CatButton {
            text: I18n.t("Экран блокировки", "Lock screen")
            hint: I18n.t("без блокировки: Esc или любой пароль закрывает", "Without locking: Esc or any password closes it")
            onClicked: if (!Shell.setupLocked)
                Shell.lockPreview = !Shell.lockPreview
        }
        CatButton {
            text: I18n.t("Замер 10 с", "Measure 10 s")
            hint: I18n.t("что грузит процессор; отчёт — angelos perfReport", "What loads the CPU; the report: angelos perfReport")
            onClicked: Perf.start(10)
        }
        CatButton {
            present: GameDebug.allowed
            text: I18n.t("Отладка игры", "Game debug")
            onClicked: GameDebug.toggle()
        }
    }
}
