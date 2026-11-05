// The settings once in CursorPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Pixel cursor themes: download/build, preview, apply everywhere.
CatPage {
    id: page
    heading: I18n.t("Курсор", "Cursor")
    subtitle: I18n.t("Пиксельные курсоры одним нажатием — одинаковые во всех программах и играх.", "Pixel cursors in one click — the same in every app and game.")
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
        // heaven's own (services/Heaven): angelOS Glitter is earned
        readonly property bool locked: !hell && Cursors.allowed(modelData.theme) !== modelData.theme
        width: (parent.width - (columns - 1) * gap) / columns
        height: cardCol.implicitHeight + Theme.u * 8
        sunken: current
        color: current ? Theme.mix(Theme.toneFor("face", parent), hell ? Theme.hellBlood : Theme.accent, 0.3) : Theme.toneFor("face", parent)
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
                border.color: Theme.toneFor("lo", parent)
                Image {
                    anchors.centerIn: parent
                    visible: !!card.modelData.installed && source !== ""
                    // in the grimoire (or a dress): an engraving the right way round, not a negative
                    layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
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
                visible: card.locked
                width: parent.width
                text: Heaven.label("cursor.glitter") + ": " + Heaven.lockHint("cursor.glitter")
                kind: "tiny"
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
                    enabled: !Cursors.busy && !card.locked
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
                    enabled: !Cursors.busy && !card.locked
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
    CatGroup {
        name: "pixel-themes"
        title: I18n.t("Пиксельные темы", "Pixel themes")
        icon: "cursor"
        present: !(Angel.demon && !!Config.cursor.hell)
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    CatGroup {
        name: "cursor-hell"
        title: I18n.t("Курсор в аду", "Cursor in hell")
        icon: "fire"
        present: Angel.hellShown
        CatToggle {
            label: I18n.t("Демоница меняет курсор", "The demon changes the cursor")
            hint: Cursors.hellOn ? I18n.t("сейчас она тут — курсор адский; твой вернётся вместе с ангелом", "she's here now, so the cursor is hers; yours comes back with the angel") : I18n.t("пока она правит, курсор адский; ангел вернёт твой", "while she rules the pointer is hers; the angel gives yours back")
            checked: !!Config.cursor.hell
            onToggled: c => Cursors.setHell(c ? "circle" : "")
        }
        CatChoice {
            present: !!Config.cursor.hell
            label: I18n.t("Какой", "Which")
            hint: Cursors.byCircle ? I18n.t("у каждого круга свой: пепельный в Лимбе, с каплей масла в Чревоугодии, золотой в Жадности, ледяной в Предательстве… Меняется вместе с кругом", "each circle its own: ash in Limbo, dripping oil in Gluttony, gold in Greed, ice in Treachery… It changes with the circle") : I18n.t("всегда одна тема — выбери ниже", "always one theme — pick it below")
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
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    // the living pointer drawn by angel-niri (cursor_fx) — any cursor theme,
    // Classic and Golden Gate alike (services/CursorShake sends it to the compositor)
    CatGroup {
        name: "motion"
        title: I18n.t("Живой курсор", "Motion cursor")
        icon: "sparkle"
        CatToggle {
            label: I18n.t("Живой курсор", "Motion cursor")
            hint: !CursorShake.ownMotion ? I18n.t("нужна сборка angel-niri с cursor_fx", "needs angel-niri with cursor_fx") : Motion.still ? I18n.t("сейчас выключен: в «Движении» стоит «без анимаций»", "off for now: Motion is set to no animation") : I18n.t("курсор наклоняется в движении, пружинит при клике с кольцом и отбрасывает пиксельную тень — с любой темой курсора", "the pointer leans as it moves, springs on a click with a ring and casts a pixel shadow — with any cursor theme")
            enabled: CursorShake.ownMotion
            checked: Config.cursor.motion && CursorShake.ownMotion
            onToggled: c => Config.cursor.motion = c
        }
        CatSlider {
            present: Config.cursor.motion && CursorShake.ownMotion
            label: I18n.t("Размер", "Size")
            hint: I18n.t("во сколько раз больше обычного", "how many times bigger than usual")
            from: 1
            to: 3
            stepSize: 1
            value: Math.round(Config.cursor.motionSize ?? 2)
            suffix: "×"
            onMoved: v => Config.cursor.motionSize = v
        }
        CatSlider {
            present: Config.cursor.motion && CursorShake.ownMotion
            label: I18n.t("Наклон", "Lean")
            hint: I18n.t("как сильно курсор наклоняется по ходу движения", "how far the pointer leans into its motion")
            from: 0
            to: 300
            stepSize: 10
            value: Math.round((Config.cursor.motionSway ?? 1) * 100)
            suffix: "%"
            onMoved: v => Config.cursor.motionSway = v / 100
        }
        CatSlider {
            present: Config.cursor.motion && CursorShake.ownMotion
            label: I18n.t("Клик", "Click")
            hint: I18n.t("пружина и кольцо при нажатии; 0 — без них", "the dip and ring on a click; 0 — none")
            from: 0
            to: 300
            stepSize: 10
            value: Math.round((Config.cursor.motionBounce ?? 1) * 100)
            suffix: "%"
            onMoved: v => Config.cursor.motionBounce = v / 100
        }
        CatSlider {
            present: Config.cursor.motion && CursorShake.ownMotion
            label: I18n.t("Тень", "Shadow")
            hint: I18n.t("насколько тёмная; 0 — без тени", "how dark; 0 — no shadow")
            from: 0
            to: 300
            stepSize: 10
            value: Math.round((Config.cursor.motionShadow ?? 1) * 100)
            suffix: "%"
            onMoved: v => Config.cursor.motionShadow = v / 100
        }
        CatSlider {
            present: Config.cursor.motion && CursorShake.ownMotion
            label: I18n.t("Дальность тени", "Shadow distance")
            hint: I18n.t("на сколько пикселей она отступает; на скорости — дальше", "how many pixels away it falls; further when fast")
            from: 0
            to: 300
            stepSize: 10
            value: Math.round((Config.cursor.motionShadowDist ?? 1) * 100)
            suffix: "%"
            onMoved: v => Config.cursor.motionShadowDist = v / 100
        }
        CatCustom {
            wide: true
            present: Config.cursor.motion && CursorShake.ownMotion
            CatBox {
                PxButton {
                    compact: true
                    icon: "refresh"
                    text: I18n.t("Как было по умолчанию", "Back to defaults")
                    onClicked: {
                        Config.cursor.motionSize = 2;
                        Config.cursor.motionSway = 1;
                        Config.cursor.motionBounce = 1;
                        Config.cursor.motionShadow = 1;
                        Config.cursor.motionShadowDist = 1;
                    }
                }
            }
        }
    }
    // the camera that follows the pointer (angel-niri camera.rs)
    CatGroup {
        name: "camera"
        title: I18n.t("Камера за курсором", "Camera follows the pointer")
        icon: "search"
        CatToggle {
            label: I18n.t("Камера за курсором", "Follow the pointer")
            hint: !CursorShake.ownCamera ? I18n.t("нужна сборка angel-niri с камерой", "needs angel-niri with the camera") : I18n.t("Super + Ctrl + Shift + U — экран приближается к курсору и плавно едет за ним, смазываясь в движении; ещё раз — назад. Курсор, клики и окна работают как обычно.", "Super + Ctrl + Shift + U — the screen zooms in on the pointer and glides after it, smearing as it moves; again — back out. The pointer, clicks and windows work as usual.")
            enabled: CursorShake.ownCamera
            checked: Config.cursor.camera && CursorShake.ownCamera
            onToggled: c => Config.cursor.camera = c
        }
        CatSlider {
            present: Config.cursor.camera && CursorShake.ownCamera
            label: I18n.t("Приближение", "Zoom")
            hint: I18n.t("во сколько раз крупнее", "how many times closer")
            from: 1.25
            to: 3.5
            stepSize: 0.05
            decimals: 2
            value: Config.cursor.cameraZoom ?? 1.8
            suffix: "×"
            onMoved: v => Config.cursor.cameraZoom = v
        }
        CatSlider {
            present: Config.cursor.camera && CursorShake.ownCamera
            label: I18n.t("Плавность", "Smoothness")
            hint: I18n.t("как мягко камера догоняет курсор", "how softly the camera catches up")
            from: 30
            to: 300
            stepSize: 10
            value: Math.round((Config.cursor.cameraSmooth ?? 1) * 100)
            suffix: "%"
            onMoved: v => Config.cursor.cameraSmooth = v / 100
        }
        CatSlider {
            present: Config.cursor.camera && CursorShake.ownCamera
            label: I18n.t("Размытие в движении", "Motion blur")
            hint: I18n.t("смаз экрана на быстром проезде и при приближении; 0 — без него", "the screen smears on a fast pan and while zooming; 0 — none")
            from: 0
            to: 300
            stepSize: 10
            value: Math.round((Config.cursor.cameraBlur ?? 1) * 100)
            suffix: "%"
            onMoved: v => Config.cursor.cameraBlur = v / 100
        }
        CatCustom {
            wide: true
            present: Config.cursor.camera && CursorShake.ownCamera
            CatBox {
                PxButton {
                    compact: true
                    icon: "sparkle"
                    text: I18n.t("Приблизить / назад", "Zoom in / back")
                    onClicked: CursorShake.cameraToggle()
                }
            }
        }
    }
    CatGroup {
        name: "shake-find-pointer"
        title: I18n.t("Найти курсор встряхиванием", "Shake to find the pointer")
        advanced: true
        icon: "search"
        CatToggle {
            label: I18n.t("Увеличивать при встряхивании", "Grow when shaken")
            hint: CursorShake.status === "noperm" ? I18n.t("нет доступа к мыши: нужна группа input (как для Win → «Пуск»), затем перезайди", "no access to the mouse: the input group is needed (like Win → Start), then log in again") : CursorShake.status === "noevdev" ? I18n.t("не нашлось ни мыши, ни тачпада", "no mouse or touchpad found") : I18n.t("потряси мышкой — курсор ненадолго станет большим, как в macOS. В играх на весь экран не срабатывает.", "shake the mouse and the pointer grows for a moment, like on macOS. Not in fullscreen games.")
            checked: Config.cursor.shake
            onToggled: c => Config.cursor.shake = c
        }
        CatChoice {
            present: Config.cursor.shake
            label: I18n.t("Чувствительность", "Sensitivity")
            hint: ({
                    "low": I18n.t("только размашистая тряска", "only a big, wide shake"),
                    "normal": I18n.t("несколько быстрых взмахов", "a few quick strokes"),
                    "high": I18n.t("хватит лёгкого покачивания", "a light wiggle is enough")
                })[Config.cursor.shakeSensitivity || "normal"] || ""
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
        CatSlider {
            present: Config.cursor.shake
            label: I18n.t("Во сколько раз", "How big")
            hint: I18n.t("во сколько раз вырастает курсор", "how many times the pointer grows")
            from: 2
            to: 8
            stepSize: 1
            value: Config.cursor.shakeScale || 4
            suffix: "×"
            onReleased: v => Config.cursor.shakeScale = v
        }
        CatCustom {
            wide: true
            CatBox {
                PxButton {
                    visible: Config.cursor.shake
                    compact: true
                    icon: "sparkle"
                    text: I18n.t("Показать", "Show me")
                    onClicked: CursorShake.demo()
                }
            }
        }
    }
    CatGroup {
        name: "size-compatibility"
        title: I18n.t("Размер и совместимость", "Size and compatibility")
        advanced: true
        icon: "gear"
        CatChoice {
            label: I18n.t("Размер курсора", "Cursor size")
            hint: I18n.t("пиксельные темы angelOS чётче всего в 24, 36 и 48", "angelOS pixel themes are crispest at 24, 36 and 48")
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
        CatToggle {
            label: I18n.t("Flatpak-приложения", "Flatpak apps")
            hint: I18n.t("разрешить им читать темы курсоров (flatpak override --user)", "let them read cursor themes (flatpak override --user)")
            checked: Config.cursor.flatpak
            onToggled: c => Config.cursor.flatpak = c
        }
        CatChoice {
            present: Cursors.other.length > 0
            label: I18n.t("Другие темы в системе", "Other themes on the system")
            hint: I18n.t("например, вернуть прежний курсор", "for example, to go back to the old one")
            combo: true
            model: Cursors.other.map(n => ({
                        "label": n,
                        "value": n
                    }))
            currentValue: Cursors.other.includes(Cursors.theme) ? Cursors.theme : ""
            placeholder: I18n.t("выбрать…", "choose…")
            onActivated: v => Cursors.apply(v, page.size)
        }
        // where the theme is really set right now
        CatCustom {
            wide: true
            CatBox {
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
                            color: same ? Theme.toneFor("ok", parent) : Theme.toneFor("textDim", parent)
                        }
                    }
                }
            }
        }
        CatNote {
            present: Cursors.log !== ""
            text: Cursors.log
        }
    }
}
