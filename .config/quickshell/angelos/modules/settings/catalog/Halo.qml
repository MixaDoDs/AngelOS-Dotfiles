// The settings once in HaloPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "../../halo/HaloCat.js" as Kitty
import qs.modules.settings.kit

// Settings → Halo (Нимб): the pixel Dynamic Island at the top centre (services/Halo, modules/halo)
CatPage {
    heading: I18n.t("Нимб", "Halo")
    subtitle: I18n.t("Капсулы сверху по центру: музыка, таймеры, запись, загрузки. Брось на Нимб файл, ссылку или текст — он ляжет на Полку и подождёт.", "Pills at the top centre: music, timers, recording, downloads. Drop a file, link or text on the Halo and it waits on the Shelf.")
    id: page
    // the look, as pictures: each a small Halo at rest in its colours
    CatGroup {
        name: "look"
        title: I18n.t("Облик", "Look")
        icon: "palette"
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: [
                            {
                                id: "ears",
                                label: I18n.t("Ушки iPhone", "iPhone ears"),
                                face: Theme.panel,
                                edge: Theme.tone("edge", Theme.p5For(parent)),
                                ink: Theme.tone("text", Theme.p5For(parent)),
                                shadow: true,
                                ears: true
                            },
                            {
                                id: "notch",
                                label: I18n.t("Вырез MacBook", "MacBook notch"),
                                face: "#000000",
                                edge: "transparent",
                                ink: "#efe9ff",
                                flat: true
                            },
                            {
                                id: "float",
                                label: I18n.t("Парящая", "Floating"),
                                face: Theme.panel,
                                edge: Theme.tone("edge", Theme.p5For(parent)),
                                ink: Theme.tone("text", Theme.p5For(parent)),
                                shadow: true
                            },
                            {
                                id: "tamagotchi",
                                label: I18n.t("Тамагочи", "Tamagotchi"),
                                face: Qt.tint(Theme.panel, "#402f6f9f"),
                                edge: Theme.tone("edge", Theme.p5For(parent)),
                                ink: Theme.tone("text", Theme.p5For(parent)),
                                shadow: true,
                                grass: true
                            }
                        ]
                        Item {
                            id: lookTile
                            required property var modelData
                            readonly property bool picked: Halo.skin === modelData.id
                            width: Theme.u * 78
                            height: Theme.u * 34
                            PxPill {
                                anchors.fill: parent
                                radius: Theme.u * 3
                                color: lookArea.containsMouse ? Theme.menuSurface : Theme.tone("sunken", Theme.p5For(parent))
                                edge: lookTile.picked ? Theme.accent : Theme.menuBorder
                            }
                            // the little Halo
                            Item {
                                id: mini
                                width: Theme.u * 62
                                height: Theme.u * 11
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: lookTile.modelData.flat ? Theme.u * 2 : Theme.u * 4
                                PxPill {
                                    visible: !!lookTile.modelData.shadow
                                    x: Theme.u
                                    y: Theme.u
                                    width: parent.width
                                    height: parent.height
                                    color: Qt.rgba(0, 0, 0, 0.6)
                                }
                                PxPill {
                                    visible: !lookTile.modelData.ears
                                    anchors.fill: parent
                                    radius: height / 2
                                    flatTop: !!lookTile.modelData.flat
                                    color: lookTile.modelData.face
                                    edge: lookTile.modelData.edge
                                }
                                Row {
                                    visible: !!lookTile.modelData.ears
                                    anchors.centerIn: parent
                                    spacing: Theme.u * 2
                                    PxPill {
                                        width: Theme.u * 18
                                        height: mini.height
                                        color: lookTile.modelData.face
                                        edge: lookTile.modelData.edge
                                    }
                                    PxPill {
                                        width: Theme.u * 16
                                        height: mini.height
                                        color: "#000000"
                                    }
                                    PxPill {
                                        width: Theme.u * 18
                                        height: mini.height
                                        color: lookTile.modelData.face
                                        edge: lookTile.modelData.edge
                                    }
                                }
                                PxText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: lookTile.modelData.ears ? Theme.u * 6 : Theme.u * 5
                                    text: "19:02"
                                    kind: "tiny"
                                    color: lookTile.modelData.ink
                                }
                                PxIcon {
                                    anchors.centerIn: parent
                                    bitmap: Kitty.run[0]
                                    pixel: 1
                                    ink: lookTile.modelData.ears ? "#efe9ff" : lookTile.modelData.ink
                                }
                                Row {
                                    visible: !!lookTile.modelData.grass
                                    x: Theme.u * 2
                                    y: parent.height - Theme.u * 2
                                    spacing: Theme.u
                                    Repeater {
                                        model: 19
                                        Rectangle {
                                            width: Theme.u * 2
                                            height: Theme.u
                                            color: "#6fd06a"
                                        }
                                    }
                                }
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.u * 3
                                text: lookTile.modelData.label
                                kind: "tiny"
                                dim: !lookTile.picked
                            }
                            MouseArea {
                                id: lookArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.halo.skin = lookTile.modelData.id
                            }
                        }
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Музыка в раскрытом", "Music when open")
            hint: I18n.t("какой будет плитка песни", "how the song's tile looks")
            model: [
                {
                    label: I18n.t("Обложка", "Cover"),
                    value: "cover"
                },
                {
                    label: I18n.t("Кассета", "Cassette"),
                    value: "cassette"
                },
                {
                    label: I18n.t("Пластинка", "Record"),
                    value: "vinyl"
                }
            ]
            currentValue: Config.halo.musicView
            onActivated: v => Config.halo.musicView = v
        }
    }
    CatGroup {
        name: "main"
        title: I18n.t("Нимб", "Halo")
        icon: "sparkle"
        CatToggle {
            label: I18n.t("Включено", "Enabled")
            checked: Config.halo.enabled
            onToggled: c => Config.halo.enabled = c
        }
        CatToggle {
            label: I18n.t("Своя полоса сверху", "A strip of its own")
            hint: I18n.t("окна начинаются под Нимбом и не закрываются им (вкладки браузера); раскрытая карточка всё равно ложится поверх", "windows start below the Halo, so it covers none (browser tabs); the open card still lies over them")
            checked: Config.halo.reserve
            onToggled: c => Config.halo.reserve = c
        }
        CatCustom {
            label: I18n.t("На каких экранах", "Show on displays")
            hint: I18n.t("ничего не выбрано = на всех", "No selection = all displays")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 6
                    Repeater {
                        model: Quickshell.screens
                        PxCheck {
                            required property var modelData
                            text: modelData.name
                            checked: (Config.halo.screens || []).includes(modelData.name)
                            onToggled: c => {
                                const l = (Config.halo.screens || []).filter(s => s !== modelData.name);
                                if (c)
                                    l.push(modelData.name);
                                Config.halo.screens = l;
                            }
                        }
                    }
                }
            }
        }
        CatSlider {
            label: I18n.t("Раскрывать при наведении через", "Open on hover after")
            hint: I18n.t("клик раскрывает сразу", "a click opens it at once")
            from: 0
            to: 1500
            stepSize: 50
            value: Config.halo.hoverMs
            suffix: I18n.t(" мс", " ms")
            onMoved: v => Config.halo.hoverMs = v
        }
        CatChoice {
            label: I18n.t("Размер", "Size")
            model: [
                {
                    label: I18n.t("Маленький", "Small"),
                    value: "s"
                },
                {
                    label: I18n.t("Средний", "Medium"),
                    value: "m"
                },
                {
                    label: I18n.t("Большой", "Large"),
                    value: "l"
                }
            ]
            currentValue: Config.halo.size
            onActivated: v => Config.halo.size = v
        }
        CatToggle {
            label: I18n.t("Постоянная ширина", "Steady width")
            hint: I18n.t("капсула не прыгает под длину текста", "the pill doesn't jump with the length of its text")
            checked: Config.halo.fixedWidth
            onToggled: c => Config.halo.fixedWidth = c
        }
        CatChoice {
            label: I18n.t("Анимация", "Animation")
            hint: I18n.t("как растёт пилюля: пружинкой или 8-битными ступенями", "how the pill grows: with a spring or in 8-bit steps")
            model: [
                {
                    label: I18n.t("Пружина", "Spring"),
                    value: "spring"
                },
                {
                    label: I18n.t("Ступени", "Steps"),
                    value: "steps"
                }
            ]
            currentValue: Config.halo.anim
            onActivated: v => Config.halo.anim = v
        }
    }
    CatGroup {
        name: "show"
        title: I18n.t("Что показывать", "What it shows")
        icon: "eye"
        CatToggle {
            label: I18n.t("Музыка", "Music")
            checked: Config.halo.showMusic
            onToggled: c => Config.halo.showMusic = c
        }
        CatToggle {
            label: I18n.t("Таймеры", "Timers")
            hint: I18n.t("идущие таймеры в капсуле; в «Быстрых кнопках» и конец таймера видны всегда", "running timers in the pill; the quick buttons and a timer's end always show them")
            checked: Config.halo.showTimers
            onToggled: c => Config.halo.showTimers = c
        }
        CatToggle {
            label: I18n.t("Запись экрана", "Screen recording")
            hint: I18n.t("своя и OBS", "your own and OBS's")
            checked: Config.halo.showRec
            onToggled: c => Config.halo.showRec = c
        }
        CatToggle {
            label: I18n.t("Звонки", "Calls")
            hint: I18n.t("Discord, Telegram, Zoom… взяли микрофон — зелёная капсула: время звонка, «выключить микрофон» (только у этой программы, пульт и стрим не трогаются), «открыть»", "Discord, Telegram, Zoom… took the microphone — a green capsule: the call's time, mute (that program only, the mixer and the stream untouched), open")
            checked: Config.halo.calls !== false
            onToggled: c => Config.halo.calls = c
        }
    }
    // the rest of what it can show (Settings → Halo → More)
    CatGroup {
        name: "show-more"
        title: I18n.t("Что ещё показывать", "What else it shows")
        icon: "eye"
        CatToggle {
            label: I18n.t("Точка приватности", "Privacy dot")
            hint: I18n.t("оранжевая — программа пишет микрофон, зелёная — включена камера, фиолетовая — кто-то снимает экран (OBS, демонстрация в Discord); наведи — скажет какая", "orange: a program records the microphone, green: the camera is on, purple: something takes the screen (OBS, a Discord screen share); point at it to see which")
            checked: Config.halo.privacyDot
            onToggled: c => Config.halo.privacyDot = c
        }
        CatToggle {
            label: I18n.t("Свечение в такт басам", "Glow with the bass")
            hint: I18n.t("капсула с музыкой отзывается на плотный бас и на удары", "the music's pill answers a dense bass and the kicks")
            checked: Config.halo.bassGlow
            onToggled: c => Config.halo.bassGlow = c
        }
        CatChoice {
            present: Config.halo.bassGlow
            label: I18n.t("Как отзывается", "How it answers")
            hint: I18n.t("дизеринг — пиксельная кромка внутри; нимб — дужка над капсулой и волна на ударе (капсула опускается на 4 px)", "dither: a pixel band inside the edge; halo: an arc over the pill and a ring on a kick (the pill comes down 4 px)")
            model: [
                {
                    label: I18n.t("Дизеринг", "Dither"),
                    value: "dither"
                },
                {
                    label: I18n.t("Нимб", "Halo"),
                    value: "halo"
                }
            ]
            currentValue: Config.halo.bassStyle
            onActivated: v => Config.halo.bassStyle = v
        }
        CatToggle {
            label: I18n.t("Цвет обложки", "Cover colour")
            hint: I18n.t("обводка и эквалайзер музыки — цвета обложки трека", "the music's outline and bars take the colour of the cover")
            checked: Config.halo.coverTint
            onToggled: c => Config.halo.coverTint = c
        }
        CatToggle {
            label: I18n.t("Проценты загрузок", "Download percent")
            hint: I18n.t("загрузки видны из любой программы; полный размер знает только браузер — angelOS ставит в него маленькое расширение (Helium, Chromium, Brave)", "downloads show from any program; only the browser knows the full size — angelOS puts a small extension into it (Helium, Chromium, Brave)")
            checked: Config.halo.browserBridge
            onToggled: c => Config.halo.browserBridge = c
        }
        CatChoice {
            label: I18n.t("Поверх полноэкранной игры", "Over a full-screen game")
            model: [
                {
                    label: I18n.t("Ничего", "Nothing"),
                    value: "nothing"
                },
                {
                    label: I18n.t("Только конец таймера", "A timer's end only"),
                    value: "timer"
                }
            ]
            currentValue: Config.halo.overFullscreen
            onActivated: v => Config.halo.overFullscreen = v
        }
        CatToggle {
            label: I18n.t("Прятать личное на стриме", "Hide private things on stream")
            hint: I18n.t("на стримовом экране — без имён файлов, картинок полки и текста уведомлений", "on the streamed screen — no file names, shelf pictures or notification texts")
            checked: Config.halo.streamHide === true
            onToggled: c => Config.halo.streamHide = c
        }
        CatToggle {
            label: I18n.t("Ночью тусклее", "Dimmer at night")
            hint: I18n.t("после заката (город из погоды) Нимб в покое приглушён, а котик засыпает быстрее", "after sunset (the weather's city) the resting Halo dims and the cat falls asleep sooner")
            checked: Config.halo.nightDim !== false
            onToggled: c => Config.halo.nightDim = c
        }
    }
    CatGroup {
        name: "rest"
        title: I18n.t("В покое", "At rest")
        icon: "moon"
        CatNote {
            dim: true
            text: I18n.t("Когда ничего не происходит, Нимб — капсула: слева и справа что-то полезное, между ними дужка или котик. Везде «Ничего» и дужка — останется одна тонкая дужка, как раньше.", "When nothing goes on, the Halo is a pill: something useful on the left and the right, the arc or the cat between them. Nothing on both sides and the arc — just the thin arc, as before.")
        }
        CatChoice {
            label: I18n.t("Слева", "Left")
            model: [
                {
                    label: I18n.t("Часы", "Clock"),
                    value: "clock"
                },
                {
                    label: I18n.t("Погода", "Weather"),
                    value: "weather"
                },
                {
                    label: I18n.t("Экранное время", "Screen time"),
                    value: "screen"
                },
                {
                    label: I18n.t("Ничего", "Nothing"),
                    value: "none"
                }
            ]
            currentValue: Config.halo.idleLeft
            onActivated: v => Config.halo.idleLeft = v
        }
        CatChoice {
            label: I18n.t("Справа", "Right")
            model: [
                {
                    label: I18n.t("Часы", "Clock"),
                    value: "clock"
                },
                {
                    label: I18n.t("Погода", "Weather"),
                    value: "weather"
                },
                {
                    label: I18n.t("Экранное время", "Screen time"),
                    value: "screen"
                },
                {
                    label: I18n.t("Ничего", "Nothing"),
                    value: "none"
                }
            ]
            currentValue: Config.halo.idleRight
            onActivated: v => Config.halo.idleRight = v
        }
        CatChoice {
            label: I18n.t("Посередине", "In the middle")
            hint: I18n.t("котик из RunCat: бежит тем быстрее, чем сильнее загружен процессор; через минуту без мыши и клавиатуры спит", "the RunCat cat: runs the faster the busier the processor is; sleeps after a minute without the mouse and keys")
            model: [
                {
                    label: I18n.t("Дужка", "Arc"),
                    value: "ring"
                },
                {
                    label: I18n.t("Котик", "Cat"),
                    value: "cat"
                }
            ]
            currentValue: Config.halo.idleMiddle
            onActivated: v => Config.halo.idleMiddle = v
        }
        // services/KeyCast --taps: the side of each key, never which one; nothing while a password is typed
        CatToggle {
            present: Config.halo.idleMiddle !== "ring"
            label: I18n.t("Бонго-котик", "Bongo cat")
            hint: KeyCast.error !== "" ? KeyCast.error : I18n.t("стучит лапкой по столу на каждую клавишу: левая половина клавиатуры — левой, правая — правой; пока вводится пароль — сидит", "taps its desk for every key: the left half of the keyboard with the left paw, the right with the right; still while a password is typed")
            checked: Config.halo.catBongo !== false
            onToggled: v => Config.halo.catBongo = v
        }
        CatChoice {
            label: I18n.t("Менять правую сторону", "Change the right side")
            hint: I18n.t("справа по очереди: часы, погода, экранное время (кроме того, что слева)", "on the right in turn: the clock, the weather, the screen time (not the one on the left)")
            model: [
                {
                    label: I18n.t("Нет", "No"),
                    value: 0
                },
                {
                    label: I18n.t("10 с", "10 s"),
                    value: 10
                },
                {
                    label: I18n.t("30 с", "30 s"),
                    value: 30
                },
                {
                    label: I18n.t("1 мин", "1 min"),
                    value: 60
                }
            ]
            currentValue: Config.halo.idleRotate
            onActivated: v => Config.halo.idleRotate = v
        }
        CatChoice {
            label: I18n.t("Музыка на паузе", "Music in a pause")
            hint: I18n.t("столько трек держит капсулу, потом снова часы и погода, а рядом кружок ▶ с обложкой — клик включает дальше", "the song keeps the pill this long, then the clock and the weather are back with a ▶ bubble beside them — a click plays on")
            model: [
                {
                    label: I18n.t("Сразу", "At once"),
                    value: 0
                },
                {
                    label: I18n.t("30 с", "30 s"),
                    value: 30
                },
                {
                    label: I18n.t("1 мин", "1 min"),
                    value: 60
                },
                {
                    label: I18n.t("5 мин", "5 min"),
                    value: 300
                }
            ]
            currentValue: Config.halo.pauseKeep
            onActivated: v => Config.halo.pauseKeep = v
        }
        CatToggle {
            label: I18n.t("Видео и треки без синхронной лирики — сбоку", "Videos and songs without synced lyrics — on the side")
            hint: I18n.t("не занимают Нимб: справа обложка и пляшущие полоски, название всплывает на 5 с при смене трека; песня с лирикой по времени показывается как раньше", "they don't take the Halo: the cover and dancing bars on the right, the title peeks 5 s on a new track; a song with timed lyrics shows as before")
            checked: Config.halo.musicSmart
            onToggled: c => Config.halo.musicSmart = c
        }
        CatButton {
            label: I18n.t("Подсказки при наведении", "Hints on hover")
            hint: I18n.t("первые несколько раскрытий в покое объясняют колёсико, полку и меню", "the first few openings at rest explain the wheel, the shelf and the menu")
            compact: true
            text: Config.halo.hintsLeft > 0 ? I18n.t("Ещё покажутся: ", "Still to show: ") + Config.halo.hintsLeft : I18n.t("Показать снова", "Show again")
            enabled: Config.halo.hintsLeft < 3
            onClicked: Config.halo.hintsLeft = 3
        }
    }
    CatGroup {
        name: "buttons"
        title: I18n.t("Быстрые кнопки", "Quick buttons")
        icon: "grid"
        CatNote {
            dim: true
            text: I18n.t("Страница кнопок в раскрытом Нимбе. Галочка включает, порядок — перетаскивание за ручку ≡ или стрелки.", "The buttons page of the open Halo. The check turns one on; drag the ≡ handle or use the arrows to order them.")
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    id: btnList
                    // the switched-on ones in their order, then the rest of the catalog
                    readonly property var on: (Config.halo.buttons || []).filter(id => HaloButtons.catalog.some(b => b.id === id))
                    readonly property var order: on.concat(HaloButtons.catalog.map(b => b.id).filter(id => !on.includes(id)))
                    function move(id, by) {
                        const l = on.slice();
                        const i = l.indexOf(id), j = Math.max(0, Math.min(l.length - 1, i + by));
                        if (i < 0 || j === i)
                            return;
                        l.splice(i, 1);
                        l.splice(j, 0, id);
                        Config.halo.buttons = l;
                    }
                    model: order
                    Item {
                        id: btnRow
                        required property string modelData
                        required property int index
                        readonly property var b: HaloButtons.catalog.find(x => x.id === modelData) || ({})
                        readonly property bool on: btnList.on.includes(modelData)
                        width: parent.width
                        height: rowBox.implicitHeight
                        z: drag.active ? 1 : 0
                        transform: Translate {
                            y: drag.active ? drag.translation.y : 0
                        }
                        Row {
                            id: rowBox
                            width: parent.width
                            spacing: Theme.u * 3
                            // the handle: dragged up or down, the button moves by as many rows
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "≡"
                                dim: !btnRow.on
                                opacity: btnRow.on ? 1 : 0.3
                                DragHandler {
                                    id: drag
                                    enabled: btnRow.on
                                    target: null
                                    yAxis.enabled: true
                                    xAxis.enabled: false
                                    cursorShape: Qt.SizeVerCursor
                                    onActiveChanged: if (!active)
                                        btnList.move(btnRow.modelData, Math.round(translation.y / Math.max(1, btnRow.height)))
                                }
                            }
                            PxCheck {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: btnRow.on
                                onToggled: c => {
                                    const l = btnList.on.filter(x => x !== btnRow.modelData);
                                    if (c)
                                        l.push(btnRow.modelData);
                                    Config.halo.buttons = l;
                                }
                            }
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: btnRow.b.icon || "grid"
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: rowBox.width - Theme.u * 80
                                text: (btnRow.on ? (btnRow.index + 1) + ". " : "") + HaloButtons.label(btnRow.b)
                                elide: Text.ElideRight
                                dim: !btnRow.on
                            }
                            PxButton {
                                visible: btnRow.on
                                compact: true
                                icon: "arrowUp"
                                enabled: btnRow.index > 0
                                onClicked: btnList.move(btnRow.modelData, -1)
                            }
                            PxButton {
                                visible: btnRow.on
                                compact: true
                                icon: "arrowDown"
                                enabled: btnRow.index < btnList.on.length - 1
                                onClicked: btnList.move(btnRow.modelData, 1)
                            }
                        }
                    }
                }
            }
        }
        CatButton {
            text: I18n.t("Как было", "Reset")
            icon: "refresh"
            onClicked: Config.resetKeys(["halo.buttons"])
        }
    }
}
