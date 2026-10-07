pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// System sounds: every angelOS sound one by one (services/Sounds, Config.y2k.soundTweaks):
// on/off, its own volume, which sound it plays (its own, another event's, a file of
// yours), clicks per mouse button with a release tick, typing, quiet hours and quiet
// over fullscreen games. The newer events start switched off.
PxPage {
    id: page

    heading: I18n.t("Звуки системы", "System sounds")
    subtitle: I18n.t("Каждый звук по отдельности: включить, сделать тише или громче, поставить другой звук или свой файл. Клики, клавиши, окна, столы, блокировка.", "Every sound on its own: switch it, make it quieter or louder, give it another sound or a file of yours. Clicks, keys, windows, desks, the lock.")

    readonly property var labels: ({
            "startup": [I18n.t("Вход", "Startup"), I18n.t("вместе с загрузочным экраном", "With the loading screen")],
            "notify": [I18n.t("Уведомление", "Notification"), I18n.t("не звучит в «Не беспокоить»", "Silent in Do not disturb")],
            "error": [I18n.t("Важное уведомление", "Urgent notification"), ""],
            "wallpaper": [I18n.t("Смена обоев", "Wallpaper change"), ""],
            "open": [I18n.t("Окна angelOS", "angelOS windows"), I18n.t("настройки, поиск — милая мелочь", "Settings, search — a cute one")],
            "toggle": [I18n.t("Переключатель", "Switch"), I18n.t("милая мелочь", "A cute one")],
            "screenshot": [I18n.t("Скриншот", "Screenshot"), I18n.t("вместо обычного уведомления", "Instead of the usual notification")],
            "volume": [I18n.t("Громкость", "Volume"), I18n.t("милая мелочь", "A cute one")],
            "windowOpen": [I18n.t("Окно открылось", "A window opened"), I18n.t("любое приложение", "Any app")],
            "windowClose": [I18n.t("Окно закрылось", "A window closed"), I18n.t("милая мелочь", "A cute one")],
            "workspace": [I18n.t("Смена стола", "Desk switch"), I18n.t("лёгкий взмах при переходе на другой стол", "A soft swish when you go to another desk")],
            "lock": [I18n.t("Блокировка", "Lock"), ""],
            "unlock": [I18n.t("Разблокировка", "Unlock"), ""],
            "usbIn": [I18n.t("USB подключено", "USB plugged in"), I18n.t("флешка, мышь, геймпад; хаб со всем содержимым — один звук", "A stick, a mouse, a gamepad; a hub with everything on it is one sound")],
            "usbOut": [I18n.t("USB отключено", "USB unplugged"), I18n.t("после выхода из сна молчит: устройства не выдёргивали", "Quiet after waking up: nothing was pulled out")],
            "shutdown": [I18n.t("Выход и выключение", "Log out and power off"), I18n.t("успевает доиграть перед выходом", "Plays out before the session ends")],
            "click": [I18n.t("Клик", "Click"), Sounds.clickStatus === "noperm" ? I18n.t("нет доступа к мыши (группа input) — клики не слышно", "No access to the mouse (the input group): clicks stay silent") : I18n.t("щелчок на клик, во всех окнах", "A tick on a click, in every window")],
            "clickRight": [I18n.t("Правый клик — свой звук", "Right click — its own sound"), I18n.t("выключено: правая кнопка щёлкает как левая", "Off: the right button ticks like the left")],
            "key": [I18n.t("Клавиши", "Keys"), I18n.t("звук набора на каждую клавишу; слышно только тебе", "A typing tick on every key; only you hear it")],
            "angel": [I18n.t("Ангелочек говорит", "The angel speaks"), ""],
            "demon": [I18n.t("Демоница говорит", "The demon speaks"), ""],
            "voice": [I18n.t("Голоса (пип-пип)", "Voices (pip-pip)"), I18n.t("как в Undertale: писк на каждую букву", "Like Undertale: a pip for every letter")],
            "choir": [I18n.t("Хор ангела", "The angel's choir"), I18n.t("вместе с лучами", "With the rays")],
            "crack": [I18n.t("Удар по стеклу", "The glass punch"), ""],
            "rocks": [I18n.t("Тряска и камни", "Quake and rocks"), ""],
            "shatter": [I18n.t("Экран ломается", "The screen breaks"), ""],
            "bark": [I18n.t("Цербер лает", "Cerberus barks"), I18n.t("когда Колесо Ада выпускает щенка", "When the Wheel of Hell lets the puppy out")],
            "achievement": [I18n.t("Достижение", "Achievement"), I18n.t("когда выезжает карточка «Достижение получено»", "When the “Achievement earned” card slides in")],
            "stars": [I18n.t("Звёзды ✦", "Stars ✦"), I18n.t("награды Небес: вход дня, задания, пропуск — тихий перезвон", "Heaven's rewards: the day's login, tasks, the pass — a quiet chime")],
            "harp": [I18n.t("Арфа", "The harp"), I18n.t("ПКМ-меню «Арфа»: струна звенит под курсором, при открытии — глиссандо", "The Harp right-click menu: a string rings under the pointer, a glissando as it opens")]
        })
    function labelOf(id) {
        return (labels[id] || [id])[0];
    }
    function hintOf(id) {
        return (labels[id] || ["", ""])[1] || "";
    }
    // what a row can play: its own sound, any other event's, a custom file, a file from anywhere
    function choices(id) {
        const own = [{
                "label": I18n.t("Свой звук", "Its own"),
                "value": ""
            }];
        // the demon's own sounds stay hers: not offered in heaven
        const hellish = ["demon", "crack", "rocks", "shatter", "bark"];
        const others = Sounds.events.filter(e => e !== id && e !== "voice" && labels[e] && (Angel.hellShown || !hellish.includes(e))).map(e => ({
                    "label": "♪ " + labelOf(e),
                    "value": e
                }));
        const files = Sounds.customFiles.map(f => ({
                    "label": "♫ " + f,
                    "value": "file:" + Sounds.customDir + "/" + f
                }));
        const cur = Sounds.soundOf(id);
        if (cur.startsWith("file:") && !files.some(f => f.value === cur))
            files.push({
                "label": "♫ " + cur.split("/").pop(),
                "value": cur
            });
        return own.concat(files).concat(others).concat([{
                "label": I18n.t("Выбрать файл…", "Pick a file…"),
                "value": "__pick"
            }]);
    }
    property string pickFor: ""
    Connections {
        target: Sounds
        function onPicked(path) {
            if (page.pickFor) {
                Sounds.setTweak(page.pickFor, "sound", "file:" + path);
                Sounds.preview(page.pickFor);
            }
            page.pickFor = "";
        }
    }
    Component.onCompleted: Sounds.rescanCustom()

    // one event: the switch, its sound, listen, its volume, back to defaults
    Component {
        id: eventRow
        SettingRow {
            id: row
            required property string modelData
            readonly property var t: Sounds.tweak(modelData)
            enabled: Config.y2k.sounds
            opacity: enabled ? 1 : 0.5
            label: page.labelOf(modelData)
            hint: page.hintOf(modelData)
            Column {
                width: parent.width
                spacing: Theme.u * 2
                Row {
                    spacing: Theme.u * 3
                    PxToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Sounds.isOn(row.modelData)
                        onToggled: c => Sounds.setOn(row.modelData, c)
                    }
                    PxCombo {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 80
                        model: page.choices(row.modelData)
                        currentValue: Sounds.soundOf(row.modelData)
                        onActivated: v => {
                            if (v === "__pick") {
                                page.pickFor = row.modelData;
                                Sounds.pickFile();
                                return;
                            }
                            Sounds.setTweak(row.modelData, "sound", v || null);
                            Sounds.preview(row.modelData);
                        }
                    }
                    PxButton {
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        icon: "play"
                        onClicked: Sounds.preview(row.modelData)
                    }
                    PxButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.t.vol !== undefined || !!row.t.sound
                        compact: true
                        icon: "refresh"
                        onClicked: {
                            Sounds.setTweak(row.modelData, "vol", null);
                            Sounds.setTweak(row.modelData, "sound", null);
                        }
                    }
                }
                PxSlider {
                    width: Math.min(parent.width, Theme.u * 150)
                    from: 0
                    to: 150
                    stepSize: 5
                    suffix: " %"
                    live: false
                    value: Math.round((row.t.vol === undefined ? 1 : row.t.vol) * 100)
                    onReleased: v => {
                        Sounds.setTweak(row.modelData, "vol", v === 100 ? null : v / 100);
                        Sounds.preview(row.modelData);
                    }
                }
            }
        }
    }

    PxGroup {
        name: "general"
        width: parent.width
        title: I18n.t("Общее", "General")
        icon: "speaker"
        SettingRow {
            label: I18n.t("Звуки angelOS", "angelOS sounds")
            hint: I18n.t("молчат в стрим-режиме", "Quiet in stream mode")
            PxToggle {
                checked: Config.y2k.sounds
                onToggled: c => Config.y2k.sounds = c
            }
        }
        SettingRow {
            label: I18n.t("Набор", "Sound pack")
            hint: I18n.t("новые звуки (клавиши, столы, блокировка) в Overdose берутся из Y2K", "The newer ones (keys, desks, the lock) come from Y2K in Overdose")
            PxSegmented {
                model: [
                    {
                        "label": "Y2K",
                        "value": "y2k"
                    },
                    {
                        "label": "Overdose ♡",
                        "value": "overdose"
                    }
                ]
                currentValue: Config.y2k.soundPack
                onActivated: v => {
                    Config.y2k.soundPack = v;
                    Sounds.preview("notify");
                }
            }
        }
        SettingRow {
            label: I18n.t("Громкость", "Volume")
            hint: I18n.t("у каждого звука ниже ещё своя", "Each sound below has its own on top")
            PxSlider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 5
                suffix: " %"
                value: Math.round(Config.y2k.soundVolume * 100)
                live: false
                onReleased: v => {
                    Config.y2k.soundVolume = v / 100;
                    Sounds.preview("notify");
                }
            }
        }
        SettingRow {
            label: I18n.t("Милые мелочи", "Cute little sounds")
            hint: I18n.t("переключатели, окна angelOS, скриншоты, громкость, закрытие окон — разом", "Switches, angelOS windows, screenshots, volume, closing windows — all at once")
            PxToggle {
                checked: Config.y2k.cuteSounds
                onToggled: c => Config.y2k.cuteSounds = c
            }
        }
        SettingRow {
            label: I18n.t("Тихо в играх", "Quiet in games")
            hint: I18n.t("клики и клавиши молчат, пока на экране полноэкранное окно", "Clicks and keys stay silent over a fullscreen window")
            PxToggle {
                checked: Config.y2k.quietFullscreen
                onToggled: c => Config.y2k.quietFullscreen = c
            }
        }
        SettingRow {
            label: I18n.t("Тихие часы", "Quiet hours")
            hint: I18n.t("ни одного звука в эти часы (кнопки «послушать» работают)", "Not a sound in these hours (the listen buttons still play)")
            Row {
                spacing: Theme.u * 3
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Config.y2k.quietHours
                    onToggled: c => Config.y2k.quietHours = c
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("с", "from")
                    dim: !Config.y2k.quietHours
                }
                PxSpin {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: Config.y2k.quietHours
                    from: 0
                    to: 23
                    suffix: ":00"
                    value: Config.y2k.quietFrom
                    onMoved: v => Config.y2k.quietFrom = v
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("до", "to")
                    dim: !Config.y2k.quietHours
                }
                PxSpin {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: Config.y2k.quietHours
                    from: 0
                    to: 23
                    suffix: ":00"
                    value: Config.y2k.quietTo
                    onMoved: v => Config.y2k.quietTo = v
                }
            }
        }
    }

    PxGroup {
        name: "mouse-keyboard"
        width: parent.width
        title: I18n.t("Мышь и клавиатура", "Mouse and keyboard")
        advanced: true
        icon: "mouse"
        Repeater {
            model: ["click"]
            delegate: eventRow
        }
        SettingRow {
            enabled: Config.y2k.sounds
            opacity: enabled ? 1 : 0.5
            label: I18n.t("Какие кнопки щёлкают", "Which buttons tick")
            Row {
                spacing: Theme.u * 6
                Repeater {
                    model: [["left", I18n.t("левая", "left")], ["right", I18n.t("правая", "right")], ["middle", I18n.t("колесо", "wheel")]]
                    PxCheck {
                        required property var modelData
                        text: modelData[1]
                        checked: (Config.y2k.clickButtons || ["left", "right"]).includes(modelData[0])
                        onToggled: c => {
                            const l = (Config.y2k.clickButtons || ["left", "right"]).filter(b => b !== modelData[0]);
                            Config.y2k.clickButtons = c ? l.concat([modelData[0]]) : l;
                        }
                    }
                }
            }
        }
        SettingRow {
            enabled: Config.y2k.sounds
            opacity: enabled ? 1 : 0.5
            label: I18n.t("Щелчок при отпускании", "A tick on release")
            hint: I18n.t("второй, тише — как у настоящей мышки", "A second, quieter one — like a real mouse")
            PxToggle {
                checked: Config.y2k.clickRelease
                onToggled: c => Config.y2k.clickRelease = c
            }
        }
        Repeater {
            model: ["clickRight", "key"]
            delegate: eventRow
        }
        SettingRow {
            enabled: Config.y2k.sounds && Sounds.isOn("key")
            opacity: enabled ? 1 : 0.5
            label: I18n.t("Разные щелчки клавиш", "Varied key ticks")
            hint: I18n.t("три чуть разных звука вперемешку — не пулемёт", "Three slightly different ticks in turn — not a machine gun")
            PxToggle {
                checked: Sounds.tweak("key").vary !== false
                onToggled: c => Sounds.setTweak("key", "vary", c ? null : false)
            }
        }
    }

    PxGroup {
        name: "system-events"
        width: parent.width
        title: I18n.t("События системы", "System events")
        icon: "bell"
        Repeater {
            model: ["startup", "notify", "error", "windowOpen", "windowClose", "workspace", "usbIn", "usbOut", "open", "toggle", "harp", "screenshot", "volume", "wallpaper", "lock", "unlock", "shutdown"]
            delegate: eventRow
        }
    }

    PxGroup {
        name: "angel-demon"
        width: parent.width
        title: Angel.hellShown ? I18n.t("Ангел и демоница", "Angel and demon") : I18n.t("Ангелочек", "The angel")
        icon: "heart"
        SettingRow {
            label: I18n.t("Её голос", "Her voice")
            hint: I18n.t("доля от общей громкости для всего, что ниже", "A share of the volume for everything below")
            PxSlider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 5
                suffix: " %"
                live: false
                value: Math.round(Config.y2k.helperVolume * 100)
                onReleased: v => {
                    Config.y2k.helperVolume = v / 100;
                    Sounds.preview("voice");
                }
            }
        }
        Repeater {
            // the demon's own sounds (her lines, the glass, the rocks) only while she rules
            model: (Angel.hellShown ? ["angel", "demon", "voice", "choir", "crack", "rocks", "shatter", "bark"] : ["angel", "voice", "choir"]).concat(Story.enabled ? ["achievement", "stars"] : [])
            delegate: eventRow
        }
    }

    PxGroup {
        name: "your-own-sounds"
        width: parent.width
        title: I18n.t("Свои звуки", "Your own sounds")
        advanced: true
        icon: "folder"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Положи .ogg, .wav, .mp3 или .flac в папку ниже — они появятся в списке у каждого звука. Или «Выбрать файл…» прямо в списке.", "Drop .ogg, .wav, .mp3 or .flac files into the folder below — they show up in every sound's list. Or use “Pick a file…” right in the list.")
        }
        PxText {
            text: Sounds.customDir.replace(Config.home, "~") + "  ·  " + Sounds.customFiles.length + I18n.t(" файл(ов)", " file(s)")
            kind: "mono"
        }
        Row {
            spacing: Theme.u * 3
            PxButton {
                text: I18n.t("Открыть папку", "Open the folder")
                icon: "folder"
                onClicked: {
                    Quickshell.execDetached(["mkdir", "-p", Sounds.customDir]);
                    Shell.openPath(Sounds.customDir);
                }
            }
            PxButton {
                text: I18n.t("Обновить список", "Refresh the list")
                icon: "refresh"
                onClicked: Sounds.rescanCustom()
            }
        }
    }
}
