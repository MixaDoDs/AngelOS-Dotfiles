import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    heading: I18n.t("Лирика", "Lyrics")
    subtitle: I18n.t("Текущая строка песни посередине панели. Трек берётся из любого MPRIS-плеера (Spotify, браузер с YouTube, mpv…), текст ищется по названию песни в нескольких источниках. Клик по строке открывает эту страницу, правый клик ставит трек на паузу.", "The current lyric line appears in the bar. Any MPRIS player works (Spotify, a browser with YouTube, mpv…); lyrics are searched by the song title in several sources. Click the line to open this page; right-click pauses the track.")
    id: page

    PxGroup {
        name: "display"
        title: I18n.t("Показ", "Display")
        icon: "mic"
        width: parent.width
        SettingRow {
            label: I18n.t("Включено", "Enabled")
            hint: I18n.t("Mod+Alt+Y — быстро спрятать/показать", "Mod+Alt+Y toggles lyrics")
            PxToggle {
                checked: Config.lyrics.enabled
                onToggled: c => Config.lyrics.enabled = c
            }
        }
        SettingRow {
            label: I18n.t("На каких панелях", "Show on displays")
            hint: I18n.t("ничего не выбрано = на всех (где хватает места)", "No selection = all displays with enough space")
            Flow {
                width: parent.width
                spacing: Theme.u * 6
                Repeater {
                    model: Quickshell.screens
                    PxCheck {
                        required property var modelData
                        text: modelData.name
                        checked: (Config.lyrics.screens || []).includes(modelData.name)
                        onToggled: c => {
                            const l = (Config.lyrics.screens || []).filter(s => s !== modelData.name);
                            if (c)
                                l.push(modelData.name);
                            Config.lyrics.screens = l;
                        }
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Рядом с текстом", "Beside the lyrics")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Сдвиг по времени", "Timing offset")
            hint: I18n.t("если текст спешит или опаздывает", "Adjust if the lyrics are early or late")
            PxSlider {
                width: parent.width
                from: -2000
                to: 2000
                stepSize: 50
                value: Config.lyrics.offsetMs
                suffix: I18n.t(" мс", " ms")
                onMoved: v => Config.lyrics.offsetMs = v
            }
        }
        SettingRow {
            label: I18n.t("Печатная машинка", "Typewriter animation")
            PxToggle {
                checked: Config.lyrics.typewriter
                onToggled: c => Config.lyrics.typewriter = c
            }
        }
        SettingRow {
            label: I18n.t("Любимый плеер", "Preferred player")
            hint: I18n.t("если играет несколько — брать этот", "Prefer this player when several are playing")
            PxField {
                width: Theme.u * 90
                text: Config.lyrics.preferPlayer
                onEdited: Config.lyrics.preferPlayer = text
            }
        }
    }

    // the line dims with the volume (services/LyricsGlow)
    PxGroup {
        name: "brightness-follows-volume"
        id: glowGroup
        title: I18n.t("Яркость от громкости", "Brightness follows the volume")
        advanced: true
        icon: "sun"
        width: parent.width
        SettingRow {
            label: I18n.t("Что слушать", "Follow")
            hint: ({
                    "off": I18n.t("строка всегда яркая", "the line is always bright"),
                    "auto": I18n.t("RØDECaster подключён — фейдер пульта, иначе — реальная громкость плеера", "a RØDECaster plugged in: its fader; otherwise the player's real loudness"),
                    "rode": I18n.t("фейдер RØDECaster: опустишь — строка гаснет до минимума", "the RØDECaster fader: pull it down and the line fades to the floor"),
                    "level": I18n.t("как громко плеер играет на самом деле: его ползунок в микшере, общая громкость и тихие места песни", "how loud the player really plays: its slider in the mixer, the master volume and the song's quiet parts")
                })[Config.lyrics.glow] || ""
            PxSegmented {
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
        }
        SettingRow {
            visible: Config.lyrics.glow !== "off"
            label: I18n.t("Не тусклее", "Never dimmer than")
            hint: I18n.t("от 30 до 100 %", "30 to 100 %")
            PxSlider {
                width: Math.min(parent.width, Theme.u * 120)
                from: 30
                to: 100
                stepSize: 5
                value: Config.lyrics.glowFloor
                suffix: "%"
                onMoved: v => Config.lyrics.glowFloor = Math.round(v)
            }
        }
        SettingRow {
            visible: Config.lyrics.glow !== "off" && LyricsGlow.rodePresent
            label: I18n.t("Где читать фейдер", "Where the fader is read")
            hint: I18n.t("«Основной микс» и AUX0/1 — микс пульта после фейдеров, дорожку плеера в мультитреке угадывает сам; другая пара AUX — если хочешь сам указать, на какой дорожке играет плеер", "“Main mix” and AUX0/1: the console's mix after the faders, the player's multitrack track found by ear; another AUX pair: tell it yourself which track the player is on")
            PxCombo {
                width: Math.min(parent.width, Theme.u * 120)
                // every pair the console's multitrack has (LyricsGlow.taps)
                model: LyricsGlow.tapList.map(t => ({
                            "label": t === "main" ? I18n.t("Основной микс", "Main mix") : "Multitrack " + LyricsGlow.taps[t].join("/").replace(/\/AUX/, "/"),
                            "value": t
                        }))
                currentValue: Config.lyrics.glowTap
                onActivated: v => Config.lyrics.glowTap = v
            }
        }
        SettingRow {
            visible: Config.lyrics.glow !== "off"
            label: I18n.t("Сейчас", "Now")
            hint: LyricsGlow.numpyMissing ? I18n.t("для фейдера RØDECaster нужен python-numpy — пока строка следует за громкостью", "the RØDECaster fader needs python-numpy — the line follows the loudness for now") : !LyricsGlow.measuring ? I18n.t("измеряется, пока играет песня с текстом", "measured while a song with lyrics plays") : (LyricsGlow.effective === "rode" ? I18n.t("двигай фейдер — число должно идти за ним; потом отметь верх и низ", "move the fader — the number should follow; then mark the top and the bottom") : I18n.t("подвигай громкость плеера и отметь, где ярко, а где тускло", "move the player's volume and mark where it's bright and where it's dim"))
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

    PxGroup {
        name: "sources"
        title: I18n.t("Источники", "Sources")
        advanced: true
        icon: "search"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Проверяются по порядку (стрелки меняют его), пока не найдётся текст с таймкодами. Название чистится от «(Official Video)», «[MV]», «(премьера клипа)», feat., хэштегов и «- Topic»; «Артист - Песня» и «Артист «Песня»» из браузера разбираются на части. Найденная песня сверяется с играющей: название, артист (кириллица и латиница — одно и то же), длительность и версия (ремикс, live, sped up), так что чужой текст не подставится. Для sped up / slowed подходит текст оригинала — его время растягивается. Голосовые из Telegram и звонки трек у музыкального плеера не перехватывают.", "Tried in order (arrows change it) until synced lyrics turn up. Titles lose “(Official Video)”, “[MV]”, feat., hashtags and “- Topic”; “Artist - Song” and “Artist «Song»” from a browser are split. A found song is checked against the playing one: title, artist (Cyrillic and Latin spellings meet), length and version (remix, live, sped up), so someone else's lyrics don't slip in. A sped up / slowed version takes the original's lyrics, stretched in time. Telegram voice messages and calls never take the song from a music player.")
        }
        Repeater {
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
            SettingRow {
                id: srcRow
                required property string modelData
                required property int index
                readonly property bool on: (Config.lyrics.sources || []).includes(modelData)
                label: (on ? (index + 1) + ". " : "") + srcList.info[modelData][0]
                hint: srcList.info[modelData][1]
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

    PxGroup {
        name: "current"
        title: I18n.t("Сейчас", "Current")
        icon: "music"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: Lyrics.player ? "♪ " + Lyrics.title + " — " + Lyrics.artist + "  (" + (Lyrics.player.identity || "?") + ")" : I18n.t("ничего не играет", "Nothing is playing")
        }
        PxText {
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
        PxText {
            visible: !!Lyrics.player
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("ищу как: ", "searching as: ") + Lyrics.cleaned.artist + " — " + Lyrics.cleaned.title + (Lyrics.source ? I18n.t(" · источник: ", " · source: ") + Lyrics.source : "")
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Найти заново", "Search again")
                icon: "refresh"
                onClicked: Lyrics.refetch()
            }
            PxButton {
                text: Lyrics.visibleToggle ? I18n.t("Скрыть", "Hide") : I18n.t("Показать", "Show")
                icon: "mic"
                onClicked: Lyrics.visibleToggle = !Lyrics.visibleToggle
            }
        }
    }
    PxGroup {
        name: "search-by-title"
        title: I18n.t("Найти по названию", "Search by title")
        icon: "search"
        width: parent.width
        visible: !!Lyrics.player && Lyrics.title !== ""
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Если нашлось не то или ничего: введи название (и артиста), выбери результат — он запомнится для этого трека.", "Wrong or no lyrics? Type the title (and artist) and pick a result — it is remembered for this track.")
        }
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
                color: busy ? Theme.mix(Theme.face, Theme.accent, 0.3) : resMouse.containsMouse && !failed ? Theme.mix(Theme.face, Theme.accent, 0.15) : Theme.face
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

    PxGroup {
        name: "song-lyrics"
        width: parent.width
        title: I18n.t("Текст песни", "Song lyrics")
        visible: Lyrics.plainText !== ""
        icon: "music"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: Lyrics.plainText
            textFormat: Text.PlainText
        }
    }
}
