pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Spelling (services/Spell, scripts/spell.py): misspelt words underlined in the shell's own
// text fields — notes on the desktop, replies to notifications. A dictionary per language,
// downloaded here into the user's own folder; the system's Hunspell dictionaries count too.
PxPage {
    id: page

    heading: I18n.t("Орфография", "Spelling")
    subtitle: I18n.t("Слова с ошибками подчёркиваются в заметках и ответах на уведомления. Словари скачиваются по языкам.", "Misspelt words are underlined in notes and in replies to notifications. Dictionaries are downloaded per language.")
    Component.onCompleted: Spell.refresh()

    // what can be downloaded and fits what is typed; nothing typed: the usual ones
    readonly property var offered: {
        const q = find.text.trim().toLowerCase();
        const rest = Spell.catalog.filter(l => !l.installed);
        if (!q)
            return rest.filter(l => l.top);
        return rest.filter(l => l.code.toLowerCase().startsWith(q) || l.ru.toLowerCase().includes(q) || l.en.toLowerCase().includes(q)).slice(0, 12);
    }

    PxGroup {
        name: "check"
        title: I18n.t("Проверка", "The check")
        icon: "pen"
        width: parent.width

        PxText {
            visible: Spell.loaded && !Spell.engine
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: I18n.t("Не хватает пакета hunspell — без него проверять нечем. Поставь его (sudo pacman -S hunspell) и нажми «Проверить снова».", "The hunspell package is missing: there is nothing to check with. Install it (sudo pacman -S hunspell) and press “Look again”.")
        }
        PxText {
            visible: Spell.loaded && Spell.engine && Spell.installed.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Словарей пока нет — скачай свой язык ниже, и ошибки начнут подчёркиваться.", "No dictionaries yet: download your language below and mistakes get underlined.")
        }
        SettingRow {
            label: I18n.t("Подчёркивать ошибки", "Underline mistakes")
            hint: I18n.t("в заметках на рабочем столе и в ответах на уведомления; слова на языке без словаря не трогаются", "in the notes on the desktop and in replies to notifications; words of a language with no dictionary are left alone")
            PxToggle {
                checked: Config.spell.enabled
                onToggled: c => Config.spell.enabled = c
            }
        }
        SettingRow {
            label: I18n.t("Подсказывать исправления", "Offer corrections")
            hint: I18n.t("курсор в слове с ошибкой — под заметкой варианты и «в словарь»", "with the caret in a misspelt word, a note shows what it could be and “to my words”")
            PxToggle {
                checked: Config.spell.suggest
                onToggled: c => Config.spell.suggest = c
            }
        }
        SettingRow {
            label: I18n.t("Попробовать", "Try it")
            hint: I18n.t("напиши что-нибудь с ашибкой", "write something with a mistaik")
            PxTextArea {
                width: Theme.u * 110
                height: Theme.u * 42
                placeholder: I18n.t("пиши здесь…", "write here…")
            }
        }
    }

    PxGroup {
        name: "installed"
        title: I18n.t("Мои словари", "My dictionaries")
        icon: "document"
        width: parent.width

        PxText {
            visible: Spell.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: "✕ " + Spell.error
        }
        PxText {
            visible: Spell.loaded && Spell.installed.length === 0
            width: parent.width
            dim: true
            text: I18n.t("Пусто.", "None.")
        }
        Repeater {
            model: Spell.installed
            SettingRow {
                id: have
                required property var modelData
                label: Spell.title(modelData)
                hint: modelData.code + (modelData.source === "system" ? I18n.t(" · системный (пакет hunspell-…)", " · the system's (a hunspell-… package)") : "")
                Row {
                    spacing: Theme.u * 3
                    PxToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !Spell.off.includes(have.modelData.code)
                        onToggled: c => Spell.setOn(have.modelData.code, c)
                    }
                    PxButton {
                        visible: have.modelData.source === "user"
                        enabled: !Spell.working[have.modelData.code]
                        icon: "trash"
                        text: I18n.t("Удалить", "Delete")
                        onClicked: Spell.remove(have.modelData.code)
                    }
                }
            }
        }
        PxButton {
            icon: "refresh"
            text: I18n.t("Проверить снова", "Look again")
            onClicked: Spell.refresh()
        }
    }

    PxGroup {
        name: "download"
        title: I18n.t("Скачать язык", "Download a language")
        icon: "download"
        width: parent.width

        SettingRow {
            label: I18n.t("Найти язык", "Find a language")
            hint: I18n.t("всего их ", "there are ") + Spell.catalog.length + I18n.t("; ниже — частые", " of them; the usual ones are below")
            PxField {
                id: find
                width: Theme.u * 80
                icon: "search"
                placeholder: I18n.t("польский, de…", "Polish, de…")
            }
        }
        Repeater {
            model: page.offered
            SettingRow {
                id: lang
                required property var modelData
                label: Spell.title(modelData)
                hint: modelData.code
                PxButton {
                    enabled: !Spell.working[lang.modelData.code]
                    icon: "download"
                    text: Spell.working[lang.modelData.code] ? I18n.t("Скачиваю…", "Downloading…") : I18n.t("Скачать", "Download")
                    onClicked: Spell.install(lang.modelData.code)
                }
            }
        }
        PxText {
            visible: find.text.trim() !== "" && page.offered.length === 0
            width: parent.width
            dim: true
            text: I18n.t("Такого языка нет (или он уже скачан).", "No such language (or it is downloaded already).")
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Словари Hunspell из собрания wooorm/dictionaries, у каждого своя лицензия (лежит рядом со словарём в ~/.local/share/angelos/spell). Свои слова — в ~/.config/angelos/spell-words.txt.", "Hunspell dictionaries from the wooorm/dictionaries collection, each under its own licence (kept beside it in ~/.local/share/angelos/spell). Your own words are in ~/.config/angelos/spell-words.txt.")
        }
    }
}
