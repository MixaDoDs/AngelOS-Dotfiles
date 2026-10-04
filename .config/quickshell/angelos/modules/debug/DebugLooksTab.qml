pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// How hell dresses things, circle by circle: a circle's look without the story going there
// (its palette, its Settings dress, its right-click menu, its cursor); which dress Settings
// and the menu wear; Settings' views and skins; cursor themes put on for a look.
Column {
    id: root

    spacing: Theme.u * 5

    PxGroup {
        width: parent.width
        title: I18n.t("Облик круга без сюжета", "A circle's look without the story")
        icon: "palette"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            kind: "tiny"
            text: I18n.t("Палитра, обои-затемнение, одежда настроек и меню, курсор — как в этом круге; сохранение не меняется. Сейчас: ", "Palette, backdrop, the dress of Settings and the menu, the cursor — as in that circle; the save stays. Now: ") + HellLook.circle + (GameDebug.lookOverridden ? I18n.t(" (подменён)", " (overridden)") : "")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            PxButton {
                compact: true
                checked: !GameDebug.lookOverridden
                text: I18n.t("Как в сюжете", "As the story says")
                onClicked: GameDebug.lookAsStory()
            }
            PxButton {
                compact: true
                checked: GameDebug.lookOverridden && HellLook.circle === "base"
                text: I18n.t("Ад без круга", "Hell, no circle")
                onClicked: GameDebug.lookCircle("base")
            }
            Repeater {
                model: Story.order
                PxButton {
                    required property string modelData
                    compact: true
                    checked: GameDebug.lookOverridden && HellLook.circle === modelData
                    text: Theme.roman(Story.circleN(modelData)) + " " + Story.circleName(modelData)
                    onClicked: GameDebug.lookCircle(modelData)
                }
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            PxButton {
                compact: true
                icon: "grid"
                text: I18n.t("Открыть ПКМ-меню", "Open the right-click menu")
                onClicked: {
                    const s = Shell.screenByName(GameDebug.screen);
                    GameDebug.note(s ? I18n.t("меню: ", "menu: ") + DeskMenu.style : "no screen");
                    const m = Shell.desktopMenus[GameDebug.screen];
                    if (m && s)
                        m.openAt(Math.round(s.width / 2), Math.round(s.height / 2));
                }
            }
            PxButton {
                compact: true
                icon: "gear"
                text: I18n.t("Открыть настройки", "Open Settings")
                onClicked: Shell.openSettings()
            }
        }
    }

    PxGroup {
        width: parent.width
        title: I18n.t("ПКМ-меню", "The right-click menu")
        icon: "grid"
        SettingRow {
            label: I18n.t("В аду", "In hell")
            hint: I18n.t("circle — облик круга (circles.json → dress.menu); сейчас: ", "circle: the circle's own (circles.json → dress.menu); now: ") + DeskMenu.style
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: ["circle", "pentagram"].concat(HellLook.dressMenuIds).concat(["radial", "y2k", "tiles", ""])
                    PxButton {
                        required property string modelData
                        compact: true
                        checked: (Config.y2k.hellMenu || "") === modelData
                        text: modelData || I18n.t("обычное", "usual")
                        onClicked: Config.y2k.hellMenu = modelData
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("В раю", "In heaven")
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: DeskMenu.styles
                    PxButton {
                        required property string modelData
                        compact: true
                        checked: Config.desktop.menuStyle === modelData
                        text: modelData
                        onClicked: Config.desktop.menuStyle = modelData
                    }
                }
            }
        }
    }

    PxGroup {
        width: parent.width
        title: I18n.t("Настройки", "Settings")
        icon: "gear"
        SettingRow {
            label: I18n.t("В аду", "In hell")
            hint: I18n.t("circle — облик круга (circles.json → dress.settings); сейчас: ", "circle: the circle's own (circles.json → dress.settings); now: ") + (HellLook.settingsPick || I18n.t("обычное окно", "the usual window"))
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: ["circle", "grimoire"].concat(HellLook.dressSettingsIds).concat([""])
                    PxButton {
                        required property string modelData
                        compact: true
                        checked: (Config.y2k.hellSettings || "") === modelData
                        text: modelData ? (modelData === "circle" ? "circle" : HellLook.dressName(modelData)) : I18n.t("обычное", "usual")
                        onClicked: Config.y2k.hellSettings = modelData
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Вид", "View")
            PxSegmented {
                model: ["win11", "sidebar", "controlpanel", "properties", "tiles"].map(v => ({
                            "label": v,
                            "value": v
                        }))
                currentValue: Config.settingsUi.view
                onActivated: v => Config.settingsUi.view = v
            }
        }
        SettingRow {
            label: I18n.t("Скин", "Skin")
            PxSegmented {
                model: ["classic", "windose", "stream"].map(v => ({
                            "label": v,
                            "value": v
                        }))
                currentValue: Config.settingsUi.skin
                onActivated: v => Config.settingsUi.skin = v
            }
        }
    }

    PxGroup {
        width: parent.width
        title: I18n.t("Курсоры", "Cursors")
        icon: "cursor"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            kind: "tiny"
            text: I18n.t("Сейчас на экране: ", "On screen now: ") + Cursors.active + I18n.t(" · настроение: ", " · mood: ") + (Cursors.mood || "—") + I18n.t(". «Надеть» ставит тему в систему на посмотреть; «Как хочет игра» — вернуть.", ". “Put on” puts a theme on the system for a look; “As the game wants” takes it back.") + (Shell.dev ? I18n.t(" (в dev-режиме курсор системы не меняется)", " (dev mode leaves the system cursor alone)") : "")
        }
        SettingRow {
            label: I18n.t("Курсор в аду", "Cursor in hell")
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: ["circle"].concat(Cursors.hellish.filter(c => !c.circle).map(c => c.theme)).concat([""])
                    PxButton {
                        required property string modelData
                        compact: true
                        checked: (Config.cursor.hell || "") === modelData
                        text: modelData || I18n.t("не трогать", "leave it")
                        onClicked: Cursors.setHell(modelData)
                    }
                }
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            PxButton {
                compact: true
                icon: "refresh"
                text: I18n.t("Как хочет игра", "As the game wants")
                onClicked: GameDebug.cursorBack()
            }
            Repeater {
                model: Cursors.catalog
                PxButton {
                    required property var modelData
                    compact: true
                    checked: Cursors.active === modelData.theme
                    text: modelData.theme + (modelData.installed ? "" : " ⬇")
                    onClicked: modelData.installed ? GameDebug.cursorTry(modelData.theme) : Cursors.install(modelData.id, false)
                }
            }
        }
    }
}
