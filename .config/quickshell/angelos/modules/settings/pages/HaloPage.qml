import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "../../halo/HaloCat.js" as Kitty

// Settings → Halo (Нимб): the pixel Dynamic Island at the top centre (services/Halo, modules/halo)
PxPage {
    heading: I18n.t("Нимб", "Halo")
    subtitle: I18n.t("Капсулы сверху по центру экрана: музыка с лирикой, таймеры, запись экрана (средний клик — пауза), загрузки браузера, обновление angelOS; на миг — цвет пипетки, сеть, зарядка, достижения. Готовая запись и скачанный файл ложатся на полку. Держит свою полосу сверху, раскрытая карточка ложится поверх окон, в покое — часы, погода и котик (Настройки → «В покое»). Поверх полноэкранной игры или фильма показывается только конец таймера.", "Capsules at the top centre of the screen: music with its lyrics, timers, screen recording (a middle click pauses), browser downloads, an angelOS update; for a moment — the eyedropper's colour, the network, the charger, achievements. A finished recording and a downloaded file land on the shelf. It keeps a strip of its own at the top, the open card lies over the windows; at rest the clock, the weather and the cat («At rest»). Over a full-screen game or film only a timer's end shows.")
    id: page

    // the look, as pictures: each a small Halo at rest in its colours
    PxGroup {
        name: "look"
        title: I18n.t("Облик", "Look")
        icon: "palette"
        width: parent.width
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            Repeater {
                model: [
                    {
                        id: "ears",
                        label: I18n.t("Ушки iPhone", "iPhone ears"),
                        face: Theme.panel,
                        edge: Theme.edge,
                        ink: Theme.text,
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
                        edge: Theme.edge,
                        ink: Theme.text,
                        shadow: true
                    },
                    {
                        id: "tamagotchi",
                        label: I18n.t("Тамагочи", "Tamagotchi"),
                        face: Qt.tint(Theme.panel, "#402f6f9f"),
                        edge: Theme.edge,
                        ink: Theme.text,
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
                        color: lookArea.containsMouse ? Theme.menuSurface : Theme.sunken
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
        SettingRow {
            label: I18n.t("Музыка в раскрытом", "Music when open")
            hint: I18n.t("какой будет плитка песни", "how the song's tile looks")
            PxSegmented {
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
    }

    PxGroup {
        name: "main"
        title: I18n.t("Нимб", "Halo")
        icon: "sparkle"
        width: parent.width
        SettingRow {
            label: I18n.t("Включено", "Enabled")
            PxToggle {
                checked: Config.halo.enabled
                onToggled: c => Config.halo.enabled = c
            }
        }
        SettingRow {
            label: I18n.t("Своя полоса сверху", "A strip of its own")
            hint: I18n.t("окна начинаются под Нимбом и не закрываются им (вкладки браузера); раскрытая карточка всё равно ложится поверх", "windows start below the Halo, so it covers none (browser tabs); the open card still lies over them")
            PxToggle {
                checked: Config.halo.reserve
                onToggled: c => Config.halo.reserve = c
            }
        }
        SettingRow {
            label: I18n.t("На каких экранах", "Show on displays")
            hint: I18n.t("ничего не выбрано = на всех", "No selection = all displays")
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
        SettingRow {
            label: I18n.t("Раскрывать при наведении через", "Open on hover after")
            hint: I18n.t("клик раскрывает сразу", "a click opens it at once")
            PxSlider {
                width: parent.width
                from: 0
                to: 1500
                stepSize: 50
                value: Config.halo.hoverMs
                suffix: I18n.t(" мс", " ms")
                onMoved: v => Config.halo.hoverMs = v
            }
        }
        SettingRow {
            label: I18n.t("Размер", "Size")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Постоянная ширина", "Steady width")
            hint: I18n.t("капсула не прыгает под длину текста", "the pill doesn't jump with the length of its text")
            PxToggle {
                checked: Config.halo.fixedWidth
                onToggled: c => Config.halo.fixedWidth = c
            }
        }
        SettingRow {
            label: I18n.t("Анимация", "Animation")
            hint: I18n.t("как растёт пилюля: пружинкой или 8-битными ступенями", "how the pill grows: with a spring or in 8-bit steps")
            PxSegmented {
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
    }

    PxGroup {
        name: "show"
        title: I18n.t("Что показывать", "What it shows")
        icon: "eye"
        width: parent.width
        SettingRow {
            label: I18n.t("Музыка", "Music")
            PxToggle {
                checked: Config.halo.showMusic
                onToggled: c => Config.halo.showMusic = c
            }
        }
        SettingRow {
            label: I18n.t("Таймеры", "Timers")
            hint: I18n.t("идущие таймеры в капсуле; на странице «Кнопки» и конец таймера видны всегда", "running timers in the pill; the Buttons page and a timer's end always show them")
            PxToggle {
                checked: Config.halo.showTimers
                onToggled: c => Config.halo.showTimers = c
            }
        }
        SettingRow {
            label: I18n.t("Запись экрана", "Screen recording")
            hint: I18n.t("своя и OBS", "your own and OBS's")
            PxToggle {
                checked: Config.halo.showRec
                onToggled: c => Config.halo.showRec = c
            }
        }
        SettingRow {
            label: I18n.t("Точка приватности", "Privacy dot")
            hint: I18n.t("оранжевая — программа пишет микрофон, зелёная — включена камера; наведи — скажет какая", "orange: a program records the microphone, green: the camera is on; point at it to see which")
            PxToggle {
                checked: Config.halo.privacyDot
                onToggled: c => Config.halo.privacyDot = c
            }
        }
        SettingRow {
            label: I18n.t("Миниатюра скриншота", "Screenshot thumbnail")
            hint: I18n.t("сохранённый скриншот на 4 с: утащи картинку или положи на полку", "a saved screenshot for 4 s: drag the picture out or put it on the shelf")
            PxToggle {
                checked: Config.halo.shotThumb
                onToggled: c => Config.halo.shotThumb = c
            }
        }
        SettingRow {
            label: I18n.t("Свечение в такт басам", "Glow with the bass")
            hint: I18n.t("капсула с музыкой отзывается на плотный бас и на удары", "the music's pill answers a dense bass and the kicks")
            PxToggle {
                checked: Config.halo.bassGlow
                onToggled: c => Config.halo.bassGlow = c
            }
        }
        SettingRow {
            visible: Config.halo.bassGlow
            label: I18n.t("Как отзывается", "How it answers")
            hint: I18n.t("дизеринг — пиксельная кромка внутри; нимб — дужка над капсулой и волна на ударе (капсула опускается на 4 px)", "dither: a pixel band inside the edge; halo: an arc over the pill and a ring on a kick (the pill comes down 4 px)")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Цвет обложки", "Cover colour")
            hint: I18n.t("обводка и эквалайзер музыки — цвета обложки трека", "the music's outline and bars take the colour of the cover")
            PxToggle {
                checked: Config.halo.coverTint
                onToggled: c => Config.halo.coverTint = c
            }
        }
        SettingRow {
            label: I18n.t("Проценты загрузок", "Download percent")
            hint: I18n.t("загрузки видны из любой программы; полный размер знает только браузер — angelOS ставит в него маленькое расширение (Helium, Chromium, Brave)", "downloads show from any program; only the browser knows the full size — angelOS puts a small extension into it (Helium, Chromium, Brave)")
            PxToggle {
                checked: Config.halo.browserBridge
                onToggled: c => Config.halo.browserBridge = c
            }
        }
        SettingRow {
            label: I18n.t("Уведомления", "Notifications")
            hint: I18n.t("3 секунды в капсуле: иконка, программа, заголовок; наведи — весь текст. Угловое окошко тогда не появляется (кроме важных)", "3 seconds in the pill: icon, app, title; point at it for the text. The corner popup then stays away (but for critical ones)")
            PxToggle {
                checked: Config.halo.notify !== false
                onToggled: c => Config.halo.notify = c
            }
        }
        SettingRow {
            label: I18n.t("Громкость и яркость", "Volume and brightness")
            hint: I18n.t("полоской в Нимбе вместо отдельного окошка (на экране Нимба)", "a bar in the Halo instead of the separate box (on the Halo's screen)")
            PxToggle {
                checked: Config.halo.osd !== false
                onToggled: c => Config.halo.osd = c
            }
        }
        SettingRow {
            label: I18n.t("Звонки", "Calls")
            hint: I18n.t("Discord, Telegram, Zoom… взяли микрофон — зелёная капсула: время звонка, «выключить микрофон» (только у этой программы, пульт и стрим не трогаются), «открыть»", "Discord, Telegram, Zoom… took the microphone — a green capsule: the call's time, mute (that program only, the mixer and the stream untouched), open")
            PxToggle {
                checked: Config.halo.calls !== false
                onToggled: c => Config.halo.calls = c
            }
        }
        SettingRow {
            label: I18n.t("Поверх полноэкранной игры", "Over a full-screen game")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Прятать личное на стриме", "Hide private things on stream")
            hint: I18n.t("на стримовом экране — без имён файлов, картинок полки и текста уведомлений", "on the streamed screen — no file names, shelf pictures or notification texts")
            PxToggle {
                checked: Config.halo.streamHide === true
                onToggled: c => Config.halo.streamHide = c
            }
        }
        SettingRow {
            label: I18n.t("Ночью тусклее", "Dimmer at night")
            hint: I18n.t("после заката (город из погоды) Нимб в покое приглушён, а котик засыпает быстрее", "after sunset (the weather's city) the resting Halo dims and the cat falls asleep sooner")
            PxToggle {
                checked: Config.halo.nightDim !== false
                onToggled: c => Config.halo.nightDim = c
            }
        }
    }

    PxGroup {
        name: "rest"
        title: I18n.t("В покое", "At rest")
        icon: "moon"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Когда ничего не происходит, Нимб — капсула: слева и справа что-то полезное, между ними дужка или котик. Везде «Ничего» и дужка — останется одна тонкая дужка, как раньше.", "When nothing goes on, the Halo is a pill: something useful on the left and the right, the arc or the cat between them. Nothing on both sides and the arc — just the thin arc, as before.")
        }
        SettingRow {
            label: I18n.t("Слева", "Left")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Справа", "Right")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Посередине", "In the middle")
            hint: I18n.t("котик из RunCat: бежит тем быстрее, чем сильнее загружен процессор; через минуту без мыши и клавиатуры спит", "the RunCat cat: runs the faster the busier the processor is; sleeps after a minute without the mouse and keys")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Менять правую сторону", "Change the right side")
            hint: I18n.t("справа по очереди: часы, погода, экранное время (кроме того, что слева)", "on the right in turn: the clock, the weather, the screen time (not the one on the left)")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Музыка на паузе", "Music in a pause")
            hint: I18n.t("столько трек держит капсулу, потом снова часы и погода, а рядом кружок ▶ с обложкой — клик включает дальше", "the song keeps the pill this long, then the clock and the weather are back with a ▶ bubble beside them — a click plays on")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Видео и треки без синхронной лирики — сбоку", "Videos and songs without synced lyrics — on the side")
            hint: I18n.t("не занимают Нимб: справа обложка и пляшущие полоски, название всплывает на 5 с при смене трека; песня с лирикой по времени показывается как раньше", "they don't take the Halo: the cover and dancing bars on the right, the title peeks 5 s on a new track; a song with timed lyrics shows as before")
            PxToggle {
                checked: Config.halo.musicSmart
                onToggled: c => Config.halo.musicSmart = c
            }
        }
        SettingRow {
            label: I18n.t("Подсказки при наведении", "Hints on hover")
            hint: I18n.t("первые несколько раскрытий в покое объясняют колёсико, полку и меню", "the first few openings at rest explain the wheel, the shelf and the menu")
            PxButton {
                compact: true
                text: Config.halo.hintsLeft > 0 ? I18n.t("Ещё покажутся: ", "Still to show: ") + Config.halo.hintsLeft : I18n.t("Показать снова", "Show again")
                enabled: Config.halo.hintsLeft < 3
                onClicked: Config.halo.hintsLeft = 3
            }
        }
    }

    PxGroup {
        name: "buttons"
        title: I18n.t("Быстрые кнопки", "Quick buttons")
        icon: "grid"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Страница кнопок в раскрытом Нимбе. Галочка включает, порядок — перетаскивание за ручку ≡ или стрелки.", "The buttons page of the open Halo. The check turns one on; drag the ≡ handle or use the arrows to order them.")
        }
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
        PxButton {
            text: I18n.t("Как было", "Reset")
            icon: "refresh"
            onClicked: Config.resetKeys(["halo.buttons"])
        }
    }
}
