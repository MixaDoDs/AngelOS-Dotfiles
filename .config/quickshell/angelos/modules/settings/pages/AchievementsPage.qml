pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The achievements (services/Achievements) and heaven's things they open (services/Heaven):
// what is earned, how far along the rest are, what each of heaven's things waits for.
// The game off ("Just the desktop"): no achievements, all of heaven open — the page says so.
// Things (story/items.json) are listed with their pictures and open from here (the diary key →
// the Angel's diary, with the side its cover opens from). Hell's achievements wear a pentagram.
PxPage {
    id: page

    heading: I18n.t("Достижения", "Achievements")
    subtitle: !Story.enabled ? I18n.t("Игра выключена: достижений нет, а всё из рая открыто — меню, курсоры, внешности, эффекты.", "The game is off: no achievements, and all of heaven is open — the menus, cursors, looks and effects.") : I18n.t("Маленькие дела на рабочем столе: сначала совсем простые, потом сложнее. Некоторые открывают райские вещи. Получено: ", "Little things done on the desk: very easy at first, then harder. Some open heaven's things. Earned: ") + Achievements.earned + " / " + Achievements.total

    function dateText(ms) {
        return ms ? new Date(ms).toLocaleDateString(I18n.english ? Qt.locale("en_GB") : Qt.locale("ru_RU"), "d MMM yyyy") : "";
    }

    PxGroup {
        name: "achievements"
        width: parent.width
        title: I18n.t("Достижения", "Achievements")
        icon: "star"

        PxText {
            visible: !Story.enabled
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Включи игру (Ангелочек → Игра), чтобы получать достижения.", "Turn the game on (The angel → The game) to earn achievements.")
        }
        Repeater {
            model: Story.enabled ? Achievements.tiers : []
            Column {
                id: tier
                required property var modelData
                readonly property var items: Achievements.list.filter(a => Number(a.tier || 1) === Number(tier.modelData.id))
                visible: items.length > 0
                width: parent.width
                spacing: Theme.u * 2
                PxText {
                    width: parent.width
                    kind: "title"
                    font.bold: true
                    text: Theme.roman(Number(tier.modelData.id) || 1) + " · " + I18n.t(tier.modelData.ru || tier.modelData.en || "", tier.modelData.en || tier.modelData.ru || "") + "  " + tier.items.filter(a => Achievements.has(a.id)).length + "/" + tier.items.length
                }
                Repeater {
                    model: tier.items
                    SettingRow {
                        id: row
                        required property var modelData
                        readonly property bool done: Achievements.has(modelData.id)
                        readonly property var prog: done ? null : Achievements.progress(modelData)
                        width: parent.width
                        label: (done ? (row.modelData.hell ? "✠ " : "✓ ") : "") + Achievements.nameOf(modelData)
                        hint: Achievements.descOf(modelData) + (prog ? " · " + prog.n + "/" + prog.of : "") + (modelData.reward && (done || !modelData.secret) ? I18n.t(" · открывает: ", " · opens: ") + Heaven.label(modelData.reward) : "") + (modelData.pluginName ? I18n.t(" · плагин ", " · plugin ") + I18n.label(modelData.pluginName) : "") + (done ? " · " + page.dateText(Achievements.got[modelData.id]) : "")
                        PxIcon {
                            name: row.done ? (row.modelData.icon || "star") : row.modelData.hell ? "pentagram" : "lock"
                            pixel: Theme.u * 2
                            opacity: row.done ? 1 : 0.45
                            fill: row.modelData.hell ? Theme.hellBlood : Theme.accent
                        }
                    }
                }
            }
        }
    }

    PxGroup {
        name: "things"
        width: parent.width
        title: I18n.t("Вещи", "Things")
        icon: "sparkleStar"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("То, что достижения оставляют в карточке. Каждая вещь что-то открывает.", "What achievements leave in their card. Each thing opens something.")
        }
        Repeater {
            model: Heaven.things
            SettingRow {
                id: thingRow
                required property var modelData
                readonly property bool open: Heaven.has(modelData.id)
                readonly property var giver: Achievements.giverOf(modelData.id)
                width: parent.width
                label: I18n.t(modelData.ru, modelData.en)
                hint: open ? (I18n.label(modelData.desc) || "") + (modelData.opens === "diary" && Diary.unread > 0 ? I18n.t(" · новых страниц: ", " · new pages: ") + Diary.unread : "") : Heaven.lockHint(modelData.id)
                Row {
                    spacing: Theme.u * 4
                    Rectangle {
                        width: Theme.u * 20
                        height: width
                        color: Theme.sunken
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: Theme.edge
                        PxIcon {
                            anchors.centerIn: parent
                            // from Heaven itself: through the Repeater's modelData the rows are no JS array
                            readonly property var tex: (Heaven.thing(thingRow.modelData.id) || {}).texture || null
                            bitmap: tex ? tex.rows : null
                            palette: tex ? tex.palette : ({})
                            pixel: Math.max(1, Math.floor(parent.width * 0.8 / Math.max(1, tex ? Math.max(tex.rows.length, tex.rows[0].length) : 1)))
                            opacity: thingRow.open ? 1 : 0.25
                        }
                        PxIcon {
                            visible: !thingRow.open
                            anchors.centerIn: parent
                            name: "lock"
                            pixel: Theme.u
                        }
                    }
                    PxButton {
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        icon: thingRow.open ? (thingRow.modelData.opens === "diary" ? "document" : "arrowRight") : "lock"
                        enabled: thingRow.open
                        text: thingRow.open ? I18n.t("Открыть", "Open") : I18n.t("Закрыто", "Locked")
                        onClicked: Heaven.use(thingRow.modelData.id)
                    }
                }
            }
        }
        SettingRow {
            visible: !!Diary.thing
            width: parent.width
            label: I18n.t("Закладка дневника на краю экрана", "The diary's bookmark on a screen edge")
            hint: Diary.hidden ? I18n.t("её больше нет: ангел застала тебя и спрятала дневник сюда — открыть можно только кнопкой выше", "gone: the angel caught you and hid the diary here — only the button above opens it now") : Diary.owned ? I18n.t("клик — открыть дневник, перетащить — на другой край; цифра — непрочитанные страницы. Это её дневник: читай, пока она отошла", "click: open the diary; drag: to another edge; the number: pages not read yet. It's her diary: read it while she's away") : I18n.t("появится, когда будет ключ", "shows once the key is had")
            PxToggle {
                checked: Config.game.diaryTab !== false
                onToggled: c => Config.game.diaryTab = c
            }
        }
        SettingRow {
            visible: !!Diary.thing
            width: parent.width
            label: I18n.t("Дневник открывается", "The diary opens")
            hint: I18n.t("с какой стороны распахивается обложка", "which side its cover swings open from")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("справа", "from the right"),
                        "value": "right"
                    },
                    {
                        "label": I18n.t("слева", "from the left"),
                        "value": "left"
                    }
                ]
                currentValue: Diary.side
                onActivated: v => Config.game.diarySide = v
            }
        }
    }

    PxGroup {
        name: "heaven"
        width: parent.width
        title: I18n.t("Рай", "Heaven")
        icon: "sparkle"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: !Story.enabled ? I18n.t("Без игры всё открыто.", "Without the game everything is open.") : I18n.t("Райские вещи открываются достижениями. Выбранное, но ещё закрытое, не теряется: пока его нет, стоит обычное, а получишь — вернётся само.", "Heaven's things open with achievements. A pick that is still locked isn't lost: the usual one stands in until it's earned, then yours comes back by itself.")
        }
        Repeater {
            model: Heaven.looks
            SettingRow {
                id: thing
                required property var modelData
                readonly property bool open: Heaven.has(modelData.id)
                width: parent.width
                label: (open ? "♡ " : "") + I18n.t(modelData.ru, modelData.en)
                hint: open ? I18n.t("открыто", "open") : Heaven.lockHint(modelData.id)
                PxButton {
                    compact: true
                    icon: thing.open ? "arrowRight" : "lock"
                    enabled: thing.open
                    text: thing.open ? I18n.t("Выбрать", "Pick") : I18n.t("Закрыто", "Locked")
                    onClicked: Shell.settingsGo(page, thing.modelData.page)
                }
            }
        }
    }
}
