// The settings once in LyricsPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    heading: I18n.t("Лирика", "Lyrics")
    subtitle: I18n.t("Строка песни на панели или в Нимбе. Работает с любым плеером: Spotify, браузер, mpv.", "The song's current line on the bar or in the Halo. Any player: Spotify, a browser, mpv.")
    id: page
    CatGroup {
        name: "display"
        title: I18n.t("Показ", "Display")
        icon: "mic"
        CatToggle {
            label: I18n.t("Включено", "Enabled")
            hint: I18n.t("Win+Alt+Y — быстро спрятать/показать", "Win+Alt+Y toggles lyrics")
            checked: Config.lyrics.enabled
            onToggled: c => Config.lyrics.enabled = c
        }
        // every screen: the line in its bar, in the Halo (Config.lyrics.haloScreens) or nowhere
        // (Config.lyrics.screens: empty = every screen shows it)
        CatRepeat {
            model: Quickshell.screens
            delegate: Component {
                CatCustom {
                    id: placeRow
                    required property var modelData
                    readonly property string name: modelData.name
                    readonly property var shown: Config.lyrics.screens || []
                    readonly property string place: shown.length && !shown.includes(name) ? "none" : (Config.lyrics.haloScreens || []).includes(name) ? "halo" : "bar"
                    function choose(v) {
                        const halo = (Config.lyrics.haloScreens || []).filter(s => s !== name);
                        if (v === "halo")
                            halo.push(name);
                        Config.lyrics.haloScreens = halo;
                        if (v === "none")
                            Config.lyrics.screens = (shown.length ? shown : Quickshell.screens.map(s => s.name)).filter(s => s !== name);
                        else if (shown.length && !shown.includes(name))
                            Config.lyrics.screens = shown.concat([name]);
                    }
                    label: I18n.t("Где лирика: ", "Lyrics on ") + name
                    hint: place === "halo" && !Halo.on(name) ? I18n.t("Нимб на этом экране выключен — лирика останется в панели", "The Halo is off on this display: the lyrics stay in the bar") : ""
                    CatBox {
                        PxSegmented {
                            model: [
                                {
                                    "label": I18n.t("В панели", "In the bar"),
                                    "value": "bar"
                                },
                                {
                                    "label": I18n.t("В Нимбе", "In the Halo"),
                                    "value": "halo"
                                },
                                {
                                    "label": I18n.t("Нигде", "Nowhere"),
                                    "value": "none"
                                }
                            ]
                            currentValue: placeRow.place
                            onActivated: v => placeRow.choose(v)
                        }
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Рядом с текстом", "Beside the lyrics")
            model: [
                {
                    label: I18n.t("Нота", "Music note"),
                    value: "note"
                },
                {
                    label: I18n.t("Обложка", "Album cover"),
                    value: "cover"
                }
            ]
            currentValue: Config.lyrics.artwork
            onActivated: v => Config.lyrics.artwork = v
        }
        CatSlider {
            label: I18n.t("Сдвиг по времени", "Timing offset")
            hint: I18n.t("если текст спешит или опаздывает", "Adjust if the lyrics are early or late")
            from: -2000
            to: 2000
            stepSize: 50
            value: Config.lyrics.offsetMs
            suffix: I18n.t(" мс", " ms")
            onMoved: v => Config.lyrics.offsetMs = v
        }
        CatToggle {
            label: I18n.t("Печатная машинка", "Typewriter animation")
            hint: I18n.t("Строка появляется по буквам, как на машинке.", "A line appears letter by letter, like a typewriter.")
            checked: Config.lyrics.typewriter
            onToggled: c => Config.lyrics.typewriter = c
        }
        CatToggle {
            label: I18n.t("Слово за словом", "Word by word")
            hint: I18n.t("Строка появляется по словам, когда их поют.", "The line appears word by word as it is sung.")
            checked: Config.lyrics.byWord !== false
            onToggled: c => Config.lyrics.byWord = c
        }
        CatToggle {
            present: Config.lyrics.byWord !== false
            label: I18n.t("Слова на бит", "Words on the beat")
            hint: I18n.t("Слова появляются в такт музыке и подпрыгивают.", "Words come up on the beat with a hop.")
            checked: Config.lyrics.onBeat !== false
            onToggled: c => Config.lyrics.onBeat = c
        }
        CatChoice {
            present: Config.lyrics.byWord !== false
            label: I18n.t("Слова чуть раньше", "Words ahead")
            hint: I18n.t("слово появляется немного раньше, чем его поют, — успеваешь прочитать и подпеть", "Each word shows a moment before it is sung, so you can read it and sing along")
            model: [
                {"label": I18n.t("нет", "no"), "value": 0},
                {"label": "0,15 с", "value": 150},
                {"label": "0,25 с", "value": 250},
                {"label": "0,4 с", "value": 400}
            ]
            currentValue: Config.lyrics.wordLeadMs
            onActivated: v => Config.lyrics.wordLeadMs = v
        }
        CatField {
            label: I18n.t("Любимый плеер", "Preferred player")
            hint: I18n.t("если играет несколько — брать этот", "Prefer this player when several are playing")
            text: Config.lyrics.preferPlayer
            onEdited: Config.lyrics.preferPlayer = text
        }
    }
    // the line dims with the volume (services/LyricsGlow)
    CatGroup {
        name: "brightness-follows-volume"
        id: glowGroup
        title: I18n.t("Яркость от громкости", "Brightness follows the volume")
        advanced: true
        icon: "sun"
        CatChoice {
            label: I18n.t("Что слушать", "Follow")
            hint: ({
                    "off": I18n.t("строка всегда яркая", "the line is always bright"),
                    "auto": I18n.t("RØDECaster подключён — фейдер пульта, иначе — реальная громкость плеера", "a RØDECaster plugged in: its fader; otherwise the player's real loudness"),
                    "rode": I18n.t("фейдер RØDECaster: опустишь — строка гаснет до минимума", "the RØDECaster fader: pull it down and the line fades to the floor"),
                    "level": I18n.t("как громко плеер играет на самом деле: его ползунок в микшере, общая громкость и тихие места песни", "how loud the player really plays: its slider in the mixer, the master volume and the song's quiet parts")
                })[Config.lyrics.glow] || ""
            model: [
                {
                    "label": I18n.t("Выкл", "Off"),
                    "value": "off"
                },
                {
                    "label": I18n.t("Авто", "Auto"),
                    "value": "auto"
                },
                {
                    "label": "RØDECaster",
                    "value": "rode"
                },
                {
                    "label": I18n.t("Громкость", "Loudness"),
                    "value": "level"
                }
            ]
            currentValue: Config.lyrics.glow
            onActivated: v => Config.lyrics.glow = v
        }
        CatSlider {
            present: Config.lyrics.glow !== "off"
            label: I18n.t("Не тусклее", "Never dimmer than")
            hint: I18n.t("от 30 до 100 %", "30 to 100 %")
            from: 30
            to: 100
            stepSize: 5
            value: Config.lyrics.glowFloor
            suffix: "%"
            onMoved: v => Config.lyrics.glowFloor = Math.round(v)
        }
        CatChoice {
            present: Config.lyrics.glow !== "off" && LyricsGlow.rodePresent
            label: I18n.t("Где читать фейдер", "Where the fader is read")
            hint: I18n.t("Откуда брать громкость пульта. Обычно подходит «Основной микс».", "Where to read the console's volume from. Main mix usually fits.")
            combo: true
            // every pair the console's multitrack has (LyricsGlow.taps)
            model: LyricsGlow.tapList.map(t => ({
                        "label": t === "main" ? I18n.t("Основной микс", "Main mix") : "Multitrack " + LyricsGlow.taps[t].join("/").replace(/\/AUX/, "/"),
                        "value": t
                    }))
            currentValue: Config.lyrics.glowTap
            onActivated: v => Config.lyrics.glowTap = v
        }
        CatCustom {
            present: Config.lyrics.glow !== "off"
            label: I18n.t("Сейчас", "Now")
            hint: LyricsGlow.numpyMissing ? I18n.t("для фейдера RØDECaster нужен python-numpy — пока строка следует за громкостью", "the RØDECaster fader needs python-numpy — the line follows the loudness for now") : !LyricsGlow.measuring ? I18n.t("измеряется, пока играет песня с текстом", "measured while a song with lyrics plays") : (LyricsGlow.effective === "rode" ? I18n.t("двигай фейдер — число должно идти за ним; потом отметь верх и низ", "move the fader — the number should follow; then mark the top and the bottom") : I18n.t("подвигай громкость плеера и отметь, где ярко, а где тускло", "move the player's volume and mark where it's bright and where it's dim"))
            CatBox {
                Column {
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        text: (LyricsGlow.effective === "rode" ? I18n.t("фейдер ", "fader ") : I18n.t("уровень ", "level ")) + (isNaN(LyricsGlow.db) ? "—" : (LyricsGlow.db <= -89 ? "−∞" : LyricsGlow.db.toFixed(1)) + I18n.t(" дБ", " dB")) + (LyricsGlow.effective === "rode" && LyricsGlow.track ? I18n.t(" (дорожка ", " (track ") + LyricsGlow.track + ")" : "") + "  →  " + Math.round(LyricsGlow.opacity * 100) + "%"
                        font.bold: true
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            compact: true
                            icon: "arrowUp"
                            enabled: !isNaN(LyricsGlow.db)
                            text: I18n.t("Это верх (100 %)", "This is the top (100 %)")
                            onClicked: LyricsGlow.markTop()
                        }
                        PxButton {
                            compact: true
                            icon: "arrowDown"
                            enabled: !isNaN(LyricsGlow.db)
                            text: I18n.t("Это низ (минимум)", "This is the bottom (floor)")
                            onClicked: LyricsGlow.markBottom()
                        }
                        PxButton {
                            compact: true
                            flat: true
                            icon: "refresh"
                            text: I18n.t("Сбросить", "Reset")
                            onClicked: LyricsGlow.resetCalibration()
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "sources"
        title: I18n.t("Источники", "Sources")
        advanced: true
        icon: "search"
        CatNote {
            dim: true
            text: I18n.t("Источники проверяются по порядку, пока не найдётся текст с таймкодами. Чужой текст не подставится.", "Sources are tried in order until timed lyrics turn up. Lyrics of another song never slip in.")
        }
        CatRepeat {
            id: srcList
            readonly property var info: ({
                    "local": [I18n.t("Локальные .lrc", "Local .lrc files"), I18n.t("файл .lrc рядом с треком или ~/.lyrics/Артист - Песня.lrc", ".lrc next to the track or ~/.lyrics/Artist - Title.lrc")],
                    "player": [I18n.t("Текст от плеера", "Lyrics from the player"), I18n.t("если плеер сам отдаёт текст (MPRIS xesam:asText)", "When the player publishes lyrics itself (MPRIS xesam:asText)")],
                    "lrclib": ["lrclib.net", I18n.t("синхронный текст, открытая база", "synced lyrics, open database")],
                    "netease": ["NetEase Cloud Music", I18n.t("синхронный текст, много азиатской и мировой музыки", "synced lyrics, large Asian and worldwide catalogue")],
                    "kugou": ["Kugou", I18n.t("синхронный текст, большой каталог (Китай, K-pop, мировые хиты)", "synced lyrics, large catalogue (China, K-pop, worldwide hits)")],
                    "qq": ["QQ Music", I18n.t("синхронный текст, нужен curl", "synced lyrics, needs curl")],
                    "amll": ["AMLL TTML DB", I18n.t("тексты, выверенные по словам вручную; ищется по треку Spotify/NetEase или названию", "hand-timed lyrics; found by the Spotify/NetEase track or the name")],
                    "lrccx": ["lrc.cx", I18n.t("синхронный текст, большое зеркало китайских магазинов и Apple Music", "synced lyrics, a large mirror of Chinese stores and Apple Music")],
                    "musixmatch": ["Musixmatch", I18n.t("самый большой каталог; в некоторых странах без VPN не отвечает", "the largest catalogue; refuses some countries without a VPN")],
                    "ovh": ["lyrics.ovh", I18n.t("только текст без таймкодов, запасной вариант", "plain text only, last resort")]
                })
            // enabled sources in their order, then the switched-off ones
            readonly property var order: {
                const on = (Config.lyrics.sources || []).filter(x => info[x]);
                return on.concat(Lyrics.allSources.filter(x => !on.includes(x)));
            }
            function move(id, dir) {
                const on = (Config.lyrics.sources || []).slice();
                const i = on.indexOf(id), j = i + dir;
                if (i < 0 || j < 0 || j >= on.length)
                    return;
                on[i] = on[j];
                on[j] = id;
                Config.lyrics.sources = on;
            }
            model: order
            delegate: Component {
                CatCustom {
                    id: srcRow
                    required property string modelData
                    required property int index
                    readonly property bool on: (Config.lyrics.sources || []).includes(modelData)
                    label: (on ? (index + 1) + ". " : "") + srcList.info[modelData][0]
                    hint: srcList.info[modelData][1]
                    CatBox {
                        Row {
                            spacing: Theme.u * 2
                            PxToggle {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: srcRow.on
                                onToggled: c => {
                                    const cur = (Config.lyrics.sources || []).filter(x => x !== srcRow.modelData);
                                    if (c)
                                        cur.push(srcRow.modelData);
                                    Config.lyrics.sources = cur;
                                }
                            }
                            PxButton {
                                visible: srcRow.on
                                compact: true
                                icon: "arrowUp"
                                enabled: srcRow.index > 0
                                onClicked: srcList.move(srcRow.modelData, -1)
                            }
                            PxButton {
                                visible: srcRow.on
                                compact: true
                                icon: "arrowDown"
                                enabled: srcRow.index < (Config.lyrics.sources || []).length - 1
                                onClicked: srcList.move(srcRow.modelData, 1)
                            }
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "current"
        title: I18n.t("Сейчас", "Current")
        icon: "music"
        CatNote {
            text: Lyrics.player ? "♪ " + Lyrics.title + " — " + Lyrics.artist + "  (" + (Lyrics.player.identity || "?") + ")" : I18n.t("ничего не играет", "Nothing is playing")
        }
        CatNote {
            text: ({
                    "idle": I18n.t("ждём трек…", "Waiting for a track…"),
                    "loading": I18n.t("ищу текст…", "Searching for lyrics…"),
                    "ok": I18n.t("синхронный текст: ", "Synced lyrics: ") + Lyrics.lines.length + I18n.t(" строк", " lines"),
                    "plain": I18n.t("есть только текст без таймкодов", "Only unsynchronized lyrics are available"),
                    "instrumental": I18n.t("инструментал ♪", "Instrumental ♪"),
                    "notfound": I18n.t("текст не найден", "Lyrics not found"),
                    "error": I18n.t("нет сети / источники недоступны", "Offline / sources unavailable")
                })[Lyrics.status] || Lyrics.status
            dim: true
        }
        CatNote {
            present: !!Lyrics.player
            textKind: "tiny"
            dim: true
            text: I18n.t("ищу как: ", "searching as: ") + Lyrics.cleaned.artist + " — " + Lyrics.cleaned.title + (Lyrics.source ? I18n.t(" · источник: ", " · source: ") + Lyrics.source : "")
        }
        CatButton {
            text: I18n.t("Найти заново", "Search again")
            icon: "refresh"
            onClicked: Lyrics.refetch()
            CatButton {
                text: Lyrics.visibleToggle ? I18n.t("Скрыть", "Hide") : I18n.t("Показать", "Show")
                icon: "mic"
                onClicked: Lyrics.visibleToggle = !Lyrics.visibleToggle
            }
        }
    }
    CatGroup {
        name: "search-by-title"
        title: I18n.t("Найти по названию", "Search by title")
        icon: "search"
        present: !!Lyrics.player && Lyrics.title !== ""
        CatNote {
            dim: true
            text: I18n.t("Если нашлось не то или ничего: введи название (и артиста), выбери результат — он запомнится для этого трека.", "Wrong or no lyrics? Type the title (and artist) and pick a result — it is remembered for this track.")
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxField {
                        id: q
                        width: parent.width - searchButton.width - Theme.u * 3
                        placeholder: Lyrics.cleaned.artist + " " + Lyrics.cleaned.title
                        onAccepted: Lyrics.search(text || placeholder)
                    }
                    PxButton {
                        id: searchButton
                        text: Lyrics.searching ? "…" : I18n.t("Искать", "Search")
                        icon: "search"
                        enabled: !Lyrics.searching
                        onClicked: Lyrics.search(q.text || q.placeholder)
                    }
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Lyrics.results
                    PxBox {
                        id: res
                        required property var modelData
                        // what a click did (#34): fetching its lyrics, or it turned out to have none
                        readonly property bool busy: Lyrics.picking !== "" && Lyrics.picking === modelData.uid
                        readonly property bool failed: !!Lyrics.pickFailed[modelData.uid]
                        width: parent.width
                        height: resCol.implicitHeight + Theme.u * 6
                        opacity: failed ? 0.55 : 1
                        color: busy ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.3) : resMouse.containsMouse && !failed ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.15) : Theme.tone("face", Theme.p5For(parent))
                        Column {
                            id: resCol
                            x: Theme.u * 4
                            y: Theme.u * 3
                            width: parent.width - Theme.u * 8
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: res.modelData.title + " — " + res.modelData.artist
                                font.bold: true
                            }
                            PxText {
                                kind: "tiny"
                                dim: true
                                text: res.modelData.source + " · " + (res.busy ? I18n.t("загружаю текст…", "fetching the lyrics…") : res.failed ? I18n.t("текста у этого результата нет", "this one has no lyrics") : res.modelData.data ? (res.modelData.synced ? I18n.t("с таймкодами", "synced") : I18n.t("без таймкодов", "plain")) : I18n.t("текст загрузится при выборе", "lyrics load when picked")) + (res.modelData.duration ? " · " + Math.floor(res.modelData.duration / 60) + ":" + String(Math.round(res.modelData.duration % 60)).padStart(2, "0") : "")
                            }
                        }
                        MouseArea {
                            id: resMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !res.failed && Lyrics.picking === ""
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lyrics.pick(res.modelData)
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "song-lyrics"
        title: I18n.t("Текст песни", "Song lyrics")
        icon: "music"
        present: Lyrics.plainText !== ""
        CatNote {
            text: Lyrics.plainText
        }
    }
}
