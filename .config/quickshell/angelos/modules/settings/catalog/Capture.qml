// The settings once in CapturePage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    id: page
    heading: I18n.t("Снимки и запись", "Screenshots and recording")
    subtitle: I18n.t("Снимок области — Win+Shift+S, запись области — Win+Shift+R (ещё раз — стоп).", "A region screenshot is Win+Shift+S, recording a region is Win+Shift+R (again to stop).")
    readonly property var skins: [
        {
            "id": "ropes",
            "label": I18n.t("Верёвочки", "Ropes"),
            "hint": I18n.t("физика верёвок, при записи превращаются в землю из Terraria", "rope physics; turn into Terraria dirt while recording")
        },
        {
            "id": "window",
            "label": I18n.exe("screenshot"),
            "hint": I18n.t("NGO-окошко: розовый заголовок, бегущий пунктир, сердечки по углам; при записи — «● REC " + I18n.exe("recording") + "» с таймером", "An NGO window: pink title bar, marching ants, corner hearts; while recording — “● REC " + I18n.exe("recording") + "” with a timer")
        },
        {
            "id": "stream",
            "label": I18n.t("Стрим Ame", "Ame stream"),
            "hint": I18n.t("цепочка бегущих сердечек, LIVE, «kawaii»-пузырь и сканлайны; при записи — зрители и таймер", "A chain of marching hearts, LIVE badge, a kawaii bubble and scanlines; while recording — viewers and a timer")
        }
    ]
    property int stamp: 0
    function renderPreviews() {
        previews.running = false;
        previews.running = true;
    }
    Component.onCompleted: renderPreviews()
    Process {
        id: previews
        command: ["sh", "-c", 'mkdir -p "$1" && for s in ropes window stream; do python3 "$2" --preview "$s" "$1/capture-$s.png"; done', "sh", Config.cacheDir, Quickshell.shellDir + "/scripts/capture_skins.py"]
        // only pictures that were drawn (no python-cairo: none, and no broken images)
        onExited: code => {
            if (code === 0)
                page.stamp++;
        }
    }
    Connections {
        target: Config.capture
        function onThemeColorsChanged() {
            page.renderPreviews();
        }
    }
    // a folder from the desktop's file chooser (scripts/pick-file.py --dir) into a capture key
    property string pickKey: ""
    function pickDir(key, title) {
        pickKey = key;
        dirPicker.command = ["python3", Quickshell.shellDir + "/scripts/pick-file.py", "--dir", title];
        dirPicker.running = true;
    }
    Process {
        id: dirPicker
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                if (d && page.pickKey)
                    Config.capture[page.pickKey] = d;
            }
        }
    }
    component DirRow: SettingRow {
        id: dirRow
        property string key: ""
        property string fallback: ""
        property string pickTitle: ""
        Row {
            width: parent.width
            spacing: Theme.u * 3
            PxText {
                // the path gives way to the buttons: a narrow window elides it more
                width: Math.max(0, Math.min(implicitWidth, Theme.u * 110, parent.width - chooseButton.width - (resetDir.visible ? resetDir.width + parent.spacing : 0) - parent.spacing))
                anchors.verticalCenter: parent.verticalCenter
                text: Config.capture[dirRow.key] || dirRow.fallback
                elide: Text.ElideMiddle
                dim: !Config.capture[dirRow.key]
            }
            PxButton {
                id: chooseButton
                compact: true
                icon: "folder"
                text: I18n.t("Выбрать…", "Choose…")
                onClicked: page.pickDir(dirRow.key, dirRow.pickTitle)
            }
            PxButton {
                id: resetDir
                compact: true
                visible: !!Config.capture[dirRow.key]
                icon: "refresh"
                onClicked: Config.capture[dirRow.key] = ""
            }
        }
    }
    CatGroup {
        name: "shots"
        title: I18n.t("Снимки", "Screenshots")
        icon: "camera"
        CatCustom {
            wide: true
            CatBox {
                DirRow {
                    label: I18n.t("Папка для снимков", "Screenshots folder")
                    key: "shotDir"
                    fallback: "~/Pictures/Screenshots"
                    pickTitle: I18n.t("Куда сохранять снимки", "Where screenshots go")
                }
            }
        }
        CatToggle {
            label: I18n.t("Копировать в буфер", "Copy to the clipboard")
            hint: I18n.t("снимок сразу можно вставить в чат", "paste the shot into a chat right away")
            checked: Config.capture.shotCopy
            onToggled: v => Config.capture.shotCopy = v
        }
        // one place for the thumbnail: the corner (services/ShotEdit) or the Halo's own
        // (services/Halo: halo.shotThumb, only while the corner one is off)
        CatChoice {
            label: I18n.t("Миниатюра снимка", "The shot's thumbnail")
            hint: Config.capture.shotPreview ? I18n.t("ждёт в углу: повернуть, обрезать, скрыть личное", "Waits in the corner: turn, crop, hide what is private") : I18n.t("на 4 секунды: утащи картинку или положи на полку", "For 4 seconds: drag the picture out or put it on the shelf")
            model: [["corner", "В углу", "In the corner"], ["halo", "В Нимбе", "In the Halo"], ["off", "Нигде", "Nowhere"]].filter(c => c[0] !== "halo" || Config.halo.enabled).map(c => ({
                        "label": I18n.t(c[1], c[2]),
                        "value": c[0]
                    }))
            currentValue: Config.capture.shotPreview ? "corner" : Config.halo.enabled && Config.halo.shotThumb !== false ? "halo" : "off"
            onActivated: v => {
                Config.capture.shotPreview = v === "corner";
                Config.halo.shotThumb = v === "halo";
            }
        }
        CatCustom {
            present: Config.capture.shotPreview
            label: I18n.t("Где миниатюра", "Where the thumbnail goes")
            hint: I18n.t("«Сама» — в свободное место, мимо ангела и виджетов; или клик по месту на мониторе", "«By itself»: a free place, clear of the angel and the widgets; or click a place on the display")
            CatBox {
                Flow {
                    id: whereRow
                    width: parent.width
                    spacing: Theme.u * 4
                    // side by side the button sits level with the monitor's middle; too narrow, the
                    // monitor goes under it (a Flow can't centre by anchors)
                    Item {
                        width: autoButton.width
                        height: whereRow.width >= autoButton.width + whereRow.spacing + wherePicker.width ? wherePicker.height : autoButton.height
                        PxButton {
                            id: autoButton
                            anchors.verticalCenter: parent.verticalCenter
                            compact: true
                            checked: (Config.capture.shotPreviewAt || "auto") === "auto"
                            text: I18n.t("Сама", "By itself")
                            onClicked: Config.capture.shotPreviewAt = "auto"
                        }
                    }
                    PxPositionPicker {
                        id: wherePicker
                        value: Config.capture.shotPreviewAt === "auto" ? "" : Config.capture.shotPreviewAt
                        onPicked: v => Config.capture.shotPreviewAt = v
                    }
                }
            }
        }
        CatToggle {
            label: I18n.t("Открывать после снимка", "Open after the shot")
            hint: I18n.t("в просмотрщике картинок", "in the image viewer")
            checked: Config.capture.shotOpen
            onToggled: v => Config.capture.shotOpen = v
        }
        CatToggle {
            label: I18n.t("Классический выбор области", "Classic region selection")
            hint: I18n.t("клавиша скриншота открывает старый выбор рамкой (скины ниже), без поиска, текста и автовыделения", "the screenshot key opens the old frame selector (the skins below), no search, text or smart areas")
            checked: Config.capture.classic
            onToggled: v => Config.capture.classic = v
        }
    }
    CatGroup {
        name: "circle"
        title: I18n.t("Обвести и найти", "Circle to search")
        icon: "search"
        CatButton {
            label: I18n.t("Как вызвать", "How to open")
            hint: I18n.t("Win+Shift+S или Print: экран замирает, выбери область, окно или текст.", "Win+Shift+S or Print: the screen freezes, pick an area, a window or text.")
            text: I18n.t("Попробовать", "Try it")
            icon: "search"
            onClicked: CircleHost.start("")
        }
        CatChoice {
            label: I18n.t("Искать в", "Search with")
            combo: true
            model: ["google", "duckduckgo", "yandex", "ecosia", "bing", "brave", "mojeek"].map(id => ({
                        "value": id,
                        "label": {
                            "google": "Google",
                            "duckduckgo": "DuckDuckGo",
                            "yandex": I18n.t("Яндекс", "Yandex"),
                            "ecosia": "Ecosia",
                            "bing": "Bing",
                            "brave": "Brave",
                            "mojeek": "Mojeek"
                        }[id]
                    }))
            currentValue: Config.circle.engine
            onActivated: v => Config.circle.engine = v
        }
        CatChoice {
            label: I18n.t("Переводить на", "Translate into")
            hint: I18n.t("«сам» — русский текст на английский, остальное на русский", "“auto”: Russian into English, the rest into Russian")
            combo: true
            model: [
                {
                    "value": "auto",
                    "label": I18n.t("сам", "auto")
                },
                {
                    "value": "ru",
                    "label": I18n.t("русский", "Russian")
                },
                {
                    "value": "en",
                    "label": I18n.t("английский", "English")
                },
                {
                    "value": "uk",
                    "label": I18n.t("украинский", "Ukrainian")
                },
                {
                    "value": "de",
                    "label": I18n.t("немецкий", "German")
                },
                {
                    "value": "ja",
                    "label": I18n.t("японский", "Japanese")
                }
            ]
            currentValue: Config.circle.translateTo
            onActivated: v => Config.circle.translateTo = v
        }
        CatToggle {
            label: I18n.t("Подсвечивать слова сразу", "Outline the words at once")
            hint: I18n.t("весь экран читается сразу, по строке можно просто нажать", "The whole screen is read at once; click a line to pick it")
            checked: Config.circle.liveText
            onToggled: v => Config.circle.liveText = v
        }
        CatToggle {
            label: I18n.t("Ссылки — в мини-остров", "Links into the mini island")
            hint: I18n.t("Ссылки открываются в маленьком окне в углу, а не в браузере. Win+Alt+I — клики сквозь него.", "Links open in a small corner window instead of the browser. Win+Alt+I clicks through it.")
            checked: Config.island.enabled
            onToggled: v => Config.island.enabled = v
        }
        CatToggle {
            label: I18n.t("Кнопка «Найти картинкой»", "“Search the picture” button")
            hint: I18n.t("отправляет обведённый кусок в Google Lens", "sends the circled piece to Google Lens")
            checked: Config.circle.lens
            onToggled: v => Config.circle.lens = v
        }
        CatToggle {
            present: Config.circle.lens
            label: I18n.t("Результаты Lens в окне angelOS", "Lens results in an angelOS window")
            hint: I18n.t("Похожие картинки и текст — в своём окне. Выключено — страница Google в маленьком окне.", "Similar pictures and text in a window of its own. Off: Google's page in the small window.")
            checked: Config.circle.lensWindow
            onToggled: v => Config.circle.lensWindow = v
        }
        CatCustom {
            label: I18n.t("Чему научился", "What it has learned")
            hint: I18n.t("Запоминает, как ты поправляешь рамки и текст в каждой программе. Не уверен — спросит после снимка.", "Learns how you fix frames and text in each app. When unsure, it asks after the shot.")
            CatBox {
                PxButton {
                    readonly property int n: CircleHost.learnedCount
                    text: n ? I18n.t("Забыть (" + n + ")", "Forget (" + n + ")") : I18n.t("Пока ничего", "Nothing yet")
                    enabled: n > 0
                    icon: "trash"
                    onClicked: CircleHost.forget()
                }
            }
        }
    }
    CatGroup {
        name: "shots-more"
        title: I18n.t("Формат снимка", "Screenshot format")
        icon: "image"
        CatChoice {
            label: I18n.t("Формат", "Format")
            hint: I18n.t("PNG — без потерь, JPG — меньше весит", "PNG is lossless, JPG is smaller")
            model: [
                {
                    "label": "PNG",
                    "value": "png"
                },
                {
                    "label": "JPG",
                    "value": "jpg"
                }
            ]
            currentValue: Config.capture.shotFormat
            onActivated: v => Config.capture.shotFormat = v
        }
        CatToggle {
            label: I18n.t("Курсор на снимке", "The pointer in the shot")
            checked: Config.capture.shotCursor
            onToggled: v => Config.capture.shotCursor = v
        }
    }
    CatGroup {
        name: "recording"
        title: I18n.t("Запись экрана", "Screen recording")
        icon: "play"
        CatCustom {
            wide: true
            CatBox {
                DirRow {
                    label: I18n.t("Папка для записей", "Recordings folder")
                    key: "recordDir"
                    fallback: "~/Videos"
                    pickTitle: I18n.t("Куда сохранять записи", "Where recordings go")
                }
            }
        }
        CatChoice {
            label: I18n.t("Звук в записи", "Sound in the recording")
            hint: I18n.t("«Система» — то, что ты слышишь", "“System” is what you hear")
            model: [
                {
                    "label": I18n.t("Без звука", "None"),
                    "value": "none"
                },
                {
                    "label": I18n.t("Система", "System"),
                    "value": "system"
                },
                {
                    "label": I18n.t("Микрофон", "Microphone"),
                    "value": "mic"
                }
            ]
            currentValue: Config.capture.recordAudio === "both" ? "system" : Config.capture.recordAudio
            onActivated: v => Config.capture.recordAudio = v
        }
        CatChoice {
            label: I18n.t("Кадров в секунду", "Frames per second")
            model: [30, 60, 120].map(n => ({
                        "label": String(n),
                        "value": n
                    }))
            currentValue: Config.capture.recordFps
            onActivated: v => Config.capture.recordFps = v
        }
        // services/Capture: gpu-screen-recorder's replay buffer
        CatToggle {
            label: I18n.t("Мгновенный повтор", "Instant replay")
            hint: !Capture.canReplay ? I18n.t("Нужна программа записи: sudo pacman -S gpu-screen-recorder", "Needs the recorder: sudo pacman -S gpu-screen-recorder") : I18n.t("Win+Alt+G — последние секунды главного экрана на Полку. Почти не ест FPS. Окна, скрытые от эфира, в повтор попадают", "Win+Alt+G puts the main screen's last seconds on the shelf. Costs almost no FPS. Windows hidden from the stream do get into it")
            enabled: Capture.canReplay
            checked: Config.capture.replay
            onToggled: v => Config.capture.replay = v
        }
        // services/Timelapse: gpu-screen-recorder at a frame a second, glued at midnight
        CatCustom {
            label: I18n.t("Таймлапс дня", "The day's timelapse")
            hint: !Capture.canReplay ? I18n.t("Нужна программа записи: sudo pacman -S gpu-screen-recorder", "Needs the recorder: sudo pacman -S gpu-screen-recorder") : I18n.t("главный экран весь день, кадр в секунду, маленький; в полночь — «Таймлапс <дата>.mp4» в папке записей, со временем в углу. Пишется всё — что выкладывать, решаешь ты", "The main screen all day, a frame a second, small; at midnight «Таймлапс <date>.mp4» in the recordings folder, the time in a corner. Everything is recorded: what to post is yours")
            CatBox {
                Row {
                    spacing: Theme.u * 3
                    PxButton {
                        compact: true
                        visible: Config.capture.timelapse
                        icon: "play"
                        text: Timelapse.building ? I18n.t("Собираю…", "Building…") : I18n.t("Собрать сегодня", "Build today")
                        enabled: !Timelapse.building
                        onClicked: Timelapse.buildToday()
                    }
                    PxToggle {
                        enabled: Capture.canReplay
                        checked: Config.capture.timelapse
                        onToggled: v => Config.capture.timelapse = v
                    }
                }
            }
        }
        CatChoice {
            present: Config.capture.timelapse
            label: I18n.t("Кадр ролика", "A frame of the video")
            hint: I18n.t("раз во сколько секунд дня — меньше значит длиннее ролик (за 8 часов: 30 с — около 40 с видео)", "Every how many seconds of the day: less means a longer video (8 hours at 30 s: about 40 s of video)")
            model: [10, 30, 60].map(n => ({
                        "label": I18n.t(n + " с", n + " s"),
                        "value": n
                    }))
            currentValue: Config.capture.timelapseStep
            onActivated: v => Config.capture.timelapseStep = v
        }
        CatChoice {
            present: Config.capture.replay
            label: I18n.t("Длина повтора", "Replay length")
            hint: I18n.t("Сколько последних секунд сохраняет Win+Alt+G.", "How many last seconds Win+Alt+G saves.")
            model: [15, 30, 60, 120].map(n => ({
                        "label": I18n.t(n + " с", n + " s"),
                        "value": n
                    }))
            currentValue: Config.capture.replaySec
            onActivated: v => Config.capture.replaySec = v
        }
        // services/VideoGrab: the button in Quick Look and on the shelf
        CatChoice {
            label: I18n.t("Лимит для Discord", "Discord's limit")
            hint: I18n.t("Кнопка «≤20 МБ» в просмотре видео и на Полке ужимает ролик под это число", "The «≤20 MB» button in a video's Quick Look and on the shelf squeezes it under this size")
            model: [10, 20, 50, 500].map(n => ({
                        "label": I18n.t(n + " МБ", n + " MB"),
                        "value": n
                    }))
            currentValue: Config.capture.discordMb
            onActivated: v => Config.capture.discordMb = v
        }
        // the keys pressed, on screen (services/KeyCast): for guides and streams
        CatToggle {
            label: I18n.t("Показывать нажатые клавиши", "Show the keys pressed")
            hint: KeyCast.error !== "" ? KeyCast.error : I18n.t("Win+Shift+K — вкл/выкл. Сочетания и особые клавиши внизу экрана; пока вводится пароль — ничего", "Win+Shift+K turns it on and off. Shortcuts and special keys at the bottom of the screen; nothing while a password is typed")
            checked: Config.keycast.enabled
            onToggled: v => Config.keycast.enabled = v
        }
        CatToggle {
            present: Config.keycast.enabled
            label: I18n.t("И набираемый текст", "Typing too")
            hint: I18n.t("Буквы по клавишам (латиницей — раскладку клавиатура не сообщает)", "Letters by key (Latin: the keyboard does not report the layout)")
            checked: Config.keycast.text
            onToggled: v => Config.keycast.text = v
        }
    }
    CatGroup {
        name: "recording-more"
        title: I18n.t("Кодек записи", "Recording codec")
        icon: "chip"
        CatChoice {
            label: I18n.t("Кодек", "Codec")
            hint: I18n.t("«Авто»: NVENC на NVIDIA, иначе VA-API, иначе x264 на процессоре", "“Auto”: NVENC on NVIDIA, else VA-API, else x264 on the CPU")
            model: [
                {
                    "label": I18n.t("Авто", "Auto"),
                    "value": "auto"
                },
                {
                    "label": "NVENC",
                    "value": "nvenc"
                },
                {
                    "label": "VA-API",
                    "value": "vaapi"
                },
                {
                    "label": "x264",
                    "value": "x264"
                }
            ]
            currentValue: Config.capture.recordCodec
            onActivated: v => Config.capture.recordCodec = v
        }
    }
    CatGroup {
        name: "skin"
        title: I18n.t("Вид рамки", "Frame look")
        icon: "image"
        CatCustom {
            wide: true
            CatBox {
                Grid {
                    width: parent.width
                    columns: width > Theme.u * 360 ? 3 : 1
                    spacing: Theme.u * 4
                    Repeater {
                        model: page.skins
                        PxBox {
                            id: card
                            required property var modelData
                            readonly property bool current: (Config.capture.skin || "ropes") === modelData.id
                            width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                            height: cardCol.implicitHeight + Theme.u * 8
                            sunken: current
                            color: current ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.3) : cardMouse.containsMouse ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.1) : Theme.tone("face", Theme.p5For(parent))
                            Column {
                                id: cardCol
                                x: Theme.u * 4
                                y: Theme.u * 4
                                width: parent.width - Theme.u * 8
                                spacing: Theme.u * 2
                                Image {
                                    width: parent.width
                                    height: Math.round(width * 9 / 16)
                                    // in the grimoire (or a dress): an engraving the right way round, not a negative
                                    layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
                                    layer.effect: GrimoirePhoto {}
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                    cache: false
                                    source: page.stamp > 0 ? "file://" + Config.cacheDir + "/capture-" + card.modelData.id + ".png?" + page.stamp : ""
                                }
                                PxText {
                                    text: (card.current ? "♡ " : "") + card.modelData.label
                                    font.bold: true
                                }
                                PxText {
                                    width: parent.width
                                    text: card.modelData.hint
                                    kind: "tiny"
                                    dim: true
                                    wrapMode: Text.Wrap
                                }
                            }
                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.capture.skin = card.modelData.id
                            }
                        }
                    }
                }
            }
        }
        // the picked skin in motion
        CatCustom {
            wide: true
            CatBox {
                // the picked skin in motion
                PxPreview {
                    width: Math.min(parent.width, Theme.u * 200)
                    scene: "CaptureSkin"
                    variant: Config.capture.skin || "ropes"
                    caption: (page.skins.find(s => s.id === (Config.capture.skin || "ropes")) || {}).label || ""
                    closable: false
                    sceneHeight: Theme.u * 62
                }
            }
        }
        CatToggle {
            present: Config.capture.skin !== "ropes"
            label: I18n.t("Цвета темы", "Theme colours")
            hint: I18n.t("выключено — классическая NGO-палитра (розовый, фиолетовый, голубой)", "Off: the classic NGO palette (pink, purple, cyan)")
            checked: Config.capture.themeColors
            onToggled: c => Config.capture.themeColors = c
        }
        CatButton {
            text: I18n.t("Скриншот области", "Region screenshot")
            icon: "image"
            onClicked: {
                page.nav.settingsOpen = false;
                Capture.screenshot();
            }
            CatButton {
                text: I18n.t("Запись области", "Region recording")
                icon: "play"
                onClicked: {
                    page.nav.settingsOpen = false;
                    Capture.record();
                }
            }
        }
        CatNote {
            dim: true
            text: I18n.t("Снимки — в «Изображения → Screenshots», по месяцам, записи — в «Видео».", "Shots go to Pictures → Screenshots, by month; recordings to Videos.")
        }
    }
}
