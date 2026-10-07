import QtQuick
import qs.config
import qs.services
import qs.widgets

// You (the card at the top of the sidebar, like macOS's account): the avatar and the name
// every Start look shows (StartPrefs), the language, the setup wizard and the tips, and
// the everyday buttons — the pages you open most.
PxPage {
    id: page

    heading: StartPrefs.userName
    subtitle: I18n.t("Аватарка и имя видны во всех стилях «Пуска». Язык, мастер первого запуска и подсказки по интерфейсу — тоже здесь.", "The avatar and the name show in every Start look. The language, the setup wizard and the interface tips live here too.")

    readonly property var fallbackFrequent: [
        {
            "id": "sound",
            "icon": "speaker",
            "label": I18n.t("Громкость", "Volume")
        },
        {
            "id": "shortcuts",
            "icon": "keyboard",
            "label": I18n.t("Горячие клавиши", "Shortcuts")
        },
        {
            "id": "widgets",
            "icon": "layers",
            "label": I18n.t("Виджеты на столе", "Desktop widgets")
        }
    ]
    // the four most visited pages (Config.settingsUi.usage); the defaults while there is no history
    readonly property var frequent: {
        // visits counted under old page ids count for their pages in the tree
        const raw = Config.settingsUi.usage || {};
        const usage = {};
        for (const k in raw) {
            const to = SettingsTree.resolve(k).page;
            usage[to] = (usage[to] || 0) + raw[k];
        }
        const all = page.view ? page.view.allPages : [];
        const top = Object.keys(usage).filter(id => id !== "wallpaper" && id !== "theme" && id !== "updates" && id !== "account" && usage[id] >= 2 && all.some(p => p.id === id)).sort((a, b) => usage[b] - usage[a]).slice(0, 4).map(id => {
            const p = all.find(x => x.id === id);
            return {
                "id": id,
                "icon": p.icon,
                "label": p.label
            };
        });
        for (const f of fallbackFrequent)
            if (top.length < 3 && !top.some(t => t.id === f.id))
                top.push(f);
        return top;
    }

    PxGroup {
        name: "you"
        width: parent.width
        title: I18n.t("Ты", "You")
        icon: "heart"
        Row {
            spacing: Theme.u * 6
            PxBox {
                id: face
                width: Theme.u * 34
                height: width
                color: Theme.accent
                Image {
                    id: pic
                    anchors.fill: parent
                    anchors.margins: face.inset
                    source: StartPrefs.avatarUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Config.bar.avatarPixel ? Qt.size(20, 20) : Qt.size(width * 2, height * 2)
                    smooth: !Config.bar.avatarPixel
                    visible: status === Image.Ready
                }
                PxIcon {
                    visible: pic.status !== Image.Ready
                    anchors.centerIn: parent
                    name: "heart"
                    fill: "#ffffff"
                    pixel: Theme.u * 2
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StartPrefs.pickAvatar()
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.u * 3
                Flow {
                    width: page.innerWidth - face.width - Theme.u * 30
                    spacing: Theme.u * 3
                    PxButton {
                        compact: true
                        icon: "image"
                        text: StartPrefs.picking ? I18n.t("выбираю…", "picking…") : I18n.t("Выбрать аватарку…", "Choose an avatar…")
                        onClicked: StartPrefs.pickAvatar()
                    }
                    PxButton {
                        visible: !!Config.bar.avatar
                        compact: true
                        icon: "trash"
                        text: I18n.t("Убрать", "Remove")
                        onClicked: StartPrefs.clearAvatar()
                    }
                }
                PxText {
                    width: page.innerWidth - face.width - Theme.u * 30
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    dim: true
                    text: Config.bar.avatar ? I18n.t("копия лежит в ~/.local/share/angelos", "a copy is kept in ~/.local/share/angelos") : StartPrefs.systemAvatar ? I18n.t("сейчас — картинка системы", "now the system's picture") : I18n.t("пока сердечко", "a heart for now")
                }
                PxText {
                    width: page.innerWidth - face.width - Theme.u * 30
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    color: Theme.danger
                    text: StartPrefs.pickError
                }
            }
        }
        SettingRow {
            label: I18n.t("Имя", "Name")
            hint: I18n.t("пусто — имя пользователя системы", "Empty: the system's user name")
            PxField {
                width: Math.min(parent.width, Theme.u * 120)
                text: Config.bar.userName
                placeholder: StartPrefs.userName
                onEdited: Config.bar.userName = text
            }
        }
        SettingRow {
            label: I18n.t("Пиксельная аватарка", "Pixel avatar")
            hint: I18n.t("картинка крупными пикселями, как всё в angelOS", "The picture in big pixels, like the rest of angelOS")
            PxToggle {
                checked: Config.bar.avatarPixel
                onToggled: c => Config.bar.avatarPixel = c
            }
        }
    }

    PxGroup {
        name: "language-getting-started"
        width: parent.width
        title: I18n.t("Язык и знакомство", "Language and getting started")
        icon: "info"
        SettingRow {
            label: I18n.t("Язык", "Language")
            PxCombo {
                model: [
                    {
                        label: "Русский",
                        value: "ru"
                    },
                    {
                        label: "English",
                        value: "en"
                    }
                ]
                currentValue: Config.appearance.language
                onActivated: v => Config.appearance.language = v
            }
        }
        SettingRow {
            visible: !Shell.setupOpen
            label: I18n.t("Мастер первого запуска", "The setup wizard")
            hint: I18n.t("пройти ещё раз на весь экран: язык, игра, раскладки, тема, движение", "Go through it again, full screen: language, the game, layouts, theme, motion")
            PxButton {
                compact: true
                text: I18n.t("Открыть", "Open")
                icon: "sparkle"
                onClicked: Shell.setupOpen = true
            }
        }
        SettingRow {
            label: I18n.t("Подсказки по интерфейсу", "Interface tips")
            hint: I18n.t("кружки вокруг кнопок: что где", "Circles around the buttons: what's where")
            PxButton {
                compact: true
                text: I18n.t("Показать", "Show")
                icon: "info"
                onClicked: {
                    page.nav.settingsOpen = false;
                    Tour.start();
                }
            }
        }
    }

    // Recovery: progress + settings on your GitHub (a private repo) or in a file
    PxGroup {
        name: "recovery"
        width: parent.width
        title: I18n.t("Восстановление", "Recovery")
        icon: "refresh"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Прогресс игры (сюжет, ачивки, звёзды ✦) и все настройки, плагины и горячие клавиши — на твоём GitHub в приватном репозитории angelos-save или в файле. На новом компьютере или после переустановки — вернуть одной кнопкой.", "The game's progress (the story, achievements, stars ✦) and every setting, plugin and shortcut, on your GitHub in a private repository, angelos-save, or in a file. On a new computer or after a reinstall, bring it back with one button.")
        }
        SettingRow {
            label: "GitHub"
            hint: !Recovery.checked ? I18n.t("проверяю…", "checking…") : !Recovery.gh ? I18n.t("нет входа: Мастер первого запуска → GitHub (или gh auth login)", "not logged in: the setup wizard → GitHub (or gh auth login)") : Recovery.exists ? I18n.t("последнее сохранение: ", "last save: ") + (Recovery.last || "?") : I18n.t("сохранений ещё нет", "no saves yet")
            Row {
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    icon: "arrowUp"
                    enabled: Recovery.gh && Recovery.busy === ""
                    text: Recovery.busy === "push" ? I18n.t("Сохраняю…", "Saving…") : I18n.t("Сохранить", "Save")
                    onClicked: Recovery.push()
                }
                PxButton {
                    compact: true
                    icon: "download"
                    enabled: Recovery.gh && Recovery.exists && Recovery.busy === ""
                    text: Recovery.busy === "pull" ? I18n.t("Восстанавливаю…", "Restoring…") : I18n.t("Восстановить", "Restore")
                    onClicked: Recovery.pull()
                }
            }
        }
        SettingRow {
            label: I18n.t("Сохранять каждый день", "Save every day")
            hint: I18n.t("сам, раз в сутки, пока есть вход в GitHub", "by itself, once a day, while you're logged in to GitHub")
            PxToggle {
                checked: Config.recovery.auto
                onToggled: v => Config.recovery.auto = v
            }
        }
        SettingRow {
            label: I18n.t("Файл", "A file")
            hint: I18n.t("без GitHub: сохранить в ~/Documents или вернуть из файла", "without GitHub: save into ~/Documents or restore from a file")
            Row {
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    icon: "folder"
                    enabled: Recovery.busy === ""
                    text: I18n.t("В файл", "To a file")
                    onClicked: Recovery.exportNow()
                }
                PxButton {
                    compact: true
                    icon: "folder"
                    enabled: Recovery.busy === ""
                    text: I18n.t("Из файла…", "From a file…")
                    onClicked: Recovery.pickImport()
                }
            }
        }
        PxText {
            visible: Recovery.message !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Recovery.failed ? Theme.danger : Theme.accent
            text: (Recovery.failed ? "✕ " : "✓ ") + Recovery.message
        }
    }

    PxGroup {
        name: "everyday"
        width: parent.width
        title: I18n.t("Частое", "Everyday")
        icon: "star"
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: "image"
                text: I18n.t("Сменить обои", "Change wallpaper")
                onClicked: page.nav.settingsPage = "wallpaper"
            }
            // the theme and the size are set in one place (Theme and colours): a link to it
            PxButton {
                icon: "palette"
                text: I18n.t("Тема и размер ›", "Theme and size ›")
                onClicked: page.nav.settingsPage = "theme"
            }
            PxButton {
                icon: "download"
                accent: Updates.available
                text: Updates.available ? I18n.t("Обновление готово ♡", "Update available ♡") : I18n.t("Обновление", "Update")
                onClicked: page.nav.settingsPage = "updates"
            }
            Repeater {
                model: page.frequent
                PxButton {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.label
                    onClicked: page.nav.settingsPage = modelData.id
                }
            }
        }
    }
}
