// Generated from modules/settings/pages/Y2kPage.qml by the settings-p5 converter;
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.y2k
import "../../y2k/AngelSprite.js" as AngelArt
import "../../y2k/DemonSprite.js" as DemonArt
import "../../y2k/AngelSpriteMini.js" as AngelMini
import "../../y2k/DemonSpriteMini.js" as DemonMini
import qs.modules.settings.kit

// Y2K bits: the helper angel, glitter, the sound pack and the CD-ROM loading screen.
CatPage {
    id: page
    heading: Angel.demon ? I18n.t("Демоница ⛧", "The demon ⛧") : I18n.t("Ангел ✧", "The angel ✧")
    // in hell the angel's own things step aside: the page is about the demon (Angel.demon)
    subtitle: Angel.demon ? I18n.t("Немного 2000-х: демоница в углу экрана, блёстки, звуки и загрузка как у игры с диска.", "A bit of the 2000s: the demon in the corner, glitter, sounds and a loading screen like a game on a disc.") : I18n.t("Немного 2000-х: ангелочек-помощник, блёстки, звуки и загрузка как у игры с диска.", "A bit of the 2000s: a helper angel, glitter, sounds and a loading screen like a game on a disc.")
    readonly property var screenNames: Quickshell.screens.map(s => s.name)
    function toggleIn(list, name, on) {
        const l = (list || []).filter(n => n !== name);
        return on ? l.concat([name]) : l;
    }
    CatGroup {
        name: "stream-mode"
        title: I18n.t("Стрим-режим", "Stream mode")
        advanced: true
        icon: "monitor"
        CatButton {
            label: I18n.t("Сейчас", "Now")
            hint: StreamMode.active ? I18n.t("эфир: angelOS не лезет в кадр", "Live: angelOS stays out of the picture") : Config.stream.auto ? (StreamMode.obsUp ? I18n.t("OBS на связи, эфира нет", "OBS connected, not streaming") : StreamMode.obsAuth ? I18n.t("OBS просит пароль WebSocket — включи вход без пароля или сохрани пароль в OBS", "OBS wants a WebSocket password") : I18n.t("OBS не запущен или WebSocket-сервер выключен (Инструменты → Настройки WebSocket)", "OBS isn't running or its WebSocket server is off (Tools → WebSocket Server Settings)")) : I18n.t("выключен", "Off")
            icon: StreamMode.active ? "close" : "play"
            accent: !StreamMode.active
            confirm: true
            text: confirming ? I18n.t("Точно? Ещё раз", "Sure? Again") : StreamMode.active ? I18n.t("Выключить", "Switch off") : I18n.t("Включить вручную", "Switch on by hand")
            onConfirmed: StreamMode.set("toggle")
        }
        CatToggle {
            label: I18n.t("Включать сам, когда OBS в эфире", "On by itself while OBS is live")
            hint: I18n.t("включается, пока OBS ведёт трансляцию (obs-websocket, порт ", "On while OBS is streaming (obs-websocket, port ") + Config.stream.port + ")"
            checked: Config.stream.auto
            onToggled: c => Config.stream.auto = c
        }
        CatCustom {
            present: page.screenNames.length > 1
            label: I18n.t("Экраны в эфире", "Streamed screens")
            hint: I18n.t("ничего не выбрано — все; остальные экраны живут как обычно", "Nothing picked means all; the others carry on as usual")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.screenNames
                        PxButton {
                            required property string modelData
                            compact: true
                            checkable: true
                            checked: (Config.stream.screens || []).includes(modelData)
                            text: modelData
                            onClicked: Config.stream.screens = page.toggleIn(Config.stream.screens, modelData, checked)
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "stream-mode-more"
        title: I18n.t("Что меняется в эфире", "What changes while live")
        icon: "camera"
        CatToggle {
            label: I18n.t("Ангел уходит с экрана", "The angel leaves the screen")
            hint: I18n.t("на другой экран, а если его нет — прячется", "To another screen, or hides if there is none")
            checked: Config.stream.hideAngel
            onToggled: c => Config.stream.hideAngel = c
        }
        CatToggle {
            label: I18n.t("Тишина", "Quiet")
            hint: I18n.t("звуки angelOS не попадут в эфир", "angelOS sounds stay off the stream")
            checked: Config.stream.mute
            onToggled: c => Config.stream.mute = c
        }
        CatToggle {
            label: I18n.t("«Не беспокоить»", "Do not disturb")
            hint: I18n.t("уведомления копятся в истории; после эфира всё как было", "Notifications wait in the history; back to normal after the stream")
            checked: Config.stream.dnd
            onToggled: c => Config.stream.dnd = c
        }
        CatToggle {
            label: I18n.t("Без эффектов", "No effects")
            hint: Angel.hellShown ? I18n.t("ни блёсток, ни загрузочного экрана, ни лучей и трещин на экранах в эфире", "No sparkles, loading screen, rays or cracks on streamed screens") : I18n.t("ни блёсток, ни загрузочного экрана, ни лучей на экранах в эфире", "No sparkles, loading screen or rays on streamed screens")
            checked: Config.stream.effects
            onToggled: c => Config.stream.effects = c
        }
        // the stream's chat on screen (services/StreamChat): read from a chat reader's session log
        CatCustom {
            label: I18n.t("Чат на экране", "Chat on screen")
            hint: I18n.t("Папка, куда бот чата пишет сообщения эфира. Пусто — выключено.", "The folder a chat bot writes the stream's messages to. Empty: off.")
            CatBox {
                PxField {
                    width: Math.min(Theme.u * 110, parent.width)
                    text: Config.stream.chatLog
                    placeholder: "~/…/stream-logs"
                    kind: "mono"
                    input.onEditingFinished: Config.stream.chatLog = text.trim()
                }
            }
        }
        CatToggle {
            present: !!Config.stream.chatLog
            label: I18n.t("Сообщения в Нимбе", "Messages on the Halo")
            hint: I18n.t("ник и текст на несколько секунд, котик поднимает лапы; донат — с сердечком. Поверх игры тоже, пока идёт эфир", "The nick and the text for a few seconds, the cat raises its paws; a paid one with a heart. Over a game too while on air")
            checked: Config.stream.chatHalo !== false
            onToggled: c => Config.stream.chatHalo = c
        }
        CatToggle {
            present: !!Config.stream.chatLog
            label: I18n.t("Котики внизу экрана", "Cats along the bottom")
            hint: I18n.t("кто написал — пробегает котиком со своим ником по низу экрана в эфире; у постоянных зрителей корона", "Whoever writes runs along the bottom of the streamed screen as a cat with the nick; regulars wear a crown")
            checked: Config.stream.chatRunners !== false
            onToggled: c => Config.stream.chatRunners = c
        }
        CatToggle {
            present: !!Config.stream.chatLog && Config.stream.chatRunners !== false && Niri.nativeMinimize
            label: I18n.t("Котики только зрителям", "Cats for the viewers only")
            hint: I18n.t("котики видны в эфире, но не на твоём мониторе", "The cats show on stream but not on your monitor")
            checked: Config.stream.chatRunnersViewersOnly !== false
            onToggled: c => Config.stream.chatRunnersViewersOnly = c
        }
    }
    // privacy on stream (services/Privacy, the dotfiles' niri-cast-privacy): which apps are
    // black in the screencast while the mode is on
    CatGroup {
        name: "stream-privacy"
        title: I18n.t("Приватность в эфире", "Privacy on stream")
        icon: "eye"
        CatButton {
            label: I18n.t("Сейчас", "Now")
            hint: Privacy.error !== "" ? Privacy.error : Privacy.on ? (Privacy.hidden.length ? (Privacy.nativeLook ? I18n.t("в записи и трансляции закрыты: ", "Covered in recordings and on stream: ") : I18n.t("в записи и трансляции чёрные: ", "Black in recordings and on stream: ")) + Privacy.hidden.map(a => a.name).join(", ") : I18n.t("включена, но в списке ничего не отмечено", "On, but nothing in the list is ticked")) : I18n.t("выключена: в эфире видно всё. Win+Shift+X включает её с клавиатуры", "Off: the stream shows everything. Win+Shift+X switches it from the keyboard")
            icon: Privacy.on ? "close" : "eye"
            accent: !Privacy.on
            text: Privacy.on ? I18n.t("Выключить", "Switch off") : I18n.t("Включить", "Switch on")
            onClicked: Privacy.set("toggle")
        }
        CatToggle {
            label: I18n.t("Включать саму, когда OBS в эфире", "On by itself while OBS is live")
            hint: I18n.t("включается с началом трансляции и возвращается как было, когда она кончится", "On when the stream starts, back to what it was when it ends")
            checked: Config.stream.privacyAuto
            onToggled: c => Config.stream.privacyAuto = c
        }
        // angel-niri: what the viewers see, drawn into the stream by niri itself
        CatChoice {
            present: Privacy.nativeLook
            label: I18n.t("Что видят зрители", "What the viewers see")
            hint: I18n.t("на месте скрытого окна в эфире и на записи. Своя заглушка у программы — в списке ниже", "In the hidden window's place, on stream and in recordings. An app can have its own in the list below")
            combo: true
            model: Privacy.looks.map(l => ({
                        "label": Privacy.lookName(l),
                        "value": l
                    }))
            currentValue: Config.stream.privacyLook
            onActivated: v => {
                if (v === "image" && !Config.stream.privacyImage)
                    Privacy.pickImage("");
                else
                    Config.stream.privacyLook = v;
            }
        }
        CatButton {
            present: Privacy.nativeLook && Config.stream.privacyLook === "image"
            label: I18n.t("Картинка", "Picture")
            hint: Config.stream.privacyImage ? Config.stream.privacyImage.split("/").pop() : I18n.t("не выбрана — пока плашка", "None yet — the plate meanwhile")
            compact: true
            icon: "image"
            enabled: !Privacy.picking
            text: I18n.t("Выбрать…", "Choose…")
            onClicked: Privacy.pickImage("")
        }
        CatToggle {
            present: !Privacy.nativeLook
            label: I18n.t("Плашка «Privacy ON» для зрителей", "«Privacy ON» plate for the viewers")
            hint: I18n.t("Зрители видят плашку вместо окна. В OBS добавь «Захват окна» → «angelOS · Privacy для OBS».", "Viewers see a plate instead of the window. In OBS add Window Capture → angelOS · Privacy.")
            checked: Config.stream.privacyPlates
            onToggled: c => Config.stream.privacyPlates = c
        }
        CatNote {
            dim: true
            text: Privacy.nativeLook ? I18n.t("Окна отмеченных программ в эфире закрыты заглушкой, у тебя — как обычно. Win+Ctrl+Shift+X — добавить или убрать программу в фокусе, Win+Ctrl+X — показать её в эфире на время.", "The ticked apps' windows are covered on stream and look as usual to you. Win+Ctrl+Shift+X adds or removes the focused app, Win+Ctrl+X shows it on stream for now.") : I18n.t("Окна отмеченных программ в эфире закрыты плашкой «Privacy ON» (без неё в OBS — чёрным), у тебя — как обычно. Win+Ctrl+Shift+X — добавить или убрать программу в фокусе, Win+Ctrl+X — показать её в эфире на время.", "The ticked apps' windows get a «Privacy ON» plate on stream (black without it in OBS) and look as usual to you. Win+Ctrl+Shift+X adds or removes the focused app, Win+Ctrl+X shows it on stream for now.")
        }
        CatRepeat {
            model: Privacy.apps
            delegate: Component {
                CatCustom {
                    id: hiddenApp
                    required property var modelData
                    label: modelData.name
                    hint: modelData.id
                    CatBox {
                        // a Flow: in a narrow card the look and the buttons wrap below the toggle
                        Flow {
                            id: hiddenFlow
                            width: parent.width
                            spacing: Theme.u * 3
                            Row {
                                spacing: Theme.u * 3
                                AppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    appId: hiddenApp.modelData.id
                                    size: Theme.u * 8
                                }
                                PxToggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: hiddenApp.modelData.on
                                    onToggled: c => Privacy.app(c ? "add" : "remove", hiddenApp.modelData.id)
                                }
                            }
                            // its own look (angel-niri): "" — as every app
                            PxCombo {
                                visible: Privacy.nativeLook && hiddenApp.modelData.on
                                width: Math.min(Theme.u * 100, hiddenFlow.width)
                                readonly property var own: Privacy.appLook(hiddenApp.modelData.id)
                                model: [{
                                        "label": I18n.t("Как у всех", "As the rest"),
                                        "value": ""
                                    }].concat(Privacy.looks.map(l => ({
                                                "label": Privacy.lookName(l),
                                                "value": l
                                            })))
                                currentValue: own ? own.look : ""
                                onActivated: v => {
                                    if (v === "image" && !(own && own.image))
                                        Privacy.pickImage(hiddenApp.modelData.id);
                                    else
                                        Privacy.setAppLook(hiddenApp.modelData.id, v);
                                }
                            }
                            PxButton {
                                visible: Privacy.nativeLook && hiddenApp.modelData.on && !!Privacy.appLook(hiddenApp.modelData.id) && Privacy.appLook(hiddenApp.modelData.id).look === "image"
                                compact: true
                                icon: "image"
                                enabled: !Privacy.picking
                                text: I18n.t("Картинка…", "Picture…")
                                onClicked: Privacy.pickImage(hiddenApp.modelData.id)
                            }
                            // on stream for now, until pressed again (Mod+Ctrl+X for the focused window)
                            PxButton {
                                visible: Privacy.on && hiddenApp.modelData.on
                                compact: true
                                accent: Privacy.isShown(hiddenApp.modelData.id)
                                icon: "eye"
                                text: Privacy.isShown(hiddenApp.modelData.id) ? I18n.t("Скрыть снова", "Hide again") : I18n.t("Показать сейчас", "Show now")
                                onClicked: Privacy.show("toggle", hiddenApp.modelData.id)
                            }
                            PxButton {
                                compact: true
                                icon: "trash"
                                text: I18n.t("Убрать", "Remove")
                                onClicked: Privacy.app("forget", hiddenApp.modelData.id)
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            present: Privacy.candidates.length > 0
            label: I18n.t("Открыто сейчас", "Open right now")
            hint: I18n.t("нажми на программу, чтобы скрывать и её", "Pick an app to hide it too")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: Privacy.candidates
                        PxButton {
                            required property var modelData
                            compact: true
                            icon: "plus"
                            text: modelData.name
                            onClicked: Privacy.app("add", modelData.id)
                        }
                    }
                }
            }
        }
        CatCustom {
            label: I18n.t("Другая программа", "Another app")
            hint: I18n.t("если её нет среди открытых: имя программы, как его знает система", "If it isn't open: the app's name as the system knows it")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxField {
                        id: privacyId
                        width: Math.min(Theme.u * 60, parent.width)
                        placeholder: "org.example.App"
                        kind: "mono"
                        input.onAccepted: privacyAdd.clicked()
                    }
                    PxButton {
                        id: privacyAdd
                        compact: true
                        icon: "plus"
                        text: I18n.t("Добавить", "Add")
                        onClicked: {
                            const id = privacyId.text.trim();
                            if (id === "")
                                return;
                            Privacy.app("add", id);
                            privacyId.text = "";
                        }
                    }
                }
            }
        }
    }
    // the angel on stream: on the streamed screen's taskbar, talking with the mic
    CatGroup {
        name: "stream-angel"
        title: I18n.t("Ангел на стриме", "The angel on stream")
        advanced: true
        icon: "chat"
        CatToggle {
            label: I18n.t("Показывать на стриме", "Show her on stream")
            hint: I18n.t("во время эфира ангелочек переходит на экран эфира, сидит на панели и говорит твоим микрофоном", "While you're live the angel moves to the streamed screen, sits on the bar and talks with your microphone")
            checked: !!Config.stream.streamer
            onToggled: c => Config.stream.streamer = c
        }
        CatButton {
            label: I18n.t("Сейчас", "Now")
            hint: !StreamAngel.enabled && !StreamAngel.preview ? I18n.t("выключено", "Off") : StreamAngel.shown ? (StreamAngel.preview && !StreamAngel.live ? I18n.t("показ без эфира", "Preview, not live") : I18n.t("в эфире", "Live")) + (StreamAngel.talking ? I18n.t(" · говорит", " · talking") : "") : StreamAngel.obsUp ? I18n.t("OBS на связи, ждёт эфира", "OBS connected, waiting for the stream") : I18n.t("OBS не запущен или WebSocket-сервер выключен (Инструменты → Настройки WebSocket)", "OBS isn't running or its WebSocket server is off (Tools → WebSocket Server Settings)")
            icon: StreamAngel.preview ? "close" : "eye"
            text: StreamAngel.preview ? I18n.t("Убрать", "Hide") : I18n.t("Показать сейчас", "Show her now")
            onClicked: StreamAngel.set("test")
        }
        CatSlider {
            label: I18n.t("Размер на стриме", "Size on stream")
            hint: I18n.t("какую часть высоты экрана она занимает над панелью; ещё — Ctrl + колесо на ней", "How much of the screen's height she takes above the bar; also Ctrl + wheel over her")
            from: 10
            to: 50
            stepSize: 2
            value: Config.stream.streamerSize || 30
            suffix: "%"
            onMoved: v => Config.stream.streamerSize = Math.round(v)
        }
        CatChoice {
            label: I18n.t("Угол", "Corner")
            combo: true
            model: [{
                    "label": I18n.t("Справа внизу", "Bottom right"),
                    "value": "right"
                }, {
                    "label": I18n.t("Слева внизу", "Bottom left"),
                    "value": "left"
                }]
            currentValue: Config.stream.streamerSide || "right"
            onActivated: v => Config.stream.streamerSide = v
        }
    }
    CatGroup {
        name: "stream-angel-voice"
        title: I18n.t("Голос", "Voice")
        icon: "mic"
        CatChoice {
            label: I18n.t("Микрофон", "Microphone")
            hint: (StreamAngel.using ? I18n.t("слушает: ", "Listening to: ") + StreamAngel.using.replace(/^obs:/, "OBS → ").replace(/^pw:/, "PipeWire → ") : StreamAngel.error === "no-mic" ? I18n.t("микрофон не найден — выбери вход", "No microphone found — pick an input") : I18n.t("из OBS: тот вход, что он слышит, после его ползунка; заглушён в OBS — ангел молчит", "From OBS: the input it hears, after its slider; muted in OBS, she's quiet"))
            combo: true
            model: [{
                    "label": I18n.t("Сам найдёт", "Find it"),
                    "value": "auto"
                }].concat((StreamAngel.inputs || []).map(i => ({
                        "label": (i.kind === "pipewire" ? "PipeWire: " : "OBS: ") + i.name + (i.device && i.device !== "(null)" && i.kind === "pipewire" ? " (" + i.device + ")" : ""),
                        "value": (i.kind === "pipewire" ? "pw:" : "obs:") + i.name
                    }))).concat(Config.stream.streamerMic && Config.stream.streamerMic !== "auto" && !(StreamAngel.inputs || []).some(i => ((i.kind === "pipewire" ? "pw:" : "obs:") + i.name) === Config.stream.streamerMic) ? [{
                        "label": Config.stream.streamerMic,
                        "value": Config.stream.streamerMic
                    }] : [])
            currentValue: Config.stream.streamerMic || "auto"
            onActivated: v => Config.stream.streamerMic = v
        }
        CatCustom {
            label: I18n.t("Чувствительность", "Sensitivity")
            hint: I18n.t("где открывается рот: меньше — слышит тихий голос, больше — не реагирует на шум. Сейчас: ", "Where her mouth opens: lower hears a quiet voice, higher ignores noise. Now: ") + Math.round(StreamAngel.level * 100) + "%"
            CatBox {
                Column {
                    width: parent.width
                    spacing: Theme.u
                    PxSlider {
                        width: Math.min(parent.width, Theme.u * 120)
                        from: 5
                        to: 90
                        stepSize: 5
                        value: Config.stream.streamerThreshold ?? 30
                        suffix: "%"
                        onMoved: v => Config.stream.streamerThreshold = Math.round(v)
                    }
                    // the live voice against the threshold
                    Rectangle {
                        visible: StreamAngel.enabled || StreamAngel.preview
                        width: Math.min(parent.width, Theme.u * 120)
                        height: Theme.u * 3
                        color: Theme.toneFor("sunken", parent)
                        Rectangle {
                            width: parent.width * Math.min(1, StreamAngel.level)
                            height: parent.height
                            color: StreamAngel.talking ? Theme.accent : Theme.mix(Theme.toneFor("face", parent), Theme.accent, 0.4)
                        }
                        Rectangle {
                            x: parent.width * StreamAngel.threshold
                            width: Math.max(1, Theme.u / 2)
                            height: parent.height
                            color: Theme.toneFor("edge", parent)
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "stream-angel-obs"
        title: I18n.t("Экран и OBS", "Screen and OBS")
        icon: "camera"
        CatChoice {
            present: page.screenNames.length > 1
            label: I18n.t("Экран", "Screen")
            hint: I18n.t("На каком мониторе стоит ангел, если в эфире их несколько.", "Which monitor the angel stands on when several are streamed.")
            combo: true
            model: [{
                    "label": I18n.t("Первый в эфире", "The first streamed one"),
                    "value": ""
                }].concat(page.screenNames.map(n => ({
                        "label": n,
                        "value": n
                    })))
            currentValue: Config.stream.streamerScreen || ""
            onActivated: v => Config.stream.streamerScreen = v
        }
        // Mod+Alt+A: off your own screen; her window for OBS has her either way
        // Mod+Alt+A: off your own screen; her window for OBS has her either way
        CatButton {
            label: I18n.t("Спрятать от себя", "Hide her from you")
            hint: (StreamAngel.view === "obs" ? I18n.t("сейчас ты её не видишь, она только в окне для OBS. ", "You don't see her now, she's only in the window for OBS. ") : I18n.t("сейчас она и у тебя на экране. ", "She's on your screen too now. ")) + I18n.t("Окно для OBS рисует её всё время, пока OBS запущен, это только про твой экран", "The window for OBS draws her the whole time OBS runs; this is about your screen only") + (Config.stream.streamerKeys !== false ? I18n.t(". Переключает Win+Alt+A, в игре тоже", ". Win+Alt+A switches it, in games too") : "")
            icon: StreamAngel.view === "screen" ? "close" : "eye"
            text: StreamAngel.view === "screen" ? I18n.t("Спрятать", "Hide") : I18n.t("Показать", "Show")
            onClicked: StreamAngel.set("view")
        }
        CatCustom {
            label: I18n.t("Окно для OBS", "Window for OBS")
            hint: (!StreamAngel.niriKeys ? I18n.t("нужна клавиша ниже: с ней niri прячет это окно с экрана. ", "Needs the key below: with it niri keeps the window off your screen. ") : StreamAngel.castOpen ? (Niri.castWindowId >= 0 ? I18n.t("открыто. ", "Open. ") : I18n.t("открывается… ", "Opening… ")) : I18n.t("откроется, когда запустится OBS. ", "Opens when OBS starts. ")) + I18n.t("Один раз в OBS: Источники → + → «Захват окна (PipeWire)» → «angelOS · ангел для OBS», поверх панели. Фон прозрачный.", "Once in OBS: Sources → + → Window Capture (PipeWire) → «angelOS · ангел для OBS», over the bar. The background is see-through.")
            CatBox {
            }
        }
        CatToggle {
            label: I18n.t("Клавиша Win+Alt+A", "Win+Alt+A key")
            hint: I18n.t("прячет её и возвращает, работает и в полноэкранной игре; заодно правило niri для окна OBS", "Hides her and brings her back, in fullscreen games too; also niri's rule for the OBS window")
            checked: Config.stream.streamerKeys !== false
            onToggled: c => Config.stream.streamerKeys = c
        }
    }
    // the helper's versions (four each), for each of them apart
    component LookCard: PxButton {
        id: card
        required property var modelData
        property string who: "angel"
        // the angel's: the look she wears (a locked pick waits — services/Heaven)
        readonly property string current: who === "demon" ? Config.y2k.demonLook || "glitch" : Heaven.lookOk(Config.y2k.angelLook) ? Config.y2k.angelLook || "glitch" : "glitch"
        readonly property bool locked: who !== "demon" && !Heaven.lookOk(modelData.value)
        // (P5 slants the card: its corners eat into the words)
        width: Math.max(Theme.u * 64, lookLabel.implicitWidth + Theme.u * (card.p5 ? 20 : 8))
        height: Theme.u * 78
        checked: current === modelData.value
        enabled: !locked
        onClicked: {
            if (who === "demon")
                Config.y2k.demonLook = modelData.value;
            else
                Config.y2k.angelLook = modelData.value;
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.u * 4
            width: parent.width - Theme.u * 6
            height: parent.height - lookLabel.height - Theme.u * 10
            SpriteRig {
                visible: card.modelData.value === "chibi" || card.modelData.value === "glitch"
                anchors.centerIn: parent
                who: card.who
                variant: card.modelData.value === "glitch" ? "glitch" : ""
                px: Math.max(0.5, Theme.u / 4)
                width: implicitWidth
                height: implicitHeight
            }
            PxIcon {
                visible: card.modelData.value === "adult" || card.modelData.value === "mini"
                anchors.centerIn: parent
                readonly property bool mini: card.modelData.value === "mini"
                bitmap: mini ? (card.who === "demon" ? DemonMini.up : AngelMini.up) : (card.who === "demon" ? DemonArt.up : AngelArt.up)
                pixel: mini ? Math.max(1, Theme.u) : Math.max(1, Math.round(Theme.u * 0.75))
                ink: card.who === "demon" ? "#1a0a14" : (Theme.dark ? Theme.toneFor("text", parent) : Theme.toneFor("edge", parent))
                body: card.who === "demon" ? "#f7d9e3" : "#ffd9c7"
                fill: card.who === "demon" ? "#ff3b6b" : Theme.accent
                fill2: "#3a1a46"
                fill3: Theme.dark ? "#ffe07a" : "#f5c542"
                light: card.who === "demon" ? "#7a1e46" : "#ffffff"
                bad: "#d8203a"
                palette: mini ? ({}) : card.who === "demon" ? DemonArt.palette : Object.assign({}, AngelArt.palette, {
                    "o": Theme.hex(Theme.accent)
                })
            }
        }
        PxText {
            id: lookLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.u * 3
            kind: "tiny"
            font.bold: card.checked
            // P5 paints the picked card black: the words go paper
            color: card.p5 ? (card.checked ? Theme.p5Paper : Theme.p5Black) : Theme.text
            text: (card.checked ? "♡ " : "") + card.modelData.label
        }
        PxIcon {
            visible: card.locked
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.u * 2
            name: "lock"
            pixel: Math.max(1, Theme.u)
        }
    }
    CatGroup {
        name: "glitter"
        title: I18n.t("Блёстки", "Glitter")
        advanced: true
        icon: "sparkle"
        CatToggle {
            label: I18n.t("Шлейф за курсором", "Sparkle trail")
            hint: Heaven.lockHint("fx.sparkles") || I18n.t("видно, пока курсор над рабочим столом (над окнами он чужой — там блестит сам курсор)", "Shows while the pointer is over the desktop; over windows only the glitter cursor sparkles")
            enabled: Heaven.has("fx.sparkles")
            checked: Config.y2k.sparkles && Heaven.has("fx.sparkles")
            onToggled: c => Config.y2k.sparkles = c
        }
        CatCustom {
            present: Config.y2k.sparkles && page.screenNames.length > 1
            label: I18n.t("На экранах", "On screens")
            hint: I18n.t("ничего не выбрано — на всех; например, убери стримовый", "Nothing picked means all; e.g. leave out the streaming one")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.screenNames
                        PxButton {
                            required property string modelData
                            compact: true
                            checkable: true
                            checked: (Config.y2k.sparkleScreens || []).includes(modelData)
                            text: modelData
                            onClicked: Config.y2k.sparkleScreens = page.toggleIn(Config.y2k.sparkleScreens, modelData, checked)
                        }
                    }
                }
            }
        }
        CatButton {
            label: I18n.t("Блестящий курсор", "Glitter cursor")
            hint: !Cursors.glitterOk ? Heaven.lockHint("cursor.glitter") : Cursors.theme === "angelOS-Glitter" ? I18n.t("стоит ♡ другие курсоры — выше", "In use ♡ other cursors are above") : I18n.t("angelOS Pixel с мерцающими искорками, во всех программах", "angelOS Pixel with twinkling sparks, in every app")
            enabled: !Cursors.busy && Cursors.theme !== "angelOS-Glitter" && Cursors.glitterOk
            icon: "cursor"
            text: Cursors.busy ? I18n.t("Ставлю…", "Installing…") : I18n.t("Поставить", "Use it")
            onClicked: Cursors.install("glitter", true)
        }
    }
    CatGroup {
        name: "loading-screen"
        title: I18n.t("Загрузочный экран", "Loading screen")
        advanced: true
        icon: "monitor"
        CatToggle {
            label: I18n.t("При входе в систему", "On login")
            hint: I18n.t("крутится диск, «Вставьте диск 1…», полоска загрузки; один раз за вход, клик — пропустить", "A spinning disc, “insert disc 1…”, a loading bar; once per login, click to skip")
            checked: Config.y2k.boot
            onToggled: c => Config.y2k.boot = c
        }
        CatCustom {
            present: Config.y2k.boot && page.screenNames.length > 1
            label: I18n.t("На экранах", "On screens")
            hint: I18n.t("ничего не выбрано — на всех", "Nothing picked means all")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.screenNames
                        PxButton {
                            required property string modelData
                            compact: true
                            checkable: true
                            checked: (Config.y2k.bootScreens || []).includes(modelData)
                            text: modelData
                            onClicked: Config.y2k.bootScreens = page.toggleIn(Config.y2k.bootScreens, modelData, checked)
                        }
                    }
                }
            }
        }
        CatButton {
            icon: "play"
            text: I18n.t("Показать сейчас", "Show it now")
            onClicked: {
                page.nav.settingsOpen = false;
                Shell.bootOpen = true;
            }
        }
    }
    CatGroup {
        name: "demon-corner"
        title: I18n.t("В углу экрана", "In the corner of the screen")
        icon: Angel.demon ? "fire" : "heart"
        // with the game off (the setup wizard's "Just the desktop", `angelos game off`) nobody is
        // in the corner whatever this says: the toggle shows that, and switching her on brings
        // the game back — it used to stay on and show nothing
        CatToggle {
            label: I18n.t("Показывать", "Show her")
            hint: !Story.enabled ? I18n.t("игра выключена («Ангелочек» → «Игра»), поэтому её нет; включишь — вернётся и игра", "The game is off (Angel → The game), so she isn't there; switch her on and the game comes back too") : Angel.demon ? I18n.t("сидит в правом нижнем углу, язвит, болтает и пакостит; клик по ней — меню", "Sits in the bottom-right corner, teases, chats and plays pranks; click her for a menu") : I18n.t("живёт в правом нижнем углу, подсказывает и радуется вместе с тобой; клик по ней — меню", "Lives in the bottom-right corner, gives tips and cheers you on; click her for a menu")
            checked: Config.y2k.helper && Story.enabled
            onToggled: c => {
                if (c && !Story.enabled)
                    Story.setEnabled(true);
                Config.y2k.helper = c;
            }
        }
        CatChoice {
            label: I18n.t("На каком экране", "Screen")
            hint: I18n.t("главный выбирается в «Экранах»; там же — её трещины и лучи", "The main one is picked on the Displays page; her cracks and rays go along")
            combo: true
            model: [
                {
                    "label": I18n.t("Главный (", "Main (") + Shell.primaryName + ")",
                    "value": ""
                },
                {
                    "label": I18n.t("Где фокус", "Where the focus is"),
                    "value": "focus"
                }
            ].concat(page.screenNames.map(n => ({
                        "label": n,
                        "value": n
                    })))
            currentValue: Config.y2k.helperScreen
            onActivated: v => Config.y2k.helperScreen = v
        }
        CatSlider {
            label: I18n.t("Размер в углу", "Size in the corner")
            hint: I18n.t("75–200 %; Ctrl + колёсико мыши над ней — по 5 %. Размер ограничен шириной и 55 % высоты экрана", "75–200%; Ctrl + mouse wheel over her: 5% a notch. Size is capped by the screen width and 55% of its height")
            from: 75
            to: 200
            stepSize: 5
            value: Math.round((Config.y2k.helperScale || 1) * 100)
            suffix: "%"
            onMoved: v => Config.y2k.helperScale = Math.round(v) / 100
        }
        CatChoice {
            label: Angel.demon ? I18n.t("Болтает сама", "Talks on her own") : I18n.t("Советы сами по себе", "Tips on her own")
            model: [
                {
                    "label": I18n.t("Нет", "Off"),
                    "value": "off"
                },
                {
                    "label": I18n.t("Редко", "Rarely"),
                    "value": "rare"
                },
                {
                    "label": I18n.t("Часто", "Often"),
                    "value": "often"
                }
            ]
            currentValue: Config.y2k.helperTips
            onActivated: v => Config.y2k.helperTips = v
        }
        CatToggle {
            label: I18n.t("Шутит", "Jokes")
            hint: I18n.t("иногда вместо совета — шутка (на языке интерфейса)", "Now and then a joke instead of a tip (in the interface language)")
            checked: Config.y2k.jokes
            onToggled: c => Config.y2k.jokes = c
        }
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    // she comes by herself too; this calls her now (and sends the demon off)
                    PxButton {
                        visible: !Angel.demon
                        icon: "heart"
                        enabled: !Angel.transition
                        text: I18n.t("Позвать ангела", "Call the angel")
                        onClicked: {
                            const r = Angel.summon();
                            summonNote.text = r === "hidden" ? I18n.t("стрим-режим прячет её с экранов в эфире — выбери экран не в эфире или выключи «Ангелочек уходит с экрана»", "Stream mode keeps her off the streamed screens: pick another screen or switch off “The angel leaves the screen”") : "";
                        }
                    }
                    PxButton {
                        enabled: Config.y2k.helper
                        icon: "star"
                        text: I18n.t("Скажи что-нибудь", "Say something")
                        onClicked: {
                            Angel.hiddenUntil = 0;
                            Angel.tip();
                        }
                    }
                    PxButton {
                        enabled: Config.y2k.helper
                        icon: "sparkle"
                        text: I18n.t("Пошути", "Tell a joke")
                        onClicked: {
                            Angel.hiddenUntil = 0;
                            Angel.joke();
                        }
                    }
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                PxText {
                    id: summonNote
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    color: Theme.danger
                }
            }
        }
    }
    CatGroup {
        name: "looks"
        title: I18n.t("Внешность", "Looks")
        icon: "palette"
        CatNote {
            dim: true
            text: Angel.demon ? I18n.t("Нынешняя неоновая демоница без сна, прошлая чиби, суккуб 30×40 или чертёнок 20×21.", "Today's sleepless neon demon, the earlier chibi, a 30×40 succubus or a 20×21 imp.") : Angel.hellShown ? I18n.t("Нынешние глитч-девочки (ангел с треснувшим нимбом и неоновая демоница), прошлые чиби, взрослые пиксельные 30×40 или самые первые малышки 20×21. Ангел и демоница выбираются отдельно.", "Today's glitch girls (the cracked-halo angel and the neon demon), the earlier chibi, the adult 30×40 pixel ones or the very first 20×21 minis. The angel and the demon are picked apart.") : I18n.t("Нынешняя глитч-девочка (ангел с треснувшим нимбом), прошлая чиби, взрослая пиксельная 30×40 или самая первая малышка 20×21.", "Today's glitch girl (the cracked-halo angel), the earlier chibi, the adult 30×40 pixel one or the very first 20×21 mini.")
        }
        CatCustom {
            present: !Angel.demon
            label: I18n.t("Ангел", "Angel")
            // the looks still locked (services/Heaven) and what opens each
            hint: ["mini", "chibi", "adult"].filter(l => !Heaven.lookOk(l)).map(l => Heaven.label(Heaven.lookItem(l)) + " — " + Heaven.lockHint(Heaven.lookItem(l))).join("; ")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: [
                            {
                                "value": "glitch",
                                "label": I18n.t("Треснувший нимб (сейчас)", "Cracked halo (now)")
                            },
                            {
                                "value": "chibi",
                                "label": I18n.t("Чиби", "Chibi")
                            },
                            {
                                "value": "adult",
                                "label": I18n.t("Взрослая 30×40", "Adult 30×40")
                            },
                            {
                                "value": "mini",
                                "label": I18n.t("Малышка 20×21", "Mini 20×21")
                            }
                        ]
                        LookCard {
                            who: "angel"
                        }
                    }
                }
            }
        }
        // hell's own rows below show only while the demon rules (Angel.hellShown)
        CatCustom {
            present: Angel.hellShown
            label: I18n.t("Демоница", "Demon")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: [
                            {
                                "value": "glitch",
                                "label": I18n.t("Неон без сна (сейчас)", "Sleepless neon (now)")
                            },
                            {
                                "value": "chibi",
                                "label": I18n.t("Чиби", "Chibi")
                            },
                            {
                                "value": "adult",
                                "label": I18n.t("Суккуб 30×40", "Succubus 30×40")
                            },
                            {
                                "value": "mini",
                                "label": I18n.t("Чертёнок 20×21", "Imp 20×21")
                            }
                        ]
                        LookCard {
                            who: "demon"
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "angel-or-demon"
        title: Angel.hellShown ? I18n.t("Рай и ад", "Heaven and hell") : I18n.t("Ангел и портал", "Angel and the portal")
        icon: Angel.hellShown ? "fire" : "heart"
        CatCustom {
            label: I18n.t("Кто живёт в углу", "Who lives in the corner")
            hint: Angel.demon ? I18n.t("Демоница. Путь наверх лежит вниз, через круги: её меню → «Спросить…» → «Искать выход», не чаще раза в 10 минут. Сейчас: круг ", "The demon. The way up lies down, through the circles: her menu → “Ask…” → “Seek the way out”, once per 10 minutes at most. Now: circle ") + Theme.roman(Story.circleN(Story.circle)) + " · " + Story.circleName(Story.circle) : I18n.t("Ангелочек. Схвати её мышкой и скинь вниз — провалится в ад, и придёт демоница: тёмные обои, пошлые шутки и пакости, которые показывают фишки angelOS.", "Angel. Grab her with the mouse and throw her down: she drops into hell and the demon comes — dark wallpaper, cheeky jokes and pranks that show off angelOS features.")
            CatBox {
                PxIcon {
                    name: Angel.demon ? "fire" : "heart"
                    pixel: Theme.u * 2
                }
            }
        }
        CatButton {
            label: I18n.t("Портал", "Portal")
            hint: Angel.portalOpen ? I18n.t("открыт: в ад и обратно — когда захочешь, без мольб и бросков (ещё — в её меню и `angelos helper portal`); адские настройки — в аду", "Open: to hell and back whenever you like, no begging and no throwing (also in her menu and `angelos helper portal`); hell's settings are in hell") : I18n.t("откроется, когда ангел трижды вернётся из ада. Возвращений: ", "Opens once the angel has come back from hell three times. Comebacks: ") + Math.min(Angel.returns, Angel.returnsNeeded) + "/" + Angel.returnsNeeded
            enabled: Angel.portalOpen && !Angel.transition
            icon: Angel.portalOpen ? "sparkle" : "lock"
            accent: Angel.portalOpen
            text: !Angel.portalOpen ? I18n.t("Закрыт", "Closed") : Angel.demon ? I18n.t("В рай", "To heaven") : I18n.t("В ад", "To hell")
            onClicked: Angel.portal()
        }
    }
    CatGroup {
        name: "game-effects"
        title: I18n.t("Эффекты", "Effects")
        icon: "sparkle"
        CatChoice {
            label: I18n.t("Дрожание текста", "Text tremble")
            hint: I18n.t("буквы в её репликах иногда подёргиваются на пиксель, как в Undertale", "Now and then a letter in her lines twitches by a pixel, like in Undertale")
            model: [
                {
                    "label": I18n.t("Нет", "Off"),
                    "value": "off"
                },
                {
                    "label": I18n.t("Слегка", "Light"),
                    "value": "light"
                },
                {
                    "label": I18n.t("Сильно", "Strong"),
                    "value": "strong"
                }
            ]
            currentValue: Config.y2k.textShake
            onActivated: v => Config.y2k.textShake = v
        }
        CatToggle {
            label: I18n.t("Тряска экрана", "Screen shake")
            hint: Angel.hellShown ? I18n.t("когда ангел и демоница меняются, экран трясётся и бьётся стекло; с демоницей ещё сыплются 8-битные камни", "When the angel and the demon swap the screen shakes and the glass breaks; with the demon 8-bit rocks tumble down too") : I18n.t("когда ангел уходит через портал или возвращается, экран трясётся и бьётся стекло", "When the angel leaves through the portal or comes back the screen shakes and the glass breaks")
            checked: Config.y2k.shake
            onToggled: c => Config.y2k.shake = c
        }
        CatToggle {
            label: I18n.t("Лучи и хор ангела", "The angel's rays and choir")
            hint: Heaven.lockHint("fx.rays") || I18n.t("когда она возвращается из ада: полторы секунды солнца справа (при запуске — только самый первый раз)", "When she comes back from hell: a second and a half of sunshine on the right (at start-up only the very first time)")
            enabled: Heaven.has("fx.rays")
            checked: Config.y2k.heavenFx && Heaven.has("fx.rays")
            onToggled: c => Config.y2k.heavenFx = c
        }
    }
    CatGroup {
        name: "sounds"
        title: I18n.t("Звуки", "Sounds")
        icon: "speaker"
        // the sounds and her voice are set in one place: System sounds
        CatLink {
            label: Angel.hellShown ? I18n.t("Звуки angelOS, голос ангела и демоницы", "angelOS sounds, the angel's and the demon's voice") : I18n.t("Звуки angelOS и голос ангела", "angelOS sounds and the angel's voice")
            hint: I18n.t("включить, набор, громкость, каждый звук отдельно", "on or off, the pack, the volume, every sound on its own")
            page: "sfx"
        }
    }
    // hell's versions of everything, a sub-page of its own (only while the demon is about)
    CatGroup {
        name: "hell"
        title: I18n.t("Ад", "Hell")
        icon: "pentagram"
        advanced: true
        present: Angel.hellShown
        CatChoice {
            present: Angel.hellShown
            label: I18n.t("ПКМ в аду", "Right-click menu in hell")
            hint: DeskMenu.heavenly.includes(DeskMenu.chosen) ? I18n.t("пока правит демоница; вернётся ангел — снова твоё меню. Райское («" + DeskMenu.styleLabel(DeskMenu.chosen) + "») в ад не спускается: «как обычно» здесь — меню круга", "while the demon rules; the angel brings your own menu back. Heaven's own (“" + DeskMenu.styleLabel(DeskMenu.chosen) + "”) never comes down: “as usual” here is the circle's own") : I18n.t("пока правит демоница; вернётся ангел — снова твоё меню", "while the demon rules; the angel brings your own menu back")
            combo: true
            // each circle's own (story/circles.json → dress), the pentagram, one circle's
            // look always, or the usual menus
            model: [
                {
                    "label": DeskMenu.styleLabel("circle"),
                    "value": "circle"
                },
                {
                    "label": DeskMenu.styleLabel("pentagram"),
                    "value": "pentagram"
                }
            ].concat(HellLook.ids.filter(c => c !== "base" && HellLook.looks[c].dress).map(c => ({
                            "label": DeskMenu.styleLabel(HellLook.looks[c].dress.menu) + " · " + I18n.label(HellLook.looks[c].name),
                            "value": HellLook.looks[c].dress.menu
                        }))).concat([
                {
                    "label": I18n.t("Как обычно (моё меню)", "As usual (my menu)"),
                    "value": ""
                },
                {
                    "label": I18n.t("Кольцо", "Ring"),
                    "value": "radial"
                },
                {
                    "label": I18n.t("Y2K глянец", "Y2K gloss"),
                    "value": "y2k"
                },
                {
                    "label": I18n.t("Плитки", "Tiles"),
                    "value": "tiles"
                }
            ])
            currentValue: Config.y2k.hellMenu || ""
            onActivated: v => Config.y2k.hellMenu = v
        }
        CatChoice {
            present: Angel.hellShown
            label: I18n.t("Настройки в аду", "Settings in hell")
            hint: I18n.t("Вид окна настроек в аду: свой у каждого круга или старая книга.", "How Settings look in hell: one per circle, or an old book.")
            combo: true
            model: [
                {
                    "label": I18n.t("Свой у каждого круга", "Each circle's own"),
                    "value": "circle"
                },
                {
                    "label": HellLook.dressName("grimoire"),
                    "value": "grimoire"
                }
            ].concat(HellLook.ids.filter(c => c !== "base" && HellLook.looks[c].dress).map(c => ({
                            "label": HellLook.dressName(HellLook.looks[c].dress.settings) + " · " + I18n.label(HellLook.looks[c].name),
                            "value": HellLook.looks[c].dress.settings
                        }))).concat([
                {
                    "label": I18n.t("Как обычно", "As usual"),
                    "value": ""
                }
            ])
            currentValue: Config.y2k.hellSettings || ""
            onActivated: v => Config.y2k.hellSettings = v
        }
        CatChoice {
            present: Angel.hellShown
            label: I18n.t("«Пуск» в аду", "Start in hell")
            hint: I18n.t("«Пуск» в цветах круга. «Своё адское» — отдельное меню ада.", "Start in the circle's colours. Hell's own: a menu of its own.")
            model: [
                {
                    "label": I18n.t("Адская версия", "Hell version"),
                    "value": "skin"
                },
                {
                    "label": I18n.t("Своё адское", "Hell's own"),
                    "value": "hell"
                },
                {
                    "label": I18n.t("Как обычно", "As usual"),
                    "value": ""
                }
            ]
            currentValue: Config.y2k.hellStart || ""
            onActivated: v => Config.y2k.hellStart = v
        }
        CatChoice {
            present: Angel.hellShown
            label: I18n.t("Alt+Tab в аду", "Alt+Tab in hell")
            hint: I18n.t("«Своё адское» — окно " + I18n.exe("inferno") + ": выбранное окно над пентаграммой, столы — круги ада. «Адская версия» — твой стиль Alt+Tab в цветах круга", "“Hell's own” is an " + I18n.exe("inferno") + " window: the pick over a pentagram, desks are hell's circles. “Hell version” is your Alt+Tab style in the circle's colours")
            model: [
                {
                    "label": I18n.t("Своё адское", "Hell's own"),
                    "value": "hell"
                },
                {
                    "label": I18n.t("Адская версия", "Hell version"),
                    "value": "skin"
                },
                {
                    "label": I18n.t("Как обычно", "As usual"),
                    "value": ""
                }
            ]
            currentValue: Config.y2k.hellAltTab || ""
            onActivated: v => Config.y2k.hellAltTab = v
            CatButton {
                compact: true
                icon: "play"
                text: I18n.t("Попробовать", "Try it")
                onClicked: AltTab.tryIt("")
            }
        }
        CatToggle {
            present: Angel.hellShown
            label: I18n.t("Терминал в аду", "Terminal in hell")
            hint: I18n.t("Терминалы в цветах круга: тёмный фон и костяной текст.", "Terminals in the circle's colours: a dark background and bone text.")
            checked: Config.y2k.hellTerminal
            onToggled: c => Config.y2k.hellTerminal = c
        }
        CatToggle {
            present: Angel.hellShown
            label: I18n.t("Приложения в аду", "Apps in hell")
            hint: I18n.t("Программы целиком в адских цветах, а не только заголовки.", "Apps wholly in hell's colours, not just their title bars.")
            checked: Config.y2k.hellApps
            onToggled: c => Config.y2k.hellApps = c
        }
        CatToggle {
            present: Angel.hellShown
            label: I18n.t("Панель в аду", "Bar in hell")
            hint: I18n.t("У каждого вида панели адская версия. Док остаётся обычным.", "Every bar style has a hell version. The dock stays as it is.")
            checked: Config.y2k.hellBar
            onToggled: c => Config.y2k.hellBar = c
        }
        CatToggle {
            present: Angel.hellShown
            label: I18n.t("Лирика в аду", "Lyrics in hell")
            hint: I18n.t("Строка на панели — адской готикой в цвете круга, без анимаций.", "The bar's line in hell's blackletter, in the circle's colour, no animation.")
            checked: Config.y2k.hellLyrics
            onToggled: c => Config.y2k.hellLyrics = c
            CatButton {
                compact: true
                icon: "fire"
                text: I18n.t("Салют", "Salute")
                onClicked: {
                    const sc = Shell.primaryScreen || Shell.screens[0];
                    if (sc)
                        HellFx.fireworks(sc.name, sc.width / 2, BarLayout.bottom ? sc.height - Theme.u * 12 : Theme.u * 12, !BarLayout.bottom);
                }
            }
        }
        CatButton {
            present: Angel.hellShown
            label: I18n.t("Колесо Ада", "Wheel of Hell")
            hint: I18n.t("Виджет на стол, только в аду: раз в 20 минут крутишь колесо.", "A desktop widget, hell only: a spin every 20 minutes.")
            compact: true
            icon: "pentagram"
            text: DesktopWidgets.widgets.some(w => w.type === "hellwheel") ? I18n.t("Уже на столе", "On the desk") : I18n.t("Поставить на стол", "Put it on the desk")
            enabled: !DesktopWidgets.widgets.some(w => w.type === "hellwheel")
            onClicked: DesktopWidgets.add("hellwheel", Shell.primaryName)
        }
        CatToggle {
            present: Angel.hellShown
            label: I18n.t("Виджеты в аду", "Widgets in hell")
            hint: I18n.t("Виджеты в аду сгорают и встают адскими. Плагины без своей версии перекрашиваются.", "In hell widgets burn and rise anew. Plugins without a hell look are re-inked.")
            checked: Config.y2k.hellWidgets
            onToggled: c => Config.y2k.hellWidgets = c
        }
        CatChoice {
            present: Angel.hellShown
            label: I18n.t("Какой ад на обоях", "Which hell on the wallpaper")
            hint: I18n.t("Какие обои показывать, пока правит демоница.", "Which wallpaper shows while the demon rules.")
            model: [
                {
                    "label": I18n.t("Картины", "Paintings"),
                    "value": "pack"
                },
                {
                    "label": I18n.t("Нарисованный", "Drawn"),
                    "value": "drawn"
                }
            ]
            currentValue: Config.y2k.hellStyle
            onActivated: v => Config.y2k.hellStyle = v
        }
        CatChoice {
            present: Angel.hellShown
            label: I18n.t("Трещины на экране", "Screen cracks")
            hint: I18n.t("Чем ближе мышь к трещинам, тем прозрачнее стекло; клики проходят сквозь.", "The nearer the pointer, the clearer the glass; clicks go through.")
            model: [
                {
                    "label": I18n.t("Сильно", "Full"),
                    "value": "full"
                },
                {
                    "label": I18n.t("Слабо", "Weak"),
                    "value": "weak"
                },
                {
                    "label": I18n.t("Нет", "Off"),
                    "value": "off"
                }
            ]
            currentValue: Config.y2k.cracks
            onActivated: v => Config.y2k.cracks = v
        }
        CatChoice {
            id: breakRow
            present: Angel.hellShown && Config.y2k.cracks !== "off"
            // D4: the punch and what spreads from it, drawn as on the desktop
            preview: "Breakage"
            label: I18n.t("Что она ломает", "What she breaks")
            hint: I18n.t("Что появляется на месте удара: своё у каждого круга, одно и то же или случайно.", "What shows where the fist lands: one per circle, always the same, or random.")
            combo: true
            model: [
                {
                    "label": I18n.t("По кругу", "By circle"),
                    "value": "circle"
                },
                {
                    "label": I18n.t("Стекло", "Glass"),
                    "value": "glass"
                },
                {
                    "label": I18n.t("Разбитый телевизор", "Smashed TV"),
                    "value": "tv"
                },
                {
                    "label": I18n.t("Прожжённая дыра", "Burnt hole"),
                    "value": "burn"
                },
                {
                    "label": I18n.t("Следы когтей", "Claw marks"),
                    "value": "claws"
                },
                {
                    "label": I18n.t("Выжженная печать", "Burnt sigil"),
                    "value": "sigil"
                },
                {
                    "label": I18n.t("Запотевшее стекло", "Fogged glass"),
                    "value": "fog"
                },
                {
                    "label": I18n.t("Трещина вихрем", "Whirling crack"),
                    "value": "whirl"
                },
                {
                    "label": I18n.t("Сочащаяся жижа", "Oozing"),
                    "value": "ooze"
                },
                {
                    "label": I18n.t("Вбитая монета", "A coin hammered in"),
                    "value": "coin"
                },
                {
                    "label": I18n.t("Круги как на воде", "Rings like on water"),
                    "value": "ripple"
                },
                {
                    "label": I18n.t("Брызги", "Spatter"),
                    "value": "spatter"
                },
                {
                    "label": I18n.t("Смола", "Pitch"),
                    "value": "pitch"
                },
                {
                    "label": I18n.t("Иней", "Frost"),
                    "value": "frost"
                },
                {
                    "label": I18n.t("Случайно", "Random"),
                    "value": "random"
                }
            ]
            currentValue: Config.y2k.breakage || "circle"
            onActivated: v => {
                Config.y2k.breakage = v;
                breakRow.show(v, "");
            }
        }
    }
    // the novel (services/Novel): chapters written in the editor, played out on the desktop
    CatGroup {
        name: "novel"
        title: I18n.t("Новелла", "The novel")
        advanced: true
        icon: "document"
        CatToggle {
            label: I18n.t("Истории ангела", "The angel's stories")
            hint: I18n.t("главы из папки ", "Chapters from ") + Novel.dir + I18n.t(": записки на обоях после сна, вопросы с вариантами ответа («?» над ней — нажми), её записки про тебя", ": notes on the wallpaper after sleep, questions with answers to pick (a “?” over her — click), her notes about you")
            checked: Config.novel.enabled
            onToggled: c => Config.novel.enabled = c
        }
        CatCustom {
            present: Config.novel.enabled
            label: I18n.t("Сейчас", "Now")
            hint: {
                const s = Novel.state;
                const st = Novel.stories[s.chapter];
                if (!Object.keys(Novel.stories).length)
                    return Novel.editorHere ? I18n.t("глав нет — открой редактор", "No chapters yet — open the editor") : I18n.t("глав пока нет", "No chapters yet");
                if (!s.chapter)
                    return I18n.t("ещё не началась: первая глава ждёт выхода компьютера из сна (или «Начать сейчас»)", "Not started: the first chapter waits for the computer to wake from sleep (or “Start now”)");
                return (st ? st.title || s.chapter : s.chapter) + (s.main.node ? " · " + s.main.node + (s.main.wait ? " (" + s.main.wait.replace(/^at:\d+/, I18n.t("ждёт времени", "waits for its time")) + ")" : "") : (s.done[s.chapter] ? I18n.t(" · главная линия пройдена", " · main line done") : "")) + (s.free ? I18n.t(" · вопросы и записки приходят сами", " · questions and notes come by themselves") : "");
            }
            CatBox {
                Flow {
                width: parent.width
                spacing: Theme.u * 2
                // the author's tool (E): only where it was fetched (`angelos author`)
                PxButton {
                    visible: Novel.editorHere
                    compact: true
                    accent: true
                    icon: "document"
                    text: I18n.t("Редактор диалогов", "Dialogue editor")
                    onClicked: Novel.edit()
                }
                PxButton {
                    compact: true
                    icon: "folder"
                    text: I18n.t("Папка", "Folder")
                    onClicked: Shell.openPath(Novel.dir)
                }
                PxButton {
                    compact: true
                    icon: "play"
                    text: I18n.t("Начать сейчас", "Start now")
                    onClicked: {
                        Novel.reload();
                        startLater.restart();
                    }
                    Timer {
                        id: startLater
                        interval: 600
                        onTriggered: Novel.startChapter(Novel.state.chapter || Object.keys(Novel.stories).sort()[0] || "")
                    }
                }
                PxButton {
                    compact: true
                    icon: "chat"
                    text: I18n.t("Вопрос сейчас", "A question now")
                    onClicked: Novel.forceQuestion()
                }
                PxButton {
                    compact: true
                    flat: true
                    icon: "refresh"
                    text: I18n.t("С самого начала", "From the very start")
                    onClicked: Novel.reset()
                }
            }
            }
        }
        CatChoice {
            present: Config.novel.enabled
            label: I18n.t("Кто ты", "Who you are")
            hint: I18n.t("как ангел к тебе обращается (хотел / хотела). Она всё равно однажды спросит сама", "How the angel addresses you. She still asks one day herself")
            model: [
                {
                    "label": I18n.t("Парень", "A guy"),
                    "value": "m"
                },
                {
                    "label": I18n.t("Девушка", "A girl"),
                    "value": "f"
                },
                {
                    "label": I18n.t("Не указывать", "Rather not say"),
                    "value": ""
                }
            ]
            currentValue: Config.novel.gender || ""
            onActivated: v => Config.novel.gender = v
        }
        CatField {
            present: Config.novel.enabled
            label: I18n.t("Как тебя зовут", "Your name")
            hint: I18n.t("для {name} в репликах; пусто — имя пользователя", "For {name} in her lines; empty — your login name")
            text: Config.novel.name || ""
            placeholder: StartApps.userName
            onEdited: Config.novel.name = text.trim()
        }
    }
}
