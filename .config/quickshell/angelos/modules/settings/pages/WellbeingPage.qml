pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Wellbeing (2026-10-08; services/Wellbeing), like GNOME's and Noctalia's: today's screen time,
// the week as bars, the day by the hour and by app; the breaks the angel reminds you of (the
// eyes, a stretch, water — with the day's glasses), a daily limit, when to keep quiet.
PxPage {
    id: page
    heading: I18n.t("Благополучие", "Wellbeing")
    subtitle: I18n.t("Сколько ты за компьютером, и перерывы, о которых напомнит ангел.", "How long you're at the computer, and the breaks the angel reminds you of.")

    readonly property var w: Config.wellbeing
    readonly property bool hell: Angel.demon
    readonly property string who: hell ? I18n.t("демоница", "the demon") : I18n.t("ангел", "the angel")
    readonly property var wd: I18n.english ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
    readonly property var week: Wellbeing.lastDays(7)
    readonly property int avg: Wellbeing.average(7)
    readonly property real weekMax: Math.max(3600, w.dailyLimit * 60, ...week.map(d => d.s))
    readonly property var hourly: Wellbeing.hours()
    readonly property real hourMax: Math.max(600, ...hourly)
    readonly property var apps: Wellbeing.topApps("", 5)
    readonly property color barColor: Theme.mix(Theme.face, Theme.accent, 0.45)
    readonly property color water: Theme.mix(Theme.accent2, "#4aa8ff", 0.7)

    PxGroup {
        name: "screen-time"
        title: I18n.t("Экранное время", "Screen time")
        icon: "clock"
        width: parent.width

        Row {
            spacing: Theme.u * 6
            Column {
                anchors.verticalCenter: parent.verticalCenter
                PxText {
                    text: page.w.track ? Wellbeing.fmt(Wellbeing.todaySeconds) : I18n.t("не считается", "not counted")
                    kind: "huge"
                }
                PxText {
                    text: I18n.t("сегодня", "today") + (page.avg > 0 ? I18n.t(" · в среднем ", " · on average ") + Wellbeing.fmt(page.avg) : "") + (page.w.dailyLimit > 0 ? I18n.t(" · лимит ", " · limit ") + Wellbeing.fmt(page.w.dailyLimit * 60) : "")
                    dim: true
                }
            }
        }

        // the week: a bar a day, today in the accent; the limit as a line across
        Item {
            id: chart
            width: Math.min(parent.width, Theme.u * 180)
            height: Theme.u * 44
            readonly property real barArea: height - Theme.u * 8
            Row {
                id: bars
                anchors.fill: parent
                spacing: Theme.u * 3
                Repeater {
                    model: page.week
                    delegate: Item {
                        id: col
                        required property var modelData
                        required property int index
                        readonly property bool today: index === page.week.length - 1
                        width: (bars.width - bars.spacing * 6) / 7
                        height: bars.height
                        Rectangle {
                            id: bar
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: chart.barArea - height
                            width: parent.width * 0.62
                            height: Math.max(Theme.u, chart.barArea * col.modelData.s / page.weekMax)
                            radius: Theme.fluentFor(page) ? Theme.u : 0
                            color: col.today ? Theme.accent : page.w.dailyLimit > 0 && col.modelData.s > page.w.dailyLimit * 60 ? Theme.mix(page.barColor, Theme.danger, 0.4) : page.barColor
                            Behavior on height {
                                NumberAnimation {
                                    duration: Motion.ms(240)
                                }
                            }
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: bar.top
                            anchors.bottomMargin: Theme.u
                            visible: (col.today || hover.containsMouse) && col.modelData.s >= 60
                            text: Wellbeing.fmt(col.modelData.s)
                            kind: "tiny"
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: page.wd[col.modelData.date.getDay()]
                            kind: "tiny"
                            dim: !col.today
                        }
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
            Rectangle {
                visible: page.w.dailyLimit > 0
                x: 0
                width: parent.width
                height: Math.max(1, Theme.u / 2)
                y: chart.barArea - chart.barArea * page.w.dailyLimit * 60 / page.weekMax
                color: Theme.danger
                opacity: 0.6
            }
        }

        // today by the hour
        PxText {
            visible: page.w.track && Wellbeing.todaySeconds >= 60
            text: I18n.t("Сегодня по часам", "Today by the hour")
            kind: "tiny"
            dim: true
        }
        Item {
            visible: page.w.track && Wellbeing.todaySeconds >= 60
            width: chart.width
            height: Theme.u * 18
            Row {
                id: hourRow
                width: parent.width
                height: Theme.u * 12
                spacing: Math.max(1, Theme.u / 2)
                Repeater {
                    model: page.hourly
                    delegate: Item {
                        required property real modelData
                        required property int index
                        width: (hourRow.width - hourRow.spacing * 23) / 24
                        height: hourRow.height
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(1, parent.height * parent.modelData / page.hourMax)
                            color: parent.index === new Date().getHours() ? Theme.accent : page.barColor
                            opacity: parent.modelData > 0 ? 1 : 0.35
                        }
                    }
                }
            }
            Repeater {
                model: [0, 6, 12, 18]
                delegate: PxText {
                    required property int modelData
                    x: hourRow.width * modelData / 24
                    anchors.bottom: parent.bottom
                    text: modelData + I18n.t(":00", ":00")
                    kind: "tiny"
                    dim: true
                }
            }
        }

        // the apps of the day
        PxText {
            visible: page.w.apps && page.apps.length > 0
            text: I18n.t("Приложения сегодня", "Apps today")
            kind: "tiny"
            dim: true
        }
        Column {
            visible: page.w.apps && page.apps.length > 0
            width: chart.width
            spacing: Theme.u * 2
            Repeater {
                model: page.apps
                delegate: Row {
                    id: appRow
                    required property var modelData
                    spacing: Theme.u * 3
                    width: parent.width
                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        appId: appRow.modelData.id
                        size: Theme.u * 7
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 46
                        elide: Text.ElideRight
                        text: appRow.modelData.name
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(Theme.u, (appRow.width - Theme.u * 92) * appRow.modelData.s / Math.max(1, page.apps[0].s))
                        height: Theme.u * 2
                        color: page.barColor
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Wellbeing.fmt(appRow.modelData.s)
                        kind: "tiny"
                        dim: true
                    }
                }
            }
        }

        SettingRow {
            label: I18n.t("Считать экранное время", "Count screen time")
            hint: I18n.t("пока ты за компьютером: не заблокирован, что-то делаешь (видео тоже считается)", "While you're at it: unlocked and doing something (a video counts too)")
            PxToggle {
                checked: page.w.track
                onToggled: v => page.w.track = v
            }
        }
        SettingRow {
            visible: page.w.track
            label: I18n.t("По приложениям", "Per app")
            hint: I18n.t("какое окно было в фокусе; остаётся только на этом компьютере", "Which window had the focus; stays on this computer only")
            PxToggle {
                checked: page.w.apps
                onToggled: v => page.w.apps = v
            }
        }
    }

    PxGroup {
        name: "breaks"
        title: I18n.t("Перерывы", "Breaks")
        icon: "heart"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Время до перерыва идёт, только пока ты за компьютером. Отошёл на 20 секунд — глаза отдохнули; на ", "The time till a break runs only while you're at the computer. Away for 20 seconds rests the eyes; for ") + page.w.moveLength + I18n.t(" мин — это и есть перерыв, всё начинается заново.", " min, that's the break, and it all starts over.")
        }
        SettingRow {
            label: I18n.t("Напоминать о перерывах", "Remind me of breaks")
            PxToggle {
                checked: page.w.breaks
                onToggled: v => page.w.breaks = v
            }
        }
        SettingRow {
            visible: page.w.breaks
            label: I18n.t("Кто напоминает", "Who reminds")
            hint: I18n.t("когда ангела нет на экране — всё равно уведомлением", "When the angel isn't on screen, a notification anyway")
            PxSegmented {
                model: [
                    {
                        "label": page.hell ? I18n.t("Демоница", "The demon") : I18n.t("Ангел", "The angel"),
                        "value": "angel"
                    },
                    {
                        "label": I18n.t("Уведомление", "Notification"),
                        "value": "notify"
                    }
                ]
                currentValue: page.w.via
                onActivated: v => page.w.via = v
            }
        }

        SettingRow {
            visible: page.w.breaks
            label: I18n.t("Дать глазам отдохнуть", "Rest the eyes")
            hint: I18n.t("посмотреть вдаль 20 секунд (правило 20-20-20)", "Look far away for 20 seconds (the 20-20-20 rule)") + (page.w.eyes ? I18n.t(" · через ", " · in ") + Wellbeing.dueIn("eyes") + I18n.t(" мин", " min") : "")
            Row {
                spacing: Theme.u * 3
                PxSpin {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.w.eyes
                    from: 5
                    to: 90
                    stepSize: 5
                    value: page.w.eyesEvery
                    suffix: I18n.t(" мин", " min")
                    onMoved: v => page.w.eyesEvery = v
                }
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.w.eyes
                    onToggled: v => page.w.eyes = v
                }
            }
        }
        SettingRow {
            visible: page.w.breaks
            label: I18n.t("Встать и размяться", "Stand up and stretch")
            hint: I18n.t("после стольких минут за компьютером", "After this many minutes at the computer") + (page.w.move ? I18n.t(" · через ", " · in ") + Wellbeing.dueIn("move") + I18n.t(" мин", " min") : "")
            Row {
                spacing: Theme.u * 3
                PxSpin {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.w.move
                    from: 15
                    to: 180
                    stepSize: 5
                    value: page.w.moveEvery
                    suffix: I18n.t(" мин", " min")
                    onMoved: v => page.w.moveEvery = v
                }
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.w.move
                    onToggled: v => page.w.move = v
                }
            }
        }
        SettingRow {
            visible: page.w.breaks && page.w.move
            label: I18n.t("Длина перерыва", "Break length")
            hint: I18n.t("столько нужно не трогать компьютер, чтобы перерыв засчитался", "How long away from the computer counts as the break")
            PxSpin {
                from: 1
                to: 30
                value: page.w.moveLength
                suffix: I18n.t(" мин", " min")
                onMoved: v => page.w.moveLength = v
            }
        }
        SettingRow {
            visible: page.w.breaks
            label: I18n.t("Попить воды", "Drink some water")
            hint: I18n.t("кнопка «Попил(а)» в напоминании считает стаканы", "The reminder's “Done” button counts the glasses") + (page.w.water ? I18n.t(" · через ", " · in ") + Wellbeing.dueIn("water") + I18n.t(" мин", " min") : "")
            Row {
                spacing: Theme.u * 3
                PxSpin {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.w.water
                    from: 15
                    to: 180
                    stepSize: 5
                    value: page.w.waterEvery
                    suffix: I18n.t(" мин", " min")
                    onMoved: v => page.w.waterEvery = v
                }
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.w.water
                    onToggled: v => page.w.water = v
                }
            }
        }

        // the day's glasses: a drop each, filled as you drink
        SettingRow {
            visible: page.w.breaks && page.w.water
            label: I18n.t("Выпито сегодня", "Drunk today")
            hint: Wellbeing.waterToday >= page.w.waterGoal ? I18n.t("норма есть ♡", "goal reached ♡") : I18n.t("ещё ", "") + (page.w.waterGoal - Wellbeing.waterToday) + I18n.t(" до нормы", " more to go")
            Row {
                spacing: Theme.u * 2
                Flow {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u
                    width: Math.min(Theme.u * 80, Theme.u * 11 * Math.max(page.w.waterGoal, Wellbeing.waterToday))
                    Repeater {
                        model: Math.max(page.w.waterGoal, Wellbeing.waterToday)
                        delegate: PxIcon {
                            required property int index
                            name: "drop"
                            pixel: Theme.u
                            hollow: index >= Wellbeing.waterToday
                            fill2: index >= page.w.waterGoal ? Theme.accent : page.water
                            opacity: index >= Wellbeing.waterToday ? 0.45 : 1
                        }
                    }
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wellbeing.waterToday + " / " + page.w.waterGoal
                    kind: "title"
                }
                PxButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("+ стакан", "+ glass")
                    icon: "drop"
                    compact: true
                    onClicked: Wellbeing.drink()
                }
                PxButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Wellbeing.waterToday > 0
                    text: "−"
                    compact: true
                    onClicked: Wellbeing.undrink()
                }
            }
        }
        SettingRow {
            visible: page.w.breaks && page.w.water
            label: I18n.t("Стаканов в день", "Glasses a day")
            PxSpin {
                from: 1
                to: 20
                value: page.w.waterGoal
                onMoved: v => page.w.waterGoal = v
            }
        }
        SettingRow {
            visible: page.w.breaks
            label: I18n.t("Проверить", "Try it")
            hint: Wellbeing.quietWhy === "fullscreen" ? I18n.t("сейчас окно на весь экран — настоящее напоминание подождёт", "A window fills the screen now: a real reminder would wait") : Wellbeing.quietWhy === "stream" ? I18n.t("сейчас стрим — настоящее напоминание подождёт", "You're streaming: a real reminder would wait") : Wellbeing.quietWhy === "dnd" ? I18n.t("сейчас «Не беспокоить» — настоящее напоминание подождёт", "Do not disturb is on: a real reminder would wait") : I18n.t("так напомнит ", "This is how ") + page.who + I18n.t("", " will remind you")
            Row {
                spacing: Theme.u * 2
                PxButton {
                    text: I18n.t("Глаза", "Eyes")
                    compact: true
                    onClicked: Wellbeing.remind("eyes", true)
                }
                PxButton {
                    text: I18n.t("Размяться", "Stretch")
                    compact: true
                    onClicked: Wellbeing.remind("move", true)
                }
                PxButton {
                    text: I18n.t("Вода", "Water")
                    compact: true
                    onClicked: Wellbeing.remind("water", true)
                }
            }
        }
    }

    PxGroup {
        name: "limit"
        title: I18n.t("Дневной лимит", "Daily limit")
        icon: "moon"
        width: parent.width
        SettingRow {
            label: I18n.t("Не больше в день", "No more a day")
            hint: I18n.t("0 — без лимита; на графике — красная линия", "0 = no limit; the red line on the chart")
            PxSpin {
                from: 0
                to: 16
                stepSize: 0.5
                decimals: 1
                value: page.w.dailyLimit / 60
                suffix: I18n.t(" ч", " h")
                onMoved: v => page.w.dailyLimit = Math.round(v * 60)
            }
        }
        SettingRow {
            visible: page.w.dailyLimit > 0
            label: I18n.t("Предупреждать на лимите", "Warn at the limit")
            hint: I18n.t("«Ещё 15 минут» — и она скажет снова; «Хватит на сегодня» откроет меню выключения", "“15 more minutes” and she says it again; “Done for today” opens the power menu")
            PxToggle {
                checked: page.w.limitWarn
                onToggled: v => page.w.limitWarn = v
            }
        }
    }

    PxGroup {
        name: "quiet"
        title: I18n.t("Когда не мешать", "When not to disturb")
        icon: "bell"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Напоминание не теряется — оно ждёт и приходит, как только станет можно.", "The reminder isn't lost: it waits and comes as soon as it can.")
        }
        SettingRow {
            label: I18n.t("Игра или видео на весь экран", "A game or a video on the whole screen")
            PxToggle {
                checked: page.w.quietFullscreen
                onToggled: v => page.w.quietFullscreen = v
            }
        }
        SettingRow {
            label: I18n.t("Во время стрима", "While streaming")
            PxToggle {
                checked: page.w.quietStream
                onToggled: v => page.w.quietStream = v
            }
        }
        SettingRow {
            label: I18n.t("В режиме «Не беспокоить»", "With do not disturb")
            PxToggle {
                checked: page.w.quietDnd
                onToggled: v => page.w.quietDnd = v
            }
        }
    }

    PxGroup {
        name: "history"
        title: I18n.t("История", "History")
        icon: "document"
        width: parent.width
        SettingRow {
            label: I18n.t("Хранить дней", "Keep days")
            hint: "~/.local/state/angelos/screen-time.json"
            PxSpin {
                from: 7
                to: 365
                stepSize: 7
                value: page.w.keepDays
                onMoved: v => page.w.keepDays = v
            }
        }
        SettingRow {
            label: I18n.t("Стереть историю", "Clear the history")
            hint: I18n.t("всё экранное время и стаканы воды", "All the screen time and the glasses of water")
            PxButton {
                text: I18n.t("Стереть", "Clear")
                icon: "trash"
                danger: true
                compact: true
                onClicked: Wellbeing.clear()
            }
        }
    }
}
