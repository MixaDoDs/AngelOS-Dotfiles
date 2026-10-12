pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Presets (services/Presets): the author's few whole moods as cards — what each does in words,
// how many settings it would change now, the one that is on — and the user's own: everything as
// it is right now under a name, to come back to. Applying is undone here («Вернуть как было») or
// with Settings' Undo.
PxPage {
    id: page

    heading: I18n.t("Пресеты", "Presets")
    subtitle: I18n.t("Не хочется разбираться в сотне переключателей — выбери готовый набор. Потом любую настройку можно поправить руками.", "Don't feel like walking a hundred switches? Pick a ready set. Any setting can still be changed by hand afterwards.")

    function when(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "dd.MM.yyyy hh:mm");
    }

    PxGroup {
        name: "ready"
        title: I18n.t("Готовые", "Ready-made")
        icon: "sparkle"
        width: parent.width

        Grid {
            id: grid
            width: parent.width
            columns: Math.max(1, Math.min(2, Math.floor(width / (Theme.u * 110))))
            spacing: Theme.u * 4
            readonly property int cell: Math.floor((width - spacing * (columns - 1)) / columns)
            // every card as tall as the tallest: their buttons line up
            readonly property int tallest: {
                let m = 0;
                for (let i = 0; i < cards.count; i++) {
                    const it = cards.itemAt(i);
                    if (it)
                        m = Math.max(m, it.need);
                }
                return m;
            }
            Repeater {
                id: cards
                model: Presets.builtin
                Item {
                    id: card
                    required property var modelData
                    readonly property bool on: Presets.active === modelData.id
                    readonly property int changes: Presets.plan(modelData.id).length
                    readonly property int need: words.implicitHeight + Theme.u * 3 + foot.height
                    width: grid.cell
                    height: grid.tallest + Theme.u * 10
                    PxBox {
                        anchors.fill: parent
                        color: card.on ? Theme.mix(Theme.face, Theme.accent, 0.2) : Theme.face
                    }
                    Column {
                        id: words
                        x: Theme.u * 5
                        y: Theme.u * 5
                        width: parent.width - Theme.u * 10
                        spacing: Theme.u * 3
                        Row {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxIcon {
                                id: glyph
                                name: card.modelData.icon || "sparkle"
                                pixel: Math.max(1, Math.round(Theme.u * 0.75))
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            PxText {
                                width: parent.width - glyph.width - Theme.u * 3
                                kind: "title"
                                elide: Text.ElideRight
                                text: I18n.t(card.modelData.ru, card.modelData.en)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: I18n.t(card.modelData.hintRu || "", card.modelData.hintEn || "")
                        }
                        Column {
                            width: parent.width
                            spacing: Theme.u
                            Repeater {
                                model: I18n.english ? (card.modelData.pointsEn || []) : (card.modelData.pointsRu || [])
                                PxText {
                                    required property string modelData
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    kind: "tiny"
                                    dim: true
                                    text: "· " + modelData
                                }
                            }
                        }
                    }
                    Item {
                        id: foot
                        x: Theme.u * 5
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.u * 5
                        width: parent.width - Theme.u * 10
                        height: go.height
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - go.width - Theme.u * 3
                            elide: Text.ElideRight
                            kind: "tiny"
                            color: card.on ? Theme.accent : Theme.textDim
                            text: card.on ? I18n.t("✓ сейчас так", "✓ on now") : I18n.t("изменит настроек: ", "settings it changes: ") + card.changes
                        }
                        PxButton {
                            id: go
                            anchors.right: parent.right
                            accent: !card.on
                            enabled: !card.on
                            text: I18n.t("Применить", "Apply")
                            onClicked: Presets.apply(card.modelData.id)
                        }
                    }
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Готовый набор меняет только свой список настроек — движение, эффекты, ангела, обои, блокировку. Панель, клавиши, тема, игра и всё остальное остаются твоими.", "A ready set changes only its own list of settings: motion, effects, the angel, wallpapers, the lock screen. The bar, the keys, the theme, the game and everything else stay yours.")
        }
        SettingRow {
            visible: Presets.canUndo
            label: I18n.t("Не то?", "Not what you wanted?")
            hint: I18n.t("последний применённый набор отменяется целиком", "the last set applied is undone as a whole")
            PxButton {
                icon: "refresh"
                text: I18n.t("Вернуть как было", "Put it back")
                onClicked: Presets.undo()
            }
        }
    }

    PxGroup {
        name: "own"
        title: I18n.t("Мои", "Mine")
        icon: "heart"
        width: parent.width

        SettingRow {
            label: I18n.t("Сохранить как сейчас", "Save as it is now")
            hint: I18n.t("все настройки под именем, чтобы вернуться к ним одним нажатием; то же имя — перезаписать", "every setting under a name, to come back to in one click; the same name saves over")
            Row {
                spacing: Theme.u * 3
                PxField {
                    id: nameField
                    width: Theme.u * 70
                    placeholder: I18n.t("имя набора", "a name")
                    input.onAccepted: saveBtn.clicked()
                }
                PxButton {
                    id: saveBtn
                    icon: "plus"
                    enabled: nameField.text.trim() !== ""
                    text: I18n.t("Сохранить", "Save")
                    onClicked: {
                        if (Presets.save(nameField.text))
                            nameField.text = "";
                    }
                }
            }
        }
        PxText {
            visible: Presets.own.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Своих наборов пока нет. Настрой всё как нравится и сохрани — например, один для работы и один для стрима.", "No sets of your own yet. Set everything up the way you like and save it: one for work and one for streaming, say.")
        }
        Repeater {
            model: Presets.own
            SettingRow {
                id: mine
                required property var modelData
                readonly property int changes: Presets.plan(modelData.id).length
                label: modelData.name
                hint: page.when(modelData.at) + " · " + (changes ? I18n.t("отличается настроек: ", "settings that differ: ") + changes : I18n.t("сейчас так", "on now"))
                Row {
                    spacing: Theme.u * 3
                    PxButton {
                        enabled: mine.changes > 0
                        text: I18n.t("Применить", "Apply")
                        onClicked: Presets.apply(mine.modelData.id)
                    }
                    PxButton {
                        icon: "trash"
                        text: I18n.t("Удалить", "Delete")
                        onClicked: Presets.remove(mine.modelData.id)
                    }
                }
            }
        }
    }
}
