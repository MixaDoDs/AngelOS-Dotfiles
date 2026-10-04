pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Pixel cursor themes: download/build, preview, apply everywhere.
PxPage {
    id: page

    heading: I18n.t("Курсор", "Cursor")
    subtitle: I18n.t("Пиксельные курсоры одним нажатием — одинаковые в niri, GTK и Qt, X11/XWayland, Steam и Flatpak. Темы скачиваются с проверкой SHA-256.", "Pixel cursors in one click — the same in niri, GTK and Qt, X11/XWayland, Steam and Flatpak. Themes are downloaded with SHA-256 checks.")

    Component.onCompleted: Cursors.refresh()
    readonly property int size: Config.cursor.size || 24

    // one theme: preview strip, about, licence and the buttons; `hell` cards pick
    // the demon's cursor (Config.cursor.hell) instead of yours
    component CursorCard: PxBox {
        id: card
        required property var modelData
        property bool hell: false
        property int columns: 1
        property real gap: 0
        readonly property bool current: hell ? (Cursors.byCircle ? Cursors.circleTheme.startsWith(modelData.theme) && !!modelData.circle : Config.cursor.hell === modelData.theme) : Cursors.theme === modelData.theme
        readonly property bool working: Cursors.busy && (Cursors.working === modelData.id || Cursors.working === modelData.theme)
        width: (parent.width - (columns - 1) * gap) / columns
        height: cardCol.implicitHeight + Theme.u * 8
        sunken: current
        color: current ? Theme.mix(Theme.face, hell ? Theme.hellBlood : Theme.accent, 0.3) : Theme.face
        Column {
            id: cardCol
            x: Theme.u * 4
            y: Theme.u * 4
            width: parent.width - Theme.u * 8
            spacing: Theme.u * 2
            PxText {
                text: (card.current ? (card.hell ? "⛧ " : "♡ ") : "") + card.modelData.name
                font.bold: true
            }
            // preview strip: arrow, hand, text, wait, grab, forbidden
            Rectangle {
                width: parent.width
                height: Theme.u * 22
                color: card.hell ? Theme.hellBody : Theme.dark ? "#1b1d24" : "#e9e3ec"
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.lo
                Image {
                    anchors.centerIn: parent
                    visible: !!card.modelData.installed && source !== ""
                    // in the grimoire (or a dress): an engraving the right way round, not a negative
                    layer.enabled: Theme.inkWindow !== null && Window.window === Theme.inkWindow
                    layer.effect: GrimoirePhoto {}
                    source: card.modelData.preview ? "file://" + card.modelData.preview + "?" + Cursors.catalog.length : ""
                    cache: false
                    smooth: false
                    height: parent.height - Theme.u * 4
                    fillMode: Image.PreserveAspectFit
                }
                PxText {
                    anchors.centerIn: parent
                    visible: !card.modelData.installed
                    text: I18n.t("ещё не скачан", "not downloaded yet")
                    kind: "tiny"
                    dim: true
                }
            }
            PxText {
                width: parent.width
                text: card.modelData.about || ""
                kind: "tiny"
                dim: true
                wrapMode: Text.Wrap
            }
            PxText {
                width: parent.width
                text: "© " + card.modelData.license
                kind: "tiny"
                dim: true
                wrapMode: Text.Wrap
            }
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    visible: !card.modelData.installed
                    enabled: !Cursors.busy
                    icon: "download"
                    text: card.working ? I18n.t("качаю…", "downloading…") : card.hell ? I18n.t("Скачать для ада", "Get it for hell") : I18n.t("Скачать и включить", "Get and use")
                    accent: true
                    onClicked: {
                        if (card.hell) {
                            Cursors.setHell(card.modelData.theme);
                            return;
                        }
                        Config.cursor.theme = card.modelData.theme;
                        Cursors.install(card.modelData.id, true);
                    }
                }
                PxButton {
                    compact: true
                    visible: !!card.modelData.installed && !card.current
                    enabled: !Cursors.busy
                    text: card.working ? I18n.t("применяю…", "applying…") : card.hell ? I18n.t("Для ада", "Use in hell") : I18n.t("Включить", "Use")
                    accent: true
                    onClicked: card.hell ? Cursors.setHell(card.modelData.theme) : Cursors.apply(card.modelData.theme, page.size)
                }
                // the portal is open (the angel came back three times): hell's cursors may be worn in heaven too
                PxButton {
                    compact: true
                    visible: card.hell && Angel.portalOpen && !!card.modelData.installed && Cursors.theme !== card.modelData.theme
                    enabled: !Cursors.busy
                    icon: "sparkle"
                    text: I18n.t("Носить и в раю", "Wear in heaven too")
                    onClicked: Cursors.apply(card.modelData.theme, page.size)
                }
                PxButton {
                    compact: true
                    visible: card.modelData.id === "angelos" && !!card.modelData.installed
                    enabled: !Cursors.busy
                    icon: "palette"
                    text: I18n.t("Под акцент", "Match accent")
                    onClicked: {
                        if (card.current)
                            Cursors.recolor();
                        else
                            Cursors.install("angelos", false);
                    }
                }
            }
        }
    }

    // in hell the pointer is hers (Cursors.hellOn): only hell's themes are offered
    PxGroup {
        name: "pixel-themes"
        visible: !(Angel.demon && !!Config.cursor.hell)
        title: I18n.t("Пиксельные темы", "Pixel themes")
        icon: "cursor"
        width: parent.width

        Grid {
            id: heavenGrid
            width: parent.width
            columns: Math.max(1, Math.floor(width / (Theme.u * 150)))
            spacing: Theme.u * 3
            Repeater {
                model: Cursors.heavenly
                CursorCard {
                    columns: heavenGrid.columns
                    gap: heavenGrid.spacing
                }
            }
        }
    }

    PxGroup {
        name: "cursor-hell"
        visible: Angel.hellShown
        title: I18n.t("Курсор в аду", "Cursor in hell")
        icon: "fire"
        width: parent.width
        SettingRow {
            label: I18n.t("Демоница меняет курсор", "The demon changes the cursor")
            hint: Cursors.hellOn ? I18n.t("сейчас она тут — курсор адский; твой вернётся вместе с ангелом", "she's here now, so the cursor is hers; yours comes back with the angel") : I18n.t("пока она правит, курсор адский; ангел вернёт твой", "while she rules the pointer is hers; the angel gives yours back")
            PxToggle {
                checked: !!Config.cursor.hell
                onToggled: c => Cursors.setHell(c ? "circle" : "")
            }
        }
        SettingRow {
            visible: !!Config.cursor.hell
            label: I18n.t("Какой", "Which")
            hint: Cursors.byCircle ? I18n.t("у каждого круга свой: пепельный в Лимбе, с каплей масла в Чревоугодии, золотой в Жадности, ледяной в Предательстве… Меняется вместе с кругом", "each circle its own: ash in Limbo, dripping oil in Gluttony, gold in Greed, ice in Treachery… It changes with the circle") : I18n.t("всегда одна тема — выбери ниже", "always one theme — pick it below")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("По кругу", "By circle"),
                        "value": "circle"
                    },
                    {
                        "label": I18n.t("Одна тема", "One theme"),
                        "value": "one"
                    }
                ]
                currentValue: Cursors.byCircle ? "circle" : "one"
                onActivated: v => Cursors.setHell(v === "circle" ? "circle" : (Config.cursor.hellPick || "angelOS-Hell"))
            }
        }
        Grid {
            id: hellGrid
            visible: !!Config.cursor.hell
            width: parent.width
            columns: Math.max(1, Math.floor(width / (Theme.u * 150)))
            spacing: Theme.u * 3
            Repeater {
                model: Cursors.hellish
                CursorCard {
                    hell: true
                    columns: hellGrid.columns
                    gap: hellGrid.spacing
                }
            }
        }
    }

    PxGroup {
        name: "shake-find-pointer"
        title: I18n.t("Найти курсор встряхиванием", "Shake to find the pointer")
        advanced: true
        icon: "search"
        width: parent.width
        SettingRow {
            label: I18n.t("Увеличивать при встряхивании", "Grow when shaken")
            hint: CursorShake.status === "noperm" ? I18n.t("нет доступа к мыши: нужна группа input (как для Meta → «Пуск»), затем перезайди", "no access to the mouse: the input group is needed (like Meta → Start), then log in again") : CursorShake.status === "noevdev" ? I18n.t("не нашлось ни мыши, ни тачпада", "no mouse or touchpad found") : I18n.t("потряси мышкой — курсор ненадолго станет большим, как в macOS. В играх на весь экран не срабатывает.", "shake the mouse and the pointer grows for a moment, like on macOS. Not in fullscreen games.")
            PxToggle {
                checked: Config.cursor.shake
                onToggled: c => Config.cursor.shake = c
            }
        }
        SettingRow {
            visible: Config.cursor.shake
            label: I18n.t("Чувствительность", "Sensitivity")
            hint: ({
                    "low": I18n.t("только размашистая тряска", "only a big, wide shake"),
                    "normal": I18n.t("несколько быстрых взмахов", "a few quick strokes"),
                    "high": I18n.t("хватит лёгкого покачивания", "a light wiggle is enough")
                })[Config.cursor.shakeSensitivity || "normal"] || ""
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Низкая", "Low"),
                        "value": "low"
                    },
                    {
                        "label": I18n.t("Обычная", "Normal"),
                        "value": "normal"
                    },
                    {
                        "label": I18n.t("Высокая", "High"),
                        "value": "high"
                    }
                ]
                currentValue: Config.cursor.shakeSensitivity || "normal"
                onActivated: v => Config.cursor.shakeSensitivity = v
            }
        }
        SettingRow {
            visible: Config.cursor.shake
            label: I18n.t("Во сколько раз", "How big")
            hint: I18n.t("во сколько раз вырастает курсор", "how many times the pointer grows")
            PxSlider {
                width: parent.width
                from: 2
                to: 8
                stepSize: 1
                value: Config.cursor.shakeScale || 4
                suffix: "×"
                onReleased: v => Config.cursor.shakeScale = v
            }
        }
        PxButton {
            visible: Config.cursor.shake
            compact: true
            icon: "sparkle"
            text: I18n.t("Показать", "Show me")
            onClicked: CursorShake.demo()
        }
    }

    PxGroup {
        name: "size-compatibility"
        title: I18n.t("Размер и совместимость", "Size and compatibility")
        advanced: true
        icon: "gear"
        width: parent.width
        SettingRow {
            label: I18n.t("Размер", "Size")
            hint: I18n.t("пиксельные темы angelOS чётче всего в 24, 36 и 48", "angelOS pixel themes are crispest at 24, 36 and 48")
            PxSegmented {
                model: [24, 32, 36, 48].map(v => ({
                            "label": String(v),
                            "value": v
                        }))
                currentValue: page.size
                onActivated: v => {
                    if (Cursors.theme)
                        Cursors.apply(Cursors.theme, v);
                    else
                        Config.cursor.size = v;
                }
            }
        }
        SettingRow {
            label: I18n.t("Flatpak-приложения", "Flatpak apps")
            hint: I18n.t("разрешить им читать темы курсоров (flatpak override --user)", "let them read cursor themes (flatpak override --user)")
            PxToggle {
                checked: Config.cursor.flatpak
                onToggled: c => Config.cursor.flatpak = c
            }
        }
        SettingRow {
            visible: Cursors.other.length > 0
            label: I18n.t("Другие темы в системе", "Other themes on the system")
            hint: I18n.t("например, вернуть прежний курсор", "for example, to go back to the old one")
            PxCombo {
                width: parent.width
                model: Cursors.other.map(n => ({
                            "label": n,
                            "value": n
                        }))
                currentValue: Cursors.other.includes(Cursors.theme) ? Cursors.theme : ""
                placeholder: I18n.t("выбрать…", "choose…")
                onActivated: v => Cursors.apply(v, page.size)
            }
        }
        // where the theme is really set right now
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Repeater {
                model: [
                    {
                        "k": "niri",
                        "v": Cursors.status.niri ? Cursors.status.niri[0] : null
                    },
                    {
                        "k": "GTK 3",
                        "v": Cursors.status["gtk-3.0"]
                    },
                    {
                        "k": "GTK 4",
                        "v": Cursors.status["gtk-4.0"]
                    },
                    {
                        "k": "X11 / Steam",
                        "v": Cursors.status.x11
                    },
                    {
                        "k": "gsettings",
                        "v": Cursors.status.gsettings
                    }
                ].filter(x => x.v !== undefined)
                PxText {
                    required property var modelData
                    readonly property bool same: !!Cursors.theme && modelData.v === Cursors.theme
                    text: (same ? "✓ " : "✕ ") + modelData.k + ": " + (modelData.v || "—")
                    kind: "tiny"
                    color: same ? Theme.ok : Theme.textDim
                }
            }
        }
        PxText {
            visible: Cursors.log !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Cursors.log
            color: Cursors.log.startsWith(I18n.t("Ошибка", "Error")) ? Theme.danger : Theme.textDim
        }
    }
}
